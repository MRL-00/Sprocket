import SwiftUI

/// 8-tooth gear silhouette + centre ring. Geometric, no wordmark.
struct SprocketMark: View {
    var size: CGFloat = 16
    var color: Color = .primary

    var body: some View {
        Canvas { ctx, sz in
            let cx = sz.width / 2
            let cy = sz.height / 2
            let outer = sz.width * 0.44
            let inner = sz.width * 0.33
            let teeth = 8
            var path = Path()
            for i in 0..<teeth {
                let a = (Double(i) / Double(teeth)) * .pi * 2
                let next = (Double(i + 1) / Double(teeth)) * .pi * 2
                let half = (next - a) / 2
                let pts: [(Double, Double, Double)] = [
                    (cos(a + half - 0.18), sin(a + half - 0.18), inner),
                    (cos(a + half - 0.12), sin(a + half - 0.12), outer),
                    (cos(a + half + 0.12), sin(a + half + 0.12), outer),
                    (cos(a + half + 0.18), sin(a + half + 0.18), inner),
                ]
                for (idx, p) in pts.enumerated() {
                    let pt = CGPoint(x: cx + p.0 * p.2, y: cy + p.1 * p.2)
                    if i == 0 && idx == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
            }
            path.closeSubpath()
            ctx.fill(path, with: .color(color))

            // Centre ring
            let r = sz.width * 0.14
            let ringRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
            ctx.stroke(Path(ellipseIn: ringRect), with: .color(color), lineWidth: max(1, sz.width * 0.05))
        }
        .frame(width: size, height: size)
    }
}
