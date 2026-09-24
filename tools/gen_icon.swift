import AppKit

// Generates the MacWall app icon as an .iconset directory (exact pixel sizes).
// usage: swift tools/gen_icon.swift <output.iconset>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func drawIcon(size: CGFloat, ctx: CGContext) {
    let inset = size * 0.045
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = rect.width * 0.2237
    let tile = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Tile background: near-black vertical gradient
    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    let top = NSColor(calibratedRed: 0.090, green: 0.102, blue: 0.118, alpha: 1).cgColor
    let bottom = NSColor(calibratedRed: 0.036, green: 0.040, blue: 0.047, alpha: 1).cgColor
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [top, bottom] as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: rect.midX, y: rect.maxY),
                               end: CGPoint(x: rect.midX, y: rect.minY),
                               options: [])
    }
    ctx.restoreGState()

    // Hairline border
    ctx.saveGState()
    ctx.addPath(tile)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.09).cgColor)
    ctx.setLineWidth(max(1, size * 0.004))
    ctx.strokePath()
    ctx.restoreGState()

    // Glyph: rounded rectangle + play triangle, in lime
    let lime = NSColor(calibratedRed: 0.78, green: 0.95, blue: 0.31, alpha: 1).cgColor
    let glyphWidth = size * 0.56
    let glyphHeight = size * 0.40
    let glyphRect = CGRect(x: (size - glyphWidth) / 2, y: (size - glyphHeight) / 2, width: glyphWidth, height: glyphHeight)
    let glyph = CGPath(roundedRect: glyphRect, cornerWidth: glyphHeight * 0.24, cornerHeight: glyphHeight * 0.24, transform: nil)
    ctx.saveGState()
    ctx.addPath(glyph)
    ctx.setStrokeColor(lime)
    ctx.setLineWidth(size * 0.05)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()

    let side = glyphHeight * 0.52
    let center = CGPoint(x: glyphRect.midX, y: glyphRect.midY)
    let triangle = CGMutablePath()
    triangle.move(to: CGPoint(x: center.x - side * 0.42, y: center.y + side / 2))
    triangle.addLine(to: CGPoint(x: center.x - side * 0.42, y: center.y - side / 2))
    triangle.addLine(to: CGPoint(x: center.x + side * 0.58, y: center.y))
    triangle.closeSubpath()
    ctx.saveGState()
    ctx.addPath(triangle)
    ctx.setFillColor(lime)
    ctx.fillPath()
    ctx.restoreGState()
}

let outputs: [(Int, [String])] = [
    (16, ["icon_16x16.png"]),
    (32, ["icon_16x16@2x.png", "icon_32x32.png"]),
    (64, ["icon_32x32@2x.png"]),
    (128, ["icon_128x128.png"]),
    (256, ["icon_128x128@2x.png", "icon_256x256.png"]),
    (512, ["icon_256x256@2x.png", "icon_512x512.png"]),
    (1024, ["icon_512x512@2x.png"])
]

for (pixels, names) in outputs {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep) else { continue }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawIcon(size: CGFloat(pixels), ctx: context.cgContext)
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else { continue }
    for name in names {
        try? png.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
    }
}

print("iconset written: \(outDir)")
