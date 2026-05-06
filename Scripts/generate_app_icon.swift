#!/usr/bin/env swift
import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "build/AppIcon.icns"
let outputURL = URL(fileURLWithPath: outputPath)
let fileManager = FileManager.default
let iconsetURL = fileManager.temporaryDirectory
    .appendingPathComponent("Sprocket-\(UUID().uuidString).iconset", isDirectory: true)

try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let iconFiles: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for iconFile in iconFiles {
    let image = renderIcon(size: iconFile.pixels)
    let destination = iconsetURL.appendingPathComponent(iconFile.name)
    try writePNG(image, to: destination)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "--convert", "icns",
    "--output", outputURL.path,
    iconsetURL.path,
]
try process.run()
process.waitUntilExit()

try? fileManager.removeItem(at: iconsetURL)

if process.terminationStatus != 0 {
    fputs("iconutil failed while writing \(outputURL.path)\n", stderr)
    exit(Int32(process.terminationStatus))
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "SprocketIcon", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not encode PNG for \(url.path)"
        ])
    }
    try png.write(to: url)
}

func renderIcon(size: Int) -> NSImage {
    let side = CGFloat(size)
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high

    let bounds = NSRect(x: 0, y: 0, width: side, height: side)
    NSColor.clear.setFill()
    bounds.fill()

    let inset = side * 0.035
    let plate = bounds.insetBy(dx: inset, dy: inset)
    let cornerRadius = side * 0.22
    let platePath = NSBezierPath(roundedRect: plate, xRadius: cornerRadius, yRadius: cornerRadius)

    let gradient = NSGradient(colors: [
        NSColor(red: 0.09, green: 0.11, blue: 0.13, alpha: 1),
        NSColor(red: 0.20, green: 0.23, blue: 0.25, alpha: 1),
    ])
    gradient?.draw(in: platePath, angle: -35)

    NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.18).setStroke()
    platePath.lineWidth = max(1, side * 0.012)
    platePath.stroke()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
    shadow.shadowBlurRadius = side * 0.045
    shadow.shadowOffset = NSSize(width: 0, height: -side * 0.018)
    shadow.set()

    let mark = chainringPath(centerX: bounds.midX, centerY: bounds.midY, radius: side * 0.33)
    NSColor(red: 0.45, green: 0.83, blue: 0.72, alpha: 1).setFill()
    mark.fill()

    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)

    let highlight = chainringPath(centerX: bounds.midX, centerY: bounds.midY + side * 0.006, radius: side * 0.33)
    NSColor.white.withAlphaComponent(0.18).setStroke()
    highlight.lineWidth = max(1, side * 0.012)
    highlight.stroke()
    return image
}

func chainringPath(centerX: CGFloat, centerY: CGFloat, radius: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.windingRule = .evenOdd

    let teeth: CGFloat = 16
    let rOuter = radius
    let rRoot = radius * 0.84
    let samples = 360

    for i in 0...samples {
        let theta = (CGFloat(i) / CGFloat(samples)) * .pi * 2
        let wave = (cos(teeth * theta) + 1) / 2
        let r = rRoot + (rOuter - rRoot) * pow(wave, 0.7)
        let x = centerX + r * cos(theta)
        let y = centerY + r * sin(theta)

        if i == 0 {
            path.move(to: NSPoint(x: x, y: y))
        } else {
            path.line(to: NSPoint(x: x, y: y))
        }
    }
    path.close()

    let cutoutCount = 5
    let rCutoutOuter = radius * 0.74
    let rCutoutInner = radius * 0.36
    let halfAngleOuterDeg: CGFloat = 30
    let halfAngleInnerDeg: CGFloat = 14
    let center = NSPoint(x: centerX, y: centerY)
    let baseDeg: CGFloat = 90

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

    let rBoltCircle = radius * 0.30
    let rBolt = max(0.6, radius * 0.05)
    for i in 0..<cutoutCount {
        let spokeDeg = baseDeg + 36 + CGFloat(i) * 72
        let theta = spokeDeg * .pi / 180
        let bx = centerX + rBoltCircle * cos(theta)
        let by = centerY + rBoltCircle * sin(theta)
        path.append(NSBezierPath(ovalIn: NSRect(
            x: bx - rBolt,
            y: by - rBolt,
            width: rBolt * 2,
            height: rBolt * 2
        )))
    }

    let rHole = radius * 0.16
    path.append(NSBezierPath(ovalIn: NSRect(
        x: centerX - rHole,
        y: centerY - rHole,
        width: rHole * 2,
        height: rHole * 2
    )))

    return path
}
