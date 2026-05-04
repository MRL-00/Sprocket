import Foundation
import UserNotifications
import SprocketKit

enum Notifier {
    /// `UNUserNotificationCenter` asserts on launch when there's no app bundle
    /// (e.g. `swift run` outside of `Sprocket.app`). Skip the whole subsystem
    /// in that case so the menu bar app still runs for development.
    static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuthorizationIfNeeded() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Post a failure-transition banner.
    /// Title = `org/repo`; body = `Workflow "{name}" failed on {branch}`.
    static func postFailure(_ run: WorkflowRun) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = run.repo
        content.body = "Workflow \"\(run.workflowName)\" failed on \(run.branch)"
        content.userInfo = ["url": run.htmlURL.absoluteString]
        content.sound = .default

        let req = UNNotificationRequest(
            identifier: "sprocket.failure.\(run.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    /// Coalesced summary when more than 5 failures arrive in one tick.
    static func postSummary(failureCount: Int) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "Sprocket"
        content.body = "\(failureCount) workflow runs failed"
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "sprocket.summary.\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    /// Apply diff events with the >5 coalesce rule.
    static func handle(events: [RunStateChange]) {
        let failures = events.compactMap { ev -> WorkflowRun? in
            if case .failed(let run) = ev { return run } else { return nil }
        }
        if failures.count > 5 {
            postSummary(failureCount: failures.count)
        } else {
            for run in failures { postFailure(run) }
        }
    }
}
