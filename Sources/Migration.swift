import Foundation

/// One-time migration from the pre-rename builds ("LiveWall", bundle id
/// com.mohind.livewall) to MacWall: copies the settings domain, moves the
/// cache (thumbnails + lock-screen stills), and replaces the login agent.
/// Runs at the top of main() — before any VideoLibrary access.
enum LegacyMigration {
    private static let oldBundleID = "com.mohind.livewall"

    static func run() {
        migrateSettings()
        migrateCaches()
        migrateLoginAgent()
    }

    private static func migrateSettings() {
        let defaults = UserDefaults.standard
        // Only when the new domain is still empty (fresh install → nothing to do).
        guard defaults.object(forKey: "entries") == nil, defaults.string(forKey: "themeKey") == nil else { return }
        let oldPlist = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Preferences/\(oldBundleID).plist")
        guard let data = try? Data(contentsOf: oldPlist),
              let dict = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any]
        else { return }
        for (key, value) in dict where !key.hasPrefix("NS") {
            defaults.set(value, forKey: key)
        }
        defaults.synchronize()
    }

    private static func migrateCaches() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let old = caches.appendingPathComponent(oldBundleID)
        let new = caches.appendingPathComponent("com.mohind.macwall")
        guard FileManager.default.fileExists(atPath: old.path),
              !FileManager.default.fileExists(atPath: new.path) else { return }
        try? FileManager.default.moveItem(at: old, to: new)
    }

    private static func migrateLoginAgent() {
        let oldAgent = URL(fileURLWithPath: NSHomeDirectory() + "/Library/LaunchAgents/\(oldBundleID).plist")
        guard FileManager.default.fileExists(atPath: oldAgent.path) else { return }
        try? FileManager.default.removeItem(at: oldAgent)
        LoginItem().enable()   // rewrites the agent under the new label + installed path
    }
}
