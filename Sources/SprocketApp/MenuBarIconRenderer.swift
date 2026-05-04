import AppKit
import SprocketKit

/// Builds the menu-bar gear glyph with a status badge in the lower-right quadrant.
///
/// - For `success`, `failure`, `auth`, `rateLimited` we render a template image
///   so the OS tints it for light/dark menu bars.
/// - For `running` we ship a non-template tinted variant so the amber badge reads
///   regardless of menu-bar luminance.
enum MenuBarIconRenderer {
    static let pointSize = NSSize(width: 22, height: 22)

    static func image(for state: MenuBarState) -> NSImage {
        switch state {
        case .running:
            let img = render(state: state, template: false)
            img.isTemplate = false
            return img
        default:
            let img = render(state: state, template: true)
            img.isTemplate = true
            return img
        }
    }

    private static func render(state: MenuBarState, template: Bool) -> NSImage {
        let size = pointSize
        let img = NSImage(size: size, flipped: false) { rect in
            drawGearSilhouette(in: rect, template: template, state: state)
            drawBadge(in: rect, state: state, template: template)
            return true
        }
        img.accessibilityDescription = accessibilityLabel(state)
        return img
    }

    private static func accessibilityLabel(_ s: MenuBarState) -> String {
        switch s {
        case .success: return "Sprocket — all green"
        case .running: return "Sprocket — running"
        case .failure: return "Sprocket — failing"
        case .rateLimited: return "Sprocket — rate-limited"
        case .authMissing: return "Sprocket — sign in required"
        }
    }

    // 8-tooth gear in the upper-left quadrant so the badge can sit lower-right.
    private static func drawGearSilhouette(in rect: NSRect, template: Bool, state: MenuBarState) {
        let teeth = 8
        let cx = rect.minX + rect.width * 0.36
        let cy = rect.minY + rect.height * 0.64
        let outer = rect.width * 0.30
        let inner = rect.width * 0.21
        let path = NSBezierPath()
        for i in 0..<teeth {
            let a = (Double(i) / Double(teeth)) * .pi * 2
            let next = (Double(i + 1) / Double(teeth)) * .pi * 2
            let half = (next - a) / 2
            let pts: [(Double, Double)] = [
                (cos(a + half - 0.22), sin(a + half - 0.22)),
                (cos(a + half - 0.13), sin(a + half - 0.13)),
                (cos(a + half + 0.13), sin(a + half + 0.13)),
                (cos(a + half + 0.22), sin(a + half + 0.22)),
            ]
            let radii: [Double] = [inner, outer, outer, inner]
            for (idx, p) in pts.enumerated() {
                let r = radii[idx]
                let x = cx + p.0 * r
                let y = cy + p.1 * r
                if i == 0 && idx == 0 { path.move(to: NSPoint(x: x, y: y)) }
                else { path.line(to: NSPoint(x: x, y: y)) }
            }
        }
        path.close()

        let fg: NSColor = template
            ? NSColor.black                                  // template image; OS tints
            : (state == .authMissing ? NSColor(white: 0.6, alpha: 1) : NSColor.black)
        fg.setFill()
        path.fill()

        // Inner ring
        let ringRadius = rect.width * 0.085
        let ring = NSBezierPath(ovalIn: NSRect(
            x: cx - ringRadius, y: cy - ringRadius,
            width: ringRadius * 2, height: ringRadius * 2
        ))
        ring.lineWidth = 1.4
        if template { NSColor.black.setStroke() } else { fg.setStroke() }
        ring.stroke()
        // Punch the centre hole so the gear reads at small sizes
        NSColor.clear.setFill()
        let hole = NSBezierPath(ovalIn: NSRect(
            x: cx - ringRadius * 0.55, y: cy - ringRadius * 0.55,
            width: ringRadius * 1.1, height: ringRadius * 1.1
        ))
        hole.fill()
    }

    private static func drawBadge(in rect: NSRect, state: MenuBarState, template: Bool) {
        let bx = rect.minX + rect.width * 0.62
        let by = rect.minY + rect.height * 0.30
        let r  = rect.width * 0.24
        let badgeRect = NSRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)

        let badge = NSBezierPath(ovalIn: badgeRect)

        switch state {
        case .success:
            // Filled disc + check stroke. Template = single colour mask.
            (template ? NSColor.black : NSColor.systemGreen).setFill()
            badge.fill()
            let check = NSBezierPath()
            check.move(to: NSPoint(x: bx - r * 0.45, y: by + r * 0.05))
            check.line(to: NSPoint(x: bx - r * 0.10, y: by - r * 0.30))
            check.line(to: NSPoint(x: bx + r * 0.45, y: by + r * 0.30))
            check.lineWidth = max(1.3, r * 0.20)
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            (template ? NSColor.white : NSColor.white).setStroke()
            check.stroke()
        case .failure:
            (template ? NSColor.black : NSColor(red: 0.85, green: 0.29, blue: 0.22, alpha: 1)).setFill()
            badge.fill()
            let cross = NSBezierPath()
            cross.move(to: NSPoint(x: bx - r * 0.40, y: by - r * 0.40))
            cross.line(to: NSPoint(x: bx + r * 0.40, y: by + r * 0.40))
            cross.move(to: NSPoint(x: bx + r * 0.40, y: by - r * 0.40))
            cross.line(to: NSPoint(x: bx - r * 0.40, y: by + r * 0.40))
            cross.lineWidth = max(1.4, r * 0.22)
            cross.lineCapStyle = .round
            NSColor.white.setStroke()
            cross.stroke()
        case .running:
            // Non-template tinted amber so the spinner reads on dark + light bars
            NSColor(red: 0.91, green: 0.68, blue: 0.16, alpha: 1).setFill()
            badge.fill()
            // Dot in middle as a static representation; live spin animation is owned by SwiftUI elsewhere
            let dot = NSBezierPath(ovalIn: NSRect(
                x: bx - r * 0.20, y: by - r * 0.20,
                width: r * 0.40, height: r * 0.40
            ))
            NSColor.white.setFill()
            dot.fill()
        case .rateLimited:
            (template ? NSColor.black : NSColor(red: 0.85, green: 0.65, blue: 0.20, alpha: 1)).setFill()
            badge.fill()
            // Simple clock-hand glyph
            let hand = NSBezierPath()
            hand.move(to: NSPoint(x: bx, y: by + r * 0.40))
            hand.line(to: NSPoint(x: bx, y: by))
            hand.line(to: NSPoint(x: bx + r * 0.30, y: by - r * 0.15))
            hand.lineWidth = max(1.2, r * 0.18)
            hand.lineCapStyle = .round
            hand.lineJoinStyle = .round
            NSColor.white.setStroke()
            hand.stroke()
        case .authMissing:
            // Hollow muted ring with a "!"
            (template ? NSColor.black : NSColor(white: 0.5, alpha: 1)).setStroke()
            badge.lineWidth = max(1.0, r * 0.14)
            badge.stroke()
            let bang = NSBezierPath()
            bang.move(to: NSPoint(x: bx, y: by + r * 0.30))
            bang.line(to: NSPoint(x: bx, y: by - r * 0.05))
            bang.lineWidth = max(1.2, r * 0.18)
            bang.lineCapStyle = .round
            (template ? NSColor.black : NSColor(white: 0.5, alpha: 1)).setStroke()
            bang.stroke()
            let dotR = r * 0.10
            let dotPath = NSBezierPath(ovalIn: NSRect(
                x: bx - dotR, y: by - r * 0.30 - dotR,
                width: dotR * 2, height: dotR * 2
            ))
            (template ? NSColor.black : NSColor(white: 0.5, alpha: 1)).setFill()
            dotPath.fill()
        }
    }
}
