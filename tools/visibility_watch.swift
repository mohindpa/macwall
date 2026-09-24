import CoreGraphics
import ApplicationServices
import AppKit
import Foundation

// One-shot check: screen lock state + whether the MacWall status item is
// hit-testable on the menu bar (i.e. actually displayed).
// usage: vwatch   -> prints "LOCKED|UNLOCKED found: x=...|none"

let session = CGSessionCopyCurrentDictionary() as? [String: Any]
let locked = (session?["CGSSessionScreenIsLocked"] as? Bool) ?? false

let macwallPids = Set(
    NSRunningApplication.runningApplications(withBundleIdentifier: "com.mohind.macwall")
        .map { $0.processIdentifier }
)

var found: String? = nil
if !macwallPids.isEmpty {
    let sys = AXUIElementCreateSystemWide()
    let screenWidth = Int(NSScreen.screens.first?.frame.width ?? 1512)
    outer: for y in [10, 22] {
        for x in stride(from: 0, through: screenWidth, by: 4) {
            var el: AXUIElement?
            guard AXUIElementCopyElementAtPosition(sys, Float(x), Float(y), &el) == .success,
                  let e = el else { continue }
            var pid: pid_t = 0
            AXUIElementGetPid(e, &pid)
            if macwallPids.contains(pid) {
                found = "x=\(x) y=\(y)"
                break outer
            }
        }
    }
}

print("\(locked ? "LOCKED" : "UNLOCKED") found: \(found ?? "none")")
