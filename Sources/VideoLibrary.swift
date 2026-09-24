import Foundation

/// Persistent list of the user's imported videos + settings.
/// Everything is stored under the app's own defaults domain (com.mohind.macwall).
final class VideoLibrary {
    static let shared = VideoLibrary()
    /// Standard defaults — inside the app bundle this is the
    /// com.mohind.macwall domain automatically. (Using the bundle id as a
    /// suite name explicitly is rejected by the OS.)
    static let defaults = UserDefaults.standard

    struct Entry: Codable {
        var name: String
        var path: String
        var bookmark: Data?
    }

    private(set) var entries: [Entry] = []

    var activePath: String? {
        get { Self.defaults.string(forKey: "activePath") }
        set { Self.defaults.set(newValue, forKey: "activePath") }
    }

    var rotationMinutes: Int {
        get { Self.defaults.object(forKey: "rotationMinutes") as? Int ?? 0 }
        set { Self.defaults.set(newValue, forKey: "rotationMinutes") }
    }

    var isMuted: Bool {
        get { Self.defaults.object(forKey: "isMuted") as? Bool ?? true }
        set { Self.defaults.set(newValue, forKey: "isMuted") }
    }

    var volume: Double {
        get { Self.defaults.object(forKey: "volume") as? Double ?? 0.5 }
        set { Self.defaults.set(newValue, forKey: "volume") }
    }

    var fill: Bool {
        get { Self.defaults.object(forKey: "fill") as? Bool ?? true }
        set { Self.defaults.set(newValue, forKey: "fill") }
    }

    /// Video screensaver: cover every screen with the wallpaper video when idle.
    var screensaverEnabled: Bool {
        get { Self.defaults.object(forKey: "screensaverEnabled") as? Bool ?? true }
        set { Self.defaults.set(newValue, forKey: "screensaverEnabled") }
    }

    /// Idle minutes before the video screensaver appears (1–30).
    var screensaverMinutes: Int {
        get { Self.defaults.object(forKey: "screensaverMinutes") as? Int ?? 5 }
        set { Self.defaults.set(newValue, forKey: "screensaverMinutes") }
    }

    /// Dashboard theme key (see PixelTheme.all).
    var themeKey: String {
        get { Self.defaults.string(forKey: "themeKey") ?? "lime" }
        set { Self.defaults.set(newValue, forKey: "themeKey") }
    }

    /// Video used by the video screensaver; nil = follow the wallpaper video.
    var screensaverPath: String? {
        get { Self.defaults.string(forKey: "screensaverPath") }
        set { Self.defaults.set(newValue, forKey: "screensaverPath") }
    }

    /// Video whose still frame is the macOS lock-screen wallpaper; nil = off.
    var lockScreenPath: String? {
        get { Self.defaults.string(forKey: "lockScreenPath") }
        set { Self.defaults.set(newValue, forKey: "lockScreenPath") }
    }

    /// System wallpapers captured before MacWall changed them (screen name → path).
    var wallpaperBackup: [String: String] {
        get { (Self.defaults.dictionary(forKey: "wallpaperBackup") as? [String: String]) ?? [:] }
        set { Self.defaults.set(newValue, forKey: "wallpaperBackup") }
    }

    /// Extra offset added to the desktop window level (0 = desktop level).
    var levelOffset: Int {
        get { Self.defaults.object(forKey: "levelOffset") as? Int ?? 0 }
        set { Self.defaults.set(newValue, forKey: "levelOffset") }
    }

    private init() {
        load()
    }

    func load() {
        if let data = Self.defaults.data(forKey: "entries"),
           let list = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = list
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(entries) {
            Self.defaults.set(data, forKey: "entries")
        }
        Self.defaults.synchronize()
    }

    /// Remember a video the user picked. The file itself is never copied or touched.
    @discardableResult
    func importVideo(_ url: URL) -> Entry {
        let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        if let idx = entries.firstIndex(where: { $0.path == url.path }) {
            entries[idx].bookmark = bookmark ?? entries[idx].bookmark
            entries[idx].name = url.lastPathComponent
            save()
            return entries[idx]
        }
        let entry = Entry(name: url.lastPathComponent, path: url.path, bookmark: bookmark)
        entries.append(entry)
        save()
        return entry
    }

    /// Resolve an entry back to a readable URL (survives file moves via bookmark).
    func resolve(_ entry: Entry) -> URL? {
        if let bookmark = entry.bookmark {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                _ = url.startAccessingSecurityScopedResource()
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
        }
        let url = URL(fileURLWithPath: entry.path)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = url.startAccessingSecurityScopedResource()
            return url
        }
        return nil
    }

    var favoritePaths: [String] {
        get { Self.defaults.stringArray(forKey: "favorites") ?? [] }
        set { Self.defaults.set(newValue, forKey: "favorites") }
    }

    func toggleFavorite(_ path: String) {
        var list = favoritePaths
        if let index = list.firstIndex(of: path) {
            list.remove(at: index)
        } else {
            list.append(path)
        }
        favoritePaths = list
    }

    /// Removes one video from the list. The file on disk is NOT touched.
    func removeEntry(path: String) {
        entries.removeAll { $0.path == path }
        if activePath == path { activePath = nil }
        var favorites = favoritePaths
        favorites.removeAll { $0 == path }
        favoritePaths = favorites
        save()
    }

    /// Forgets the list. The video files on disk are NOT touched.
    func clearList() {
        entries.removeAll()
        activePath = nil
        favoritePaths = []
        save()
    }
}
