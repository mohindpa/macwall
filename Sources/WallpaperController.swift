import AppKit
import AVFoundation

/// Owns the AVQueuePlayer (looped via AVPlayerLooper) and the wallpaper windows.
final class WallpaperController {
    private var windows: [WallpaperWindow] = []
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var rotationTimer: Timer?
    private var urls: [URL] = []
    private(set) var index = 0
    private(set) var isPaused = false

    private let lib = VideoLibrary.shared

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    var currentURL: URL? {
        urls.indices.contains(index) ? urls[index] : nil
    }

    /// The shared player (the video screensaver renders the same video).
    var currentPlayer: AVPlayer? { player }

    @objc private func screensChanged() {
        guard player != nil else { return }
        rebuildWindows()
    }

    // MARK: - Playback

    func start(urls: [URL], startAt startIndex: Int = 0) {
        self.urls = urls
        self.index = urls.isEmpty ? 0 : min(max(0, startIndex), urls.count - 1)
        isPaused = false
        guard !urls.isEmpty else { clear(); return }
        playCurrent()
        scheduleRotation()
    }

    func clear() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        teardownLooper()
        player = nil
        urls = []
        index = 0
        for window in windows { window.orderOut(nil); window.close() }
        windows.removeAll()
    }

    private func playCurrent() {
        guard urls.indices.contains(index) else { return }
        let url = urls[index]

        teardownLooper()
        if player == nil { player = AVQueuePlayer() }
        guard let player = player else { return }

        player.isMuted = lib.isMuted
        player.volume = Float(lib.volume)

        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)

        if windows.isEmpty { rebuildWindows() } else { attachPlayers() }
        player.play()
        lib.activePath = url.path
    }

    private func teardownLooper() {
        player?.pause()
        looper?.disableLooping()
        looper = nil
        player?.removeAllItems()
    }

    private func attachPlayers() {
        guard let player = player else { return }
        for window in windows { window.attach(player: player) }
    }

    func rebuildWindows() {
        for window in windows { window.orderOut(nil); window.close() }
        windows.removeAll()

        let fill = lib.fill
        for screen in NSScreen.screens {
            let window = WallpaperWindow(screen: screen)
            window.setFill(fill)
            windows.append(window)
        }
        attachPlayers()
    }

    // MARK: - Controls

    func setMuted(_ muted: Bool) {
        lib.isMuted = muted
        player?.isMuted = muted
    }

    func setVolume(_ level: Double) {
        lib.volume = level
        if level > 0 { lib.isMuted = false }
        player?.volume = Float(level)
        player?.isMuted = lib.isMuted
    }

    func setFill(_ fill: Bool) {
        lib.fill = fill
        for window in windows { window.setFill(fill) }
    }

    func togglePause() {
        guard let player = player else { return }
        if isPaused {
            player.play()
            isPaused = false
        } else {
            player.pause()
            isPaused = true
        }
    }

    func next() {
        guard !urls.isEmpty else { return }
        index = (index + 1) % urls.count
        playCurrent()
    }

    func scheduleRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        let minutes = lib.rotationMinutes
        guard minutes > 0, urls.count > 1 else { return }
        rotationTimer = Timer.scheduledTimer(withTimeInterval: Double(minutes) * 60, repeats: true) { [weak self] _ in
            self?.next()
        }
    }
}
