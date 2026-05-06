import Foundation
import Testing
@testable import SprocketKit

@Suite("Notification planner")
struct NotificationPlannerTests {
    @Test("quiet hours suppress delivery")
    func quietHoursSuppressDelivery() {
        var planner = NotificationPlanner()
        let notifications = planner.handle(
            events: [.failed(run(id: 1))],
            preferences: NotificationPreferences(quietHours: true),
            currentUserLogin: "matt",
            isRepositoryMuted: { _ in false },
            now: date(hour: 23),
            calendar: utcCalendar
        )

        #expect(notifications.isEmpty)
    }

    @Test("coalesces more than five failures")
    func coalescesFailures() {
        var planner = NotificationPlanner()
        let events = (1...6).map { RunStateChange.failed(run(id: Int64($0))) }
        let notifications = planner.handle(
            events: events,
            preferences: NotificationPreferences(quietHours: false, coalesceFailures: true),
            currentUserLogin: "matt",
            isRepositoryMuted: { _ in false },
            now: date(hour: 12),
            calendar: utcCalendar
        )

        #expect(notifications == [.summary(6)])
    }

    @Test("filters my runs only and muted repositories")
    func filtersMyRunsOnlyAndMutedRepositories() {
        var planner = NotificationPlanner()
        let notifications = planner.handle(
            events: [
                .failed(run(id: 1, repo: "acme/app", actor: "matt")),
                .failed(run(id: 2, repo: "acme/other", actor: "alex")),
                .failed(run(id: 3, repo: "acme/muted", actor: "matt")),
            ],
            preferences: NotificationPreferences(myRunsOnly: true, quietHours: false),
            currentUserLogin: "matt",
            isRepositoryMuted: { $0 == "acme/muted" },
            now: date(hour: 12),
            calendar: utcCalendar
        )

        #expect(notifications == [.failure(run(id: 1, repo: "acme/app", actor: "matt"))])
    }

    @Test("emits back to green after previous failure")
    func backToGreen() {
        var planner = NotificationPlanner()
        let preferences = NotificationPreferences(backToGreen: true, quietHours: false)

        _ = planner.handle(
            events: [.failed(run(id: 1, repo: "acme/app"))],
            preferences: preferences,
            currentUserLogin: "matt",
            isRepositoryMuted: { _ in false },
            now: date(hour: 12),
            calendar: utcCalendar
        )
        let notifications = planner.handle(
            events: [.succeeded(run(id: 2, repo: "acme/app", conclusion: .success))],
            preferences: preferences,
            currentUserLogin: "matt",
            isRepositoryMuted: { _ in false },
            now: date(hour: 12),
            calendar: utcCalendar
        )

        #expect(notifications == [.backToGreen(run(id: 2, repo: "acme/app", conclusion: .success))])
    }

    private func run(
        id: Int64,
        repo: String = "acme/app",
        actor: String = "matt",
        conclusion: RunConclusion = .failure
    ) -> WorkflowRun {
        WorkflowRun(
            id: id,
            repo: repo,
            workflowName: "CI",
            displayTitle: "Build",
            branch: "main",
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

    private func date(hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 6
        components.hour = hour
        return components.date!
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
