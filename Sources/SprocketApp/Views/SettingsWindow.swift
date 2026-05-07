import SwiftUI
import SprocketKit
import ServiceManagement

struct SettingsWindow: View {
    @Environment(AppState.self) private var state

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            AccountTab()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
            ReposTab()
                .tabItem { Label("Repositories", systemImage: "folder") }
            NotificationsTab()
                .tabItem { Label("Notifications", systemImage: "bell") }
            AdvancedTab()
                .tabItem { Label("Advanced", systemImage: "wand.and.stars") }
        }
        .padding(20)
        .frame(width: 660, height: 520)
    }
}

private struct GeneralTab: View {
    @Environment(AppState.self) private var state
    @Environment(UpdateManager.self) private var updater
    @AppStorage("updates.autoCheck") private var autoCheckForUpdates = true
    @AppStorage("updates.autoInstall") private var autoInstallUpdates = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        @Bindable var state = state
        @Bindable var settings = state.settings
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))
                Toggle("Hide from Dock", isOn: .constant(true))
                    .disabled(true)
                Text("Sprocket is packaged as an LSUIElement menu bar app, so Dock visibility is fixed.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Polling") {
                Picker("Refresh cadence", selection: Binding(
                    get: { settings.pollingCadenceSeconds },
                    set: { state.setPollingCadenceSeconds($0) }
                )) {
                    Text("Every 30 seconds").tag(30)
                    Text("Every minute").tag(60)
                    Text("Every 2 minutes").tag(120)
                    Text("Every 5 minutes").tag(300)
                    Text("Every 15 minutes").tag(900)
                }
                Text("Repos with in-progress runs poll every 15 s regardless.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Battery saver", isOn: $settings.batterySaver)
                Toggle("Pause on no network", isOn: $settings.pauseOnNoNetwork)
            }
            Section("Density") {
                Picker("Row density", selection: $state.density) {
                    Text("Compact").tag(Density.compact)
                    Text("Comfortable").tag(Density.comfortable)
                    Text("Spacious").tag(Density.spacious)
                }
                .pickerStyle(.segmented)
            }
            Section("Updates") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current version")
                        Text(updater.currentVersion)
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(updateButtonTitle) {
                        Task { await updater.checkForUpdates() }
                    }
                    .disabled(isUpdateButtonDisabled)
                }
                Toggle("Automatically check for updates", isOn: $autoCheckForUpdates)
                Toggle("Install updates automatically", isOn: $autoInstallUpdates)
                    .disabled(!autoCheckForUpdates)
                updateStatusView
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private var updateButtonTitle: String {
        switch updater.status {
        case .checking:
            return "Checking…"
        default:
            return "Check Now"
        }
    }

    private var isUpdateButtonDisabled: Bool {
        switch updater.status {
        case .checking, .downloading, .installing:
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updater.status {
        case .idle:
            Text("Checks GitHub Releases for a newer Sprocket build.")
                .font(.caption).foregroundStyle(.secondary)
        case .checking:
            ProgressView("Checking for updates…")
        case .upToDate:
            Text("Sprocket is up to date.")
                .font(.caption).foregroundStyle(.secondary)
        case .updateAvailable(let update):
            HStack {
                Text("Version \(update.version) is available.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("View Release") { updater.openReleasePage() }
                Button("Install Update") {
                    Task { await updater.installAvailableUpdate() }
                }
                .buttonStyle(.borderedProminent)
            }
        case .downloading(let update):
            ProgressView("Downloading \(update.version)…")
        case .installing(let update):
            ProgressView("Installing \(update.version)…")
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.sprocketFailure)
        }
    }
}

private struct AccountTab: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Form {
            Section("Signed in") {
                HStack(spacing: 12) {
                    Avatar(login: state.user?.login ?? "?",
                           imageURL: state.user?.avatarURL,
                           hue: Double(state.user?.avatarHue ?? 200),
                           size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.user?.name ?? "Not signed in")
                            .font(.system(size: 13.5, weight: .semibold))
                        Text("@" + (state.user?.login ?? "—"))
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Sign out") { Task { await state.signOut() } }
                        .buttonStyle(.bordered)
                        .disabled(!state.isAuthed)
                }
                .padding(.vertical, 4)
            }
            Section("Scopes granted") {
                ForEach(scopes, id: \.0) { (s, h) in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.sprocketSuccess)
                            .font(.system(size: 10, weight: .bold))
                        Text(s).font(.system(size: 12, design: .monospaced)).fontWeight(.medium)
                        Text("· " + h).foregroundStyle(.secondary).font(.system(size: 11.5))
                    }
                }
            }
            Section("OAuth app") {
                HStack {
                    Text("Client ID")
                    Spacer()
                    Text(clientIDLabel)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                }
                Text("Stored in UserDefaults. Token kept separately in Keychain.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Reconfigure OAuth app") { state.reconfigureOAuthApp() }
                    Button("Forget OAuth app", role: .destructive) {
                        Task { await state.forgetOAuthApp() }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var clientIDLabel: String {
        let trimmed = state.clientIDDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, let stored = UserDefaults.standard.string(forKey: AuthStore.clientIDDefaultsKey) {
            return stored
        }
        return trimmed.isEmpty ? "Not configured" : trimmed
    }

    private let scopes: [(String, String)] = [
        ("repo",      "Read & write across repos you can access"),
        ("workflow",  "Re-run / cancel runs"),
        ("read:org",  "Discover repos in your orgs"),
        ("user",      "Your avatar, login, and Actions billing usage"),
    ]
}

private struct ReposTab: View {
    @Environment(AppState.self) private var state
    @State private var query = ""
    @State private var selection: Repository.ID?

    var body: some View {
        @Bindable var settings = state.settings
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 8)
                    TextField("Filter repositories…", text: $query)
                        .textFieldStyle(.plain)
                        .padding(.leading, 26)
                        .padding(.vertical, 6)
                        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                }
                Button {
                    settings.muteArchived = true
                    settings.muteRepositories(where: { $0.isArchived }, in: state.repositories)
                    state.repositories = state.repositories.map { settings.applyPreferences(to: $0) }
                } label: { Label("Mute archived", systemImage: "archivebox") }
                Button {
                    settings.muteForks = true
                    settings.muteRepositories(where: { $0.isFork }, in: state.repositories)
                    state.repositories = state.repositories.map { settings.applyPreferences(to: $0) }
                } label: { Label("Mute forks", systemImage: "tuningfork") }
            }
            Table(filtered, selection: $selection) {
                TableColumn("") { (it: Repository) in
                    Button {
                        toggle(repository: it)
                    } label: {
                        Image(systemName: it.muted ? "square" : "checkmark.square.fill")
                            .foregroundStyle(it.muted ? Color.secondary : Color.sprocketAccent)
                    }
                    .buttonStyle(.plain)
                    .help(it.muted ? "Watch repository" : "Mute repository")
                }
                .width(30)
                TableColumn("Repository") { (it: Repository) in
                    HStack(spacing: 6) {
                        if it.isArchived {
                            Image(systemName: "archivebox").foregroundStyle(.tertiary).font(.system(size: 10))
                        }
                        Text(it.fullName).font(.system(size: 11.5, design: .monospaced))
                    }
                }
                TableColumn("Org") { (it: Repository) in
                    Text(it.org).foregroundStyle(.secondary).font(.system(size: 11))
                }
                .width(110)
                TableColumn("Notify") { (it: Repository) in
                    Text(notifyLabel(for: it))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .width(120)
            }
            if let selected = selectedRepository {
                RepoNotificationRules(repository: selected)
                    .padding(.top, 4)
            } else {
                Text("Select a repository to override its notification rules.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var filtered: [Repository] {
        guard !query.isEmpty else { return state.repositories }
        let q = query.lowercased()
        return state.repositories.filter { $0.fullName.lowercased().contains(q) }
    }

    private var selectedRepository: Repository? {
        guard let selection else { return nil }
        return state.repositories.first(where: { $0.id == selection })
    }

    private func notifyLabel(for repo: Repository) -> String {
        let pref = state.settings.repositoryPreferences[repo.fullName]
        let global = state.settings.notificationPreferences.onFailure
        let onFailure = pref?.notifyOnFailure ?? global
        var parts: [String] = []
        parts.append(onFailure ? "On failure" : "Silent")
        if let branches = pref?.watchedBranches, !branches.isEmpty {
            parts.append(branches.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    private func toggle(repository: Repository) {
        let muted = !repository.muted
        state.settings.setRepository(repository, watching: !muted, muted: muted)
        state.repositories = state.repositories.map { repo in
            repo.id == repository.id ? state.settings.applyPreferences(to: repo) : repo
        }
    }
}

private struct RepoNotificationRules: View {
    let repository: Repository
    @Environment(AppState.self) private var state
    @State private var branchesText: String = ""
    @FocusState private var branchesFieldFocused: Bool

    enum NotifyOverride: Hashable { case global, on, off }

    var body: some View {
        let pref = state.settings.repositoryPreferences[repository.fullName]
        Form {
            Section("Notification rules · \(repository.fullName)") {
                Picker("On failure", selection: Binding(
                    get: { currentOverride(pref) },
                    set: { applyOverride($0) }
                )) {
                    Text("Use global setting").tag(NotifyOverride.global)
                    Text("Always notify").tag(NotifyOverride.on)
                    Text("Never notify").tag(NotifyOverride.off)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text("Watched branches")
                    Spacer()
                    TextField("e.g. main, release/*", text: $branchesText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 280)
                        .focused($branchesFieldFocused)
                        .onSubmit(applyBranches)
                        .onChange(of: branchesFieldFocused) { _, focused in
                            if !focused { applyBranches() }
                        }
                }
                Text("Comma-separated. Use `prefix/*` to match a branch prefix. Empty means all branches.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { syncFromPref(pref) }
        .onChange(of: repository.id) { _, _ in
            syncFromPref(state.settings.repositoryPreferences[repository.fullName])
        }
    }

    private func currentOverride(_ pref: RepositoryPreference?) -> NotifyOverride {
        switch pref?.notifyOnFailure {
        case .none: return .global
        case .some(true): return .on
        case .some(false): return .off
        }
    }

    private func syncFromPref(_ pref: RepositoryPreference?) {
        branchesText = (pref?.watchedBranches ?? []).joined(separator: ", ")
    }

    private func applyOverride(_ value: NotifyOverride) {
        let mapped: Bool? = {
            switch value {
            case .global: return nil
            case .on: return true
            case .off: return false
            }
        }()
        state.settings.setRepositoryNotificationOverride(repository.fullName, notifyOnFailure: mapped)
    }

    private func applyBranches() {
        let parts = branchesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        state.settings.setRepositoryWatchedBranches(repository.fullName, branches: parts.isEmpty ? nil : parts)
    }
}

private struct NotificationsTab: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var settings = state.settings
        Form {
            Section("Events") {
                Toggle("On failure", isOn: Binding(
                    get: { settings.notificationPreferences.onFailure },
                    set: { settings.notificationPreferences.onFailure = $0 }
                ))
                Text("Notify when a run transitions to failure, timed_out, or action_required.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Back to green", isOn: Binding(
                    get: { settings.notificationPreferences.backToGreen },
                    set: { settings.notificationPreferences.backToGreen = $0 }
                ))
                Text("Notify on the first success after a previously-failing repo.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("My runs only", isOn: Binding(
                    get: { settings.notificationPreferences.myRunsOnly },
                    set: { settings.notificationPreferences.myRunsOnly = $0 }
                ))
            }
            Section("Delivery") {
                Picker("Sound", selection: Binding(
                    get: { settings.notificationPreferences.sound },
                    set: { settings.notificationPreferences.sound = $0 }
                )) {
                    Text("Default").tag(NotificationSound.default)
                    Text("None").tag(NotificationSound.none)
                    Text("Funk").tag(NotificationSound.funk)
                    Text("Glass").tag(NotificationSound.glass)
                }
                Toggle("Quiet hours · 22:00–08:00", isOn: Binding(
                    get: { settings.notificationPreferences.quietHours },
                    set: { settings.notificationPreferences.quietHours = $0 }
                ))
                Toggle("Coalesce >5 failures into one summary", isOn: Binding(
                    get: { settings.notificationPreferences.coalesceFailures },
                    set: { settings.notificationPreferences.coalesceFailures = $0 }
                ))
            }
            Section("Actions usage budget") {
                Toggle("Alert when included CI minutes are used", isOn: Binding(
                    get: { settings.notificationPreferences.actionsUsageAlerts },
                    set: { settings.notificationPreferences.actionsUsageAlerts = $0 }
                ))
                ForEach(usageThresholdOptions(settings.notificationPreferences.actionsUsageThresholds), id: \.self) { threshold in
                    Toggle("\(threshold)% of included minutes", isOn: Binding(
                        get: { settings.notificationPreferences.actionsUsageThresholds.contains(threshold) },
                        set: { isOn in
                            var current = Set(settings.notificationPreferences.actionsUsageThresholds)
                            if isOn { current.insert(threshold) } else { current.remove(threshold) }
                            settings.notificationPreferences.actionsUsageThresholds = current.sorted()
                        }
                    ))
                    .disabled(!settings.notificationPreferences.actionsUsageAlerts)
                }
                Text("Alerts fire at most once per account per month per threshold.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func usageThresholdOptions(_ configured: [Int]) -> [Int] {
        let known: Set<Int> = [75, 90, 100, 125]
        return Array(known.union(configured)).sorted()
    }
}

private struct AdvancedTab: View {
    @Environment(AppState.self) private var state
    @State private var cacheSize = AppSettings.cacheSizeBytes()
    @State private var confirmingReset = false

    var body: some View {
        @Bindable var settings = state.settings
        Form {
            Section("API") {
                TextField("Base URL", text: Binding(
                    get: { settings.gitHubAPIBaseURL },
                    set: { value in
                        settings.gitHubAPIBaseURL = value
                        Task { await state.applyGitHubClientSettings() }
                    }
                ))
                Text("For GitHub Enterprise Server. The OAuth registration deeplink updates accordingly.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("User-Agent", text: Binding(
                    get: { settings.userAgent },
                    set: { value in
                        settings.userAgent = value
                        Task { await state.applyGitHubClientSettings() }
                    }
                ))
            }
            Section("Cache") {
                HStack {
                    Text("Cache size")
                    Spacer()
                    Text(cacheSizeLabel).font(.system(size: 12, design: .monospaced))
                    Button("Reveal in Finder") { revealCacheInFinder() }
                }
                Text("Sprocket cache directory.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Reset") {
                Button("Reset all data…", role: .destructive) { confirmingReset = true }
                Text("Wipes Keychain entry, UserDefaults, and the cache. The OAuth app on GitHub is unaffected.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { cacheSize = AppSettings.cacheSizeBytes() }
        .confirmationDialog(
            "Reset all Sprocket data?",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset all data", role: .destructive) {
                Task {
                    await state.resetAllData()
                    cacheSize = AppSettings.cacheSizeBytes()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears Keychain credentials, OAuth configuration, preferences, repository choices, cached data, and the current app state.")
        }
    }

    private var cacheSizeLabel: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }

    private func revealCacheInFinder() {
        let directory = AppSettings.cacheDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }
}
