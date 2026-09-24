import ApplicationServices
import AppKit
import Foundation

func attr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var v: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(el, name as CFString, &v)
    return err == .success ? v : nil
}

guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.mohind.macwall").first else {
    print("MacWall not running")
    exit(1)
}
let axApp = AXUIElementCreateApplication(app.processIdentifier)

guard let extrasRaw = attr(axApp, kAXExtrasMenuBarAttribute as String) else {
    print("no extras menu bar exposed")
    exit(1)
}
let bar = extrasRaw as! AXUIElement
let children = (attr(bar, kAXChildrenAttribute as String) as? [AXUIElement]) ?? []
print("status items found: \(children.count)")
for (i, item) in children.enumerated() {
    let title = (attr(item, kAXTitleAttribute as String) as? String) ?? ""
    let desc = (attr(item, kAXDescriptionAttribute as String) as? String) ?? ""
    var pos = CGPoint.zero
    if let pv = attr(item, kAXPositionAttribute as String) {
        AXValueGetValue(pv as! AXValue, .cgPoint, &pos)
    }
    var size = CGSize.zero
    if let sv = attr(item, kAXSizeAttribute as String) {
        AXValueGetValue(sv as! AXValue, .cgSize, &size)
    }
    print("item \(i): title='\(title)' desc='\(desc)' pos=(\(pos.x),\(pos.y)) size=(\(size.width)x\(size.height))")
}
