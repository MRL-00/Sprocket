import Foundation
import SprocketKit

let repoDiscoveryPerPage = 100
let repoDiscoveryPageLimit = 10
let apiPerRepoPage = 5

struct Snapshot {
    let user: GitHubUser
    let repositories: [Repository]
    let runs: [WorkflowRun]
    let rateLimit: RateLimit?
    let actionsUsage: ActionsUsage?
    let failures: [RepositoryRefreshFailure]
}

enum CLIError: LocalizedError {
    case missingToken
    case missingClientID

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Not signed in. Run `sprocket auth login <client-id>` or sign in with Sprocket.app."
        case .missingClientID:
            return "Missing OAuth Client ID. Run `sprocket auth login <client-id>`."
        }
    }
}

func configuredClient(requireToken: Bool = true) async throws -> (GitHubClient, AuthStore, AppSettings) {
    let settings = AppSettings()
    let store = AuthStore()
    let client = GitHubClient()
    await client.setBaseURL(settings.resolvedGitHubAPIBaseURL)
    await client.setUserAgent(settings.resolvedUserAgent)
    await client.setClientID(await store.clientID())
    if let creds = await store.loadCredentials() {
        await client.setToken(creds.token)
    } else if requireToken {
        throw CLIError.missingToken
    }
    return (client, store, settings)
}

func discoverRepositories(client: GitHubClient, settings: AppSettings) async throws -> [Repository] {
    var repositories: [Repository] = []
    var seen: Set<Int64> = []
    for page in 1...repoDiscoveryPageLimit {
        let pageRepos = try await client.listRepos(perPage: repoDiscoveryPerPage, page: page)
            .map { settings.applyPreferences(to: $0) }
        for repository in pageRepos where !seen.contains(repository.id) {
            seen.insert(repository.id)
            repositories.append(repository)
        }
        let availableToPoll = repositories.filter { $0.watching && !$0.muted }.count
        if availableToPoll >= settings.maxReposToScan || pageRepos.count < repoDiscoveryPerPage {
            break
        }
    }
    return repositories
}

func loadSnapshot() async throws -> Snapshot {
    let (client, _, settings) = try await configuredClient()
    let user = try await client.currentUser()
    let repositories = try await discoverRepositories(client: client, settings: settings)
    let candidates = Array(repositories.filter { $0.watching && !$0.muted }.prefix(settings.maxReposToScan))

    var runs: [WorkflowRun] = []
    var failures: [RepositoryRefreshFailure] = []
    await withTaskGroup(of: RepositoryRunPageResult.self) { group in
        for repo in candidates {
            group.addTask {
                do {
                    let runs = try await client.listRuns(repo: repo, perPage: apiPerRepoPage)
                    return RepositoryRunPageResult(repository: repo.fullName, runs: runs, errorMessage: nil)
                } catch {
                    return RepositoryRunPageResult(repository: repo.fullName, runs: [], errorMessage: String(describing: error))
                }
            }
        }
        for await result in group {
            runs.append(contentsOf: result.runs)
            if let message = result.errorMessage {
                failures.append(RepositoryRefreshFailure(repository: result.repository, message: message))
            }
        }
    }

    let usageOwners = actionsUsageOwners(user: user, repositories: repositories)
    var usages: [ActionsUsage] = []
    for owner in usageOwners {
        if let usage = try? await client.fetchActionsUsage(for: owner.name, isOrg: owner.isOrg) {
            usages.append(usage)
        }
    }

    return Snapshot(
        user: user,
        repositories: repositories,
        runs: runs.sorted { $0.startedAt > $1.startedAt },
        rateLimit: await client.rateLimit,
        actionsUsage: ActionsUsage.aggregate(usages),
        failures: failures.sorted { $0.repository < $1.repository }
    )
}

func runStatus() async throws {
    let snapshot = try await loadSnapshot()
    let live = snapshot.runs.filter { $0.effective.isLive }.count
    let failing = snapshot.runs.filter { $0.effective.isFailure }.count
    let success = snapshot.runs.filter { $0.effective == .success }.count
    print("Sprocket — \(snapshot.user.login)")
    print("  \(success) green · \(live) running · \(failing) failing")
    print("  repos: \(snapshot.repositories.count) discovered · \(snapshot.repositories.filter { $0.watching && !$0.muted }.count) watched")
    if let rl = snapshot.rateLimit {
        print("  rate limit: \(rl.remaining)/\(rl.limit), resets at \(rl.resetAt)")
    }
    if let usage = snapshot.actionsUsage {
        print("  CI minutes: \(usage.totalMinutesUsed)/\(usage.includedMinutes) this month")
        print("  estimated hosted-runner cost: \(usage.estimatedHostedRunnerCost.formatted(.currency(code: "USD")))")
    } else {
        print("  CI minutes: unavailable")
    }
    printRefreshFailures(snapshot.failures)
}

func runList() async throws {
    let snapshot = try await loadSnapshot()
    for run in snapshot.runs.prefix(25) {
        print(formatRun(run))
    }
    printRefreshFailures(snapshot.failures)
}

func runWatch() async throws {
    let (_, _, settings) = try await configuredClient()
    print("Watching GitHub Actions every \(settings.pollingCadenceSeconds)s. Ctrl-C to exit.")
    let monitor = RunMonitor()
    while !Task.isCancelled {
        let snapshot = try await loadSnapshot()
        let events = await monitor.ingest(snapshot.runs)
        let live = snapshot.runs.filter { $0.effective.isLive }.count
        let failing = snapshot.runs.filter { $0.effective.isFailure }.count
        print("\n\(Date()) · \(snapshot.runs.count) runs · \(live) running · \(failing) failing")
        for event in events {
            print("  event: \(event)")
        }
        printRefreshFailures(snapshot.failures)
        try? await Task.sleep(for: .seconds(settings.pollingCadenceSeconds))
    }
}

func runAuth(_ args: [String]) async throws {
    let sub = args.first ?? "status"
    switch sub {
    case "status":
        let (_, store, _) = try await configuredClient(requireToken: false)
        if let creds = await store.loadCredentials() {
            let prefix = String(creds.token.prefix(6))
            print("Signed in. Token: \(prefix)…")
        } else {
            print("Not signed in. Run `sprocket auth login <client-id>`.")
        }
    case "login":
        try await runAuthLogin(Array(args.dropFirst()))
    case "logout":
        let (_, store, _) = try await configuredClient(requireToken: false)
        await store.clearCredentials()
        print("Signed out.")
    default:
        print("Unknown auth subcommand: \(sub)")
    }
}

func runAuthLogin(_ args: [String]) async throws {
    let (client, store, _) = try await configuredClient(requireToken: false)
    let storedClientID = await store.clientID()
    let clientID = args.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        ?? storedClientID
    guard let clientID, !clientID.isEmpty else { throw CLIError.missingClientID }
    await store.setClientID(clientID)
    await client.setClientID(clientID)

    let device = try await client.requestDeviceCode()
    print("Open \(device.verificationURI.absoluteString)")
    print("Enter code: \(device.userCode)")

    let started = Date()
    var interval = max(1, device.interval)
    while Date().timeIntervalSince(started) < TimeInterval(device.expiresIn) {
        try? await Task.sleep(for: .seconds(interval))
        do {
            let response = try await client.pollAccessToken(deviceCode: device.deviceCode)
            guard let token = response.accessToken else {
                throw AuthError.other("GitHub did not return a token.")
            }
            try await store.saveCredentials(AuthCredentials(token: token))
            print("Signed in.")
            return
        } catch AuthError.authorizationPending {
            continue
        } catch AuthError.slowDown {
            interval += 5
            continue
        } catch AuthError.expiredToken, AuthError.accessDenied {
            throw AuthError.other("Sign-in cancelled or expired.")
        }
    }
    throw AuthError.expiredToken
}

func actionsUsageOwners(user: GitHubUser, repositories: [Repository]) -> [ActionsUsageOwner] {
    let orgOwners = Set(
        repositories
            .map(\.org)
            .filter { $0 != "Personal" && $0 != user.login }
    )
    return [ActionsUsageOwner(name: user.login, isOrg: false)]
        + orgOwners.sorted().map { ActionsUsageOwner(name: $0, isOrg: true) }
}

func printRefreshFailures(_ failures: [RepositoryRefreshFailure]) {
    guard !failures.isEmpty else { return }
    print("  warning: \(failures.count) repos failed to refresh")
    for failure in failures.prefix(5) {
        print("    \(failure.repository): \(failure.message)")
    }
}

func formatRun(_ run: WorkflowRun) -> String {
    let dot: String
    switch run.effective {
    case .success: dot = "✓"
    case .failure, .timedOut, .actionRequired: dot = "✕"
    case .running: dot = "↻"
    case .queued: dot = "·"
    default: dot = "—"
    }
    let repo = run.repo.padding(toLength: 32, withPad: " ", startingAt: 0)
    let workflow = run.workflowName.padding(toLength: 22, withPad: " ", startingAt: 0)
    return "\(dot) \(repo)  \(workflow)  \(run.displayTitle)"
}

func printUsage() {
    print("""
    sprocket — GitHub Actions CLI for Sprocket.app

    USAGE:
      sprocket status                 Print the same summary the popover shows
      sprocket list                   Print recent runs across watched repos
      sprocket watch                  Long-run polling, prints state transitions
      sprocket auth status            Show signed-in status
      sprocket auth login <client-id> Run device flow
      sprocket auth logout            Clear credentials
    """)
}

struct RepositoryRunPageResult: Sendable {
    let repository: String
    let runs: [WorkflowRun]
    let errorMessage: String?
}

struct ActionsUsageOwner {
    let name: String
    let isOrg: Bool
}

let args = Array(CommandLine.arguments.dropFirst())
let command = args.first ?? "status"

do {
    switch command {
    case "status":
        try await runStatus()
    case "list":
        try await runList()
    case "watch":
        try await runWatch()
    case "auth":
        try await runAuth(Array(args.dropFirst()))
    case "-h", "--help", "help":
        printUsage()
    default:
        print("Unknown command: \(command)\n")
        printUsage()
        exit(1)
    }
} catch {
    if let localized = error as? LocalizedError, let message = localized.errorDescription {
        print("error: \(message)")
    } else {
        print("error: \(error)")
    }
    exit(1)
}
