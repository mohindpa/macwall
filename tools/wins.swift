import CoreGraphics
import Foundation

let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
var found = false
for w in list {
    let owner = w[kCGWindowOwnerName as String] as? String ?? "?"
    if owner != "MacWall" { continue }
    found = true
    let layer = w[kCGWindowLayer as String] as? Int ?? -999
    let name = w[kCGWindowName as String] as? String ?? ""
    let num = w[kCGWindowNumber as String] as? Int ?? 0
    let onscreen = w[kCGWindowIsOnscreen as String] as? Bool ?? false
    let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    print("id=\(num) layer=\(layer) onscreen=\(onscreen) name=\"\(name)\" x=\(Int(b["X"] ?? 0)) y=\(Int(b["Y"] ?? 0)) w=\(Int(b["Width"] ?? 0)) h=\(Int(b["Height"] ?? 0))")
}
if !found { print("no MacWall windows") }
