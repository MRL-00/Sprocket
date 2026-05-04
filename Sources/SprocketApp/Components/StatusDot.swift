import SwiftUI
import SprocketKit

struct StatusDot: View {
    let status: EffectiveStatus
    var size: CGFloat = 9

    @State private var pulse = false

    var body: some View {
        let c = Color.forStatus(status)
        ZStack {
            if status == .running {
                Circle()
                    .fill(c.opacity(0.25))
                    .scaleEffect(pulse ? 2.4 : 0.5)
                    .opacity(pulse ? 0 : 0.8)
                    .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse)
                Circle()
                    .fill(c)
                    .frame(width: size * 0.6, height: size * 0.6)
            } else {
                Circle().fill(c)
            }
        }
        .frame(width: size, height: size)
        .onAppear { pulse = true }
    }
}
