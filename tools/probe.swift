import CoreGraphics
import Foundation

let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
var found = 0
for w in list {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    guard owner == "MacWall" else { continue }
    found += 1
    let num = w[kCGWindowNumber as String] as? Int ?? -1
    let layer = w[kCGWindowLayer as String] as? Int ?? 0
    let onscreen = w[kCGWindowIsOnscreen as String] as? Bool ?? false
    let bounds = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let name = w[kCGWindowName as String] as? String ?? ""
    print("id=\(num) layer=\(layer) onscreen=\(onscreen) bounds=\(bounds) name=\(name)")
}
print("total MacWall windows: \(found)")
if let first = list.first(where: { (($0[kCGWindowOwnerName as String] as? String) ?? "") == "MacWall" }),
   let num = first[kCGWindowNumber as String] as? Int {
    print("FIRST_WINDOW_ID=\(num)")
}
