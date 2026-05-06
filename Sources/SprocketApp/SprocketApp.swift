import SwiftUI
import SprocketKit
import UserNotifications

@main
struct SprocketApp: App {
    @State private var state = AppState()
    @State private var updater = UpdateManager()
    @Environment(\.openURL) private var openURL

    init() {
        let mock = CommandLine.arguments.contains("--mock")
        let s = AppState()
        let u = UpdateManager()
        if mock { s.loadMock() }
        s.onStateChanges = { events in
            Notifier.handle(events: events, settings: s.settings, currentUserLogin: s.user?.login)
        }
        _state = State(initialValue: s)
        _updater = State(initialValue: u)
        Notifier.requestAuthorizationIfNeeded()
        MenuBarContextMenu.shared.install(state: s, updater: u)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(state)
                .environment(updater)
                .frame(width: 440, height: 560)
        } label: {
            MenuBarLabel(state: state.menuBarState)
                .environment(updater)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Welcome", id: "welcome") {
            WelcomeWindow()
                .environment(state)
                .environment(updater)
                .frame(width: 520, height: 580)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsWindow()
                .environment(state)
                .environment(updater)
                .frame(width: 660, height: 520)
        }
    }
}

private struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(UpdateManager.self) private var updater
    @State private var didCheckForUpdates = false
    let state: MenuBarState

    var body: some View {
        Image(nsImage: MenuBarIconRenderer.image(for: state))
            .onReceive(NotificationCenter.default.publisher(for: .sprocketShowWelcome)) { _ in
                openWindow(id: "welcome")
            }
            .onReceive(NotificationCenter.default.publisher(for: .sprocketShowSettings)) { _ in
                openSettings()
            }
            .task {
                guard !didCheckForUpdates else { return }
                didCheckForUpdates = true
                await updater.checkOnLaunchIfNeeded()
            }
    }
}
