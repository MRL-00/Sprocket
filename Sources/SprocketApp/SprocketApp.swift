import SwiftUI
import SprocketKit
import UserNotifications

@main
struct SprocketApp: App {
    @State private var state = AppState()
    @Environment(\.openURL) private var openURL

    init() {
        let mock = CommandLine.arguments.contains("--mock")
        let s = AppState()
        if mock { s.loadMock() }
        s.onStateChanges = { events in Notifier.handle(events: events) }
        _state = State(initialValue: s)
        Notifier.requestAuthorizationIfNeeded()
        MenuBarContextMenu.shared.install(state: s)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(state)
                .frame(width: 420, height: 560)
        } label: {
            MenuBarLabel(state: state.menuBarState)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Welcome", id: "welcome") {
            WelcomeWindow()
                .environment(state)
                .frame(width: 520, height: 580)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsWindow()
                .environment(state)
                .frame(width: 660, height: 520)
        }
    }
}

private struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    let state: MenuBarState

    var body: some View {
        Image(nsImage: MenuBarIconRenderer.image(for: state))
            .onReceive(NotificationCenter.default.publisher(for: .sprocketShowWelcome)) { _ in
                openWindow(id: "welcome")
            }
            .onReceive(NotificationCenter.default.publisher(for: .sprocketShowSettings)) { _ in
                openSettings()
            }
    }
}
