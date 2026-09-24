import AppKit

// One-time settings migration from the pre-rename builds ("LiveWall") must run
// before anything touches VideoLibrary / UserDefaults.
LegacyMigration.run()

let arguments = CommandLine.arguments

func value(for flag: String) -> String? {
    guard let idx = arguments.firstIndex(of: flag), idx + 1 < arguments.count else { return nil }
    return arguments[idx + 1]
}

// ---------------------------------------------------------------------------
// CLI utilities (used from the terminal for setup / verification)
// ---------------------------------------------------------------------------

if arguments.contains("--print-state") {
    let lib = VideoLibrary.shared
    print("My Videos (\(lib.entries.count)):")
    for entry in lib.entries {
        let ok = lib.resolve(entry) != nil
        print("  [\(ok ? "ok" : "MISSING")] \(entry.name)  ->  \(entry.path)")
    }
    print("active: \(lib.activePath ?? "none")")
    print("favorites: \(lib.favoritePaths.count)")
    print("rotation: \(lib.rotationMinutes) min | muted: \(lib.isMuted) | volume: \(lib.volume) | fill: \(lib.fill) | levelOffset: \(lib.levelOffset)")
    exit(0)
}

if let path = value(for: "--set-video") {
    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        FileHandle.standardError.write("no such file: \(url.path)\n".data(using: .utf8)!)
        exit(1)
    }
    let lib = VideoLibrary.shared
    lib.importVideo(url)
    lib.activePath = url.path
    print("active video set: \(url.path)")
    exit(0)
}

if let raw = value(for: "--level-offset"), let n = Int(raw) {
    VideoLibrary.shared.levelOffset = n
    print("levelOffset = \(n)")
    exit(0)
}

if let mode = value(for: "--login") {
    let item = LoginItem()
    switch mode {
    case "on":
        item.enable()
        print("login item: \(item.isEnabled ? "enabled" : "FAILED")")
    case "off":
        item.disable()
        print("login item: \(item.isEnabled ? "FAILED to disable" : "disabled")")
    default:
        print("login item: \(item.isEnabled ? "enabled" : "disabled")")
    }
    exit(0)
}

if let mode = value(for: "--screensaver") {
    let lib = VideoLibrary.shared
    switch mode {
    case "on":
        lib.screensaverEnabled = true
        print("screensaver: on (after \(lib.screensaverMinutes) min)")
    case "off":
        lib.screensaverEnabled = false
        print("screensaver: off")
    case "preview":
        let seconds = value(for: "--seconds").flatMap(Double.init) ?? 8
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.mohind.macwall.screensaver-preview"),
            object: nil,
            userInfo: ["seconds": seconds],
            deliverImmediately: true
        )
        print("preview requested (\(Int(seconds))s)")
    case "status":
        print("screensaver: \(lib.screensaverEnabled ? "on" : "off") after \(lib.screensaverMinutes) min")
    default:
        if let minutes = Int(mode) {
            lib.screensaverMinutes = minutes
            print("screensaver delay: \(minutes) min")
        } else {
            print("usage: --screensaver on|off|status|preview|<minutes>")
        }
    }
    exit(0)
}

if arguments.contains("--about") {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    // Safety net when used for verification: never leave the panel orphaned.
    DispatchQueue.main.asyncAfter(deadline: .now() + 8) { exit(0) }
    AppDelegate.showAboutPanel()
    exit(0)
}

if let theme = value(for: "--theme") {
    let lib = VideoLibrary.shared
    if PixelTheme.all.contains(where: { $0.key == theme }) {
        lib.themeKey = theme
        print("theme: \(theme)")
    } else {
        print("themes: \(PixelTheme.all.map { $0.key }.joined(separator: ", "))")
    }
    exit(0)
}

if let value = value(for: "--saver-video") {
    let lib = VideoLibrary.shared
    if value == "off" || value == "same" {
        lib.screensaverPath = nil
        print("screensaver video: follow wallpaper")
    } else {
        lib.screensaverPath = value
        print("screensaver video: \(value)")
    }
    exit(0)
}

if let value = value(for: "--lock-video") {
    let lib = VideoLibrary.shared
    if value == "off" {
        lib.lockScreenPath = nil
        LockWallpaper.clear(lib: lib)
        print("lock screen: off (original wallpapers restored)")
    } else {
        lib.lockScreenPath = value
        let ok = LockWallpaper.apply(videoPath: value, lib: lib)
        print(ok ? "lock screen: still applied — \(value)" : "lock screen: FAILED to export still — \(value)")
    }
    exit(0)
}

if arguments.contains("--support") {
    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name("com.mohind.macwall.show-support"),
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )
    print("support panel requested")
    exit(0)
}

if let value = value(for: "--wallpaper-list") {
    if value == "off" || value == "none" {
        // Explicit "" (not removeObject) so "off" also beats the compiled default in Support.swift.
        UserDefaults.standard.set("", forKey: "wallpaperListURL")
        print("wallpaper list URL: cleared")
    } else {
        UserDefaults.standard.set(value, forKey: "wallpaperListURL")
        print("wallpaper list URL: \(value)")
    }
    exit(0)
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar only — no Dock icon (LSUIElement in Info.plist sets this at launch; keep it in sync)
let delegate = AppDelegate()
delegate.isLoginLaunch = arguments.contains("--login-launch")
app.delegate = delegate
app.run()
