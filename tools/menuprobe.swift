import ApplicationServices
import AppKit
import Foundation

func attr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var v: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(el, name as CFString, &v)
    return err == .success ? v : nil
}

guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.mohind.macwall").first else {
    print("MacWall not running"); exit(1)
}
let axApp = AXUIElementCreateApplication(app.processIdentifier)
guard let extrasRaw = attr(axApp, kAXExtrasMenuBarAttribute as String) else {
    print("no extras menu bar"); exit(1)
}
let bar = extrasRaw as! AXUIElement
guard let item = (attr(bar, kAXChildrenAttribute as String) as? [AXUIElement])?.first else {
    print("no status item"); exit(1)
}

var pos = CGPoint.zero
if let pv = attr(item, kAXPositionAttribute as String) { AXValueGetValue(pv as! AXValue, .cgPoint, &pos) }
var size = CGSize.zero
if let sv = attr(item, kAXSizeAttribute as String) { AXValueGetValue(sv as! AXValue, .cgSize, &size) }
print("item pos=(\(pos.x),\(pos.y)) size=(\(size.width)x\(size.height))")

// Press it to open the menu, then report the menu structure textually.
var actionNames: CFArray?
AXUIElementCopyActionNames(item, &actionNames)
print("actions: \(actionNames as? [String] ?? [])")

let pressErr = AXUIElementPerformAction(item, kAXPressAction as CFString)
print("AXPress err=\(pressErr.rawValue)")
Thread.sleep(forTimeInterval: 1.0)

// Screenshot while the menu is open.
let shot = Process()
shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
shot.arguments = ["-x", "/tmp/mb_menu_open.png"]
try? shot.run()
shot.waitUntilExit()
print("screenshot rc=\(shot.terminationStatus)")

// Dump the open menu (children of our app's menu bars).
var menuText: [String] = []
if let bars = attr(axApp, kAXChildrenAttribute as String) as? [AXUIElement] {
    for b in bars {
        let role = (attr(b, kAXRoleAttribute as String) as? String) ?? "?"
        if role.contains("MenuBar") {
            if let menuChildren = attr(b, kAXChildrenAttribute as String) as? [AXUIElement] {
                for c in menuChildren {
                    let title = (attr(c, kAXTitleAttribute as String) as? String) ?? ""
                    if !title.isEmpty { menuText.append(title) }
                    // submenus
                    if let menus = attr(c, kAXChildrenAttribute as String) as? [AXUIElement] {
                        for m in menus {
                            if let items = attr(m, kAXChildrenAttribute as String) as? [AXUIElement] {
                                for it in items {
                                    let t = (attr(it, kAXTitleAttribute as String) as? String) ?? ""
                                    if !t.isEmpty { menuText.append("   - " + t) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
print("MENU:")
for line in menuText { print(line) }

// Close the menu again.
if let esc = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true) {
    esc.post(tap: .cghidEventTap)
}
if let escUp = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false) {
    escUp.post(tap: .cghidEventTap)
}
print("done")
