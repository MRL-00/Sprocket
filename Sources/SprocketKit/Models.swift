import Foundation

public enum RunStatus: String, Sendable, Codable, Hashable {
    case queued
    case inProgress = "in_progress"
    case completed
    case waiting
    case requested
    case pending

    public var isLive: Bool {
        switch self {
        case .queued, .inProgress, .waiting, .requested, .pending: return true
        case .completed: return false
        }
    }
}

public enum RunConclusion: String, Sendable, Codable, Hashable {
    case success
    case failure
    case cancelled
    case skipped
    case timedOut = "timed_out"
    case actionRequired = "action_required"
    case neutral
    case stale
}

/// Effective status used by the UI: collapses status + conclusion into a
/// single value the popover and menu bar render against.
public enum EffectiveStatus: String, Sendable, Hashable {
    case success
    case failure
    case running
    case queued
    case cancelled
    case skipped
    case actionRequired
    case timedOut
    case unknown

    public var isFailure: Bool {
        switch self {
        case .failure, .timedOut, .actionRequired: return true
        default: return false
        }
    }

    public var isLive: Bool { self == .running || self == .queued }
}

public struct WorkflowRun: Sendable, Identifiable, Hashable, Codable {
    public let id: Int64
    public let repo: String                 // "org/repo"
    public let workflowName: String
    public let displayTitle: String
    public let branch: String
    public let event: String                // push, pull_request, schedule, workflow_dispatch
    public let status: RunStatus
    public let conclusion: RunConclusion?
    public let runNumber: Int
    public let actor: String
    public let actorHue: Int                // for procedural avatar tint
    public let startedAt: Date
    public let updatedAt: Date
    public let durationSeconds: Int
    public let htmlURL: URL

    public init(
        id: Int64,
        repo: String,
        workflowName: String,
        displayTitle: String,
        branch: String,
        event: String,
        status: RunStatus,
        conclusion: RunConclusion?,
        runNumber: Int,
        actor: String,
        actorHue: Int,
        startedAt: Date,
        updatedAt: Date,
        durationSeconds: Int,
        htmlURL: URL
    ) {
        self.id = id
        self.repo = repo
        self.workflowName = workflowName
        self.displayTitle = displayTitle
        self.branch = branch
        self.event = event
        self.status = status
        self.conclusion = conclusion
        self.runNumber = runNumber
        self.actor = actor
        self.actorHue = actorHue
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.durationSeconds = durationSeconds
        self.htmlURL = htmlURL
    }

    public var effective: EffectiveStatus {
        switch status {
        case .queued, .waiting, .requested, .pending: return .queued
        case .inProgress: return .running
        case .completed:
            switch conclusion {
            case .success: return .success
            case .failure: return .failure
            case .cancelled: return .cancelled
            case .skipped: return .skipped
            case .timedOut: return .timedOut
            case .actionRequired: return .actionRequired
            case .neutral, .stale, .none: return .unknown
            }
        }
    }
}

public struct Repository: Sendable, Identifiable, Hashable, Codable {
    public let id: Int64
    public let fullName: String   // "org/repo"
    public let org: String
    public let isArchived: Bool
    public let isFork: Bool
    public var watching: Bool
    public var muted: Bool

    public init(id: Int64, fullName: String, org: String, isArchived: Bool, isFork: Bool, watching: Bool, muted: Bool) {
        self.id = id
        self.fullName = fullName
        self.org = org
        self.isArchived = isArchived
        self.isFork = isFork
        self.watching = watching
        self.muted = muted
    }
}

public struct GitHubUser: Sendable, Hashable, Codable {
    public let login: String
    public let name: String?
    public let avatarHue: Int

    public init(login: String, name: String?, avatarHue: Int = 200) {
        self.login = login
        self.name = name
        self.avatarHue = avatarHue
    }
}

public struct RateLimit: Sendable, Hashable, Codable {
    public var limit: Int
    public var remaining: Int
    public var resetAt: Date

    public init(limit: Int, remaining: Int, resetAt: Date) {
        self.limit = limit
        self.remaining = remaining
        self.resetAt = resetAt
    }

    public var fraction: Double {
        guard limit > 0 else { return 0 }
        return Double(remaining) / Double(limit)
    }
}

/// Aggregate state for the menu bar glyph.
/// Precedence: failure → running → rateLimited → success.
public enum MenuBarState: Sendable, Hashable {
    case authMissing
    case rateLimited
    case failure
    case running
    case success

    public static func aggregate(runs: [WorkflowRun], authed: Bool, rateLimit: RateLimit?) -> MenuBarState {
        guard authed else { return .authMissing }
        if runs.contains(where: { $0.effective.isFailure }) { return .failure }
        if runs.contains(where: { $0.effective.isLive }) { return .running }
        if let rl = rateLimit, rl.remaining == 0 { return .rateLimited }
        return .success
    }
}

public enum FilterTab: String, Sendable, Hashable, CaseIterable {
    case all, running, failing, recent
}

public enum Density: String, Sendable, Hashable, Codable, CaseIterable {
    case compact, comfortable, spacious
}

/// State transition emitted by RunMonitor diff logic.
public enum RunStateChange: Sendable, Hashable {
    case started(WorkflowRun)
    case succeeded(WorkflowRun)
    case failed(WorkflowRun)
    case cancelled(WorkflowRun)
}
