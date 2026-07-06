import AppKit

@MainActor
enum AppWindowController {
    static func bringWelcomeToFront() {
        NSApp.activate(ignoringOtherApps: true)
        let window = NSApp.windows.first { $0.title == "Welcome" }
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
