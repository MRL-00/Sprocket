import SwiftUI
import SprocketKit

struct StatusDot: View {
    let status: EffectiveStatus
    var size: CGFloat = 9

    var body: some View {
        let c = Color.forStatus(status)
        ZStack {
            if status == .running {
                // TimelineView-driven pulse instead of .repeatForever: a
                // repeating SwiftUI animation keeps the display link firing
                // even when the popover window is hidden; TimelineView pauses
                // when the view isn't being drawn.
                TimelineView(.animation) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 1.4) / 1.4
                    let eased = 1 - pow(1 - phase, 2) // approximate easeOut
                    Circle()
                        .fill(c.opacity(0.25))
                        .scaleEffect(0.5 + eased * 1.9)
                        .opacity(0.8 * (1 - eased))
                }
                Circle()
                    .fill(c)
                    .frame(width: size * 0.6, height: size * 0.6)
            } else {
                Circle().fill(c)
            }
        }
        .frame(width: size, height: size)
    }
}
