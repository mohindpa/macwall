import CoreGraphics
import ImageIO
import Foundation

// usage: imgdiff a.png b.png y0 y1  -> prints differing column ranges within rows [y0,y1)
func load(_ path: String) -> (w: Int, h: Int, data: [UInt8])? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    let w = img.width, h = img.height
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: w * 4, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return (w, h, buf)
}

let args = CommandLine.arguments
guard args.count >= 5,
      let a = load(args[1]), let b = load(args[2]),
      let y0 = Int(args[3]), let y1 = Int(args[4]), a.w == b.w else {
    print("usage: imgdiff a.png b.png y0 y1"); exit(1)
}

var colDiff = [Bool](repeating: false, count: a.w)
var total = 0
for y in max(0, y0)..<min(y1, a.h) {
    for x in 0..<a.w {
        let i = (y * a.w + x) * 4
        let d = abs(Int(a.data[i]) - Int(b.data[i])) + abs(Int(a.data[i + 1]) - Int(b.data[i + 1])) + abs(Int(a.data[i + 2]) - Int(b.data[i + 2]))
        if d > 40 { colDiff[x] = true; total += 1 }
    }
}

var ranges: [(Int, Int)] = []
var start = -1
for x in 0..<a.w {
    if colDiff[x] {
        if start < 0 { start = x }
    } else if start >= 0 {
        if x - start > 3 { ranges.append((start, x - 1)) }
        start = -1
    }
}
if start >= 0 { ranges.append((start, a.w - 1)) }

print("changed pixels: \(total)")
print("differing ranges (x, in rows \(y0)..<\(y1)): " + ranges.map { "\($0.0)-\($0.1)" }.joined(separator: ", "))
