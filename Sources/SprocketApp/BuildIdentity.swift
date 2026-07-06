import Foundation

enum BuildIdentity {
    static var isLocalBuild: Bool {
        // Anything not running from a packaged .app bundle (e.g. `swift run`) is local.
        Bundle.main.bundleURL.pathExtension != "app"
    }

    static func versionLabel(_ version: String) -> String {
        isLocalBuild ? "v\(version) local" : "v\(version)"
    }

    static func helpText(version: String) -> String {
        isLocalBuild
            ? "Sprocket \(version) local build"
            : "Sprocket \(version)"
    }
}
