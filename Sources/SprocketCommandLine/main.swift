import Foundation
import SprocketKit

func runStatus() async {
    let runs = MockData.runs
    let live = runs.filter { $0.effective.isLive }.count
    let failing = runs.filter { $0.effective.isFailure }.count
    let success = runs.filter { $0.effective == .success }.count
    let rl = MockData.rateLimit
    print("Sprocket — \(MockData.user.login)")
    print("  \(success) green · \(live) running · \(failing) failing")
    print("  rate limit: \(rl.remaining)/\(rl.limit), resets at \(rl.resetAt)")
}

func runList() {
    for r in MockData.runs.prefix(15) {
        let dot: String
        switch r.effective {
        case .success: dot = "✓"
        case .failure, .timedOut, .actionRequired: dot = "✕"
        case .running: dot = "↻"
        case .queued: dot = "·"
        default: dot = "—"
        }
        let repo = r.repo.padding(toLength: 32, withPad: " ", startingAt: 0)
        let wf = r.workflowName.padding(toLength: 22, withPad: " ", startingAt: 0)
        print("\(dot) \(repo)  \(wf)  \(r.displayTitle)")
    }
}

func runWatch() async {
    print("Watching… (mock mode — Ctrl-C to exit)")
    let monitor = RunMonitor()
    var snapshot = MockData.runs
    while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(60))
        let events = await monitor.ingest(snapshot)
        for e in events { print("event: \(e)") }
        snapshot = MockData.runs
    }
}

func runAuth(_ args: [String]) async {
    let store = AuthStore()
    let sub = args.first ?? "status"
    switch sub {
    case "status":
        if let creds = await store.loadCredentials() {
            let prefix = String(creds.token.prefix(6))
            print("Signed in. Token: \(prefix)…")
        } else {
            print("Not signed in. Run `sprocket auth login`.")
        }
    case "login":
        print("Run the Sprocket app and complete the device flow there.")
        print("(CLI device flow not yet implemented in this skeleton.)")
    case "logout":
        await store.clearCredentials()
        print("Signed out.")
    default:
        print("Unknown auth subcommand: \(sub)")
    }
}

func printUsage() {
    print("""
    sprocket — GitHub Actions CLI for Sprocket.app

    USAGE:
      sprocket status        Print the same summary the popover shows
      sprocket list          Print recent runs across watched repos
      sprocket watch         Long-run polling, prints state transitions
      sprocket auth status   Show signed-in user
      sprocket auth login    Run device flow
      sprocket auth logout   Clear credentials
    """)
}

let args = Array(CommandLine.arguments.dropFirst())
let cmd = args.first ?? "status"

switch cmd {
case "status":
    await runStatus()
case "list":
    runList()
case "watch":
    await runWatch()
case "auth":
    await runAuth(Array(args.dropFirst()))
case "-h", "--help", "help":
    printUsage()
default:
    print("Unknown command: \(cmd)\n")
    printUsage()
    exit(1)
}
