import Foundation
import ServiceManagement

/// Start-at-login handling.
///
/// Always uses a LaunchAgent plist (not SMAppService) so MacWall is launched
/// with the `--login-launch` flag and can therefore tell "started at login"
/// (no dashboard window) from "user opened the app" (dashboard window shows).
struct LoginItem {
    private let label = "com.mohind.macwall"

    private var agentPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist").path
    }

    var isEnabled: Bool { FileManager.default.fileExists(atPath: agentPath) }

    func enable() {
        // Drop any legacy SMAppService registration (MacWall 1.0) so the app
        // doesn't get launched twice at login.
        LoginItem.unregisterLegacyService()
        writeAgent()
    }

    func disable() {
        LoginItem.unregisterLegacyService()
        try? FileManager.default.removeItem(atPath: agentPath)
    }

    /// Called at app start: if the old SMAppService login item is still
    /// registered while the LaunchAgent exists, unregister it (1.0 → 2.0 migration).
    static func cleanupLegacy() {
        let agentExists = FileManager.default.fileExists(
            atPath: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents/com.mohind.macwall.plist").path
        )
        guard agentExists else { return }
        unregisterLegacyService()
    }

    private static func unregisterLegacyService() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            if status == .enabled || status == .requiresApproval {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    private func writeAgent() {
        // Prefer the installed copy so a login agent never points into a
        // build directory (e.g. when enabling the login item before install).
        let installed = NSHomeDirectory() + "/Applications/MacWall.app/Contents/MacOS/MacWall"
        let executable: String
        if FileManager.default.fileExists(atPath: installed) {
            executable = installed
        } else {
            executable = Bundle.main.executablePath ?? ""
        }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable, "--login-launch"],
            "RunAtLoad": true,
            "ProcessType": "Interactive"
        ]
        let url = URL(fileURLWithPath: agentPath)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        (plist as NSDictionary).write(to: url, atomically: true)
    }
}
