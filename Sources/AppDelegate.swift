import AppKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    /// Set at launch when macwall was started by the login item (--login-launch).
    /// In that case the dashboard window is not popped automatically.
    var isLoginLaunch = false

    private var statusItem: NSStatusItem!
    private let lib = VideoLibrary.shared
    private let controller = WallpaperController()
    private let loginItem = LoginItem()
    private let screensaver = VideoScreensaver()

    // Dashboard
    private let model = DashboardModel()
    private var dashboardWindow: NSWindow?

    private struct Meta {
        var duration: Double?
        var width: Int?
        var height: Int?
        var fileSize: String?
    }
    private var metadata: [String: Meta] = [:]
    private var metadataInFlight: Set<String> = []

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single instance only: hand off to the already-running copy, which
        // opens its dashboard window.
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.mohind.macwall")
        if running.count > 1 {
            DistributedNotificationCenter.default().postNotificationName(
                Notification.Name("com.mohind.macwall.reveal"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            NSApp.terminate(nil)
            return
        }

        // 1.0 registered the login item via SMAppService; migrate away from it
        // so the app can pass --login-launch (used to skip the dashboard at login).
        LoginItem.cleanupLegacy()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "MacWallStatusItem"
        statusItem.isVisible = true
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: "MacWall")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "MacWall — video desktop wallpaper"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Double-launch / reopen while running: show the dashboard.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.mohind.macwall.reveal"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openDashboard()
        }

        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.mohind.macwall.screensaver-preview"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let seconds = (note.userInfo?["seconds"] as? Double) ?? 8
            self?.screensaver.preview(seconds: seconds)
        }

        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.mohind.macwall.show-support"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.openDashboard()
            self.model.showSupport = true
        }

        screensaver.provideVideoURL = { [weak self] in self?.screensaverVideoURL() }
        screensaver.start()

        wireModel()
        restorePlayback()
        refreshModel()
        applyLockWallpaperIfNeeded()

        if !isLoginLaunch {
            openDashboard()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openDashboard()
        return true
    }

    /// Finder "Open With → MacWall" support.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        for url in urls { lib.importVideo(url) }
        setActive(first)
        refreshModel()
    }

    // MARK: - Dashboard

    private func wireModel() {
        model.onAddVideos = { [weak self] in self?.chooseVideo() }
        model.onSetWallpaper = { [weak self] path in
            guard let self = self else { return }
            self.setActive(URL(fileURLWithPath: path))
            self.refreshModel()
        }
        model.onRemove = { [weak self] path in self?.removeEntry(path) }
        model.onReveal = { path in
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        }
        model.onToggleFavorite = { [weak self] path in
            guard let self = self else { return }
            self.lib.toggleFavorite(path)
            self.refreshModel()
        }
        model.onTogglePause = { [weak self] in
            guard let self = self else { return }
            self.controller.togglePause()
            self.refreshModel()
        }
        model.onToggleMute = { [weak self] in
            guard let self = self else { return }
            self.controller.setMuted(!self.lib.isMuted)
            self.refreshModel()
        }
        model.onSetVolume = { [weak self] value in
            guard let self = self else { return }
            self.controller.setVolume(value)
            self.refreshModel()
        }
        model.onToggleFill = { [weak self] on in
            guard let self = self else { return }
            self.controller.setFill(on)
            self.refreshModel()
        }
        model.onSetRotation = { [weak self] minutes in
            guard let self = self else { return }
            self.lib.rotationMinutes = minutes
            self.controller.scheduleRotation()
            self.refreshModel()
        }
        model.onToggleLogin = { [weak self] on in
            guard let self = self else { return }
            if on { self.loginItem.enable() } else { self.loginItem.disable() }
            self.refreshModel()
        }
        model.onToggleScreensaver = { [weak self] on in
            guard let self = self else { return }
            self.lib.screensaverEnabled = on
            self.refreshModel()
        }
        model.onSetScreensaverDelay = { [weak self] minutes in
            guard let self = self else { return }
            self.lib.screensaverMinutes = minutes
            self.refreshModel()
        }
        model.onSetTheme = { [weak self] key in
            guard let self = self else { return }
            self.lib.themeKey = key
            self.refreshModel()
        }
        model.onSetSaverVideo = { [weak self] path in
            guard let self = self else { return }
            self.lib.screensaverPath = path
            self.screensaver.reloadIfNeeded()
            self.refreshModel()
        }
        model.onSetLockVideo = { [weak self] path in
            guard let self = self else { return }
            self.lib.lockScreenPath = path
            if let path = path {
                LockWallpaper.apply(videoPath: path, lib: self.lib)
            } else {
                LockWallpaper.clear(lib: self.lib)
            }
            self.refreshModel()
        }
        model.onImportURLs = { [weak self] urls in
            self?.importDropped(urls)
        }
    }

    private func openDashboard() {
        if dashboardWindow == nil { createDashboardWindow() }
        refreshModel()
        NSApp.activate(ignoringOtherApps: true)
        dashboardWindow?.makeKeyAndOrderFront(nil)
    }

    private func createDashboardWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MacWall"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 900, height: 600)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.backgroundColor = NSColor(red: 0.055, green: 0.063, blue: 0.075, alpha: 1)
        window.contentView = NSHostingView(rootView: DashboardView(model: model))
        window.setFrameAutosaveName("MacWallDashboard")
        window.center()
        dashboardWindow = window
    }

    /// Rebuilds the model from the library + controller state, then starts
    /// background loading of any missing video metadata (duration / resolution / size).
    private func refreshModel() {
        let favorites = Set(lib.favoritePaths)
        model.videos = lib.entries.map { entry in
            let meta = metadata[entry.path]
            return VideoItem(
                name: entry.name,
                path: entry.path,
                url: lib.resolve(entry),
                isFavorite: favorites.contains(entry.path),
                duration: meta?.duration,
                width: meta?.width,
                height: meta?.height,
                fileSize: meta?.fileSize
            )
        }
        model.nowPlayingPath = controller.currentURL?.path ?? lib.activePath
        model.isPaused = controller.isPaused
        model.isMuted = lib.isMuted
        model.volume = lib.volume
        model.fill = lib.fill
        model.rotationMinutes = lib.rotationMinutes
        model.startAtLogin = loginItem.isEnabled
        model.screensaverEnabled = lib.screensaverEnabled
        model.screensaverMinutes = lib.screensaverMinutes
        model.themeKey = lib.themeKey
        model.screensaverPath = lib.screensaverPath
        model.lockScreenPath = lib.lockScreenPath
        loadMissingMetadata()
    }

    private func loadMissingMetadata() {
        for entry in lib.entries where metadata[entry.path] == nil && !metadataInFlight.contains(entry.path) {
            metadataInFlight.insert(entry.path)
            let path = entry.path
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                var meta = Meta()
                let seconds = CMTimeGetSeconds(asset.duration)
                if seconds.isFinite && seconds > 0 { meta.duration = seconds }
                if let track = asset.tracks(withMediaType: .video).first {
                    let size = track.naturalSize.applying(track.preferredTransform)
                    let width = Int(abs(size.width).rounded())
                    let height = Int(abs(size.height).rounded())
                    if width > 0, height > 0 {
                        meta.width = width
                        meta.height = height
                    }
                }
                if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                   let bytes = attributes[.size] as? Int64 {
                    meta.fileSize = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                }
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.metadataInFlight.remove(path)
                    self.metadata[path] = meta
                    if let index = self.model.videos.firstIndex(where: { $0.path == path }) {
                        self.model.videos[index].duration = meta.duration
                        self.model.videos[index].width = meta.width
                        self.model.videos[index].height = meta.height
                        self.model.videos[index].fileSize = meta.fileSize
                    }
                }
            }
        }
    }

    /// Drag & drop import.
    private func importDropped(_ urls: [URL]) {
        var imported: [URL] = []
        for url in urls {
            let type = UTType(filenameExtension: url.pathExtension.lowercased())
            let isMovie = type?.conforms(to: .movie) == true || type?.conforms(to: .video) == true
            guard isMovie else { continue }
            lib.importVideo(url)
            imported.append(url)
        }
        guard !imported.isEmpty else { return }
        if controller.currentURL == nil, let first = imported.first {
            setActive(first)
        }
        refreshModel()
    }

    private func removeEntry(_ path: String) {
        let name = lib.entries.first(where: { $0.path == path })?.name ?? (path as NSString).lastPathComponent
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Remove “\(name)” from the list?"
        alert.informativeText = "The video file itself is not touched — it is only removed from MacWall's list."
        alert.addButton(withTitle: "Remove from List")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        lib.removeEntry(path: path)
        metadata[path] = nil
        if controller.currentURL?.path == path || lib.activePath == path {
            var playable: [URL] = []
            for entry in lib.entries {
                if let url = lib.resolve(entry) { playable.append(url) }
            }
            if playable.isEmpty {
                controller.clear()
            } else {
                controller.start(urls: playable, startAt: 0)
            }
        }
        refreshModel()
    }

    // MARK: - Playback

    private func restorePlayback() {
        var playable: [URL] = []
        for entry in lib.entries {
            if let url = lib.resolve(entry) { playable.append(url) }
        }
        guard !playable.isEmpty else { return }
        var startIndex = 0
        if let active = lib.activePath, let idx = playable.firstIndex(where: { $0.path == active }) {
            startIndex = idx
        }
        controller.start(urls: playable, startAt: startIndex)
    }

    private func setActive(_ url: URL) {
        lib.importVideo(url)
        lib.activePath = url.path
        var playable: [URL] = []
        for entry in lib.entries {
            if let resolved = lib.resolve(entry) { playable.append(resolved) }
        }
        let startIndex = playable.firstIndex(where: { $0.path == url.path }) ?? 0
        controller.start(urls: playable, startAt: startIndex)
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let current = controller.currentURL?.lastPathComponent ?? "no video chosen"
        let nowPlaying = NSMenuItem(title: "Now playing: \(current)", action: nil, keyEquivalent: "")
        nowPlaying.isEnabled = false
        menu.addItem(nowPlaying)
        menu.addItem(.separator())

        let dashboard = NSMenuItem(title: "Open Dashboard…", action: #selector(openDashboardAction), keyEquivalent: "d")
        dashboard.target = self
        menu.addItem(dashboard)

        let choose = NSMenuItem(title: "Choose Video…", action: #selector(chooseVideo), keyEquivalent: "o")
        choose.target = self
        menu.addItem(choose)

        // My Videos submenu
        let mine = NSMenuItem(title: "My Videos (\(lib.entries.count))", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for entry in lib.entries {
            let item = NSMenuItem(title: entry.name, action: #selector(pickVideo(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = entry.path
            item.state = (entry.path == lib.activePath) ? .on : .off
            sub.addItem(item)
        }
        if lib.entries.isEmpty {
            let empty = NSMenuItem(title: "Nothing added yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            sub.addItem(empty)
        } else {
            sub.addItem(.separator())
            let clear = NSMenuItem(title: "Clear List (video files are kept)", action: #selector(clearList), keyEquivalent: "")
            clear.target = self
            sub.addItem(clear)
        }
        mine.submenu = sub
        menu.addItem(mine)

        // Rotate submenu
        let rotateTitle = lib.rotationMinutes == 0 ? "Rotate Videos: Off" : "Rotate Videos: every \(lib.rotationMinutes) min"
        let rotate = NSMenuItem(title: rotateTitle, action: nil, keyEquivalent: "")
        let rotateSub = NSMenu()
        for minutes in [0, 5, 10, 15, 30, 60] {
            let item = NSMenuItem(title: minutes == 0 ? "Off" : "Every \(minutes) minutes", action: #selector(setRotation(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = minutes
            item.state = (lib.rotationMinutes == minutes) ? .on : .off
            item.isEnabled = minutes == 0 || lib.entries.count > 1
            rotateSub.addItem(item)
        }
        rotate.submenu = rotateSub
        menu.addItem(rotate)

        let pause = NSMenuItem(title: controller.isPaused ? "Resume" : "Pause", action: #selector(togglePause), keyEquivalent: "p")
        pause.target = self
        menu.addItem(pause)

        let mute = NSMenuItem(title: "Mute", action: #selector(toggleMute), keyEquivalent: "")
        mute.target = self
        mute.state = lib.isMuted ? .on : .off
        menu.addItem(mute)

        let volume = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        let volumeSub = NSMenu()
        for level in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let item = NSMenuItem(title: "\(Int(level * 100))%", action: #selector(setVolume(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = level
            item.state = (abs(lib.volume - level) < 0.01) ? .on : .off
            volumeSub.addItem(item)
        }
        volume.submenu = volumeSub
        menu.addItem(volume)

        let fill = NSMenuItem(title: "Fill Screen (off = fit inside)", action: #selector(toggleFill), keyEquivalent: "")
        fill.target = self
        fill.state = lib.fill ? .on : .off
        menu.addItem(fill)

        let saver = NSMenuItem(title: "Video Screensaver (idle)", action: #selector(toggleScreensaver), keyEquivalent: "")
        saver.target = self
        saver.state = lib.screensaverEnabled ? .on : .off
        menu.addItem(saver)

        let saverDelay = NSMenuItem(title: "Screensaver after", action: nil, keyEquivalent: "")
        let saverSub = NSMenu()
        for minutes in [1, 2, 5, 10, 15, 30] {
            let item = NSMenuItem(title: "\(minutes) min", action: #selector(setScreensaverDelay(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = minutes
            item.state = (lib.screensaverMinutes == minutes) ? .on : .off
            saverSub.addItem(item)
        }
        saverDelay.submenu = saverSub
        menu.addItem(saverDelay)

        let saverVideo = NSMenuItem(title: "Screensaver Video", action: nil, keyEquivalent: "")
        let saverVideoSub = NSMenu()
        let followItem = NSMenuItem(title: "Follow Wallpaper", action: #selector(setSaverVideo(_:)), keyEquivalent: "")
        followItem.target = self
        followItem.representedObject = ""
        followItem.state = (lib.screensaverPath == nil) ? .on : .off
        saverVideoSub.addItem(followItem)
        if !lib.entries.isEmpty { saverVideoSub.addItem(.separator()) }
        for entry in lib.entries {
            let item = NSMenuItem(title: entry.name, action: #selector(setSaverVideo(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = entry.path
            item.state = (lib.screensaverPath == entry.path) ? .on : .off
            saverVideoSub.addItem(item)
        }
        saverVideo.submenu = saverVideoSub
        menu.addItem(saverVideo)

        let lockVideo = NSMenuItem(title: "Lock Screen Video (still)", action: nil, keyEquivalent: "")
        let lockVideoSub = NSMenu()
        let lockOff = NSMenuItem(title: "Off", action: #selector(setLockVideo(_:)), keyEquivalent: "")
        lockOff.target = self
        lockOff.representedObject = ""
        lockOff.state = (lib.lockScreenPath == nil) ? .on : .off
        lockVideoSub.addItem(lockOff)
        if !lib.entries.isEmpty { lockVideoSub.addItem(.separator()) }
        for entry in lib.entries {
            let item = NSMenuItem(title: entry.name, action: #selector(setLockVideo(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = entry.path
            item.state = (lib.lockScreenPath == entry.path) ? .on : .off
            lockVideoSub.addItem(item)
        }
        lockVideo.submenu = lockVideoSub
        menu.addItem(lockVideo)

        let themeItem = NSMenuItem(title: "Dashboard Theme", action: nil, keyEquivalent: "")
        let themeSub = NSMenu()
        for dashboardTheme in PixelTheme.all {
            let item = NSMenuItem(title: dashboardTheme.name, action: #selector(setTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = dashboardTheme.key
            item.state = (lib.themeKey == dashboardTheme.key) ? .on : .off
            themeSub.addItem(item)
        }
        themeItem.submenu = themeSub
        menu.addItem(themeItem)

        menu.addItem(.separator())

        let login = NSMenuItem(title: "Start at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = loginItem.isEnabled ? .on : .off
        menu.addItem(login)

        let reveal = NSMenuItem(title: "Reveal Current Video in Finder", action: #selector(revealCurrent), keyEquivalent: "")
        reveal.target = self
        reveal.isEnabled = controller.currentURL != nil
        menu.addItem(reveal)

        menu.addItem(.separator())

        let support = NSMenuItem(title: "Support MacWall…", action: #selector(showSupportAction), keyEquivalent: "")
        support.target = self
        menu.addItem(support)

        let about = NSMenuItem(title: "About MacWall", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit MacWall", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func openDashboardAction() { openDashboard() }

    @objc private func showSupportAction() {
        openDashboard()
        model.showSupport = true
    }

    @objc private func chooseVideo() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Choose a video wallpaper"
        panel.message = "Pick a video from your Mac (mp4, mov, m4v…). It plays as your desktop wallpaper; the file stays where it is."
        panel.prompt = "Use as Wallpaper"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.movie]
        panel.begin { [weak self] response in
            guard response == .OK, let self = self, let first = panel.urls.first else { return }
            for url in panel.urls { self.lib.importVideo(url) }
            self.setActive(first)
            self.refreshModel()
        }
    }

    @objc private func pickVideo(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        setActive(URL(fileURLWithPath: path))
        refreshModel()
    }

    @objc private func clearList() {
        lib.clearList()
        controller.clear()
        refreshModel()
    }

    @objc private func setRotation(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        lib.rotationMinutes = minutes
        controller.scheduleRotation()
        refreshModel()
    }

    @objc private func togglePause() {
        controller.togglePause()
        refreshModel()
    }

    @objc private func toggleMute() {
        controller.setMuted(!lib.isMuted)
        refreshModel()
    }

    @objc private func setVolume(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? Double else { return }
        controller.setVolume(level)
        refreshModel()
    }

    @objc private func toggleFill() {
        controller.setFill(!lib.fill)
        refreshModel()
    }

    @objc private func toggleLogin() {
        if loginItem.isEnabled {
            loginItem.disable()
        } else {
            loginItem.enable()
        }
        refreshModel()
    }

    @objc private func toggleScreensaver() {
        lib.screensaverEnabled.toggle()
        refreshModel()
    }

    @objc private func setScreensaverDelay(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        lib.screensaverMinutes = minutes
        refreshModel()
    }

    @objc private func setTheme(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        lib.themeKey = key
        refreshModel()
    }

    @objc private func setSaverVideo(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        lib.screensaverPath = value.isEmpty ? nil : value
        screensaver.reloadIfNeeded()
        refreshModel()
    }

    @objc private func setLockVideo(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        let path: String? = value.isEmpty ? nil : value
        lib.lockScreenPath = path
        if let path = path {
            LockWallpaper.apply(videoPath: path, lib: lib)
        } else {
            LockWallpaper.clear(lib: lib)
        }
        refreshModel()
    }

    /// The screensaver video (assignment, falling back to the wallpaper video).
    private func screensaverVideoURL() -> URL? {
        if let path = lib.screensaverPath, FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return controller.currentURL
    }

    /// Re-applies the lock-screen still on launch (only when one is assigned).
    private func applyLockWallpaperIfNeeded() {
        guard let path = lib.lockScreenPath, FileManager.default.fileExists(atPath: path) else { return }
        LockWallpaper.apply(videoPath: path, lib: lib)
    }

    @objc private func revealCurrent() {
        guard let url = controller.currentURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func showAbout() {
        AppDelegate.showAboutPanel()
    }

    /// The About panel — also reachable via `--about` (used for verification).
    static func showAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "MacWall"
        alert.informativeText = """
        Personal video desktop wallpaper for macOS.
        Created by @mohind

        • Dashboard — your videos side by side; click “Set as Wallpaper” or double-click a card.
        • Add Videos… (or drag & drop) — import your own videos. Files are never copied or moved; MacWall only remembers where they live.
        • Video Screensaver — your video takes over the screen when the Mac is idle (on/off + delay in Settings).
        • Lock Screen — right-click a video → “Use for Lock Screen”; its scene becomes the lock-screen wallpaper (a still frame — macOS does not let third-party apps animate the real lock screen).
        • Pick which video plays where: every card has WALLPAPER · SCREENSAVER · LOCK SCREEN buttons. MacWall lives in the menu bar only (no Dock icon).
        • Rotate Videos — automatically cycle through your imports.
        • Start at Login — your wallpaper comes back after every restart.
        • Support — MacWall is free and stays free. If it's useful to you, donations via PayPal (mohindpa@protonmail.com) keep the projects coming. Want a custom wallpaper? Email the same address — every request joins the free wallpaper list with your name on it.

        Videos loop, muted by default — turn sound on via Mute/Volume.
        """
        alert.runModal()
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}
