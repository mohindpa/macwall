import AppKit
import AVFoundation
import CryptoKit

/// The macOS lock screen shows the *system wallpaper* — apps cannot draw over
/// the lock UI, and macOS 26 accepts a video file via `setDesktopImageURL` but
/// renders it as a flat backstop color. So the reliable path is a full-res
/// still frame exported from the chosen video, set as the system wallpaper
/// (the lock screen then displays that scene). Originals are backed up first
/// and restorable.
enum LockWallpaper {
    private static var cacheDir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.mohind.macwall", isDirectory: true)
            .appendingPathComponent("lock", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// Export (or reuse) a still frame for `videoPath`.
    static func still(for videoPath: String) -> URL? {
        let out = cacheDir.appendingPathComponent(hash(videoPath) + ".jpg")
        if FileManager.default.fileExists(atPath: out.path) { return out }

        let asset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 3840, height: 3840)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        var image: CGImage?
        for time in [1.0, 0.0] {
            if let cg = try? generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil) {
                image = cg
                break
            }
        }
        guard let cg = image else { return nil }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else { return nil }
        try? data.write(to: out)
        return out
    }

    /// Apply the video's still as the system wallpaper on every screen.
    /// (`NSScreen` works fine from a plain CLI process — verified.)
    @discardableResult
    static func apply(videoPath: String, lib: VideoLibrary) -> Bool {
        guard let jpg = still(for: videoPath) else { return false }
        backupCurrent(lib: lib)
        for screen in NSScreen.screens {
            try? NSWorkspace.shared.setDesktopImageURL(jpg, for: screen, options: [:])
        }
        return true
    }

    /// Restore the wallpaper that was active before MacWall first changed it.
    static func clear(lib: VideoLibrary) {
        let backups = lib.wallpaperBackup
        guard !backups.isEmpty else { return }
        for screen in NSScreen.screens {
            if let path = backups[screen.localizedName], FileManager.default.fileExists(atPath: path) {
                try? NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: path), for: screen, options: [:])
            }
        }
        lib.wallpaperBackup = [:]
    }

    /// Keep only the FIRST backup — re-assigning a different video must not
    /// overwrite the user's originals with a previous MacWall still.
    private static func backupCurrent(lib: VideoLibrary) {
        guard lib.wallpaperBackup.isEmpty else { return }
        var map: [String: String] = [:]
        for screen in NSScreen.screens {
            if let url = NSWorkspace.shared.desktopImageURL(for: screen) {
                map[screen.localizedName] = url.path
            }
        }
        lib.wallpaperBackup = map
    }

    private static func hash(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
