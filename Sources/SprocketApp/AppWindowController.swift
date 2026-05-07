import AppKit

@MainActor
enum AppWindowController {
    static func bringWelcomeToFront() {
        bringWindowToFront(title: "Welcome")
    }

    static func bringWindowToFront(title: String) {
        NSApp.activate(ignoringOtherApps: true)
        let window = NSApp.windows.first { $0.title == title }
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    static func bringWelcomeToFrontAfterOpen() {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            bringWelcomeToFront()
        }
    }
}
