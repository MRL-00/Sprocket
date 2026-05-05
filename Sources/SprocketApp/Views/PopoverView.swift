import SwiftUI
import SprocketKit

struct PopoverView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow
    @State private var didBootstrap = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderRow()
            Divider().opacity(0.6)
            FilterRow()
            Divider().opacity(0.6)
            OrgSwitcherRow()
            Divider().opacity(0.6)
            if !state.isAuthed && !state.mockMode {
                SignedOutPlaceholder {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "welcome")
                }
            } else {
                RunListView()
            }
            Divider().opacity(0.6)
            FooterRow()
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.primary.opacity(0.10), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(width: 420, height: 560)
        .font(.system(size: 12, design: .default))
        .task {
            guard !didBootstrap, !state.mockMode else { return }
            didBootstrap = true
            // Detach so closing the popover doesn't cancel the in-flight refresh.
            Task { @MainActor in
                await state.bootstrap()
                if !state.isAuthed {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "welcome")
                }
            }
        }
    }
}

private struct SignedOutPlaceholder: View {
    let onSignIn: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Not signed in")
                .font(.system(size: 13, weight: .semibold))
            Text("Connect Sprocket to GitHub to see your workflow runs.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Sign in to GitHub", action: onSignIn)
                .buttonStyle(.borderedProminent)
                .tint(Color.sprocketAccent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HeaderRow: View {
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 10) {
            Avatar(login: state.user?.login ?? "?",
                   hue: Double(state.user?.avatarHue ?? 200),
                   size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(state.user?.login ?? "Not signed in")
                    .font(.system(size: 12.5, weight: .semibold))
                    .kerning(-0.1)
                Text(headline)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            IconButton(systemName: "arrow.clockwise", help: "Refresh (⌘R)") {
                Task { await state.refresh() }
            }
            IconButton(systemName: "gearshape", help: "Settings") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            IconButton(systemName: "ellipsis", help: "More") { /* TODO */ }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var headline: String {
        let n = state.repositories.count
        let refresh = state.lastRefresh.map { Formatting.relative($0) } ?? "never refreshed"
        return "\(n) repos · last refreshed \(refresh)"
    }
}

private struct IconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(hover ? Color.primary.opacity(0.06) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5))
                .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

private struct FilterRow: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        HStack(spacing: 8) {
            Picker("", selection: $state.filter) {
                ForEach(FilterTab.allCases, id: \.self) { t in
                    Text(label(t))
                        .font(.system(size: 11, weight: .medium))
                        .tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            ZStack(alignment: .leading) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 7)
                TextField("Filter…", text: $state.freeTextFilter)
                    .textFieldStyle(.plain)
                    .padding(.leading, 22)
                    .padding(.trailing, 8)
                    .frame(height: 24)
                    .background(.background.opacity(0.6),
                                in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func label(_ t: FilterTab) -> String {
        let c = state.counts
        switch t {
        case .all:     return "All  \(c.all)"
        case .running: return "Running  \(c.running)"
        case .failing: return "Failing  \(c.failing)"
        case .recent:  return "Recent"
        }
    }
}

private struct OrgSwitcherRow: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 6) {
            Text("Showing")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            Menu {
                Button("All organizations") { state.orgScope = "All organizations" }
                Divider()
                ForEach(orgs, id: \.self) { org in
                    Button(org) { state.orgScope = org }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(state.orgScope)
                        .font(.system(size: 11))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Spacer(minLength: 0)
            Text("\(state.visibleRuns.count) runs")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var orgs: [String] {
        Array(Set(state.repositories.map(\.org))).sorted()
    }
}

private struct RunListView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            if filtered.isEmpty && state.isRefreshing {
                LoadingPlaceholder()
            } else if filtered.isEmpty, let err = state.lastFetchError {
                ErrorPlaceholder(message: err) { Task { await state.refresh() } }
            } else if filtered.isEmpty {
                EmptyPlaceholder()
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { run in
                            RunRow(run: run)
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filtered: [WorkflowRun] {
        let scoped: [WorkflowRun]
        if state.orgScope == "All organizations" {
            scoped = state.visibleRuns
        } else {
            scoped = state.visibleRuns.filter { $0.repo.hasPrefix(state.orgScope + "/") }
        }
        return scoped
    }
}

private struct LoadingPlaceholder: View {
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView().controlSize(.regular)
            Text("Loading workflow runs…")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyPlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No workflow runs match")
                .font(.system(size: 12, weight: .medium))
            Text("Try a different filter or refresh.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ErrorPlaceholder: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Couldn't fetch runs")
                .font(.system(size: 12, weight: .medium))
            Text(message)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .lineLimit(3)
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FooterRow: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 8) {
            RateBar(fraction: state.rateLimit?.fraction ?? 0)
            Text(rateText)
                .font(.system(size: 10.5, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text("· resets in \(resetText)")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
            Link(destination: URL(string: "https://github.com")!) {
                HStack(spacing: 3) {
                    Text("Open Actions").font(.system(size: 10.5))
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 9))
                }
            }
            .foregroundStyle(Color.sprocketAccent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.02))
    }

    private var rateText: String {
        let l = state.rateLimit?.limit ?? 5_000
        let r = state.rateLimit?.remaining ?? 0
        return "\(Formatting.compactNumber(r)) / \(Formatting.compactNumber(l))"
    }

    private var resetText: String {
        guard let r = state.rateLimit?.resetAt else { return "—" }
        let m = max(0, Int(r.timeIntervalSinceNow) / 60)
        return "\(m)m"
    }
}

private struct RateBar: View {
    let fraction: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.primary.opacity(0.10)).frame(width: 56, height: 4)
            Capsule().fill(Color.sprocketSuccess).frame(width: max(2, 56 * fraction), height: 4)
        }
        .frame(width: 56, height: 4)
    }
}
