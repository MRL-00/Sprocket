import SwiftUI
import SprocketKit

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
    @State private var launchAtLogin = true
    @State private var batterySaver = true
    @State private var pauseOnNoNetwork = true

    var body: some View {
        @Bindable var state = state
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Hide from Dock", isOn: .constant(true)).disabled(true)
            }
            Section("Polling") {
                Picker("Refresh cadence", selection: $state.pollingCadenceSeconds) {
                    Text("Every 30 seconds").tag(30)
                    Text("Every minute").tag(60)
                    Text("Every 2 minutes").tag(120)
                    Text("Every 5 minutes").tag(300)
                    Text("Every 15 minutes").tag(900)
                }
                Text("Repos with in-progress runs poll every 15 s regardless.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Battery saver", isOn: $batterySaver)
                Toggle("Pause on no network", isOn: $pauseOnNoNetwork)
            }
            Section("Density") {
                Picker("Row density", selection: $state.density) {
                    Text("Compact").tag(Density.compact)
                    Text("Comfortable").tag(Density.comfortable)
                    Text("Spacious").tag(Density.spacious)
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
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
                    Button("Sign out") { state.isAuthed = false }
                        .buttonStyle(.bordered)
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
                    Text("Iv1.a4f2e9c81b3d7e60")
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                }
                Text("Stored in UserDefaults. Token kept separately in Keychain.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Reconfigure OAuth app") { /* TODO */ }
                    Button("Forget OAuth app", role: .destructive) { /* TODO */ }
                }
            }
        }
        .formStyle(.grouped)
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

    var body: some View {
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
                Button { /* mute archived */ } label: { Label("Mute archived", systemImage: "archivebox") }
                Button { /* mute forks */ } label: { Label("Mute forks", systemImage: "tuningfork") }
            }
            Table(filtered) {
                TableColumn("") { (it: Repository) in
                    Image(systemName: it.muted ? "square" : "checkmark.square.fill")
                        .foregroundStyle(it.muted ? Color.secondary : Color.sprocketAccent)
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
            }
        }
    }

    private var filtered: [Repository] {
        guard !query.isEmpty else { return state.repositories }
        let q = query.lowercased()
        return state.repositories.filter { $0.fullName.lowercased().contains(q) }
    }
}

private struct NotificationsTab: View {
    @State private var onFailure = true
    @State private var backToGreen = false
    @State private var myRunsOnly = false
    @State private var coalesce = true
    @State private var quietHours = true

    var body: some View {
        Form {
            Section("Events") {
                Toggle("On failure", isOn: $onFailure)
                Text("Notify when a run transitions to failure, timed_out, or action_required.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Back to green", isOn: $backToGreen)
                Text("Notify on the first success after a previously-failing repo.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("My runs only", isOn: $myRunsOnly)
            }
            Section("Delivery") {
                Picker("Sound", selection: .constant("default")) {
                    Text("Default").tag("default")
                    Text("None").tag("none")
                    Text("Funk").tag("funk")
                    Text("Glass").tag("glass")
                }
                Toggle("Quiet hours · 22:00–08:00", isOn: $quietHours)
                Toggle("Coalesce >5 failures into one summary", isOn: $coalesce)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AdvancedTab: View {
    @State private var baseURL = "https://api.github.com"
    @State private var userAgent = "Sprocket/0.1 (matts-mbp; macOS 26.0)"

    var body: some View {
        Form {
            Section("API") {
                TextField("Base URL", text: $baseURL)
                Text("For GitHub Enterprise Server. The OAuth registration deeplink updates accordingly.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("User-Agent", text: $userAgent)
            }
            Section("Cache") {
                HStack {
                    Text("Cache size")
                    Spacer()
                    Text("284 KB").font(.system(size: 12, design: .monospaced))
                    Button("Reveal in Finder") { /* TODO */ }
                }
                Text("ETags + last-seen run snapshots.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Reset") {
                Button("Reset all data…", role: .destructive) { /* TODO */ }
                Text("Wipes Keychain entry, UserDefaults, and the cache. The OAuth app on GitHub is unaffected.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
