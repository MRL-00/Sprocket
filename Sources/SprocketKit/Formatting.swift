import Foundation

public enum Formatting {
    public static func duration(seconds: Int) -> String {
        if seconds < 60 { return "0m \(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%dm %02ds", m, s)
    }

    public static func relative(_ date: Date, now: Date = Date()) -> String {
        let delta = Int(now.timeIntervalSince(date))
        if delta < 60 { return "just now" }
        if delta < 3_600 { return "\(delta / 60)m ago" }
        if delta < 86_400 { return "\(delta / 3_600)h ago" }
        return "\(delta / 86_400)d ago"
    }

    public static func compactNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
