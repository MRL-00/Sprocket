import SwiftUI
import Combine
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
            if !state.repositoryRefreshFailures.isEmpty {
                Divider().opacity(0.6)
                RefreshWarningRow()
            }
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
        .frame(width: 440, height: 560)
        .font(.system(size: 12, design: .default))
        .task {
            guard !state.mockMode else { return }
            // Detach so closing the popover doesn't cancel the in-flight refresh.
            if !didBootstrap {
                didBootstrap = true
                Task { @MainActor in
                    await state.bootstrap()
                    if !state.isAuthed {
                        openWindow(id: "welcome")
                        AppWindowController.bringWelcomeToFrontAfterOpen()
                    }
                }
            } else if state.isAuthed {
                // Each subsequent open kicks an immediate refresh so the user
                // sees the freshest state without waiting on the poll cadence.
                Task { @MainActor in await state.refresh() }
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
    @Environment(UpdateManager.self) private var updater
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 10) {
            Avatar(login: state.user?.login ?? "?",
                   imageURL: state.user?.avatarURL,
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
            Text(BuildIdentity.versionLabel(updater.currentVersion))
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(BuildIdentity.isLocalBuild ? Color.sprocketAccent : Color.secondary.opacity(0.7))
                .lineLimit(1)
                .help(BuildIdentity.helpText(version: updater.currentVersion))
            IconButton(systemName: "arrow.clockwise", help: "Refresh (⌘R)") {
                Task { await state.refresh() }
            }
            IconButton(systemName: "gearshape", help: "Settings") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            MoreMenu()
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

private struct MoreMenu: View {
    @Environment(AppState.self) private var state
    @Environment(UpdateManager.self) private var updater
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var hover = false

    var body: some View {
        Menu {
            if state.isAuthed {
                Button("Refresh now", systemImage: "arrow.clockwise") {
                    Task { await state.refresh() }
                }
                .keyboardShortcut("r")

                if state.isPolling {
                    Button("Pause polling", systemImage: "pause.circle") {
                        state.stopPolling()
                    }
                } else {
                    Button("Resume polling", systemImage: "play.circle") {
                        state.startPolling()
                    }
                }

                Divider()

                Button("Open GitHub Actions", systemImage: "arrow.up.right.square") {
                    openURL(URL(string: "https://github.com")!)
                }
            } else {
                Button("Sign in to GitHub", systemImage: "person.crop.circle.badge.plus") {
                    openWindow(id: "welcome")
                    AppWindowController.bringWelcomeToFrontAfterOpen()
                }
                Divider()
            }

            Button("Welcome / Reconfigure…", systemImage: "sparkles") {
                openWindow(id: "welcome")
                AppWindowController.bringWelcomeToFrontAfterOpen()
            }

            Divider()

            Button("Check for Updates…", systemImage: "arrow.down.circle") {
                Task { await updater.checkForUpdatesWithUserFeedback() }
            }

            Button("Settings…", systemImage: "gearshape") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            .keyboardShortcut(",")

            Button("About Sprocket", systemImage: "info.circle") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            }

            if state.isAuthed {
                Divider()
                Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    Task { await state.signOut() }
                }
            }

            Divider()

            Button("Quit Sprocket", systemImage: "power") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(hover ? Color.primary.opacity(0.06) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5))
                .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hover = $0 }
        .help("More")
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
                        .font(.system(size: 10.5, weight: .medium))
                        .tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

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
            .frame(width: 116)
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
                Button("All accounts") { state.orgScope = "All accounts" }
                Button("All organizations") { state.orgScope = "All organizations" }
                Divider()
                if let login = state.user?.login {
                    Button("\(login) · Personal") { state.orgScope = login }
                } else {
                    Button("Personal account") { state.orgScope = "Personal" }
                }
                ForEach(orgs, id: \.self) { org in
                    Button("\(org) · Organization") { state.orgScope = org }
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
            Text(runCountLabel)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var orgs: [String] {
        Array(
            Set(
                state.repositories
                    .map(\.org)
                    .filter { $0 != "Personal" && $0 != state.user?.login }
            )
        )
        .sorted()
    }

    private var runCountLabel: String {
        let shown = scoped(state.displayedRuns).count
        let total = scoped(state.visibleRuns).count
        if total > shown {
            return "\(shown) of \(total)+"
        }
        return state.hasMoreHistory ? "\(shown)+ runs" : "\(shown) runs"
    }

    private func scoped(_ runs: [WorkflowRun]) -> [WorkflowRun] {
        switch state.orgScope {
        case "All accounts":
            return runs
        case "All organizations":
            let orgPrefixes = Set(orgs.map { $0 + "/" })
            return runs.filter { run in orgPrefixes.contains(where: { run.repo.hasPrefix($0) }) }
        case "Personal":
            guard let login = state.user?.login else { return runs }
            return runs.filter { $0.repo.hasPrefix(login + "/") }
        default:
            return runs.filter { $0.repo.hasPrefix(state.orgScope + "/") }
        }
    }
}

private struct RefreshWarningRow: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.sprocketWarning)
            Text(warningText)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Menu {
                ForEach(state.repositoryRefreshFailures) { failure in
                    Text("\(failure.repository): \(failure.message)")
                }
            } label: {
                Text("Details")
                    .font(.system(size: 10.5, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            Button {
                Task { await state.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .help("Retry refresh")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.sprocketWarning.opacity(0.08))
    }

    private var warningText: String {
        let count = state.repositoryRefreshFailures.count
        return count == 1 ? "1 repo failed to refresh" : "\(count) repos failed to refresh"
    }
}

private struct RunListView: View {
    @Environment(AppState.self) private var state
    @State private var now = Date()
    private let liveTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, run in
                            RunRow(run: run, now: now)
                                .equatable()
                                .onAppear {
                                    // Prefetch when user scrolls within 5 of the end.
                                    if index >= filtered.count - 5 {
                                        Task { await state.loadMoreRuns() }
                                    }
                                }
                            Divider().opacity(0.4)
                        }
                        LoadMoreFooter()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(liveTicker) { date in
            now = date
            if Int(date.timeIntervalSince1970) % 10 == 0 {
                state.evaluateLongRunAlerts(now: date)
            }
        }
    }

    private var filtered: [WorkflowRun] {
        switch state.orgScope {
        case "All accounts":
            return state.displayedRuns
        case "All organizations":
            let prefixes = Set(
                state.repositories
                    .map(\.org)
                    .filter { $0 != "Personal" && $0 != state.user?.login }
                    .map { $0 + "/" }
            )
            return state.displayedRuns.filter { run in prefixes.contains(where: { run.repo.hasPrefix($0) }) }
        case "Personal":
            guard let login = state.user?.login else { return state.displayedRuns }
            return state.displayedRuns.filter { $0.repo.hasPrefix(login + "/") }
        default:
            return state.displayedRuns.filter { $0.repo.hasPrefix(state.orgScope + "/") }
        }
    }
}

private struct LoadMoreFooter: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            if state.isLoadingMore {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading older runs…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            } else if state.hasMoreHistory {
                Button {
                    Task { await state.loadMoreRuns() }
                } label: {
                    Text("Load older runs")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.sprocketAccent)
                .onAppear {
                    // Auto-load when the user scrolls the sentinel into view.
                    Task { await state.loadMoreRuns() }
                }
            } else if !state.runs.isEmpty {
                Text("End of history")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
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
            if let usage = state.actionsUsage {
                UsageBar(fraction: usage.fraction, isOverBudget: usage.isOverBudget)
                Text(actionsUsageText(usage))
                    .font(.system(size: 10.5, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(usage.isOverBudget ? Color.sprocketFailure : Color.secondary)
            } else {
                UsageBar(fraction: 0, isOverBudget: false)
                Text("CI minutes unavailable")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            Menu {
                let repoBreakdown = state.estimatedWorkflowCostBreakdown(groupByWorkflow: false)
                let workflowBreakdown = state.estimatedWorkflowCostBreakdown(groupByWorkflow: true)
                if let projected = state.projectedEndOfMonthMinutes() {
                    Text("Projected EOM: \(Formatting.compactNumber(projected)) minutes")
                } else {
                    Text("Projected EOM: available after day 5")
                }
                if let usage = state.actionsUsage {
                    Section("Reported runner cost estimate") {
                        if usage.runnerCostBreakdown.isEmpty {
                            Text("No runner breakdown available")
                        } else {
                            ForEach(usage.runnerCostBreakdown) { item in
                                Text("\(item.runner) · \(Formatting.compactNumber(item.minutes))m · \(costLabel(item.estimatedCost))")
                            }
                            Text("Total · \(costLabel(usage.estimatedHostedRunnerCost))")
                        }
                    }
                }
                Section("By repository · Linux-equivalent estimate") {
                    if repoBreakdown.isEmpty {
                        Text("No current-month runs in view")
                    } else {
                        ForEach(repoBreakdown.prefix(8)) { item in
                            Text("\(item.repo) · \(Formatting.compactNumber(item.minutes))m · \(costLabel(item.estimatedCost)) Linux est.")
                        }
                    }
                }
                Section("By workflow · Linux-equivalent minutes") {
                    if workflowBreakdown.isEmpty {
                        Text("No current-month runs in view")
                    } else {
                        ForEach(workflowBreakdown.prefix(8)) { item in
                            Text("\(item.repo) / \(item.workflowName ?? "Workflow") · \(Formatting.compactNumber(item.minutes))m")
                        }
                    }
                }
            } label: {
                Image(systemName: "chart.pie")
                    .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Cost breakdown")

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
        .help(actionsUsageHelp)
    }

    private func actionsUsageText(_ usage: ActionsUsage) -> String {
        "\(Formatting.compactNumber(usage.totalMinutesUsed)) / \(Formatting.compactNumber(usage.includedMinutes)) CI minutes this month"
    }

    private func costLabel(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    private var actionsUsageHelp: String {
        let accounts = scopedAccounts
        guard !accounts.isEmpty else {
            return "GitHub Actions billing usage is unavailable for this account."
        }
        var lines = accounts
            .map { account in
                "\(account.displayName): \(Formatting.compactNumber(account.usage.totalMinutesUsed)) / \(Formatting.compactNumber(account.usage.includedMinutes)) minutes"
            }
        if let projected = state.projectedEndOfMonthMinutes() {
            lines.append("Projected end of month: \(Formatting.compactNumber(projected)) minutes")
        } else {
            lines.append("Projected end of month: available after day 5")
        }
        lines.append("Cost estimates use Linux hosted-runner pricing; GitHub bills Windows and macOS at higher multipliers.")
        return lines.joined(separator: "\n")
    }

    private var scopedAccounts: [ActionsUsageAccount] {
        if state.orgScope == "All accounts" || state.orgScope == "All organizations" {
            return state.orgScope == "All organizations"
                ? state.actionsUsageAccounts.filter(\.isOrg)
                : state.actionsUsageAccounts
        }
        if state.orgScope == "Personal" || state.orgScope == state.user?.login {
            return state.actionsUsageAccounts.filter { !$0.isOrg }
        }
        return state.actionsUsageAccounts.filter { $0.isOrg && $0.name == state.orgScope }
    }
}

private struct UsageBar: View {
    let fraction: Double
    let isOverBudget: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.primary.opacity(0.10)).frame(width: 56, height: 4)
            Capsule()
                .fill(isOverBudget ? Color.sprocketFailure : Color.sprocketAccent)
                .frame(width: max(2, 56 * min(max(fraction, 0), 1)), height: 4)
        }
        .frame(width: 56, height: 4)
    }
}
