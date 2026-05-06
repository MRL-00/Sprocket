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

    public init(
        onFailure: Bool = true,
        backToGreen: Bool = false,
        myRunsOnly: Bool = false,
        sound: NotificationSound = .default,
        quietHours: Bool = true,
        coalesceFailures: Bool = true
    ) {
        self.onFailure = onFailure
        self.backToGreen = backToGreen
        self.myRunsOnly = myRunsOnly
        self.sound = sound
        self.quietHours = quietHours
        self.coalesceFailures = coalesceFailures
    }
}

public struct RepositoryPreference: Sendable, Codable, Hashable {
    public var watching: Bool
    public var muted: Bool

    public init(watching: Bool = true, muted: Bool = false) {
        self.watching = watching
        self.muted = muted
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
            return value > 0 ? value : 60
        }()
        self.batterySaver = defaults.object(forKey: Defaults.batterySaver) as? Bool ?? true
        self.pauseOnNoNetwork = defaults.object(forKey: Defaults.pauseOnNoNetwork) as? Bool ?? true
        self.density = defaults.string(forKey: Defaults.density).flatMap(Density.init(rawValue:)) ?? .comfortable
        self.muteArchived = defaults.object(forKey: Defaults.muteArchived) as? Bool ?? false
        self.muteForks = defaults.object(forKey: Defaults.muteForks) as? Bool ?? false
        self.repositoryPreferences = Self.decode([String: RepositoryPreference].self, from: defaults, key: Defaults.repositoryPreferences) ?? [:]
        self.notificationPreferences = Self.decode(NotificationPreferences.self, from: defaults, key: Defaults.notificationPreferences) ?? NotificationPreferences()
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
        repositoryPreferences[repository.fullName] = RepositoryPreference(watching: watching, muted: muted)
    }

    public func muteRepositories(where predicate: (Repository) -> Bool, in repositories: [Repository]) {
        var next = repositoryPreferences
        for repository in repositories where predicate(repository) {
            next[repository.fullName] = RepositoryPreference(watching: false, muted: true)
        }
        repositoryPreferences = next
    }

    public func isRepositoryMuted(_ fullName: String) -> Bool {
        repositoryPreferences[fullName]?.muted == true || repositoryPreferences[fullName]?.watching == false
    }

    public func resetAll() {
        for key in Defaults.allKeys {
            defaults.removeObject(forKey: key)
        }
        pollingCadenceSeconds = 60
        batterySaver = true
        pauseOnNoNetwork = true
        density = .comfortable
        muteArchived = false
        muteForks = false
        repositoryPreferences = [:]
        notificationPreferences = NotificationPreferences()
        gitHubAPIBaseURL = GitHubClientConfig.defaultBaseURL.absoluteString
        userAgent = GitHubClientConfig.defaultUserAgent
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

        for event in events {
            switch event {
            case .failed(let run):
                guard preferences.onFailure,
                      shouldInclude(run, preferences: preferences, currentUserLogin: currentUserLogin),
                      !isRepositoryMuted(run.repo) else { continue }
                failures.append(run)
            case .succeeded(let run):
                guard preferences.backToGreen,
                      failingRepositories.contains(run.repo),
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
        guard preferences.quietHours else { return false }
        let hour = calendar.component(.hour, from: now)
        return hour >= 22 || hour < 8
    }
}
