import AppKit
import AVFoundation
import CoreGraphics
import IOKit

/// Video screensaver: when the Mac sits idle, covers every screen with the
/// assigned screensaver video (full-screen) on its own player. Any input
/// dismisses it; the system lock screen always wins (overlay hides when the
/// session locks).
///
/// On/off + idle delay live in VideoLibrary (`screensaverEnabled`,
/// `screensaverMinutes`); the video is `screensaverPath` (nil = follow the
/// wallpaper video). Deliberately independent of the macOS Screen Saver.
final class VideoScreensaver {
    private let lib = VideoLibrary.shared
    private var windows: [ScreensaverWindow] = []
    private var timer: Timer?
    private var isActive = false
    private var previewUntil: Date?
    private var cursorHidden = false

    // Own player so the screensaver can show a different video than the wallpaper.
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    /// Supplied by AppDelegate — the video to cover the screen with.
    var provideVideoURL: () -> URL? = { nil }

    init() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(systemTookOver),
                           name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        center.addObserver(self, selector: #selector(systemTookOver),
                           name: Notification.Name("com.apple.screensaver.didstart"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    deinit {
        timer?.invalidate()
        releasePlayer()
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func start() {
        timer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Control

    /// Shows the overlay immediately for `seconds` (ignores idle; used by
    /// `--screensaver preview` so the effect can be demonstrated/verified).
    func preview(seconds: Double) {
        guard !VideoScreensaver.isLocked() else { return }
        previewUntil = Date().addingTimeInterval(seconds)
        show()
    }

    /// Called when the screensaver-video assignment changes; drops the player
    /// so the next show() picks up the new video.
    func reloadIfNeeded() {
        if isActive { dismiss() }
        releasePlayer()
    }

    private func tick() {
        if VideoScreensaver.isLocked() {
            previewUntil = nil
            dismiss()
            return
        }
        if let until = previewUntil {
            if Date() >= until { dismiss() }
            return
        }
        guard lib.screensaverEnabled, lib.screensaverMinutes > 0 else {
            dismiss()
            return
        }
        let idle = VideoScreensaver.idleSeconds()
        if idle >= Double(lib.screensaverMinutes) * 60 {
            if !isActive { show() }
        } else if isActive && idle < 1.0 {
            dismiss()
        }
    }

    @objc private func systemTookOver() {
        previewUntil = nil
        dismiss()
    }

    @objc private func screensChanged() {
        guard isActive else { return }
        dismiss()
        show()
    }

    // MARK: - Player

    private func ensurePlayer() -> AVPlayer? {
        guard let url = provideVideoURL() else { return nil }
        if let player = player, currentURL == url { return player }
        releasePlayer()
        let queue = AVQueuePlayer()
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        queue.isMuted = lib.isMuted
        queue.volume = Float(lib.volume)
        currentURL = url
        player = queue
        queue.play()   // MUST start it — creating the looper alone never does
        return queue
    }

    private func releasePlayer() {
        looper?.disableLooping()
        looper = nil
        player?.pause()
        player = nil
        currentURL = nil
    }

    // MARK: - Overlay

    private func show() {
        guard windows.isEmpty, let player = ensurePlayer() else { return }
        isActive = true
        for screen in NSScreen.screens {
            let window = ScreensaverWindow(screen: screen)
            window.setFill(lib.fill)
            window.attach(player: player)
            window.orderFrontRegardless()
            windows.append(window)
        }
        player.play()
        if !cursorHidden {
            NSCursor.hide()
            cursorHidden = true
        }
    }

    private func dismiss() {
        guard isActive || !windows.isEmpty || cursorHidden else { return }
        isActive = false
        previewUntil = nil
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        if cursorHidden {
            NSCursor.unhide()
            cursorHidden = false
        }
    }

    // MARK: - State helpers

    /// Seconds since the last user input (IOKit HID idle time — no permissions needed).
    static func idleSeconds() -> Double {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != 0 else { return 0 }
        defer { IOObjectRelease(service) }
        guard let property = IORegistryEntryCreateCFProperty(service, "HIDIdleTime" as CFString, kCFAllocatorDefault, 0),
              let value = property.takeRetainedValue() as? Int64 else { return 0 }
        return Double(value) / 1_000_000_000.0
    }

    static func isLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (session["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }
}

/// Full-screen borderless window at the screen-saver level showing the
/// screensaver player. Swallows input (the click that dismisses is consumed,
/// so nothing behind the overlay gets clicked accidentally).
final class ScreensaverWindow: NSWindow {
    private let playerLayer = AVPlayerLayer()

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        ignoresMouseEvents = false
        isReleasedWhenClosed = false

        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        view.layer = CALayer()
        view.layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.frame = view.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(playerLayer)
        contentView = view
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func attach(player: AVPlayer) {
        playerLayer.player = player
    }

    func setFill(_ fill: Bool) {
        playerLayer.videoGravity = fill ? .resizeAspectFill : .resizeAspect
    }
}
