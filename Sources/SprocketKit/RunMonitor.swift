import Foundation

/// Diff a previous and current snapshot of runs into a list of state-change events.
///
/// Rules:
/// - A run that becomes `inProgress`/`queued` (or appears for the first time
///   already live) emits `.started`.
/// - A run that transitions to `.completed` emits exactly one of `.succeeded`,
///   `.failed`, or `.cancelled` based on the conclusion.
/// - Runs already in their terminal state across both snapshots emit nothing.
public func diff(previous: [WorkflowRun], current: [WorkflowRun]) -> [RunStateChange] {
    let prev = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
    var events: [RunStateChange] = []

    for run in current {
        let was = prev[run.id]

        // Started: appears live, and either didn't exist before or wasn't live before.
        if run.effective.isLive {
            if was == nil || was?.effective.isLive == false {
                events.append(.started(run))
            }
            continue
        }

        // Completed transitions emit exactly once: when previous was live.
        // First-sight terminal runs emit nothing — we only learn of them after the fact.
        guard was?.effective.isLive == true else { continue }

        switch run.effective {
        case .success:
            events.append(.succeeded(run))
        case .failure, .timedOut, .actionRequired:
            events.append(.failed(run))
        case .cancelled, .skipped:
            events.append(.cancelled(run))
        case .running, .queued, .unknown:
            break
        }
    }
    return events
}

/// Actor that owns the latest run snapshot and emits `RunStateChange`
/// events on transitions. Polling cadence lives in `AppState`.
public actor RunMonitor {
    public private(set) var runs: [WorkflowRun] = []

    public init() {}

    /// Replace the snapshot and return the diff.
    @discardableResult
    public func ingest(_ next: [WorkflowRun]) -> [RunStateChange] {
        let events = diff(previous: runs, current: next)
        runs = next
        return events
    }
}
