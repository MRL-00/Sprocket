import Foundation
import os.log
#if canImport(Network)
import Network
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(Observation)
import Observation
#endif

private let stateLog = Logger(subsystem: "nz.matt.sprocket", category: "state")

@MainActor @Observable
public final class AppState {
    public var user: GitHubUser?
    public var runs: [WorkflowRun] = []
    public var repositories: [Repository] = []
    public var rateLimit: RateLimit?
    public var actionsUsage: ActionsUsage?
    public var actionsUsageAccounts: [ActionsUsageAccount] = []
    public var lastRefresh: Date?
    public var density: Density = .comfortable {
        didSet { settings.density = density }
    }
    public var filter: FilterTab = .all
    public var freeTextFilter: String = ""
    public var orgScope: String = "All accounts" {
        didSet {
            guard oldValue != orgScope else { return }
            applyActionsUsageForCurrentScope()
            if isAuthed && shouldFetchActionsUsageForCurrentScope {
                Task { await refreshActionsUsageForCurrentScope() }
            }
        }
    }
    public var isAuthed: Bool = false
    public var welcomeStep: Int = 1
    public var clientIDDraft: String = ""
    public var mockMode: Bool = false
    public var settings: AppSettings

    /// Live device-flow state — non-nil while the user is completing the flow.
    public var pendingUserCode: String?
    public var pendingVerificationURL: URL?
    public var isSigningIn: Bool = false
    public var signInError: String?
    public var lastFetchError: String?
    public var isRefreshing: Bool = false

    public let client = GitHubClient()
    public let auth = AuthStore()
    public let monitor = RunMonitor()

    /// Hook for run state-change events emitted on every refresh. Consumers
    /// (e.g. the app's `Notifier`) can subscribe at startup.
    public var onStateChanges: (@MainActor ([RunStateChange]) -> Void)?

    private var pollTask: Task<Void, Never>?
    private let fastLaneSeconds: Int = 15
    private var lastActionsUsageRefresh: Date?
    private var lastActionsUsageScopeKey: String?
    #if canImport(Network)
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "nz.matt.sprocket.network")
    private var networkIsOnline = true
    #endif

    public var isPolling: Bool { pollTask != nil }

    public init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        self.density = settings.density
        #if canImport(Network)
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.networkIsOnline = path.status == .satisfied
            }
        }
        pathMonitor.start(queue: pathQueue)
        #endif
    }

    public var menuBarState: MenuBarState {
        MenuBarState.aggregate(runs: unmutedRuns(runs), authed: isAuthed, rateLimit: rateLimit)
    }

    public var visibleRuns: [WorkflowRun] {
        let filtered: [WorkflowRun]
        switch filter {
        case .all:     filtered = unmutedRuns(runs)
        case .running: filtered = unmutedRuns(runs).filter { $0.effective.isLive }
        case .failing: filtered = unmutedRuns(runs).filter { $0.effective.isFailure }
        case .recent:  filtered = unmutedRuns(runs).sorted { $0.startedAt > $1.startedAt }
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
        for r in unmutedRuns(runs) {
            if r.effective.isLive { running += 1 }
            if r.effective.isFailure { failing += 1 }
        }
        return (unmutedRuns(runs).count, running, failing)
    }

    public func loadMock() {
        self.user = MockData.user
        self.runs = MockData.runs
        self.repositories = MockData.repositories.map { settings.applyPreferences(to: $0) }
        self.rateLimit = MockData.rateLimit
        self.actionsUsage = MockData.actionsUsage
        self.actionsUsageAccounts = [ActionsUsageAccount(name: MockData.user.login, isOrg: false, usage: MockData.actionsUsage)]
        self.lastActionsUsageRefresh = Date()
        self.lastActionsUsageScopeKey = "mock"
        self.lastRefresh = Date()
        self.isAuthed = true
        self.mockMode = true
    }

    /// Called once on launch: pull saved credentials + Client ID, set them on
    /// the client, and refresh data if signed in.
    public func bootstrap() async {
        let storedID = await auth.clientID()
        stateLog.info("bootstrap — clientID=\(storedID ?? "nil")")
        await applyGitHubClientSettings()
        await client.setClientID(storedID)
        clientIDDraft = storedID ?? ""
        if let creds = await auth.loadCredentials() {
            stateLog.info("bootstrap — token loaded (\(creds.token.count) chars)")
            await client.setToken(creds.token)
            isAuthed = true
            startPolling()
        } else {
            stateLog.info("bootstrap — no token in keychain")
        }
    }

    /// Start background polling. Refreshes immediately, then loops with the
    /// fast-lane cadence when any run is live and `pollingCadenceSeconds`
    /// otherwise — so the interval is always based on the freshest snapshot.
    public func startPolling() {
        guard pollTask == nil else { return }
        stateLog.info("polling started — base=\(self.settings.pollingCadenceSeconds)s fast=\(self.fastLaneSeconds)s")
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard self.isAuthed else { return }
                await self.refresh()
                if Task.isCancelled { return }
                let interval = self.nextPollInterval()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    public func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func nextPollInterval() -> Int {
        #if os(macOS)
        if settings.batterySaver && ProcessInfo.processInfo.isLowPowerModeEnabled {
            return max(settings.pollingCadenceSeconds, 300)
        }
        #endif
        let anyLive = runs.contains { $0.effective.isLive }
        return anyLive ? min(fastLaneSeconds, settings.pollingCadenceSeconds) : settings.pollingCadenceSeconds
    }

    public func setPollingCadenceSeconds(_ seconds: Int) {
        guard settings.pollingCadenceSeconds != seconds else { return }
        settings.pollingCadenceSeconds = seconds
        if isPolling {
            stopPolling()
            startPolling()
        }
    }

    public func applyGitHubClientSettings() async {
        await client.setBaseURL(settings.resolvedGitHubAPIBaseURL)
        await client.setUserAgent(settings.resolvedUserAgent)
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
        clientIDDraft = trimmed

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
                startPolling()
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
        stopPolling()
        await auth.clearCredentials()
        await client.setToken(nil)
        isAuthed = false
        user = nil
        runs = []
        repositories = []
        rateLimit = nil
        actionsUsage = nil
        actionsUsageAccounts = []
        lastActionsUsageRefresh = nil
        lastActionsUsageScopeKey = nil
    }

    public func reconfigureOAuthApp() {
        welcomeStep = 2
        pendingUserCode = nil
        pendingVerificationURL = nil
        signInError = nil
        NotificationCenter.default.post(name: Notification.Name("nz.matt.sprocket.showWelcome"), object: nil)
    }

    public func forgetOAuthApp() async {
        await auth.setClientID(nil)
        await client.setClientID(nil)
        clientIDDraft = ""
        signInError = nil
    }

    public func resetAllData() async {
        stopPolling()
        await auth.clearCredentials()
        await auth.setClientID(nil)
        settings.resetAll()
        AppSettings.clearCache()
        await client.setToken(nil)
        await applyGitHubClientSettings()
        user = nil
        runs = []
        repositories = []
        rateLimit = nil
        actionsUsage = nil
        actionsUsageAccounts = []
        lastRefresh = nil
        density = settings.density
        orgScope = "All accounts"
        filter = .all
        freeTextFilter = ""
        isAuthed = false
        welcomeStep = 1
        clientIDDraft = ""
        pendingUserCode = nil
        pendingVerificationURL = nil
        isSigningIn = false
        signInError = nil
        lastFetchError = nil
        lastActionsUsageRefresh = nil
        lastActionsUsageScopeKey = nil
        mockMode = false
        _ = await monitor.ingest([])
    }

    /// Fetch user, recent repos, and recent runs.
    public func refresh() async {
        guard isAuthed else { stateLog.info("refresh skipped — not authed"); return }
        #if canImport(Network)
        if settings.pauseOnNoNetwork && !networkIsOnline {
            stateLog.info("refresh skipped — no network")
            return
        }
        #endif
        lastFetchError = nil
        isRefreshing = true
        defer { isRefreshing = false }
        stateLog.info("refresh started")
        do {
            let me = try await client.currentUser()
            user = me
            stateLog.info("refresh — user=\(me.login)")
            let repos = try await client.listRepos(perPage: 12).map { settings.applyPreferences(to: $0) }
            repositories = repos
            stateLog.info("refresh — \(repos.count) repos")
            var allRuns: [WorkflowRun] = []
            for repo in repos.filter({ $0.watching && !$0.muted }).prefix(8) {
                let runs = (try? await client.listRuns(repo: repo, perPage: 5)) ?? []
                allRuns.append(contentsOf: runs)
            }
            let sorted = allRuns.sorted { $0.startedAt > $1.startedAt }
            let events = await monitor.ingest(sorted)
            self.runs = sorted
            self.rateLimit = await client.rateLimit
            await refreshActionsUsageForCurrentScopeIfNeeded()
            self.lastRefresh = Date()
            stateLog.info("refresh OK — \(allRuns.count) runs, \(events.count) state changes")
            if !events.isEmpty { onStateChanges?(events) }
        } catch {
            lastFetchError = "\(error)"
            stateLog.info("refresh failed — \(error)")
        }
    }

    private func shouldRefreshActionsUsage(for owners: [ActionsUsageOwner]) -> Bool {
        if lastActionsUsageScopeKey != actionsUsageScopeKey(owners) { return true }
        guard let lastActionsUsageRefresh else { return true }
        return Date().timeIntervalSince(lastActionsUsageRefresh) >= 60 * 60
    }

    private var shouldFetchActionsUsageForCurrentScope: Bool {
        guard let user else { return false }
        let owners = actionsUsageOwners(for: user, repositories: repositories)
        let known = Set(actionsUsageAccounts.map(\.id))
        return owners.contains { !known.contains($0.key) }
    }

    private func refreshActionsUsageForCurrentScopeIfNeeded() async {
        guard let user else { return }
        let owners = actionsUsageOwners(for: user, repositories: repositories)
        if shouldRefreshActionsUsage(for: owners) {
            await refreshActionsUsage(for: owners)
        } else {
            applyActionsUsageForCurrentScope()
        }
    }

    private func refreshActionsUsageForCurrentScope() async {
        guard let user else { return }
        await refreshActionsUsage(for: actionsUsageOwners(for: user, repositories: repositories))
    }

    private func refreshActionsUsage(for owners: [ActionsUsageOwner]) async {
        let accounts = await fetchActionsUsageAccounts(for: owners)
        mergeActionsUsageAccounts(accounts)
        applyActionsUsageForCurrentScope()
        self.lastActionsUsageRefresh = Date()
        self.lastActionsUsageScopeKey = actionsUsageScopeKey(owners)
    }

    private func actionsUsageOwners(for user: GitHubUser, repositories: [Repository]) -> [ActionsUsageOwner] {
        if orgScope == "Personal" || orgScope == user.login {
            return [ActionsUsageOwner(name: user.login, isOrg: false)]
        }
        if orgScope != "All accounts" && orgScope != "All organizations" && orgScope != "Personal" {
            return [ActionsUsageOwner(name: orgScope, isOrg: true)]
        }
        let orgOwners = Set(
            repositories
                .map(\.org)
                .filter { $0 != "Personal" && $0 != user.login }
        )
        return [ActionsUsageOwner(name: user.login, isOrg: false)]
            + orgOwners.sorted().map { ActionsUsageOwner(name: $0, isOrg: true) }
    }

    private func fetchActionsUsageAccounts(for owners: [ActionsUsageOwner]) async -> [ActionsUsageAccount] {
        var accounts: [ActionsUsageAccount] = []
        for owner in owners {
            do {
                if let usage = try await client.fetchActionsUsage(for: owner.name, isOrg: owner.isOrg) {
                    accounts.append(ActionsUsageAccount(name: owner.name, isOrg: owner.isOrg, usage: usage))
                }
            } catch {
                stateLog.info("actions usage failed for \(owner.key) — \(error)")
            }
        }
        return accounts
    }

    private func mergeActionsUsageAccounts(_ accounts: [ActionsUsageAccount]) {
        var keyed = Dictionary(uniqueKeysWithValues: actionsUsageAccounts.map { ($0.id, $0) })
        for account in accounts {
            keyed[account.id] = account
        }
        actionsUsageAccounts = keyed.values.sorted { $0.id < $1.id }
    }

    private func applyActionsUsageForCurrentScope() {
        guard let user else {
            actionsUsage = nil
            return
        }
        let ownerKeys = Set(actionsUsageOwners(for: user, repositories: repositories).map(\.key))
        let usages = actionsUsageAccounts
            .filter { ownerKeys.contains($0.id) }
            .map(\.usage)
        actionsUsage = ActionsUsage.aggregate(usages)
    }

    private func actionsUsageScopeKey(_ owners: [ActionsUsageOwner]) -> String {
        owners.map(\.key).joined(separator: "|")
    }

    private func copyToPasteboard(_ string: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    private func unmutedRuns(_ runs: [WorkflowRun]) -> [WorkflowRun] {
        runs.filter { !settings.isRepositoryMuted($0.repo) }
    }
}

private struct ActionsUsageOwner: Sendable, Hashable {
    let name: String
    let isOrg: Bool

    var key: String {
        "\(isOrg ? "org" : "user"):\(name)"
    }
}
