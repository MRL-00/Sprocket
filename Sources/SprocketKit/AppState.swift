import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(Observation)
import Observation
#endif

@MainActor @Observable
public final class AppState {
    public var user: GitHubUser?
    public var runs: [WorkflowRun] = []
    public var repositories: [Repository] = []
    public var rateLimit: RateLimit?
    public var lastRefresh: Date?
    public var density: Density = .comfortable
    public var filter: FilterTab = .all
    public var freeTextFilter: String = ""
    public var orgScope: String = "All organizations"
    public var isAuthed: Bool = false
    public var welcomeStep: Int = 1
    public var clientIDDraft: String = ""
    public var pollingCadenceSeconds: Int = 60
    public var mockMode: Bool = false

    /// Live device-flow state — non-nil while the user is completing the flow.
    public var pendingUserCode: String?
    public var pendingVerificationURL: URL?
    public var isSigningIn: Bool = false
    public var signInError: String?
    public var lastFetchError: String?

    public let client = GitHubClient()
    public let auth = AuthStore()

    public init() {}

    public var menuBarState: MenuBarState {
        MenuBarState.aggregate(runs: runs, authed: isAuthed, rateLimit: rateLimit)
    }

    public var visibleRuns: [WorkflowRun] {
        let filtered: [WorkflowRun]
        switch filter {
        case .all:     filtered = runs
        case .running: filtered = runs.filter { $0.effective.isLive }
        case .failing: filtered = runs.filter { $0.effective.isFailure }
        case .recent:  filtered = runs.sorted { $0.startedAt > $1.startedAt }
        }
        guard !freeTextFilter.isEmpty else { return filtered }
        let q = freeTextFilter.lowercased()
        return filtered.filter {
            $0.repo.lowercased().contains(q)
            || $0.workflowName.lowercased().contains(q)
            || $0.displayTitle.lowercased().contains(q)
            || $0.branch.lowercased().contains(q)
        }
    }

    public var counts: (all: Int, running: Int, failing: Int) {
        var running = 0, failing = 0
        for r in runs {
            if r.effective.isLive { running += 1 }
            if r.effective.isFailure { failing += 1 }
        }
        return (runs.count, running, failing)
    }

    public func loadMock() {
        self.user = MockData.user
        self.runs = MockData.runs
        self.repositories = MockData.repositories
        self.rateLimit = MockData.rateLimit
        self.lastRefresh = Date()
        self.isAuthed = true
        self.mockMode = true
    }

    /// Called once on launch: pull saved credentials + Client ID, set them on
    /// the client, and refresh data if signed in.
    public func bootstrap() async {
        let storedID = await auth.clientID()
        await client.setClientID(storedID)
        if let creds = await auth.loadCredentials() {
            await client.setToken(creds.token)
            isAuthed = true
            await refresh()
        }
    }

    /// Drive the GitHub OAuth device flow end-to-end. Saves the resulting
    /// credentials to the Keychain on success, then kicks off a refresh.
    public func signIn(clientID: String) async {
        let trimmed = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        signInError = nil
        isSigningIn = true
        defer { isSigningIn = false }

        await auth.setClientID(trimmed)
        await client.setClientID(trimmed)

        let device: GitHubClient.DeviceCode
        do {
            device = try await client.requestDeviceCode()
        } catch {
            signInError = "Couldn't start device flow: \(error)"
            return
        }

        pendingUserCode = device.userCode
        pendingVerificationURL = device.verificationURI

        // Pre-copy the user code so the user can paste it on the GitHub page.
        copyToPasteboard(device.userCode)

        let started = Date()
        var interval = max(1, device.interval)
        while Date().timeIntervalSince(started) < TimeInterval(device.expiresIn) {
            try? await Task.sleep(for: .seconds(interval))
            do {
                let resp = try await client.pollAccessToken(deviceCode: device.deviceCode)
                guard let token = resp.accessToken else {
                    signInError = "GitHub didn't return a token."
                    pendingUserCode = nil; pendingVerificationURL = nil
                    return
                }
                try? await auth.saveCredentials(AuthCredentials(token: token))
                await client.setToken(token)
                pendingUserCode = nil
                pendingVerificationURL = nil
                isAuthed = true
                await refresh()
                return
            } catch AuthError.authorizationPending {
                continue
            } catch AuthError.slowDown {
                interval += 5
                continue
            } catch AuthError.expiredToken, AuthError.accessDenied {
                signInError = "Sign-in cancelled or expired. Try again."
                pendingUserCode = nil; pendingVerificationURL = nil
                return
            } catch {
                signInError = "Sign-in failed: \(error)"
                pendingUserCode = nil; pendingVerificationURL = nil
                return
            }
        }
        signInError = "Device code expired. Try again."
        pendingUserCode = nil; pendingVerificationURL = nil
    }

    public func signOut() async {
        await auth.clearCredentials()
        await client.setToken(nil)
        isAuthed = false
        user = nil
        runs = []
        repositories = []
        rateLimit = nil
    }

    /// Fetch user, recent repos, and recent runs.
    public func refresh() async {
        guard isAuthed else { return }
        lastFetchError = nil
        do {
            let me = try await client.currentUser()
            user = me
            let repos = try await client.listRepos(perPage: 12)
            repositories = repos
            var allRuns: [WorkflowRun] = []
            // Cap to first ~8 repos to stay friendly to the rate limit on first load.
            for repo in repos.prefix(8) {
                let runs = (try? await client.listRuns(repo: repo, perPage: 5)) ?? []
                allRuns.append(contentsOf: runs)
            }
            self.runs = allRuns.sorted { $0.startedAt > $1.startedAt }
            self.rateLimit = await client.rateLimit
            self.lastRefresh = Date()
        } catch {
            lastFetchError = "\(error)"
        }
    }

    private func copyToPasteboard(_ string: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}
