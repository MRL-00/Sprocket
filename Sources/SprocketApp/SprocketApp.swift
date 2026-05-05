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
    let state: MenuBarState
    var body: some View {
        Image(nsImage: MenuBarIconRenderer.image(for: state))
    }
}
