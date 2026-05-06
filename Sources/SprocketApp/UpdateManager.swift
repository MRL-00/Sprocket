import AppKit
import Foundation
import Observation

@MainActor @Observable
final class UpdateManager {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(AppUpdate)
        case downloading(AppUpdate)
        case installing(AppUpdate)
        case failed(String)
    }

    private struct LatestRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let htmlURL: URL
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case assets
        }
    }

    private enum Defaults {
        static let autoCheck = "updates.autoCheck"
        static let autoInstall = "updates.autoInstall"

        static var autoCheckEnabled: Bool {
            UserDefaults.standard.object(forKey: autoCheck) as? Bool ?? true
        }

        static var autoInstallEnabled: Bool {
            UserDefaults.standard.bool(forKey: autoInstall)
        }
    }

    var status: Status = .idle
    var lastCheckedAt: Date?

    private let releasesURL = URL(string: "https://api.github.com/repos/MRL-00/Sprocket/releases/latest")!
    private let appName = "Sprocket.app"

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
    }

    func checkOnLaunchIfNeeded() async {
        guard Defaults.autoCheckEnabled else { return }
        await checkForUpdates(installAutomatically: Defaults.autoInstallEnabled)
    }

    func checkForUpdates(installAutomatically: Bool = false) async {
        status = .checking
        do {
            let update = try await latestUpdate()
            lastCheckedAt = Date()
            guard let update else {
                status = .upToDate
                return
            }
            status = .updateAvailable(update)
            if installAutomatically {
                await install(update)
            }
        } catch {
            status = .failed(Self.userFacingMessage(for: error))
        }
    }

    func installAvailableUpdate() async {
        guard case .updateAvailable(let update) = status else { return }
        await install(update)
    }

    func openReleasePage() {
        guard case .updateAvailable(let update) = status else { return }
        NSWorkspace.shared.open(update.releaseURL)
    }

    func checkForUpdatesWithUserFeedback() async {
        await checkForUpdates()
        switch status {
        case .upToDate:
            showAlert(
                title: "Sprocket is up to date",
                message: "You are running version \(currentVersion)."
            )
        case .updateAvailable(let update):
            let choice = showAlert(
                title: "Sprocket \(update.version) is available",
                message: "You are running version \(currentVersion).",
                buttons: ["Install Update", "View Release", "Later"]
            )
            if choice == .alertFirstButtonReturn {
                await install(update)
            } else if choice == .alertSecondButtonReturn {
                NSWorkspace.shared.open(update.releaseURL)
            }
        case .failed(let message):
            showAlert(title: "Could not check for updates", message: message)
        default:
            break
        }
    }

    private func latestUpdate() async throws -> AppUpdate? {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Sprocket/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw UpdateError.badStatus(http.statusCode)
        }

        let release = try JSONDecoder().decode(LatestRelease.self, from: data)
        let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        guard Self.compareVersions(latestVersion, currentVersion) == .orderedDescending else {
            return nil
        }
        guard let asset = release.assets.first(where: { asset in
            asset.name.hasPrefix("Sprocket-") && asset.name.hasSuffix("-macos.zip")
        }) else {
            throw UpdateError.assetMissing
        }
        return AppUpdate(version: latestVersion, releaseURL: release.htmlURL, downloadURL: asset.browserDownloadURL)
    }

    private func install(_ update: AppUpdate) async {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            status = .failed("Automatic install only works from a packaged Sprocket.app.")
            return
        }

        status = .downloading(update)
        do {
            let workDirectory = try createWorkDirectory()
            let zipURL = workDirectory.appendingPathComponent("Sprocket-\(update.version)-macos.zip")
            let expandedURL = workDirectory.appendingPathComponent("expanded")

            let (downloadedURL, response) = try await URLSession.shared.download(from: update.downloadURL)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw UpdateError.badStatus(http.statusCode)
            }
            try FileManager.default.moveItem(at: downloadedURL, to: zipURL)
            try FileManager.default.createDirectory(at: expandedURL, withIntermediateDirectories: true)
            try run("/usr/bin/ditto", arguments: ["-x", "-k", zipURL.path, expandedURL.path])

            guard let stagedAppURL = findStagedApp(in: expandedURL) else {
                throw UpdateError.appMissing
            }

            status = .installing(update)
            try launchInstaller(stagedAppURL: stagedAppURL, workDirectory: workDirectory)
            NSApp.terminate(nil)
        } catch {
            status = .failed(Self.userFacingMessage(for: error))
        }
    }

    private func createWorkDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SprocketUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func findStagedApp(in directory: URL) -> URL? {
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent(appName).path) {
            return directory.appendingPathComponent(appName)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        for case let url as URL in enumerator where url.lastPathComponent == appName {
            return url
        }
        return nil
    }

    private func launchInstaller(stagedAppURL: URL, workDirectory: URL) throws {
        let scriptURL = workDirectory.appendingPathComponent("install.sh")
        let destinationURL = Bundle.main.bundleURL
        let script = """
        #!/bin/zsh
        set -euo pipefail

        while /bin/kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do
          /bin/sleep 0.2
        done

        /bin/rm -rf \(Self.shellQuoted(destinationURL.path))
        /usr/bin/ditto \(Self.shellQuoted(stagedAppURL.path)) \(Self.shellQuoted(destinationURL.path))
        /usr/bin/open \(Self.shellQuoted(destinationURL.path))
        /bin/rm -rf \(Self.shellQuoted(workDirectory.path))
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        try run("/bin/zsh", arguments: [scriptURL.path], waitsForExit: false)
    }

    private func run(_ executable: String, arguments: [String], waitsForExit: Bool = true) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        guard waitsForExit else { return }
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw UpdateError.commandFailed(executable, process.terminationStatus)
        }
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func userFacingMessage(for error: Error) -> String {
        if let updateError = error as? UpdateError {
            return updateError.localizedDescription
        }
        return error.localizedDescription
    }

    @discardableResult
    private func showAlert(title: String, message: String, buttons: [String] = ["OK"]) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        for button in buttons {
            alert.addButton(withTitle: button)
        }
        return alert.runModal()
    }
}

struct AppUpdate: Equatable {
    let version: String
    let releaseURL: URL
    let downloadURL: URL
}

private enum UpdateError: LocalizedError {
    case assetMissing
    case appMissing
    case badStatus(Int)
    case commandFailed(String, Int32)

    var errorDescription: String? {
        switch self {
        case .assetMissing:
            return "The latest release does not include a macOS zip asset."
        case .appMissing:
            return "The downloaded update did not contain Sprocket.app."
        case .badStatus(let statusCode):
            return "GitHub returned HTTP \(statusCode)."
        case .commandFailed(let command, let status):
            return "\(command) exited with status \(status)."
        }
    }
}
