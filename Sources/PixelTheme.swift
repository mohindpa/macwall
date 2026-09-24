import SwiftUI

/// A dashboard theme: palette + animated pixel scene.
struct PixelTheme {
    enum Scene {
        case house        // cottage with glowing windows + drifting clouds (matches the lofi video)
        case halloween    // cottage + pumpkins + purple sky
        case forest       // pine silhouettes + fireflies
        case vaporwave    // retro sun + perspective grid
        case terminal     // falling pixel rain + blinking cursor
        case none         // calm, no animated scene
    }

    let key: String
    let name: String
    let scene: Scene
    let accent: Color
    let accentSecondary: Color
    let bg: Color
    let panel: Color
    let card: Color
    let cardHover: Color
    let stroke: Color
    let text: Color
    let dim: Color
    let skyTop: Color
    let skyBottom: Color
    let ground: Color
    let cloud: Color
    let glow: Color
    let scrim: Double

    static let all: [PixelTheme] = [lime, halloween, vaporwave, forest, terminal, classic]

    static func theme(for key: String) -> PixelTheme {
        all.first { $0.key == key } ?? lime
    }

    // MARK: - The themes

    static let lime = PixelTheme(
        key: "lime", name: "Lime Pixel", scene: .house,
        accent: Color(red: 0.78, green: 0.95, blue: 0.31),
        accentSecondary: Color(red: 0.49, green: 0.91, blue: 0.36),
        bg: Color(red: 0.043, green: 0.047, blue: 0.055),
        panel: Color(red: 0.063, green: 0.070, blue: 0.082),
        card: Color(red: 0.090, green: 0.102, blue: 0.122),
        cardHover: Color(red: 0.114, green: 0.129, blue: 0.153),
        stroke: Color.white.opacity(0.08),
        text: Color(white: 0.95),
        dim: Color(white: 0.60),
        skyTop: Color(red: 0.035, green: 0.047, blue: 0.090),
        skyBottom: Color(red: 0.078, green: 0.102, blue: 0.196),
        ground: Color(red: 0.039, green: 0.055, blue: 0.078),
        cloud: Color(red: 0.110, green: 0.145, blue: 0.235),
        glow: Color(red: 1.00, green: 0.82, blue: 0.49),
        scrim: 0.12
    )

    static let halloween = PixelTheme(
        key: "halloween", name: "Halloween", scene: .halloween,
        accent: Color(red: 1.00, green: 0.62, blue: 0.24),
        accentSecondary: Color(red: 0.61, green: 0.36, blue: 0.90),
        bg: Color(red: 0.075, green: 0.045, blue: 0.106),
        panel: Color(red: 0.106, green: 0.063, blue: 0.149),
        card: Color(red: 0.141, green: 0.082, blue: 0.200),
        cardHover: Color(red: 0.176, green: 0.106, blue: 0.247),
        stroke: Color.white.opacity(0.10),
        text: Color(red: 0.97, green: 0.94, blue: 0.99),
        dim: Color(red: 0.66, green: 0.58, blue: 0.74),
        skyTop: Color(red: 0.086, green: 0.043, blue: 0.149),
        skyBottom: Color(red: 0.184, green: 0.082, blue: 0.271),
        ground: Color(red: 0.075, green: 0.039, blue: 0.102),
        cloud: Color(red: 0.208, green: 0.118, blue: 0.310),
        glow: Color(red: 1.00, green: 0.70, blue: 0.28),
        scrim: 0.10
    )

    static let vaporwave = PixelTheme(
        key: "vaporwave", name: "Vaporwave", scene: .vaporwave,
        accent: Color(red: 1.00, green: 0.36, blue: 0.78),
        accentSecondary: Color(red: 0.31, green: 0.91, blue: 0.88),
        bg: Color(red: 0.090, green: 0.039, blue: 0.180),
        panel: Color(red: 0.118, green: 0.055, blue: 0.227),
        card: Color(red: 0.153, green: 0.075, blue: 0.278),
        cardHover: Color(red: 0.192, green: 0.098, blue: 0.333),
        stroke: Color.white.opacity(0.10),
        text: Color(red: 0.98, green: 0.95, blue: 1.00),
        dim: Color(red: 0.68, green: 0.60, blue: 0.80),
        skyTop: Color(red: 0.106, green: 0.043, blue: 0.200),
        skyBottom: Color(red: 0.227, green: 0.071, blue: 0.400),
        ground: Color(red: 0.071, green: 0.027, blue: 0.122),
        cloud: Color(red: 0.208, green: 0.098, blue: 0.400),
        glow: Color(red: 1.00, green: 0.85, blue: 0.96),
        scrim: 0.10
    )

    static let forest = PixelTheme(
        key: "forest", name: "Forest", scene: .forest,
        accent: Color(red: 0.43, green: 0.91, blue: 0.53),
        accentSecondary: Color(red: 0.64, green: 0.90, blue: 0.21),
        bg: Color(red: 0.031, green: 0.071, blue: 0.047),
        panel: Color(red: 0.051, green: 0.102, blue: 0.071),
        card: Color(red: 0.071, green: 0.149, blue: 0.102),
        cardHover: Color(red: 0.094, green: 0.188, blue: 0.129),
        stroke: Color.white.opacity(0.09),
        text: Color(red: 0.93, green: 0.98, blue: 0.94),
        dim: Color(red: 0.58, green: 0.70, blue: 0.61),
        skyTop: Color(red: 0.024, green: 0.075, blue: 0.055),
        skyBottom: Color(red: 0.055, green: 0.165, blue: 0.114),
        ground: Color(red: 0.024, green: 0.059, blue: 0.035),
        cloud: Color(red: 0.086, green: 0.208, blue: 0.122),
        glow: Color(red: 0.72, green: 1.00, blue: 0.62),
        scrim: 0.10
    )

    static let terminal = PixelTheme(
        key: "terminal", name: "Terminal", scene: .terminal,
        accent: Color(red: 0.24, green: 1.00, blue: 0.48),
        accentSecondary: Color(red: 0.61, green: 1.00, blue: 0.75),
        bg: Color(red: 0.016, green: 0.043, blue: 0.024),
        panel: Color(red: 0.027, green: 0.063, blue: 0.035),
        card: Color(red: 0.039, green: 0.086, blue: 0.051),
        cardHover: Color(red: 0.055, green: 0.114, blue: 0.067),
        stroke: Color(red: 0.24, green: 1.00, blue: 0.48).opacity(0.18),
        text: Color(red: 0.80, green: 1.00, blue: 0.86),
        dim: Color(red: 0.42, green: 0.65, blue: 0.48),
        skyTop: Color(red: 0.012, green: 0.031, blue: 0.016),
        skyBottom: Color(red: 0.024, green: 0.075, blue: 0.039),
        ground: Color(red: 0.008, green: 0.020, blue: 0.010),
        cloud: Color(red: 0.047, green: 0.122, blue: 0.071),
        glow: Color(red: 0.24, green: 1.00, blue: 0.48),
        scrim: 0.14
    )

    static let classic = PixelTheme(
        key: "classic", name: "Classic", scene: .none,
        accent: Color(red: 0.78, green: 0.95, blue: 0.31),
        accentSecondary: Color(white: 0.60),
        bg: Color(red: 0.055, green: 0.063, blue: 0.075),
        panel: Color(red: 0.078, green: 0.090, blue: 0.106),
        card: Color(red: 0.106, green: 0.121, blue: 0.145),
        cardHover: Color(red: 0.133, green: 0.152, blue: 0.180),
        stroke: Color.white.opacity(0.07),
        text: Color(white: 0.95),
        dim: Color(white: 0.60),
        skyTop: Color(red: 0.055, green: 0.063, blue: 0.075),
        skyBottom: Color(red: 0.078, green: 0.090, blue: 0.106),
        ground: Color(red: 0.055, green: 0.063, blue: 0.075),
        cloud: Color(white: 0.2),
        glow: Color(red: 0.78, green: 0.95, blue: 0.31),
        scrim: 0.0
    )
}

/// The pixel font (bundled Press Start 2P, OFL). Falls back to the system
/// font automatically if the .ttf is missing from the app bundle.
func pixelFont(_ size: CGFloat) -> Font {
    .custom("Press Start 2P", size: size)
}
