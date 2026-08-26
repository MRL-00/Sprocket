import SwiftUI
import SprocketKit

struct RunRow: View, Equatable {
    let run: WorkflowRun
    let now: Date
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL
    @State private var hover = false
    @State private var expanded = false
    @State private var jobs: [WorkflowJob] = []
    @State private var jobsLoading = false
    @State private var jobsError: String?
    @State private var logTails: [Int64: [String]] = [:]
    @State private var logLoading: Set<Int64> = []
    @State private var logFetchedAt: [Int64: Date] = [:]

    nonisolated static func == (lhs: RunRow, rhs: RunRow) -> Bool {
        guard lhs.run == rhs.run else { return false }
        if lhs.run.effective.isLive {
            return Int(lhs.now.timeIntervalSince1970) == Int(rhs.now.timeIntervalSince1970)
        }
        return true
    }

    var body: some View {
        let density = state.density
        let isLive = run.effective.isLive
        let titleSize: CGFloat = density == .compact ? 11.5 : 12.5
        let stats = (isLive || expanded)
            ? state.timingStats(for: run)
            : WorkflowTimingStats(completedDurations: [], trendSeconds: [])

        VStack(spacing: 0) {
            HStack(alignment: density == .compact ? .center : .top, spacing: 10) {
            StatusDot(status: run.effective, size: density == .spacious ? 10 : 9)
                .padding(.top, density == .compact ? 0 : 3)
                .frame(width: 14, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(run.repo)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    Text("·").font(.system(size: 10)).foregroundStyle(.quaternary)
                    Text(run.workflowName)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text(run.displayTitle)
                    .font(.system(size: titleSize, weight: isLive ? .medium : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, 1)

                if density != .compact {
                    HStack(spacing: 5) {
                        Chip(systemImage: "arrow.triangle.branch", text: run.branch)
                        Chip(systemImage: eventIcon, text: run.event)
                        Text(durationLabel(now: now, stats: stats))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                        if let eta = etaLabel(now: now, stats: stats) {
                            Text("· \(eta)")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.sprocketAccent)
                                .monospacedDigit()
                        }
                        Text("· \(Formatting.relative(run.startedAt))")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.quaternary)
                    }
                    .padding(.top, 5)
                } else {
                    HStack(spacing: 8) {
                        Text(run.branch)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Text("·").foregroundStyle(.quaternary).font(.system(size: 10))
                        Text(durationLabel(now: now, stats: stats))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                        Text("·").foregroundStyle(.quaternary).font(.system(size: 10))
                        Text(Formatting.relative(run.startedAt))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 5) {
                Avatar(login: run.actor,
                       imageURL: run.actorAvatarURL,
                       hue: Double(run.actorHue),
                       size: density == .compact ? 14 : 16)
                RowActions(run: run)
            }
            .padding(.top, density == .compact ? 0 : 3)
        }
            .padding(.horizontal, 14)
            .padding(.vertical, density == .compact ? 5 : (density == .spacious ? 12 : 8))
            .background(hover ? Color.primary.opacity(0.04) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { toggleExpansion() }
            .onHover { hover = $0 }
            .contextMenu { contextMenuItems }

            if expanded {
                Divider()
                    .padding(.leading, 38)
                    .padding(.trailing, 14)
                JobsDisclosure(
                    run: run,
                    jobs: jobs,
                    isLoading: jobsLoading,
                    error: jobsError,
                    stats: stats,
                    now: now,
                    logTails: logTails,
                    logLoading: logLoading,
                    loadLog: { job in Task { await loadLogTail(job) } },
                    retry: { Task { await loadJobs(force: true) } }
                )
                .transition(.opacity)
            }
        }
        .background(expanded ? Color.primary.opacity(0.03) : Color.clear)
        // Jobs are a one-shot fetch unless we keep polling while the disclosure
        // is open. Without this, a job that finishes after expand stays "running"
        // forever (even after the parent run flips to completed).
        .task(id: jobsRefreshTaskID) {
            guard expanded else { return }
            await loadJobs(force: true)
            while !Task.isCancelled {
                let shouldKeepPolling = run.effective.isLive
                    || jobs.contains { $0.effective.isLive }
                guard shouldKeepPolling else { return }
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, expanded else { return }
                await loadJobs(force: true)
            }
        }
    }

    /// Restart the jobs poll when expansion toggles, the run identity changes,
    /// or the run leaves/enters a live state (so we immediately pull terminal jobs).
    private var jobsRefreshTaskID: String {
        "\(run.id)-\(expanded)-\(run.effective.isLive)"
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button("Open in GitHub") { openURL(run.htmlURL) }
        Divider()
        Button(expanded ? "Hide jobs" : "Show jobs") { toggleExpansion() }
        Divider()
        if run.effective.isLive {
            Button("Cancel run", role: .destructive) {
                Task { await state.cancelRun(run) }
            }
        } else {
            Button("Re-run all jobs") {
                Task { await state.rerunRun(run) }
            }
            if run.effective.isFailure {
                Button("Re-run failed jobs") {
                    Task { await state.rerunFailedJobs(run) }
                }
            }
        }
        Divider()
        Button("Copy run URL") {
            #if canImport(AppKit)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(run.htmlURL.absoluteString, forType: .string)
            #endif
        }
    }

    private func toggleExpansion() {
        withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() }
    }

    private func loadJobs(force: Bool) async {
        if jobsLoading { return }
        if !force && !jobs.isEmpty { return }
        // Only show the spinner on the first load — background polls should
        // replace rows in place without flickering "Loading jobs…".
        let showLoading = jobs.isEmpty
        if showLoading { jobsLoading = true }
        jobsError = nil
        defer { if showLoading { jobsLoading = false } }
        do {
            if state.mockMode {
                jobs = MockData.jobs(forRunID: run.id)
            } else {
                jobs = try await state.client.listJobs(repo: run.repo, runID: run.id)
            }
        } catch {
            // Keep previously loaded jobs visible during a failed background poll.
            if jobs.isEmpty {
                jobsError = "\(error)"
            }
        }
    }

    private func loadLogTail(_ job: WorkflowJob) async {
        guard !logLoading.contains(job.id) else { return }
        if let fetchedAt = logFetchedAt[job.id],
           Date().timeIntervalSince(fetchedAt) < 10 {
            return
        }
        logLoading.insert(job.id)
        defer { logLoading.remove(job.id) }
        do {
            if state.mockMode {
                logTails[job.id] = [
                    "Run swift test --parallel",
                    "Test Suite 'SprocketKitTests' started",
                    "Executing current step for \(job.name)…",
                ]
            } else {
                logTails[job.id] = try await state.client.fetchJobLogTail(repo: run.repo, jobID: job.id)
            }
            logFetchedAt[job.id] = Date()
        } catch {
            let message = "\(error)"
            if message.contains("404") || message.contains("410") {
                logTails[job.id] = ["Logs not available yet — GitHub uploads them in chunks while the job runs."]
            } else {
                logTails[job.id] = ["Unable to fetch log tail: \(error)"]
            }
        }
    }

    private func durationLabel(now: Date, stats: WorkflowTimingStats) -> String {
        if run.effective == .queued {
            return "queued \(Formatting.duration(seconds: run.queuedSeconds(now: now)))"
        }
        if run.effective == .running {
            let queued = run.queuedSeconds(now: now)
            let running = run.runningSeconds(now: now)
            if queued > 0 {
                return "queued \(Formatting.duration(seconds: queued)) · running \(Formatting.duration(seconds: running))"
            }
            return "running \(Formatting.duration(seconds: running))"
        }
        return Formatting.duration(seconds: run.durationSeconds)
    }

    private func etaLabel(now: Date, stats: WorkflowTimingStats) -> String? {
        guard run.effective == .running,
              let p50 = stats.p50Seconds,
              let average = stats.averageSeconds else { return nil }
        let elapsed = run.runningSeconds(now: now)
        guard elapsed >= p50, average > elapsed else { return nil }
        return "≈ \(Formatting.durationShort(seconds: average - elapsed)) left"
    }

    private var eventIcon: String {
        switch run.event {
        case "pull_request":     return "arrow.triangle.pull"
        case "schedule":         return "calendar"
        case "workflow_dispatch": return "wand.and.stars"
        case "push":             return "arrow.up.circle"
        default:                 return "circle.dotted"
        }
    }
}

private struct RowActions: View {
    let run: WorkflowRun
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 4) {
            Button {
                state.togglePinned(run)
            } label: {
                Image(systemName: state.settings.isPinned(run) ? "star.fill" : "star")
            }
            .help(state.settings.isPinned(run) ? "Unpin workflow" : "Pin workflow")

            if run.effective.isLive {
                Button(role: .destructive) {
                    confirmCancellation()
                } label: {
                    Image(systemName: "stop.circle")
                }
                .help("Cancel run")
            } else if run.effective.isFailure {
                Button {
                    Task { await state.rerunFailedJobs(run) }
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                }
                .help("Re-run failed jobs")
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.mini)
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
    }

    private func confirmCancellation() {
        let alert = NSAlert()
        alert.messageText = "Cancel this workflow run?"
        alert.informativeText = "\(run.repo) · \(run.workflowName)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel run").hasDestructiveAction = true
        alert.addButton(withTitle: "Keep running")

        if alert.runModal() == .alertFirstButtonReturn {
            Task { await state.cancelRun(run) }
        }
    }
}

private struct JobsDisclosure: View {
    let run: WorkflowRun
    let jobs: [WorkflowJob]
    let isLoading: Bool
    let error: String?
    let stats: WorkflowTimingStats
    let now: Date
    let logTails: [Int64: [String]]
    let logLoading: Set<Int64>
    let loadLog: (WorkflowJob) -> Void
    let retry: () -> Void

    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading && jobs.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading jobs…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.horizontal, 38)
            } else if let error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.sprocketFailure)
                    Text(error)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Button("Retry", action: retry)
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.horizontal, 38)
            } else if jobs.isEmpty {
                Text("No jobs reported.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 38)
            } else {
                WorkflowMetrics(stats: stats)
                ForEach(jobs) { job in
                    JobRow(
                        job: job,
                        now: now,
                        tail: logTails[job.id],
                        isLoadingLog: logLoading.contains(job.id),
                        loadLog: { loadLog(job) }
                    )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let url = job.htmlURL { openURL(url) }
                        }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WorkflowMetrics: View {
    let stats: WorkflowTimingStats

    var body: some View {
        if !stats.trendSeconds.isEmpty {
            HStack(spacing: 8) {
                Text("last 20")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Sparkline(values: stats.trendSeconds)
                    .frame(width: 72, height: 18)
                if let avg = stats.averageSeconds {
                    Text("avg \(Formatting.durationShort(seconds: avg))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 38)
            .padding(.vertical, 5)
        }
    }
}

private struct Sparkline: View {
    let values: [Int]

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                guard values.count > 1, let minValue = values.min(), let maxValue = values.max() else { return }
                let width = proxy.size.width
                let height = proxy.size.height
                if minValue == maxValue {
                    path.move(to: CGPoint(x: 0, y: height / 2))
                    path.addLine(to: CGPoint(x: width, y: height / 2))
                    return
                }
                let range = CGFloat(maxValue - minValue)
                for index in values.indices {
                    let x = width * CGFloat(index) / CGFloat(values.count - 1)
                    let y = height - (height * CGFloat(values[index] - minValue) / range)
                    if index == values.startIndex {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.sprocketAccent, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        }
        .accessibilityLabel("Workflow duration trend")
    }
}

private struct JobRow: View {
    let job: WorkflowJob
    let now: Date
    let tail: [String]?
    let isLoadingLog: Bool
    let loadLog: () -> Void
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                StatusDot(status: job.effective, size: 7)
                    .frame(width: 14, alignment: .center)
                Text(job.name)
                    .font(.system(size: 11.5, weight: job.effective.isFailure ? .medium : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(durationLabel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            if let failing = job.firstFailingStepName {
                HStack(spacing: 6) {
                    Spacer().frame(width: 14)
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.sprocketFailure)
                    Text("failed at: \(failing)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            let slowest = job.slowestSteps(now: now)
            if !slowest.isEmpty {
                HStack(spacing: 6) {
                    Spacer().frame(width: 14)
                    Image(systemName: "timer")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(slowest.map { "\($0.0.name) \(Formatting.durationShort(seconds: $0.1))" }.joined(separator: " · "))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            if job.effective.isLive {
                HStack(spacing: 6) {
                    Spacer().frame(width: 14)
                    Button {
                        loadLog()
                    } label: {
                        Label(isLoadingLog ? "Loading log…" : "Tail log", systemImage: "text.alignleft")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.mini)
                    .disabled(isLoadingLog)
                    Spacer(minLength: 0)
                }
                if let tail, !tail.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(tail.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.leading, 24)
        .padding(.trailing, 14)
        .background(hover ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { hover = $0 }
    }

    private var durationLabel: String {
        if job.effective.isLive {
            return "running · \(Formatting.duration(seconds: job.runningSeconds(now: now)))"
        }
        return Formatting.duration(seconds: job.durationSeconds)
    }
}
