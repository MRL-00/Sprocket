import Foundation
import UserNotifications
import SprocketKit

enum Notifier {
    @MainActor private static var planner = NotificationPlanner()

    /// `UNUserNotificationCenter` asserts on launch when there's no app bundle
    /// (e.g. `swift run` outside of `Sprocket.app`). Skip the whole subsystem
    /// in that case so the menu bar app still runs for development.
    static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuthorizationIfNeeded() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private static func sound(for preference: NotificationSound) -> UNNotificationSound? {
        switch preference {
        case .default:
            return .default
        case .none:
            return nil
        case .funk, .glass:
            return UNNotificationSound(named: UNNotificationSoundName("\(preference.rawValue.capitalized).aiff"))
        }
    }

    static func postFailure(_ run: WorkflowRun, sound selectedSound: NotificationSound) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = run.repo
        content.body = "Workflow \"\(run.workflowName)\" failed on \(run.branch)"
        content.userInfo = ["url": run.htmlURL.absoluteString]
        content.sound = sound(for: selectedSound)

        let req = UNNotificationRequest(
            identifier: "sprocket.failure.\(run.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    /// Coalesced summary when more than 5 failures arrive in one tick.
    static func postBackToGreen(_ run: WorkflowRun, sound selectedSound: NotificationSound) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = run.repo
        content.body = "Workflow \"\(run.workflowName)\" is back to green on \(run.branch)"
        content.userInfo = ["url": run.htmlURL.absoluteString]
        content.sound = sound(for: selectedSound)

        let req = UNNotificationRequest(
            identifier: "sprocket.green.\(run.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    static func postSummary(failureCount: Int, sound selectedSound: NotificationSound) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = "Sprocket"
        content.body = "\(failureCount) workflow runs failed"
        content.sound = sound(for: selectedSound)
        let req = UNNotificationRequest(
            identifier: "sprocket.summary.\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    @MainActor
    static func handle(events: [RunStateChange], settings: AppSettings, currentUserLogin: String?) {
        let preferences = settings.notificationPreferences
        let planned = planner.handle(
            events: events,
            preferences: preferences,
            currentUserLogin: currentUserLogin,
            isRepositoryMuted: { settings.isRepositoryMuted($0) }
        )
        for notification in planned {
            switch notification {
            case .failure(let run):
                postFailure(run, sound: preferences.sound)
            case .backToGreen(let run):
                postBackToGreen(run, sound: preferences.sound)
            case .summary(let count):
                postSummary(failureCount: count, sound: preferences.sound)
            }
        }
    }
}
