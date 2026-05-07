import SwiftUI
import SprocketKit

struct RunRow: View {
    let run: WorkflowRun
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL
    @State private var hover = false
    @State private var expanded = false
    @State private var jobs: [WorkflowJob] = []
    @State private var jobsLoading = false
    @State private var jobsError: String?

    var body: some View {
        let density = state.density
        let isLive = run.effective.isLive
        let titleSize: CGFloat = density == .compact ? 11.5 : 12.5

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
                        Text(durationLabel)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
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
                        Text(durationLabel)
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

            Avatar(login: run.actor,
                   imageURL: run.actorAvatarURL,
                   hue: Double(run.actorHue),
                   size: density == .compact ? 14 : 16)
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
                    retry: { Task { await loadJobs(force: true) } }
                )
                .transition(.opacity)
            }
        }
        .background(expanded ? Color.primary.opacity(0.03) : Color.clear)
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
        if expanded && jobs.isEmpty && !jobsLoading {
            Task { await loadJobs(force: false) }
        }
    }

    private func loadJobs(force: Bool) async {
        if jobsLoading { return }
        if !force && !jobs.isEmpty { return }
        jobsLoading = true
        jobsError = nil
        defer { jobsLoading = false }
        do {
            if state.mockMode {
                jobs = MockData.jobs(forRunID: run.id)
            } else {
                jobs = try await state.client.listJobs(repo: run.repo, runID: run.id)
            }
        } catch {
            jobsError = "\(error)"
        }
    }

    private var durationLabel: String {
        if run.effective.isLive {
            return "running · \(Formatting.duration(seconds: run.durationSeconds))"
        }
        return Formatting.duration(seconds: run.durationSeconds)
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

private struct JobsDisclosure: View {
    let run: WorkflowRun
    let jobs: [WorkflowJob]
    let isLoading: Bool
    let error: String?
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
                ForEach(jobs) { job in
                    JobRow(job: job)
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

private struct JobRow: View {
    let job: WorkflowJob
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
        }
        .padding(.vertical, 5)
        .padding(.leading, 24)
        .padding(.trailing, 14)
        .background(hover ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { hover = $0 }
    }

    private var durationLabel: String {
        if job.effective.isLive {
            return "running · \(Formatting.duration(seconds: job.durationSeconds))"
        }
        return Formatting.duration(seconds: job.durationSeconds)
    }
}
