import Foundation

public enum Formatting {
    public static func duration(seconds: Int) -> String {
        if seconds < 60 { return "0m \(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%dm %02ds", m, s)
    }

    public static func durationShort(seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3_600 {
            return "\(seconds / 60)m"
        }
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    public static func relative(_ date: Date, now: Date = Date()) -> String {
        let delta = Int(now.timeIntervalSince(date))
        if delta < 60 { return "just now" }
        if delta < 3_600 { return "\(delta / 60)m ago" }
        if delta < 86_400 { return "\(delta / 3_600)h ago" }
        return "\(delta / 86_400)d ago"
    }

    public static func compactNumber(_ n: Int) -> String {
        n.formatted()
    }
}
