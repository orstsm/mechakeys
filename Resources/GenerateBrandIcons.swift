// Reproducible vector artwork; no third-party artwork or runtime dependencies.
// Run from the repository root: xcrun swift Resources/GenerateBrandIcons.swift
import AppKit

func harborMark(in rect: NSRect, color: NSColor, lineWidth: CGFloat) {
    // A screen-edge line dipping into the rounded physical notch.
    let p = NSBezierPath()
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }
    p.move(to: point(0, 1))
    p.line(to: point(0.24, 1))
    p.line(to: point(0.24, 0.44))
    p.curve(to: point(0.36, 0.12), controlPoint1: point(0.24, 0.2), controlPoint2: point(0.28, 0.12))
    p.line(to: point(0.64, 0.12))
    p.curve(to: point(0.76, 0.44), controlPoint1: point(0.72, 0.12), controlPoint2: point(0.76, 0.2))
    p.line(to: point(0.76, 1))
    p.line(to: point(1, 1))
    p.lineWidth = lineWidth
    p.lineCapStyle = .round
    p.lineJoinStyle = .round
    color.setStroke()
    p.stroke()
}

func png(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 196, yRadius: 196)
    NSGradient(starting: NSColor(white: 0.06, alpha: 1), ending: NSColor(white: 0.20, alpha: 1))!
        .draw(in: tile, angle: 90)
    NSColor(white: 1, alpha: 0.14).setStroke()
    tile.lineWidth = 3
    tile.stroke()
    harborMark(in: NSRect(x: 232, y: 450, width: 560, height: 220),
        color: NSColor(white: 0.96, alpha: 1), lineWidth: 30)
    NSColor(srgbRed: 1, green: 0.23, blue: 0.28, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 418, y: 326, width: 188, height: 32), xRadius: 16, yRadius: 16).fill()
    return bitmap.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")
try png(size: 1024).write(to: root.appendingPathComponent("AppIcon.png"))
// Standard PNG-backed ICNS elements avoid an external icon-service dependency.
func length(_ value: Int) -> Data {
    var bigEndian = UInt32(value).bigEndian
    return withUnsafeBytes(of: &bigEndian) { Data($0) }
}
var elements = Data()
for (type, size) in [("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128),
                     ("ic08", 256), ("ic09", 512), ("ic10", 1024)] {
    let data = try png(size: size)
    elements.append(Data(type.utf8))
    elements.append(length(data.count + 8))
    elements.append(data)
}
var icns = Data("icns".utf8)
icns.append(length(elements.count + 8))
icns.append(elements)
let iconURL = root.appendingPathComponent("AppIcon.icns")
try icns.write(to: iconURL)
guard let image = NSImage(contentsOf: iconURL), image.isValid else {
    throw NSError(domain: "BrandIcons", code: 1, userInfo: [NSLocalizedDescriptionKey: "ICNS validation failed"])
}
print("Generated NotchHarbor AppIcon.png and AppIcon.icns")
