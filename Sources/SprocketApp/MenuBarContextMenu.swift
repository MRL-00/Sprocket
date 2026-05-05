import AppKit
import SprocketKit

extension Notification.Name {
    static let sprocketShowWelcome = Notification.Name("nz.matt.sprocket.showWelcome")
    static let sprocketShowSettings = Notification.Name("nz.matt.sprocket.showSettings")
}

private struct EventCarrier: @unchecked Sendable {
    let event: NSEvent
}

@MainActor
final class MenuBarContextMenu: NSObject {
    static let shared = MenuBarContextMenu()

    private weak var state: AppState?
    private var monitor: Any?

    func install(state: AppState) {
        self.state = state
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
            // Local monitor handlers run on the main thread per AppKit contract,
            // so it's safe to hop synchronously into the main actor.
            let carrier = EventCarrier(event: event)
            let consumed: Bool = MainActor.assumeIsolated {
                MenuBarContextMenu.shared.handle(carrier.event)
            }
            return consumed ? nil : event
        }
    }

    /// Returns true if the event should be consumed (right-click on our
    /// status item). Returns false to let the event propagate normally.
    private func handle(_ event: NSEvent) -> Bool {
        guard let window = event.window else { return false }
        let cls = String(describing: type(of: window))
        // SwiftUI's MenuBarExtra hosts the button in an NSStatusBarWindow.
        guard cls.contains("StatusBar") else { return false }
        guard let view = window.contentView else { return false }

        NSMenu.popUpContextMenu(buildMenu(), with: event, for: view)
        return true
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        guard let state else { return menu }

        if state.isAuthed {
            menu.addItem(item("Refresh now", action: #selector(refreshAction), key: "r"))
            menu.addItem(item(state.isPolling ? "Pause polling" : "Resume polling",
                              action: #selector(togglePolling)))
            menu.addItem(.separator())
            menu.addItem(item("Open GitHub Actions", action: #selector(openGitHub)))
        } else {
            menu.addItem(item("Sign in to GitHub", action: #selector(showWelcome)))
            menu.addItem(.separator())
        }

        menu.addItem(item("Welcome / Reconfigure…", action: #selector(showWelcome)))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", action: #selector(showSettings), key: ","))
        menu.addItem(item("About Sprocket", action: #selector(showAbout)))

        if state.isAuthed {
            menu.addItem(.separator())
            menu.addItem(item("Sign out", action: #selector(signOutAction)))
        }

        menu.addItem(.separator())
        menu.addItem(item("Quit Sprocket", action: #selector(quit), key: "q"))
        return menu
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func refreshAction() {
        let s = state
        Task { @MainActor in await s?.refresh() }
    }

    @objc private func togglePolling() {
        guard let state else { return }
        if state.isPolling { state.stopPolling() } else { state.startPolling() }
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showWelcome() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .sprocketShowWelcome, object: nil)
    }

    @objc private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .sprocketShowSettings, object: nil)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func signOutAction() {
        let s = state
        Task { @MainActor in await s?.signOut() }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
