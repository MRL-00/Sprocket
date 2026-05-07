import Foundation
import Testing
@testable import SprocketKit

@Suite("Repository preference branch matching")
struct RepositoryPreferenceBranchMatchingTests {
    @Test("nil watched branches matches everything")
    func nilMatchesAll() {
        let pref = RepositoryPreference()
        #expect(pref.matches(branch: "main"))
        #expect(pref.matches(branch: "feature/x"))
    }

    @Test("empty watched branches matches everything")
    func emptyMatchesAll() {
        let pref = RepositoryPreference(watchedBranches: [])
        #expect(pref.matches(branch: "main"))
    }

    @Test("exact match")
    func exactMatch() {
        let pref = RepositoryPreference(watchedBranches: ["main", "develop"])
        #expect(pref.matches(branch: "main"))
        #expect(pref.matches(branch: "develop"))
        #expect(!pref.matches(branch: "feature/x"))
    }

    @Test("wildcard prefix match")
    func wildcardPrefix() {
        let pref = RepositoryPreference(watchedBranches: ["release/*"])
        #expect(pref.matches(branch: "release/3.4"))
        #expect(pref.matches(branch: "release/anything"))
        #expect(!pref.matches(branch: "main"))
        #expect(!pref.matches(branch: "feature/release"))
    }
}

@Suite("Per-repo notification override")
struct PerRepoNotificationOverrideTests {
    @Test("per-repo override forces notification on")
    func overrideOn() {
        var planner = NotificationPlanner()
        let prefs = NotificationPreferences(onFailure: false, quietHours: false)
        let notifications = planner.handle(
            events: [.failed(makeRun(id: 1, repo: "acme/app"))],
            preferences: prefs,
            currentUserLogin: "matt",
            isRepositoryMuted: { _ in false },
            shouldNotifyOnFailure: { run in run.repo == "acme/app" },
            now: noonUTC(),
            calendar: utcCalendar
        )
        #expect(notifications.count == 1)
    }

    @Test("per-repo override forces notification off")
    func overrideOff() {
        var planner = NotificationPlanner()
        let prefs = NotificationPreferences(onFailure: true, quietHours: false)
        let notifications = planner.handle(
            events: [.failed(makeRun(id: 1, repo: "noisy/repo"))],
            preferences: prefs,
            currentUserLogin: "matt",
            isRepositoryMuted: { _ in false },
            shouldNotifyOnFailure: { _ in false },
            now: noonUTC(),
            calendar: utcCalendar
        )
        #expect(notifications.isEmpty)
    }

    @Test("AppSettings.shouldNotifyOnFailure consults branch rules")
    func appSettingsBranchRules() {
        let defaults = makeIsolatedDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.notificationPreferences.onFailure = true
        settings.setRepositoryWatchedBranches("acme/app", branches: ["main", "release/*"])

        #expect(settings.shouldNotifyOnFailure(repo: "acme/app", branch: "main"))
        #expect(settings.shouldNotifyOnFailure(repo: "acme/app", branch: "release/3.4"))
        #expect(!settings.shouldNotifyOnFailure(repo: "acme/app", branch: "feature/x"))
    }

    @Test("AppSettings per-repo override beats global")
    func appSettingsOverride() {
        let defaults = makeIsolatedDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.notificationPreferences.onFailure = true
        settings.setRepositoryNotificationOverride("noisy/repo", notifyOnFailure: false)
        #expect(!settings.shouldNotifyOnFailure(repo: "noisy/repo", branch: "main"))
        #expect(settings.shouldNotifyOnFailure(repo: "other/repo", branch: "main"))
    }
}

@Suite("Usage alert tracker")
struct UsageAlertTrackerTests {
    @Test("fires once per threshold per month")
    func firesOnce() {
        var tracker = UsageAlertTracker()
        let account = ActionsUsageAccount(
            name: "octocat",
            isOrg: false,
            usage: ActionsUsage(totalMinutesUsed: 1_600, includedMinutes: 2_000, paidMinutesUsed: 0, breakdown: [:])
        )
        let first = tracker.evaluate(accounts: [account], thresholds: [50, 75, 90])
        let second = tracker.evaluate(accounts: [account], thresholds: [50, 75, 90])
        #expect(first.count == 2) // 50% and 75% (1600/2000 = 80%)
        #expect(second.isEmpty)
    }

    @Test("does not fire below threshold")
    func belowThreshold() {
        var tracker = UsageAlertTracker()
        let account = ActionsUsageAccount(
            name: "octocat",
            isOrg: false,
            usage: ActionsUsage(totalMinutesUsed: 100, includedMinutes: 2_000, paidMinutesUsed: 0, breakdown: [:])
        )
        let planned = tracker.evaluate(accounts: [account], thresholds: [50, 75, 90])
        #expect(planned.isEmpty)
    }

    @Test("resets on new month")
    func resetsOnNewMonth() {
        var tracker = UsageAlertTracker()
        let account = ActionsUsageAccount(
            name: "octocat",
            isOrg: false,
            usage: ActionsUsage(totalMinutesUsed: 1_500, includedMinutes: 2_000, paidMinutesUsed: 0, breakdown: [:])
        )
        let cal = utcCalendar
        let may = cal.date(from: DateComponents(year: 2026, month: 5, day: 15))!
        let june = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!

        let firstMonth = tracker.evaluate(accounts: [account], thresholds: [50, 75], now: may, calendar: cal)
        let nextMonth = tracker.evaluate(accounts: [account], thresholds: [50, 75], now: june, calendar: cal)

        #expect(firstMonth.count == 2)
        #expect(nextMonth.count == 2)
    }
}

@Suite("Workflow job model")
struct WorkflowJobModelTests {
    @Test("identifies first failing step")
    func firstFailingStep() {
        let job = WorkflowJob(
            id: 1, runID: 100, name: "test",
            status: .completed, conclusion: .failure,
            startedAt: Date(), completedAt: Date(), durationSeconds: 1,
            htmlURL: nil,
            steps: [
                WorkflowStep(number: 1, name: "Set up", status: .completed, conclusion: .success, startedAt: nil, completedAt: nil),
                WorkflowStep(number: 2, name: "Run tests", status: .completed, conclusion: .failure, startedAt: nil, completedAt: nil),
                WorkflowStep(number: 3, name: "Upload", status: .completed, conclusion: .skipped, startedAt: nil, completedAt: nil),
            ]
        )
        #expect(job.firstFailingStepName == "Run tests")
    }

    @Test("effective status tracks conclusion")
    func effectiveStatus() {
        let queued = WorkflowJob(
            id: 1, runID: 100, name: "x",
            status: .queued, conclusion: nil,
            startedAt: Date(), completedAt: nil, durationSeconds: 0, htmlURL: nil, steps: []
        )
        #expect(queued.effective == .queued)

        let succeeded = WorkflowJob(
            id: 2, runID: 100, name: "y",
            status: .completed, conclusion: .success,
            startedAt: Date(), completedAt: Date(), durationSeconds: 0, htmlURL: nil, steps: []
        )
        #expect(succeeded.effective == .success)
    }
}

// MARK: - Helpers

private func makeRun(
    id: Int64,
    repo: String = "acme/app",
    branch: String = "main",
    actor: String = "matt",
    conclusion: RunConclusion = .failure
) -> WorkflowRun {
    WorkflowRun(
        id: id,
        repo: repo,
        workflowName: "CI",
        displayTitle: "Build",
        branch: branch,
        event: "push",
        status: .completed,
        conclusion: conclusion,
        runNumber: Int(id),
        actor: actor,
        actorHue: 200,
        startedAt: Date(timeIntervalSince1970: TimeInterval(id)),
        updatedAt: Date(timeIntervalSince1970: TimeInterval(id + 1)),
        durationSeconds: 1,
        htmlURL: URL(string: "https://example.test/\(id)")!
    )
}

private func noonUTC() -> Date {
    var c = DateComponents()
    c.year = 2026; c.month = 5; c.day = 6; c.hour = 12
    c.calendar = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)
    return c.date!
}

private var utcCalendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    return c
}

private func makeIsolatedDefaults() -> UserDefaults {
    let suite = "test.\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    d.removePersistentDomain(forName: suite)
    return d
}
