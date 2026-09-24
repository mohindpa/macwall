import AppKit
import SwiftUI
import AVFoundation
import CryptoKit

// MARK: - Items

struct VideoItem: Identifiable, Equatable {
    var id: String { path }
    var name: String
    var path: String
    var url: URL?
    var isFavorite: Bool
    var duration: Double?
    var width: Int?
    var height: Int?
    var fileSize: String?
}

enum SidebarSection: String, CaseIterable {
    case myVideos = "My Videos"
    case favorites = "Favorites"
}

// MARK: - Model

final class DashboardModel: ObservableObject {
    @Published var videos: [VideoItem] = []
    @Published var section: SidebarSection = .myVideos
    @Published var selection: String?
    @Published var search: String = ""
    @Published var thumbs: [String: NSImage] = [:]
    @Published var nowPlayingPath: String?
    @Published var isPaused = false
    @Published var isMuted = true
    @Published var volume: Double = 0.5
    @Published var fill = true
    @Published var rotationMinutes = 0
    @Published var startAtLogin = false
    @Published var screensaverEnabled = true
    @Published var screensaverMinutes = 5
    @Published var themeKey = "lime"
    @Published var screensaverPath: String? = nil
    @Published var lockScreenPath: String? = nil

    // Local view state lives here too — direct `@State` cannot be used because
    // this build environment's toolchain is missing the SwiftUIMacros plugin.
    @Published var dropTargeted = false
    @Published var hoveredPath: String?
    @Published var hoveredNav: String?
    @Published var showSupport = false

    // AppKit bridge — wired up by AppDelegate
    var onAddVideos: () -> Void = {}
    var onSetWallpaper: (String) -> Void = { _ in }
    var onRemove: (String) -> Void = { _ in }
    var onReveal: (String) -> Void = { _ in }
    var onToggleFavorite: (String) -> Void = { _ in }
    var onTogglePause: () -> Void = {}
    var onToggleMute: () -> Void = {}
    var onSetVolume: (Double) -> Void = { _ in }
    var onToggleFill: (Bool) -> Void = { _ in }
    var onSetRotation: (Int) -> Void = { _ in }
    var onToggleLogin: (Bool) -> Void = { _ in }
    var onToggleScreensaver: (Bool) -> Void = { _ in }
    var onSetScreensaverDelay: (Int) -> Void = { _ in }
    var onSetTheme: (String) -> Void = { _ in }
    var onSetSaverVideo: (String?) -> Void = { _ in }
    var onSetLockVideo: (String?) -> Void = { _ in }
    var onImportURLs: ([URL]) -> Void = { _ in }

    var visibleVideos: [VideoItem] {
        var list = videos
        if section == .favorites { list = list.filter { $0.isFavorite } }
        let query = search.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty { list = list.filter { $0.name.localizedCaseInsensitiveContains(query) } }
        return list
    }

    var nowPlayingName: String? {
        guard let path = nowPlayingPath else { return nil }
        if let match = videos.first(where: { $0.path == path }) { return match.name }
        return (path as NSString).lastPathComponent
    }

    func requestThumb(for item: VideoItem) {
        guard thumbs[item.path] == nil else { return }
        ThumbnailCache.shared.request(path: item.path, maxSize: CGSize(width: 640, height: 360)) { [weak self] image in
            guard let image = image else { return }
            DispatchQueue.main.async { self?.thumbs[item.path] = image }
        }
    }
}

// MARK: - Thumbnails

final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let memory = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.mohind.macwall.thumbs", qos: .utility)
    private let dir: URL

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.mohind.macwall", isDirectory: true)
            .appendingPathComponent("thumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        dir = base
        memory.countLimit = 200
    }

    func request(path: String, maxSize: CGSize, completion: @escaping (NSImage?) -> Void) {
        if let cached = memory.object(forKey: path as NSString) {
            completion(cached)
            return
        }
        let key = ThumbnailCache.hash(path)
        let file = dir.appendingPathComponent(key + ".jpg")
        if let disk = NSImage(contentsOf: file) {
            memory.setObject(disk, forKey: path as NSString)
            completion(disk)
            return
        }
        queue.async { [weak self] in
            var image: NSImage?
            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = maxSize
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.6, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.6, preferredTimescale: 600)
            let times: [CMTime] = [CMTime(seconds: 1.0, preferredTimescale: 600), .zero]
            for time in times {
                if let cg = try? generator.copyCGImage(at: time, actualTime: nil) {
                    let rep = NSBitmapImageRep(cgImage: cg)
                    if let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) {
                        try? data.write(to: file)
                    }
                    image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                    break
                }
            }
            DispatchQueue.main.async {
                if let image = image { self?.memory.setObject(image, forKey: path as NSString) }
                completion(image)
            }
        }
    }

    private static func hash(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
