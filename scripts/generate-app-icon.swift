import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate-app-icon.swift OUTPUT.icns\n", stderr)
    exit(2)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
let iconset = fileManager.temporaryDirectory
    .appendingPathComponent("ui-bridge-\(UUID().uuidString).iconset")
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: iconset) }

func render(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { throw CocoaError(.fileWriteUnknown) }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    let scale = CGFloat(size) / 512
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: 512, height: 512).fill()
    let background = NSBezierPath(
        roundedRect: NSRect(x: 36, y: 36, width: 440, height: 440),
        xRadius: 104,
        yRadius: 104
    )
    NSColor(calibratedRed: 0.10, green: 0.46, blue: 0.95, alpha: 1).setFill()
    background.fill()

    NSColor.white.setStroke()
    for rect in [
        NSRect(x: 112, y: 250, width: 180, height: 124),
        NSRect(x: 220, y: 138, width: 180, height: 124),
    ] {
        let path = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
        path.lineWidth = 24
        path.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return png
}

let files: [(String, Int)] = [
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

for (name, size) in files {
    try render(size: size).write(to: iconset.appendingPathComponent(name))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { exit(iconutil.terminationStatus) }
