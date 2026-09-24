import AppKit
import CoreText

// Renders the DMG window background. Measured ground truth (AX readout of a
// live styled DMG): the Finder content area is 660x416 and icon CENTERS land
// exactly at the osascript positions — MacWall.app (150,168), Applications
// (510,168), INSTALL.txt (330,330) — in content coordinates, y from the top.
// Everything below is laid out in that same top-origin system.

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background.png"
// Canvas is padded beyond the 660x416 content area (anchored top-left by
// Finder) so a slightly larger window still shows background, never a strip.
let W: CGFloat = 700, H: CGFloat = 470
let contentW: CGFloat = 660

let fontURL = URL(fileURLWithPath: "Resources/PressStart2P-Regular.ttf")
if FileManager.default.fileExists(atPath: fontURL.path) {
    CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

/// Top-origin rect helper (image row 0 = content top, matching icon layout)
func rect(_ x: CGFloat, _ topY: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(x: x, y: H - topY - h, width: w, height: h)
}
func pixelFont(_ size: CGFloat) -> NSFont {
    NSFont(name: "Press Start 2P", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
}
/// Draws text with `topY` as the top of the text box, optionally centred.
func textTop(_ string: String, size: CGFloat, color: NSColor, topY: CGFloat, centerX: CGFloat? = nil, x: CGFloat = 0) {
    let text = NSAttributedString(string: string, attributes: [.font: pixelFont(size), .foregroundColor: color])
    let bounds = text.size()
    let px = centerX.map { $0 - bounds.width / 2 } ?? x
    text.draw(at: NSPoint(x: px, y: H - topY - bounds.height))
}

let lime = NSColor(red: 0.78, green: 0.95, blue: 0.31, alpha: 1)

// Background + faint pixel-dot texture
ctx.setFillColor(NSColor(red: 0.043, green: 0.047, blue: 0.055, alpha: 1).cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
ctx.setFillColor(NSColor.white.withAlphaComponent(0.028).cgColor)
for y in stride(from: 0, to: Int(H), by: 16) {
    for x in stride(from: 0, to: Int(W), by: 16) where (x + y) % 32 != 0 {
        ctx.fill(rect(CGFloat(x), CGFloat(y), 2, 2))
    }
}

// --- Arrow: icon centres sit at y=168 from the content top. ---
let yc: CGFloat = 168
let backX: CGFloat = 386   // head back edge
let tipX: CGFloat = 434    // head tip

// Slim dashed shaft: 8pt dashes every 16pt, vertically centred on the icons
ctx.setFillColor(NSColor.white.withAlphaComponent(0.25).cgColor)
for x in stride(from: CGFloat(230), to: backX, by: 16) {
    ctx.fill(rect(x, yc - 4, 8, 8))
}

// Stepped pixel arrowhead: 7 rows of 8pt, flat back, 1:1 slope, tip at 434
ctx.setFillColor(lime.withAlphaComponent(0.9).cgColor)
for row in 0..<7 {
    let distance = abs(CGFloat(row) - 3)
    ctx.fill(rect(backX, yc - 28 + CGFloat(row) * 8, (tipX - distance * 8) - backX, 8))
}

// --- Text, clear of the icon cells (icons span y 120-216, labels to ~236) ---
textTop("MACWALL", size: 20, color: lime, topY: 44, centerX: contentW / 2)
ctx.setFillColor(lime.withAlphaComponent(0.35).cgColor)
ctx.fill(rect((contentW - 140) / 2, 78, 140, 2))
textTop("DRAG TO INSTALL", size: 10, color: NSColor.white.withAlphaComponent(0.6), topY: 238, centerX: contentW / 2)
textTop("video desktop wallpaper  -  @mohind", size: 7, color: NSColor.white.withAlphaComponent(0.28), topY: 388, x: 24)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("background render failed\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: out))
print("background: \(out) (\(Int(W))x\(Int(H)))")
