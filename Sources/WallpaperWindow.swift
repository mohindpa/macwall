import AppKit
import AVFoundation

/// Creates one borderless window per screen, pinned at the desktop window
/// level: above the system wallpaper, below the desktop icons, on every Space.
final class WallpaperWindow: NSWindow {
    private let playerLayer = AVPlayerLayer()

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // The one macOS-version-sensitive knob. 0 = kCGDesktopWindowLevel;
        // can be overridden per-run with LW_LEVEL_OFFSET for testing.
        let envOverride = ProcessInfo.processInfo.environment["LW_LEVEL_OFFSET"].flatMap(Int.init)
        let offset = envOverride ?? VideoLibrary.shared.levelOffset
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + offset)

        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        isMovable = false
        ignoresMouseEvents = true
        animationBehavior = .none
        isReleasedWhenClosed = false

        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        let host = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        host.layer = playerLayer
        host.wantsLayer = true
        contentView = host

        setFrame(screen.frame, display: true)
        orderFrontRegardless()
    }

    func attach(player: AVPlayer?) {
        playerLayer.player = player
    }

    func setFill(_ fill: Bool) {
        playerLayer.videoGravity = fill ? .resizeAspectFill : .resizeAspect
    }
}
