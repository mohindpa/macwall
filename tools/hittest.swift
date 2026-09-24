import ApplicationServices
import AppKit
import Foundation

// Who owns the menu bar pixels across x = 900..1060 ?
let systemWide = AXUIElementCreateSystemWide()
for x in stride(from: 900, through: 1060, by: 10) {
    var el: AXUIElement?
    let err = AXUIElementCopyElementAtPosition(systemWide, Float(x), 15, &el)
    guard err == .success, let element = el else {
        print("x=\(x): hitTest err \(err.rawValue)")
        continue
    }
    var pid: pid_t = 0
    AXUIElementGetPid(element, &pid)
    var roleRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
    var descRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
    var titleRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
    let role = (roleRef as? String) ?? "?"
    let desc = (descRef as? String) ?? ""
    let title = (titleRef as? String) ?? ""
    let appName = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)"
    print("x=\(x): pid=\(pid) app=\(appName) role=\(role) title='\(title)' desc='\(desc)'")
}

// MacWall processes
let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.mohind.macwall")
print("MacWall instances: \(running.count) pids: \(running.map { $0.processIdentifier })")
