import AppKit
import CoreGraphics

/// Procedural bicycle-chainring path. Single closed path with five spoke cutouts,
/// five bolt holes, and a centre hub hole — meant to be filled with `.evenOdd`.
enum SprocketGeometry {
    static func chainringPath(centerX: CGFloat, centerY: CGFloat, radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.windingRule = .evenOdd

        // Toothed outer perimeter — 16 rounded teeth.
        let teeth: CGFloat = 16
        let rOuter = radius
        let rRoot = radius * 0.84
        let samples = 360
        for i in 0...samples {
            let θ = (CGFloat(i) / CGFloat(samples)) * .pi * 2
            // Sharpen the tooth profile slightly so peaks read at small sizes.
            let wave = (cos(teeth * θ) + 1) / 2
            let r = rRoot + (rOuter - rRoot) * pow(wave, 0.7)
            let x = centerX + r * cos(θ)
            let y = centerY + r * sin(θ)
            if i == 0 { path.move(to: NSPoint(x: x, y: y)) }
            else { path.line(to: NSPoint(x: x, y: y)) }
        }
        path.close()

        // Five spoke cutouts. Cutouts sit between spokes; one cutout is at the top.
        let cutoutCount = 5
        let rCutoutOuter = radius * 0.74
        let rCutoutInner = radius * 0.36
        let halfAngleOuterDeg: CGFloat = 30
        let halfAngleInnerDeg: CGFloat = 14
        let center = NSPoint(x: centerX, y: centerY)
        let baseDeg: CGFloat = 90 // first cutout points up

        for i in 0..<cutoutCount {
            let cDeg = baseDeg + CGFloat(i) * (360.0 / CGFloat(cutoutCount))
            let cutout = NSBezierPath()
            cutout.appendArc(
                withCenter: center,
                radius: rCutoutOuter,
                startAngle: cDeg - halfAngleOuterDeg,
                endAngle: cDeg + halfAngleOuterDeg,
                clockwise: false
            )
            cutout.appendArc(
                withCenter: center,
                radius: rCutoutInner,
                startAngle: cDeg + halfAngleInnerDeg,
                endAngle: cDeg - halfAngleInnerDeg,
                clockwise: true
            )
            cutout.close()
            path.append(cutout)
        }

        // Five bolt holes positioned on the spoke centerlines, near the hub.
        let rBoltCircle = radius * 0.30
        let rBolt = max(0.6, radius * 0.05)
        for i in 0..<cutoutCount {
            let spokeDeg = baseDeg + 36 + CGFloat(i) * 72
            let θ = spokeDeg * .pi / 180
            let bx = centerX + rBoltCircle * cos(θ)
            let by = centerY + rBoltCircle * sin(θ)
            path.append(NSBezierPath(ovalIn: NSRect(
                x: bx - rBolt, y: by - rBolt, width: rBolt * 2, height: rBolt * 2
            )))
        }

        // Hub hole.
        let rHole = radius * 0.16
        path.append(NSBezierPath(ovalIn: NSRect(
            x: centerX - rHole, y: centerY - rHole, width: rHole * 2, height: rHole * 2
        )))

        return path
    }
}
