import Testing
import Foundation
@testable import SprocketKit

@Suite("RunMonitor diff")
struct RunMonitorTests {
    private func run(id: Int64,
                     status: RunStatus,
                     conclusion: RunConclusion?) -> WorkflowRun {
        WorkflowRun(
            id: id,
            repo: "test/repo",
            workflowName: "CI",
            displayTitle: "test",
            branch: "main",
            event: "push",
            status: status,
            conclusion: conclusion,
            runNumber: Int(id),
            actor: "tester",
            actorHue: 200,
            startedAt: Date(),
            updatedAt: Date(),
            durationSeconds: 10,
            htmlURL: URL(string: "https://example.com")!
        )
    }

    @Test("queued → in_progress → success emits started + succeeded")
    func transitionEmitsStartedAndSucceeded() async {
        let monitor = RunMonitor()
        let queued = run(id: 1, status: .queued, conclusion: nil)
        let running = run(id: 1, status: .inProgress, conclusion: nil)
        let success = run(id: 1, status: .completed, conclusion: .success)

        let e1 = await monitor.ingest([queued])
        let e2 = await monitor.ingest([running])
        let e3 = await monitor.ingest([success])

        // queued is "live" — first appearance counts as started
        #expect(e1.count == 1)
        if case .started = e1.first { } else { Issue.record("expected .started, got \(String(describing: e1.first))") }

        // queued → in_progress: still live, no new event
        #expect(e2.isEmpty)

        #expect(e3.count == 1)
        if case .succeeded = e3.first { } else { Issue.record("expected .succeeded, got \(String(describing: e3.first))") }
    }

    @Test("failure transition emits .failed")
    func failureTransition() async {
        let monitor = RunMonitor()
        _ = await monitor.ingest([run(id: 2, status: .inProgress, conclusion: nil)])
        let events = await monitor.ingest([run(id: 2, status: .completed, conclusion: .failure)])
        #expect(events.count == 1)
        if case .failed = events.first { } else { Issue.record("expected .failed") }
    }

    @Test("already-terminal runs emit nothing on first sight")
    func terminalFirstSight() async {
        let monitor = RunMonitor()
        let events = await monitor.ingest([run(id: 3, status: .completed, conclusion: .success)])
        #expect(events.isEmpty)
    }
}

@Suite("Menu bar aggregation")
struct MenuBarStateTests {
    @Test("failure beats running beats rate-limit beats success")
    func precedence() {
        let now = Date()
        let url = URL(string: "https://example.com")!
        let success = WorkflowRun(id: 1, repo: "a/b", workflowName: "w", displayTitle: "t",
                                  branch: "main", event: "push",
                                  status: .completed, conclusion: .success, runNumber: 1,
                                  actor: "x", actorHue: 0, startedAt: now, updatedAt: now,
                                  durationSeconds: 1, htmlURL: url)
        let running = WorkflowRun(id: 2, repo: "a/b", workflowName: "w", displayTitle: "t",
                                  branch: "main", event: "push",
                                  status: .inProgress, conclusion: nil, runNumber: 2,
                                  actor: "x", actorHue: 0, startedAt: now, updatedAt: now,
                                  durationSeconds: 1, htmlURL: url)
        let failure = WorkflowRun(id: 3, repo: "a/b", workflowName: "w", displayTitle: "t",
                                  branch: "main", event: "push",
                                  status: .completed, conclusion: .failure, runNumber: 3,
                                  actor: "x", actorHue: 0, startedAt: now, updatedAt: now,
                                  durationSeconds: 1, htmlURL: url)

        #expect(MenuBarState.aggregate(runs: [success, running, failure], authed: true, rateLimit: nil) == .failure)
        #expect(MenuBarState.aggregate(runs: [success, running], authed: true, rateLimit: nil) == .running)
        let exhausted = RateLimit(limit: 5_000, remaining: 0, resetAt: now)
        #expect(MenuBarState.aggregate(runs: [success], authed: true, rateLimit: exhausted) == .rateLimited)
        #expect(MenuBarState.aggregate(runs: [success], authed: true, rateLimit: nil) == .success)
        #expect(MenuBarState.aggregate(runs: [], authed: false, rateLimit: nil) == .authMissing)
    }
}
