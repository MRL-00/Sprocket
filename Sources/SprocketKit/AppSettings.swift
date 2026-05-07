import Foundation
#if canImport(Observation)
import Observation
#endif

public enum NotificationSound: String, Sendable, Codable, CaseIterable, Hashable {
    case `default`
    case none
    case funk
    case glass
}

public struct NotificationPreferences: Sendable, Codable, Hashable {
    public var onFailure: Bool
    public var backToGreen: Bool
    public var myRunsOnly: Bool
    public var sound: NotificationSound
    public var quietHours: Bool
    public var coalesceFailures: Bool
    /// Notify when Actions usage crosses these percentage thresholds (0-200).
    /// Each threshold fires at most once per `crossedThresholds` reset.
    public var actionsUsageThresholds: [Int]
    public var actionsUsageAlerts: Bool
    public var longRunAlerts: Bool
    public var longRunAlertPercent: Int

    private enum CodingKeys: String, CodingKey {
        case onFailure
        case backToGreen
        case myRunsOnly
        case sound
        case quietHours
        case coalesceFailures
        case actionsUsageThresholds
        case actionsUsageAlerts
        case longRunAlerts
        case longRunAlertPercent
    }

    public init(
        onFailure: Bool = true,
        backToGreen: Bool = false,
        myRunsOnly: Bool = false,
        sound: NotificationSound = .default,
        quietHours: Bool = true,
        coalesceFailures: Bool = true,
        actionsUsageThresholds: [Int] = [75, 90, 100],
        actionsUsageAlerts: Bool = true,
        longRunAlerts: Bool = true,
        longRunAlertPercent: Int = 50
    ) {
        self.onFailure = onFailure
        self.backToGreen = backToGreen
        self.myRunsOnly = myRunsOnly
        self.sound = sound
        self.quietHours = quietHours
        self.coalesceFailures = coalesceFailures
        self.actionsUsageThresholds = actionsUsageThresholds
        self.actionsUsageAlerts = actionsUsageAlerts
        self.longRunAlerts = longRunAlerts
        self.longRunAlertPercent = longRunAlertPercent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.onFailure = try container.decodeIfPresent(Bool.self, forKey: .onFailure) ?? true
        self.backToGreen = try container.decodeIfPresent(Bool.self, forKey: .backToGreen) ?? false
        self.myRunsOnly = try container.decodeIfPresent(Bool.self, forKey: .myRunsOnly) ?? false
        self.sound = try container.decodeIfPresent(NotificationSound.self, forKey: .sound) ?? .default
        self.quietHours = try container.decodeIfPresent(Bool.self, forKey: .quietHours) ?? true
        self.coalesceFailures = try container.decodeIfPresent(Bool.self, forKey: .coalesceFailures) ?? true
        self.actionsUsageThresholds = try container.decodeIfPresent([Int].self, forKey: .actionsUsageThresholds) ?? [75, 90, 100]
        self.actionsUsageAlerts = try container.decodeIfPresent(Bool.self, forKey: .actionsUsageAlerts) ?? true
        self.longRunAlerts = try container.decodeIfPresent(Bool.self, forKey: .longRunAlerts) ?? true
        self.longRunAlertPercent = try container.decodeIfPresent(Int.self, forKey: .longRunAlertPercent) ?? 50
    }

    public func isInQuietHours(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard quietHours else { return false }
        let hour = calendar.component(.hour, from: now)
        return hour >= 22 || hour < 8
    }
}

public struct RepositoryPreference: Sendable, Codable, Hashable {
    public var watching: Bool
    public var muted: Bool
    /// Per-repo override for `NotificationPreferences.onFailure`. `nil` means
    /// "follow the global setting".
    public var notifyOnFailure: Bool?
    /// If non-empty, only runs whose `branch` matches one of these patterns
    /// (exact match, or `prefix/*` glob) generate notifications. `nil` or
    /// empty means "all branches".
    public var watchedBranches: [String]?

    public init(
        watching: Bool = true,
        muted: Bool = false,
        notifyOnFailure: Bool? = nil,
        watchedBranches: [String]? = nil
    ) {
        self.watching = watching
        self.muted = muted
        self.notifyOnFailure = notifyOnFailure
        self.watchedBranches = watchedBranches
    }

    /// Match a branch against this repo's `watchedBranches`. Always true if no
    /// rules are configured. Supports trailing `*` wildcard.
    public func matches(branch: String) -> Bool {
        guard let patterns = watchedBranches, !patterns.isEmpty else { return true }
        for pattern in patterns {
            if pattern == branch { return true }
            if pattern.hasSuffix("*") {
                let prefix = pattern.dropLast()
                if branch.hasPrefix(prefix) { return true }
            }
        }
        return false
    }
}

@Observable
public final class AppSettings {
    public enum Defaults {
        public static let pollingCadenceSeconds = "settings.pollingCadenceSeconds"
        public static let batterySaver = "settings.batterySaver"
        public static let pauseOnNoNetwork = "settings.pauseOnNoNetwork"
        public static let density = "settings.density"
        public static let muteArchived = "settings.repositories.muteArchived"
        public static let muteForks = "settings.repositories.muteForks"
        public static let repositoryPreferences = "settings.repositories.preferences"
        public static let notificationPreferences = "settings.notifications.preferences"
        public static let gitHubAPIBaseURL = "settings.github.apiBaseURL"
        public static let userAgent = "settings.github.userAgent"
        public static let updatesAutoCheck = "updates.autoCheck"
        public static let updatesAutoInstall = "updates.autoInstall"
        public static let usageAlertTracker = "settings.notifications.usageAlertTracker"
        public static let pinnedWorkflows = "settings.workflows.pinned"

        public static let allKeys: [String] = [
            pollingCadenceSeconds,
            batterySaver,
            pauseOnNoNetwork,
            density,
            muteArchived,
            muteForks,
            repositoryPreferences,
            notificationPreferences,
            gitHubAPIBaseURL,
            userAgent,
            updatesAutoCheck,
            updatesAutoInstall,
            usageAlertTracker,
            pinnedWorkflows,
            AuthStore.clientIDDefaultsKey,
        ]
    }

    @ObservationIgnored private let defaults: UserDefaults

    public var pollingCadenceSeconds: Int {
        didSet { defaults.set(pollingCadenceSeconds, forKey: Defaults.pollingCadenceSeconds) }
    }
    public var batterySaver: Bool {
        didSet { defaults.set(batterySaver, forKey: Defaults.batterySaver) }
    }
    public var pauseOnNoNetwork: Bool {
        didSet { defaults.set(pauseOnNoNetwork, forKey: Defaults.pauseOnNoNetwork) }
    }
    public var density: Density {
        didSet { defaults.set(density.rawValue, forKey: Defaults.density) }
    }
    public var muteArchived: Bool {
        didSet { defaults.set(muteArchived, forKey: Defaults.muteArchived) }
    }
    public var muteForks: Bool {
        didSet { defaults.set(muteForks, forKey: Defaults.muteForks) }
    }
    public var repositoryPreferences: [String: RepositoryPreference] {
        didSet { encode(repositoryPreferences, key: Defaults.repositoryPreferences) }
    }
    public var notificationPreferences: NotificationPreferences {
        didSet { encode(notificationPreferences, key: Defaults.notificationPreferences) }
    }
    public var usageAlertTracker: UsageAlertTracker {
        didSet { encode(usageAlertTracker, key: Defaults.usageAlertTracker) }
    }
    public var pinnedWorkflows: Set<WorkflowKey> {
        didSet { encode(pinnedWorkflows, key: Defaults.pinnedWorkflows) }
    }
    public var gitHubAPIBaseURL: String {
        didSet { defaults.set(gitHubAPIBaseURL, forKey: Defaults.gitHubAPIBaseURL) }
    }
    public var userAgent: String {
        didSet { defaults.set(userAgent, forKey: Defaults.userAgent) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.pollingCadenceSeconds = {
            let value = defaults.integer(forKey: Defaults.pollingCadenceSeconds)
            return value > 0 ? value : 30
        }()
        self.batterySaver = defaults.object(forKey: Defaults.batterySaver) as? Bool ?? true
        self.pauseOnNoNetwork = defaults.object(forKey: Defaults.pauseOnNoNetwork) as? Bool ?? true
        self.density = defaults.string(forKey: Defaults.density).flatMap(Density.init(rawValue:)) ?? .comfortable
        self.muteArchived = defaults.object(forKey: Defaults.muteArchived) as? Bool ?? false
        self.muteForks = defaults.object(forKey: Defaults.muteForks) as? Bool ?? false
        self.repositoryPreferences = Self.decode([String: RepositoryPreference].self, from: defaults, key: Defaults.repositoryPreferences) ?? [:]
        self.notificationPreferences = Self.decode(NotificationPreferences.self, from: defaults, key: Defaults.notificationPreferences) ?? NotificationPreferences()
        self.usageAlertTracker = Self.decode(UsageAlertTracker.self, from: defaults, key: Defaults.usageAlertTracker) ?? UsageAlertTracker()
        self.pinnedWorkflows = Self.decode(Set<WorkflowKey>.self, from: defaults, key: Defaults.pinnedWorkflows) ?? []
        self.gitHubAPIBaseURL = defaults.string(forKey: Defaults.gitHubAPIBaseURL) ?? GitHubClientConfig.defaultBaseURL.absoluteString
        self.userAgent = defaults.string(forKey: Defaults.userAgent) ?? GitHubClientConfig.defaultUserAgent
    }

    public var resolvedGitHubAPIBaseURL: URL {
        URL(string: gitHubAPIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines))
            ?? GitHubClientConfig.defaultBaseURL
    }

    public var resolvedUserAgent: String {
        let trimmed = userAgent.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? GitHubClientConfig.defaultUserAgent : trimmed
    }

    public var gitHubWebBaseURL: URL {
        Self.webBaseURL(forAPIBaseURL: resolvedGitHubAPIBaseURL)
    }

    public var oauthRegistrationURL: URL {
        var components = URLComponents(url: gitHubWebBaseURL.appendingPathComponent("settings/applications/new"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "oauth_application[name]", value: "Sprocket"),
            URLQueryItem(name: "oauth_application[url]", value: "https://github.com/MRL-00/Sprocket"),
            URLQueryItem(name: "oauth_application[callback_url]", value: "https://localhost/callback"),
            URLQueryItem(name: "oauth_application[description]",
                         value: "Menu-bar GitHub Actions monitor. Uses Device Flow — callback URL is unused."),
        ]
        return components.url!
    }

    public static func webBaseURL(forAPIBaseURL apiURL: URL) -> URL {
        if apiURL.host == "api.github.com" {
            return URL(string: "https://github.com")!
        }
        var components = URLComponents(url: apiURL, resolvingAgainstBaseURL: false)!
        components.path = ""
        components.query = nil
        return components.url ?? URL(string: "https://github.com")!
    }

    public func preference(for repository: Repository) -> RepositoryPreference {
        if let preference = repositoryPreferences[repository.fullName] {
            return preference
        }
        if muteArchived && repository.isArchived {
            return RepositoryPreference(watching: false, muted: true)
        }
        if muteForks && repository.isFork {
            return RepositoryPreference(watching: false, muted: true)
        }
        return RepositoryPreference(watching: repository.watching, muted: repository.muted)
    }

    public func applyPreferences(to repository: Repository) -> Repository {
        var copy = repository
        let preference = preference(for: repository)
        copy.watching = preference.watching
        copy.muted = preference.muted
        return copy
    }

    public func setRepository(_ repository: Repository, watching: Bool, muted: Bool) {
        var next = repositoryPreferences[repository.fullName] ?? RepositoryPreference()
        next.watching = watching
        next.muted = muted
        repositoryPreferences[repository.fullName] = next
    }

    public func muteRepositories(where predicate: (Repository) -> Bool, in repositories: [Repository]) {
        var next = repositoryPreferences
        for repository in repositories where predicate(repository) {
            var preference = next[repository.fullName] ?? RepositoryPreference()
            preference.watching = false
            preference.muted = true
            next[repository.fullName] = preference
        }
        repositoryPreferences = next
    }

    public func isRepositoryMuted(_ fullName: String) -> Bool {
        repositoryPreferences[fullName]?.muted == true || repositoryPreferences[fullName]?.watching == false
    }

    /// Effective per-repo notification preference. Falls back to the global
    /// `notificationPreferences.onFailure` when no override is set.
    public func shouldNotifyOnFailure(repo: String, branch: String) -> Bool {
        let pref = repositoryPreferences[repo]
        let globalOnFailure = notificationPreferences.onFailure
        let onFailure = pref?.notifyOnFailure ?? globalOnFailure
        guard onFailure else { return false }
        return pref?.matches(branch: branch) ?? true
    }

    /// Whether a repo's branch passes its `watchedBranches` filter. Used by
    /// success-path notifications (back-to-green) which respect the branch
    /// filter but not the failure-specific override.
    public func branchMatches(repo: String, branch: String) -> Bool {
        repositoryPreferences[repo]?.matches(branch: branch) ?? true
    }

    public func setRepositoryNotificationOverride(_ fullName: String, notifyOnFailure: Bool?) {
        var next = repositoryPreferences[fullName] ?? RepositoryPreference()
        next.notifyOnFailure = notifyOnFailure
        repositoryPreferences[fullName] = next
    }

    public func setRepositoryWatchedBranches(_ fullName: String, branches: [String]?) {
        var next = repositoryPreferences[fullName] ?? RepositoryPreference()
        let cleaned = branches?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        next.watchedBranches = (cleaned?.isEmpty ?? true) ? nil : cleaned
        repositoryPreferences[fullName] = next
    }

    public func resetAll() {
        for key in Defaults.allKeys {
            defaults.removeObject(forKey: key)
        }
        pollingCadenceSeconds = 30
        batterySaver = true
        pauseOnNoNetwork = true
        density = .comfortable
        muteArchived = false
        muteForks = false
        repositoryPreferences = [:]
        notificationPreferences = NotificationPreferences()
        usageAlertTracker = UsageAlertTracker()
        pinnedWorkflows = []
        gitHubAPIBaseURL = GitHubClientConfig.defaultBaseURL.absoluteString
        userAgent = GitHubClientConfig.defaultUserAgent
    }

    public func isPinned(_ run: WorkflowRun) -> Bool {
        pinnedWorkflows.contains(run.workflowKey)
    }

    public func togglePinned(_ run: WorkflowRun) {
        if pinnedWorkflows.contains(run.workflowKey) {
            pinnedWorkflows.remove(run.workflowKey)
        } else {
            pinnedWorkflows.insert(run.workflowKey)
        }
    }

    public static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sprocket", isDirectory: true)
    }

    public static func cacheSizeBytes() -> Int64 {
        let directory = cacheDirectory
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    public static func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

public enum PlannedNotification: Sendable, Hashable {
    case failure(WorkflowRun)
    case backToGreen(WorkflowRun)
    case summary(Int)
    case usageThreshold(account: String, threshold: Int, percentUsed: Int)
    case longRunning(WorkflowRun, averageSeconds: Int, elapsedSeconds: Int)
}

/// Tracks Actions usage thresholds we've already alerted on, keyed per month
/// per account, so the user gets at most one notification per crossing.
public struct UsageAlertTracker: Sendable, Hashable, Codable {
    public var fired: [String: Set<Int>]

    public init(fired: [String: Set<Int>] = [:]) {
        self.fired = fired
    }

    /// Returns thresholds that should fire now. When `isQuiet` is true, no
    /// notifications are emitted and the tracker is left untouched so the
    /// crossing fires on the next non-quiet refresh.
    public mutating func evaluate(
        accounts: [ActionsUsageAccount],
        thresholds: [Int],
        isQuiet: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlannedNotification] {
        guard !isQuiet else { return [] }
        let monthKey = Self.monthKey(now: now, calendar: calendar)
        var planned: [PlannedNotification] = []
        var working = fired.filter { $0.key.hasPrefix(monthKey + "|") }
        var changed = working.count != fired.count
        for account in accounts {
            let percent = account.usage.includedMinutes > 0
                ? Int((Double(account.usage.totalMinutesUsed) / Double(account.usage.includedMinutes)) * 100.0)
                : 0
            let key = "\(monthKey)|\(account.id)"
            let original = working[key] ?? []
            var firedForAccount = original
            for threshold in thresholds.sorted() where percent >= threshold {
                if !firedForAccount.contains(threshold) {
                    firedForAccount.insert(threshold)
                    planned.append(.usageThreshold(
                        account: account.displayName,
                        threshold: threshold,
                        percentUsed: percent
                    ))
                }
            }
            if firedForAccount != original {
                working[key] = firedForAccount
                changed = true
            }
        }
        if changed { fired = working }
        return planned
    }

    static func monthKey(now: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month], from: now)
        return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    }
}

public struct NotificationPlanner: Sendable {
    public private(set) var failingRepositories: Set<String>

    public init(failingRepositories: Set<String> = []) {
        self.failingRepositories = failingRepositories
    }

    public mutating func handle(
        events: [RunStateChange],
        preferences: NotificationPreferences,
        currentUserLogin: String?,
        isRepositoryMuted: (String) -> Bool,
        shouldNotifyOnFailure: ((WorkflowRun) -> Bool)? = nil,
        branchMatches: ((WorkflowRun) -> Bool)? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlannedNotification] {
        for event in events {
            if case .failed(let run) = event {
                failingRepositories.insert(run.repo)
            }
        }

        guard !isQuiet(now: now, calendar: calendar, preferences: preferences) else { return [] }

        var failures: [WorkflowRun] = []
        var green: [WorkflowRun] = []

        let notifyOnFailure: (WorkflowRun) -> Bool = shouldNotifyOnFailure
            ?? { _ in preferences.onFailure }
        let branchMatch: (WorkflowRun) -> Bool = branchMatches ?? { _ in true }

        for event in events {
            switch event {
            case .failed(let run):
                guard notifyOnFailure(run),
                      shouldInclude(run, preferences: preferences, currentUserLogin: currentUserLogin),
                      !isRepositoryMuted(run.repo) else { continue }
                failures.append(run)
            case .succeeded(let run):
                guard preferences.backToGreen,
                      failingRepositories.contains(run.repo),
                      branchMatch(run),
                      shouldInclude(run, preferences: preferences, currentUserLogin: currentUserLogin),
                      !isRepositoryMuted(run.repo) else { continue }
                green.append(run)
            case .started, .cancelled:
                break
            }
        }

        for event in events {
            if case .succeeded(let run) = event {
                failingRepositories.remove(run.repo)
            }
        }

        var planned: [PlannedNotification] = []
        if preferences.coalesceFailures && failures.count > 5 {
            planned.append(.summary(failures.count))
        } else {
            planned.append(contentsOf: failures.map(PlannedNotification.failure))
        }
        planned.append(contentsOf: green.map(PlannedNotification.backToGreen))
        return planned
    }

    private func shouldInclude(
        _ run: WorkflowRun,
        preferences: NotificationPreferences,
        currentUserLogin: String?
    ) -> Bool {
        guard preferences.myRunsOnly else { return true }
        guard let currentUserLogin else { return false }
        return run.actor.caseInsensitiveCompare(currentUserLogin) == .orderedSame
    }

    private func isQuiet(now: Date, calendar: Calendar, preferences: NotificationPreferences) -> Bool {
        preferences.isInQuietHours(now: now, calendar: calendar)
    }
}
