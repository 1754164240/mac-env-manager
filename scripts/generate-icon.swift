#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let generatedDirectory = root.appendingPathComponent(".build/generated-icons", isDirectory: true)
let iconsetDirectory = generatedDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = generatedDirectory.appendingPathComponent("AppIcon.icns")

try FileManager.default.removeItemIfExists(at: iconsetDirectory)
try FileManager.default.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

struct IconOutput {
    let points: Int
    let scale: Int
    let filename: String

    var pixels: Int { points * scale }
}

let outputs = [
    IconOutput(points: 16, scale: 1, filename: "icon_16x16.png"),
    IconOutput(points: 16, scale: 2, filename: "icon_16x16@2x.png"),
    IconOutput(points: 32, scale: 1, filename: "icon_32x32.png"),
    IconOutput(points: 32, scale: 2, filename: "icon_32x32@2x.png"),
    IconOutput(points: 128, scale: 1, filename: "icon_128x128.png"),
    IconOutput(points: 128, scale: 2, filename: "icon_128x128@2x.png"),
    IconOutput(points: 256, scale: 1, filename: "icon_256x256.png"),
    IconOutput(points: 256, scale: 2, filename: "icon_256x256@2x.png"),
    IconOutput(points: 512, scale: 1, filename: "icon_512x512.png"),
    IconOutput(points: 512, scale: 2, filename: "icon_512x512@2x.png")
]

for output in outputs {
    let image = renderIcon(pixelSize: output.pixels)
    try image.writePNG(to: iconsetDirectory.appendingPathComponent(output.filename))
}

try FileManager.default.removeItemIfExists(at: icnsURL)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDirectory.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(
        domain: "MacEnvManagerIcon",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: "iconutil failed"]
    )
}

print(icnsURL.path)

private func renderIcon(pixelSize: Int) -> NSImage {
    let size = NSSize(width: pixelSize, height: pixelSize)
    let image = NSImage(size: size)
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else {
        return image
    }

    let scale = CGFloat(pixelSize) / 1024
    context.scaleBy(x: scale, y: scale)
    drawIcon(in: context)
    return image
}

private func drawIcon(in context: CGContext) {
    let canvas = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    context.clear(canvas)
    context.setShouldAntialias(true)

    let outer = CGRect(x: 72, y: 72, width: 880, height: 880)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -24), blur: 48, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    context.addPath(roundedRect(outer, radius: 210))
    context.clip()
    let backgroundGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedRed: 0.09, green: 0.63, blue: 0.72, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.76, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.20, alpha: 1).cgColor
        ] as CFArray,
        locations: [0.0, 0.55, 1.0]
    )!
    context.drawLinearGradient(backgroundGradient, start: CGPoint(x: 180, y: 920), end: CGPoint(x: 860, y: 90), options: [])
    context.restoreGState()

    context.saveGState()
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.28).cgColor)
    context.setLineWidth(4)
    context.addPath(roundedRect(outer.insetBy(dx: 16, dy: 16), radius: 194))
    context.strokePath()
    context.restoreGState()

    let terminal = CGRect(x: 178, y: 246, width: 668, height: 532)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 30, color: NSColor.black.withAlphaComponent(0.34).cgColor)
    context.setFillColor(NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.11, alpha: 0.94).cgColor)
    context.addPath(roundedRect(terminal, radius: 82))
    context.fillPath()
    context.restoreGState()

    let topBar = CGRect(x: terminal.minX, y: terminal.maxY - 114, width: terminal.width, height: 114)
    context.saveGState()
    context.addPath(roundedRect(terminal, radius: 82))
    context.clip()
    context.setFillColor(NSColor(calibratedRed: 0.11, green: 0.15, blue: 0.22, alpha: 1).cgColor)
    context.fill(topBar)
    context.restoreGState()

    drawCircle(center: CGPoint(x: 252, y: 720), radius: 18, color: NSColor(calibratedRed: 1.00, green: 0.37, blue: 0.34, alpha: 1))
    drawCircle(center: CGPoint(x: 308, y: 720), radius: 18, color: NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.27, alpha: 1))
    drawCircle(center: CGPoint(x: 364, y: 720), radius: 18, color: NSColor(calibratedRed: 0.22, green: 0.84, blue: 0.44, alpha: 1))

    drawPrompt()
    drawEnvRows(in: context)
    drawPathRibbon(in: context)
}

private func drawPrompt() {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 168, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.42, green: 1.00, blue: 0.68, alpha: 1),
        .paragraphStyle: paragraph,
        .kern: -4
    ]
    NSString(string: ">_").draw(in: CGRect(x: 246, y: 438, width: 260, height: 190), withAttributes: attributes)
}

private func drawEnvRows(in context: CGContext) {
    let rows: [(CGFloat, NSColor, CGFloat)] = [
        (604, NSColor(calibratedRed: 0.41, green: 0.92, blue: 1.00, alpha: 1), 686),
        (526, NSColor(calibratedRed: 0.65, green: 0.94, blue: 0.42, alpha: 1), 620),
        (448, NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.30, alpha: 1), 714)
    ]

    for (y, color, knobX) in rows {
        let rail = CGRect(x: 520, y: y, width: 226, height: 22)
        context.setFillColor(NSColor.white.withAlphaComponent(0.16).cgColor)
        context.addPath(roundedRect(rail, radius: 11))
        context.fillPath()

        let active = CGRect(x: rail.minX, y: rail.minY, width: knobX - rail.minX, height: rail.height)
        context.setFillColor(color.withAlphaComponent(0.82).cgColor)
        context.addPath(roundedRect(active, radius: 11))
        context.fillPath()

        drawCircle(center: CGPoint(x: knobX, y: y + 11), radius: 30, color: color)
        drawCircle(center: CGPoint(x: knobX, y: y + 11), radius: 13, color: NSColor.white.withAlphaComponent(0.92))
    }
}

private func drawPathRibbon(in context: CGContext) {
    let points = [
        CGPoint(x: 292, y: 350),
        CGPoint(x: 414, y: 350),
        CGPoint(x: 492, y: 304),
        CGPoint(x: 618, y: 304),
        CGPoint(x: 704, y: 350)
    ]

    context.saveGState()
    context.setLineWidth(28)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(NSColor(calibratedRed: 0.44, green: 0.93, blue: 1.00, alpha: 0.84).cgColor)
    context.beginPath()
    context.move(to: points[0])
    for point in points.dropFirst() {
        context.addLine(to: point)
    }
    context.strokePath()
    context.restoreGState()

    for point in points {
        drawCircle(center: point, radius: 22, color: NSColor(calibratedRed: 0.94, green: 0.99, blue: 1.00, alpha: 1))
    }
}

private func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

private func drawCircle(center: CGPoint, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
}

private extension NSImage {
    func writePNG(to url: URL) throws {
        guard
            let tiffData = tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw NSError(
                domain: "MacEnvManagerIcon",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to render PNG"]
            )
        }
        try pngData.write(to: url, options: .atomic)
    }
}

private extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
    }
}
