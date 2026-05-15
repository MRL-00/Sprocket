#if canImport(SwiftUI)
import SwiftUI

public extension Color {
    /// Soft cool blue — the locked Sprocket accent.
    /// Reference: oklch(0.78 0.16 245deg).
    /// Encoded as sRGB to avoid relying on display-P3 transforms inside SwiftUI tints.
    static let sprocketAccent = Color(.sRGB, red: 0.475, green: 0.694, blue: 0.961, opacity: 1.0)

    /// oklch(0.72 0.16 145) — semantic green
    static let sprocketSuccess = Color(.sRGB, red: 0.318, green: 0.741, blue: 0.388, opacity: 1.0)
    /// oklch(0.78 0.16 80)  — semantic amber
    static let sprocketRunning = Color(.sRGB, red: 0.910, green: 0.682, blue: 0.165, opacity: 1.0)
    static let sprocketWarning = sprocketRunning
    /// oklch(0.62 0.18 25)  — semantic red
    static let sprocketFailure = Color(.sRGB, red: 0.851, green: 0.290, blue: 0.220, opacity: 1.0)
    /// oklch(0.65 0.02 250) — neutral grey for cancelled / skipped
    static let sprocketNeutral = Color(.sRGB, red: 0.604, green: 0.612, blue: 0.635, opacity: 1.0)
}

public extension Color {
    static func forStatus(_ status: EffectiveStatus) -> Color {
        switch status {
        case .success:        return .sprocketSuccess
        case .failure:        return .sprocketFailure
        case .timedOut:       return .sprocketFailure
        case .actionRequired: return .sprocketRunning
        case .running:        return .sprocketRunning
        case .queued:         return .sprocketNeutral
        case .cancelled:      return .sprocketNeutral
        case .skipped:        return .sprocketNeutral
        case .unknown:        return .sprocketNeutral
        }
    }
}
#endif
