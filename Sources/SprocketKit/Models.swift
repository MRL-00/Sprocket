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

/// Collapse a raw status + conclusion pair into the single `EffectiveStatus`
/// the UI renders against. Shared by runs, jobs, and steps.
func effectiveStatus(_ status: RunStatus, _ conclusion: RunConclusion?) -> EffectiveStatus {
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
    public let actorAvatarURL: URL?
    public let createdAt: Date
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
        actorAvatarURL: URL? = nil,
        startedAt: Date,
        updatedAt: Date,
        durationSeconds: Int,
        htmlURL: URL,
        createdAt: Date? = nil
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
        self.actorAvatarURL = actorAvatarURL
        self.createdAt = createdAt ?? startedAt
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.durationSeconds = durationSeconds
        self.htmlURL = htmlURL
    }

    public var effective: EffectiveStatus {
        effectiveStatus(status, conclusion)
    }

    public var workflowKey: WorkflowKey {
        WorkflowKey(repo: repo, workflowName: workflowName)
    }

    public var workflowBranchKey: WorkflowBranchKey {
        WorkflowBranchKey(repo: repo, workflowName: workflowName, branch: branch)
    }

    public func queuedSeconds(now: Date = Date()) -> Int {
        switch effective {
        case .queued:
            return max(0, Int(now.timeIntervalSince(createdAt)))
        default:
            return max(0, Int(startedAt.timeIntervalSince(createdAt)))
        }
    }

    public func runningSeconds(now: Date = Date()) -> Int {
        switch effective {
        case .running:
            return max(0, Int(now.timeIntervalSince(startedAt)))
        case .queued:
            return 0
        default:
            return max(0, durationSeconds)
        }
    }

    public func liveElapsedSeconds(now: Date = Date()) -> Int {
        switch effective {
        case .running:
            return max(0, Int(now.timeIntervalSince(startedAt)))
        case .queued:
            return max(0, Int(now.timeIntervalSince(createdAt)))
        default:
            return durationSeconds
        }
    }
}

public struct WorkflowKey: Sendable, Hashable, Codable {
    public let repo: String
    public let workflowName: String

    public init(repo: String, workflowName: String) {
        self.repo = repo
        self.workflowName = workflowName
    }
}

public struct WorkflowBranchKey: Sendable, Hashable, Codable {
    public let repo: String
    public let workflowName: String
    public let branch: String

    public init(repo: String, workflowName: String, branch: String) {
        self.repo = repo
        self.workflowName = workflowName
        self.branch = branch
    }
}

public struct WorkflowTimingStats: Sendable, Hashable {
    public let completedDurations: [Int]
    public let averageSeconds: Int?
    public let p50Seconds: Int?
    public let trendSeconds: [Int]

    public init(completedDurations: [Int], trendSeconds: [Int]) {
        self.completedDurations = completedDurations
        self.trendSeconds = trendSeconds
        if completedDurations.isEmpty {
            self.averageSeconds = nil
            self.p50Seconds = nil
        } else {
            self.averageSeconds = completedDurations.reduce(0, +) / completedDurations.count
            let sorted = completedDurations.sorted()
            let lower = sorted[(sorted.count - 1) / 2]
            let upper = sorted[sorted.count / 2]
            self.p50Seconds = (lower + upper) / 2
        }
    }
}

public struct WorkflowCostBreakdown: Sendable, Identifiable, Hashable {
    public let id: String
    public let repo: String
    public let workflowName: String?
    public let minutes: Int
    public let estimatedCost: Double

    public init(repo: String, workflowName: String?, minutes: Int, estimatedCost: Double) {
        self.repo = repo
        self.workflowName = workflowName
        self.minutes = minutes
        self.estimatedCost = estimatedCost
        self.id = workflowName.map { "\(repo)|\($0)" } ?? repo
    }
}

public struct RunnerCostBreakdown: Sendable, Identifiable, Hashable {
    public let runner: String
    public let minutes: Int
    public let ratePerMinute: Double

    public init(runner: String, minutes: Int, ratePerMinute: Double) {
        self.runner = runner
        self.minutes = minutes
        self.ratePerMinute = ratePerMinute
    }

    public var id: String { runner }

    public var estimatedCost: Double {
        Double(minutes) * ratePerMinute
    }
}

public struct WorkflowStep: Sendable, Hashable, Codable, Identifiable {
    public let number: Int
    public let name: String
    public let status: RunStatus
    public let conclusion: RunConclusion?
    public let startedAt: Date?
    public let completedAt: Date?

    public init(
        number: Int,
        name: String,
        status: RunStatus,
        conclusion: RunConclusion?,
        startedAt: Date?,
        completedAt: Date?
    ) {
        self.number = number
        self.name = name
        self.status = status
        self.conclusion = conclusion
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    public var id: Int { number }

    public var effective: EffectiveStatus {
        effectiveStatus(status, conclusion)
    }

    public func durationSeconds(now: Date = Date()) -> Int? {
        guard let startedAt else { return nil }
        let end = completedAt ?? (effective.isLive ? now : nil)
        guard let end else { return nil }
        return max(0, Int(end.timeIntervalSince(startedAt)))
    }
}

public struct WorkflowJob: Sendable, Identifiable, Hashable, Codable {
    public let id: Int64
    public let runID: Int64
    public let name: String
    public let status: RunStatus
    public let conclusion: RunConclusion?
    public let startedAt: Date
    public let completedAt: Date?
    public let durationSeconds: Int
    public let htmlURL: URL?
    public let steps: [WorkflowStep]

    public init(
        id: Int64,
        runID: Int64,
        name: String,
        status: RunStatus,
        conclusion: RunConclusion?,
        startedAt: Date,
        completedAt: Date?,
        durationSeconds: Int,
        htmlURL: URL?,
        steps: [WorkflowStep]
    ) {
        self.id = id
        self.runID = runID
        self.name = name
        self.status = status
        self.conclusion = conclusion
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.htmlURL = htmlURL
        self.steps = steps
    }

    public var effective: EffectiveStatus {
        effectiveStatus(status, conclusion)
    }

    /// First failing step name, if any — handy for "failed at: …" labels.
    public var firstFailingStepName: String? {
        steps.first(where: { $0.effective.isFailure })?.name
    }

    public func runningSeconds(now: Date = Date()) -> Int {
        if effective.isLive {
            return max(0, Int(now.timeIntervalSince(startedAt)))
        }
        return durationSeconds
    }

    public func slowestSteps(limit: Int = 3, now: Date = Date()) -> [(WorkflowStep, Int)] {
        steps
            .compactMap { step in step.durationSeconds(now: now).map { (step, $0) } }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0 }
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

public struct RepositoryRefreshFailure: Sendable, Identifiable, Hashable {
    public let repository: String
    public let message: String

    public init(repository: String, message: String) {
        self.repository = repository
        self.message = message
    }

    public var id: String { repository }
}

public struct GitHubUser: Sendable, Hashable, Codable {
    public let login: String
    public let name: String?
    public let avatarHue: Int
    public let avatarURL: URL?

    public init(login: String, name: String?, avatarHue: Int = 200, avatarURL: URL? = nil) {
        self.login = login
        self.name = name
        self.avatarHue = avatarHue
        self.avatarURL = avatarURL
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

public struct ActionsUsage: Sendable, Hashable, Codable {
    public var totalMinutesUsed: Int
    public var includedMinutes: Int
    public var paidMinutesUsed: Int
    public var breakdown: [String: Int]

    public init(totalMinutesUsed: Int, includedMinutes: Int, paidMinutesUsed: Int, breakdown: [String: Int]) {
        self.totalMinutesUsed = totalMinutesUsed
        self.includedMinutes = includedMinutes
        self.paidMinutesUsed = paidMinutesUsed
        self.breakdown = breakdown
    }

    public var fraction: Double {
        guard includedMinutes > 0 else { return 0 }
        return Double(totalMinutesUsed) / Double(includedMinutes)
    }

    public var isOverBudget: Bool {
        totalMinutesUsed > includedMinutes
    }

    public var estimatedHostedRunnerCost: Double {
        runnerCostBreakdown.reduce(0) { $0 + $1.estimatedCost }
    }

    public var runnerCostBreakdown: [RunnerCostBreakdown] {
        breakdown
            .map { runner, minutes in
                RunnerCostBreakdown(
                    runner: Self.normalizedRunnerName(runner),
                    minutes: minutes,
                    ratePerMinute: Self.hostedRunnerRatePerMinute(for: runner)
                )
            }
            .sorted { $0.estimatedCost > $1.estimatedCost }
    }

    public static func aggregate(_ usages: [ActionsUsage]) -> ActionsUsage? {
        guard !usages.isEmpty else { return nil }
        var breakdown: [String: Int] = [:]
        for usage in usages {
            for (key, value) in usage.breakdown {
                breakdown[key, default: 0] += value
            }
        }
        return ActionsUsage(
            totalMinutesUsed: usages.reduce(0) { $0 + $1.totalMinutesUsed },
            includedMinutes: usages.reduce(0) { $0 + $1.includedMinutes },
            paidMinutesUsed: usages.reduce(0) { $0 + $1.paidMinutesUsed },
            breakdown: breakdown
        )
    }

    enum CodingKeys: String, CodingKey {
        case totalMinutesUsed = "total_minutes_used"
        case includedMinutes = "included_minutes"
        case paidMinutesUsed = "total_paid_minutes_used"
        case breakdown = "minutes_used_breakdown"
    }

    private static func normalizedRunnerName(_ key: String) -> String {
        switch key.uppercased() {
        case "MACOS": return "macOS"
        case "WINDOWS": return "Windows"
        case "UBUNTU", "LINUX": return "Linux"
        default: return key
        }
    }

    private static func hostedRunnerRatePerMinute(for key: String) -> Double {
        switch key.uppercased() {
        case "MACOS": return 0.08
        case "WINDOWS": return 0.016
        default: return 0.008
        }
    }
}

public struct ActionsUsageAccount: Sendable, Hashable, Codable, Identifiable {
    public var name: String
    public var isOrg: Bool
    public var usage: ActionsUsage

    public init(name: String, isOrg: Bool, usage: ActionsUsage) {
        self.name = name
        self.isOrg = isOrg
        self.usage = usage
    }

    public var id: String {
        "\(isOrg ? "org" : "user"):\(name)"
    }

    public var displayName: String {
        isOrg ? name : "\(name) personal"
    }
}

/// Aggregate state for the menu bar glyph.
/// Precedence: running → (latest completed: failure | success) → rateLimited.
/// Old failed runs do not keep the icon red once everything live is complete —
/// only the most recently started completed run drives green vs red.
public enum MenuBarState: Sendable, Hashable {
    case authMissing
    case rateLimited
    case failure
    case running
    case success

    public static func aggregate(runs: [WorkflowRun], authed: Bool, rateLimit: RateLimit?) -> MenuBarState {
        guard authed else { return .authMissing }
        if runs.contains(where: { $0.effective.isLive }) { return .running }
        let latestCompleted = runs
            .filter { !$0.effective.isLive }
            .max(by: { $0.startedAt < $1.startedAt })
        if let latest = latestCompleted, latest.effective.isFailure { return .failure }
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
