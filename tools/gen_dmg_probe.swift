import AppKit
import CoreText

// DIAGNOSTIC dmg background: grid + axis labels so icon positions can be
// measured precisely from a screenshot. 660x420.

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-probe.png"
let W: CGFloat = 660, H: CGFloat = 420

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

ctx.setFillColor(NSColor.black.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

// Grid: every 32px dim, every 128px bright
for x in stride(from: 0, to: Int(W), by: 32) {
    let major = x % 128 == 0
    ctx.setFillColor(NSColor.white.withAlphaComponent(major ? 0.45 : 0.14).cgColor)
    ctx.fill(CGRect(x: CGFloat(x), y: 0, width: major ? 2 : 1, height: H))
}
for y in stride(from: 0, to: Int(H), by: 32) {
    let major = y % 128 == 0
    ctx.setFillColor(NSColor.white.withAlphaComponent(major ? 0.45 : 0.14).cgColor)
    ctx.fill(CGRect(x: 0, y: CGFloat(y), width: W, height: major ? 2 : 1))
}

// Axis labels in image-CG coordinates (y from bottom)
func label(_ s: String, at p: NSPoint, color: NSColor) {
    let font = NSFont(name: "Press Start 2P", size: 8)
        ?? NSFont.monospacedSystemFont(ofSize: 8, weight: .bold)
    NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color])
        .draw(at: p)
}
let lime = NSColor(red: 0.78, green: 0.95, blue: 0.31, alpha: 1)
for x in [0, 128, 256, 384, 512, 640] {
    label("x\(x)", at: NSPoint(x: CGFloat(x) + 4, y: H - 14), color: lime)
}
for y in [0, 128, 256, 384] {
    label("y\(Int(y))", at: NSPoint(x: 4, y: CGFloat(y) + 4), color: lime)
}
// Center mark
ctx.setFillColor(NSColor.systemPink.cgColor)
ctx.fill(CGRect(x: 328, y: 208, width: 4, height: 4))
label("c330/210", at: NSPoint(x: 300, y: 186), color: .systemPink)

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("probe: \(out)")
