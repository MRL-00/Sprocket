import Foundation

enum BuildIdentity {
    static var isLocalBuild: Bool {
        CommandLine.arguments.contains("--local")
            || ProcessInfo.processInfo.environment["SPROCKET_LOCAL_BUILD"] == "1"
            || Bundle.main.bundleURL.pathExtension != "app"
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
