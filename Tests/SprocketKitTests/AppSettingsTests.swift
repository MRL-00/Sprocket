import Foundation
import Testing
@testable import SprocketKit

@Suite("App settings", .serialized)
struct AppSettingsTests {
    @Test("defaults to faster polling cadence")
    func defaultPollingCadence() throws {
        let defaults = try isolatedDefaults()
        let settings = AppSettings(defaults: defaults)

        #expect(settings.pollingCadenceSeconds == 30)
    }

    @Test("persists general, API, notification, and repository preferences")
    func persistsPreferences() throws {
        let defaults = try isolatedDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.pollingCadenceSeconds = 300
        settings.batterySaver = false
        settings.pauseOnNoNetwork = false
        settings.density = .compact
        settings.gitHubAPIBaseURL = "https://github.example.test/api/v3"
        settings.userAgent = "Sprocket/Test"
        settings.notificationPreferences = NotificationPreferences(
            onFailure: false,
            backToGreen: true,
            myRunsOnly: true,
            sound: .none,
            quietHours: false,
            coalesceFailures: false
        )
        settings.setRepository(repo("acme/app"), watching: false, muted: true)

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.pollingCadenceSeconds == 300)
        #expect(reloaded.batterySaver == false)
        #expect(reloaded.pauseOnNoNetwork == false)
        #expect(reloaded.density == .compact)
        #expect(reloaded.resolvedGitHubAPIBaseURL.absoluteString == "https://github.example.test/api/v3")
        #expect(reloaded.resolvedUserAgent == "Sprocket/Test")
        #expect(reloaded.notificationPreferences.sound == .none)
        #expect(reloaded.notificationPreferences.backToGreen)
        #expect(reloaded.repositoryPreferences["acme/app"] == RepositoryPreference(watching: false, muted: true))
    }

    @Test("bulk repository mutes are persisted")
    func bulkRepositoryMutesPersist() throws {
        let defaults = try isolatedDefaults()
        let settings = AppSettings(defaults: defaults)
        let archived = repo("acme/old", archived: true)
        let fork = repo("acme/fork", fork: true)
        let active = repo("acme/app")

        settings.muteArchived = true
        settings.muteForks = true
        settings.muteRepositories(where: { $0.isArchived || $0.isFork }, in: [archived, fork, active])

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.applyPreferences(to: archived).muted)
        #expect(reloaded.applyPreferences(to: fork).muted)
        #expect(!reloaded.applyPreferences(to: active).muted)
    }

    @Test("older notification preferences migrate with usage alert defaults")
    func olderNotificationPreferencesMigrate() throws {
        let defaults = try isolatedDefaults()
        let data = try JSONEncoder().encode(LegacyNotificationPreferences(
            onFailure: false,
            backToGreen: true,
            myRunsOnly: true,
            sound: .none,
            quietHours: false,
            coalesceFailures: false
        ))
        defaults.set(data, forKey: AppSettings.Defaults.notificationPreferences)

        let settings = AppSettings(defaults: defaults)

        #expect(settings.notificationPreferences.onFailure == false)
        #expect(settings.notificationPreferences.backToGreen == true)
        #expect(settings.notificationPreferences.myRunsOnly == true)
        #expect(settings.notificationPreferences.sound == .none)
        #expect(settings.notificationPreferences.quietHours == false)
        #expect(settings.notificationPreferences.coalesceFailures == false)
        #expect(settings.notificationPreferences.actionsUsageAlerts == true)
        #expect(settings.notificationPreferences.actionsUsageThresholds == [75, 90, 100])
    }

    @Test("repository watch changes preserve notification rules")
    func repositoryWatchChangesPreserveNotificationRules() throws {
        let defaults = try isolatedDefaults()
        let settings = AppSettings(defaults: defaults)
        let repository = repo("acme/app")

        settings.setRepositoryNotificationOverride(repository.fullName, notifyOnFailure: false)
        settings.setRepositoryWatchedBranches(repository.fullName, branches: ["main", "release/*"])
        settings.setRepository(repository, watching: false, muted: true)

        let preference = try #require(settings.repositoryPreferences[repository.fullName])
        #expect(preference.watching == false)
        #expect(preference.muted == true)
        #expect(preference.notifyOnFailure == false)
        #expect(preference.watchedBranches == ["main", "release/*"])
    }

    @Test("repo scan limit persists and clamps to allowed range")
    func repoScanLimitPersists() throws {
        let defaults = try isolatedDefaults()
        let settings = AppSettings(defaults: defaults)

        #expect(settings.maxReposToScan == AppSettings.defaultMaxReposToScan)

        settings.maxReposToScan = 25
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.maxReposToScan == 25)

        reloaded.maxReposToScan = 9999
        #expect(reloaded.maxReposToScan == AppSettings.maxReposToScanRange.upperBound)

        reloaded.maxReposToScan = 0
        #expect(reloaded.maxReposToScan == AppSettings.maxReposToScanRange.lowerBound)

        reloaded.resetAll()
        #expect(reloaded.maxReposToScan == AppSettings.defaultMaxReposToScan)
    }

    @Test("GitHub Enterprise API URLs produce matching web registration URLs")
    func enterpriseRegistrationURL() throws {
        let defaults = try isolatedDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.gitHubAPIBaseURL = "https://github.example.test/api/v3"

        let url = settings.oauthRegistrationURL
        #expect(url.host == "github.example.test")
        #expect(url.path == "/settings/applications/new")
        #expect(url.absoluteString.contains("oauth_application"))
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suiteName = "SprocketTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func repo(_ fullName: String, archived: Bool = false, fork: Bool = false) -> Repository {
        Repository(
            id: Int64(abs(fullName.hashValue)),
            fullName: fullName,
            org: fullName.split(separator: "/").first.map(String.init) ?? "acme",
            isArchived: archived,
            isFork: fork,
            watching: true,
            muted: false
        )
    }

    private struct LegacyNotificationPreferences: Encodable {
        let onFailure: Bool
        let backToGreen: Bool
        let myRunsOnly: Bool
        let sound: NotificationSound
        let quietHours: Bool
        let coalesceFailures: Bool
    }
}
