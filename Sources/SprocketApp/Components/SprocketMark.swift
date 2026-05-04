import SwiftUI
import AppKit

/// Bicycle-chainring silhouette: 16 teeth, 5 spoke cutouts, 5 bolt holes, hub hole.
struct SprocketMark: View {
    var size: CGFloat = 16
    var color: Color = .primary

    var body: some View {
        Canvas { ctx, sz in
            let path = SprocketGeometry.chainringPath(
                centerX: sz.width / 2,
                centerY: sz.height / 2,
                radius: min(sz.width, sz.height) * 0.46
            )
            ctx.fill(Path(path.cgPath), with: .color(color), style: FillStyle(eoFill: true))
        }
        .frame(width: size, height: size)
    }
}

private extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            switch element(at: i, associatedPoints: &points) {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo, .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        return path
    }
}
