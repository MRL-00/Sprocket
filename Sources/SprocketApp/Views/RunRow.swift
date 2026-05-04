import SwiftUI
import SprocketKit

struct RunRow: View {
    let run: WorkflowRun
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL
    @State private var hover = false

    var body: some View {
        let density = state.density
        let isLive = run.effective.isLive
        let titleSize: CGFloat = density == .compact ? 11.5 : 12.5

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
                   hue: Double(run.actorHue),
                   size: density == .compact ? 14 : 16)
                .padding(.top, density == .compact ? 0 : 3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, density == .compact ? 5 : (density == .spacious ? 12 : 8))
        .background(hover ? Color.primary.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { openURL(run.htmlURL) }
        .onHover { hover = $0 }
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
