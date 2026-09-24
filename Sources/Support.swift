import AppKit

// Support & community links — everything editable lives in this one file.
enum Support {
    /// PayPal donate
    static let paypalEmail = "mohindpa@protonmail.com"
    static let donateURL = URL(string: "https://www.paypal.com/donate/?business=mohindpa%40protonmail.com&no_recurring=0&item_name=MacWall")!

    /// Custom wallpaper requests
    static let supportEmail = "mohindpa@protonmail.com"
    static let mailtoURL = URL(string: "mailto:mohindpa@protonmail.com?subject=MacWall%20wallpaper%20request")!

    /// The public wallpaper list (live at macwallmac.vercel.app).
    /// Set at runtime with:  MacWall --wallpaper-list <url>   (or : off)
    /// A runtime value overrides the compiled default below; an explicit
    /// empty string ("off") disables the link even when a default is compiled in.
    static let compiledWallpaperListURL: String? = "https://livewallmac.vercel.app"

    static var wallpaperListURL: URL? {
        if let raw = UserDefaults.standard.string(forKey: "wallpaperListURL") {
            return raw.isEmpty ? nil : URL(string: raw)
        }
        return compiledWallpaperListURL.flatMap(URL.init(string:))
    }

    static func open(_ url: URL) { NSWorkspace.shared.open(url) }
}
