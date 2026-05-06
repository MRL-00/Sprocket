import Foundation
import Testing
@testable import SprocketKit

@Suite("App settings", .serialized)
struct AppSettingsTests {
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
}
