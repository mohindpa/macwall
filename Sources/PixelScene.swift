import SwiftUI

/// 8 fps ticker for the pixel scenes. Kept separate from DashboardModel so the
/// video cards don't re-render on every frame.
final class PixelClock: ObservableObject {
    static let shared = PixelClock()

    @Published private(set) var tick = 0
    private var timer: Timer?

    private init() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.125, repeats: true) { [weak self] _ in
            self?.tick &+= 1
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}

/// The animated pixel-art backdrop. Drawn on a 6 pt grid so everything stays
/// chunky and snapped to "pixels".
struct PixelSceneView: View {
    @ObservedObject private var clock = PixelClock.shared
    let theme: PixelTheme

    init(theme: PixelTheme) {
        self.theme = theme
    }

    var body: some View {
        Canvas { context, size in
            PixelSceneRenderer.draw(context: context, size: size, theme: theme, tick: clock.tick)
        }
        .allowsHitTesting(false)
    }
}

enum PixelSceneRenderer {
    static let cell: CGFloat = 6

    // MARK: - Entry

    static func draw(context: GraphicsContext, size: CGSize, theme: PixelTheme, tick: Int) {
        if theme.scene == .none {
            drawCalm(context: context, size: size, theme: theme)
            return
        }

        drawSky(context: context, size: size, theme: theme)

        switch theme.scene {
        case .house, .halloween, .forest:
            drawStars(context: context, size: size, theme: theme, tick: tick)
            drawMoon(context: context, size: size, theme: theme)
            drawClouds(context: context, size: size, theme: theme, tick: tick)
        case .vaporwave:
            drawVaporSun(context: context, size: size, theme: theme, tick: tick)
        case .terminal:
            drawRain(context: context, size: size, theme: theme, tick: tick)
        case .none:
            break
        }

        drawGround(context: context, size: size, theme: theme, tick: tick)

        switch theme.scene {
        case .house:
            drawHouse(context: context, size: size, theme: theme, tick: tick, pumpkins: false)
        case .halloween:
            drawHouse(context: context, size: size, theme: theme, tick: tick, pumpkins: true)
        case .forest:
            drawPines(context: context, size: size, theme: theme)
            drawFireflies(context: context, size: size, theme: theme, tick: tick)
        case .vaporwave:
            drawGrid(context: context, size: size, theme: theme, tick: tick)
        case .terminal:
            drawCursor(context: context, size: size, theme: theme, tick: tick)
        case .none:
            break
        }

        drawScanlines(context: context, size: size, theme: theme)

        // Readability scrim over the whole scene.
        if theme.scrim > 0 {
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.black.opacity(theme.scrim)))
        }
    }

    // MARK: - Helpers

    private static func snap(_ value: CGFloat) -> CGFloat {
        (value / cell).rounded() * cell
    }

    private static func fill(_ context: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, _ color: Color) {
        context.fill(Path(CGRect(x: snap(x), y: snap(y), width: max(cell, snap(w)), height: max(cell, snap(h)))), with: .color(color))
    }

    private static func hash(_ n: Int) -> Int {
        var x = (n &* 374761393) &+ 668265263
        x = (x ^ (x >> 13)) &* 1274126177
        return abs(x ^ (x >> 16))
    }

    private static func hashUnit(_ n: Int) -> CGFloat {
        CGFloat(hash(n) % 1000) / 1000.0
    }

    // MARK: - Sky / ground

    private static func drawSky(context: GraphicsContext, size: CGSize, theme: PixelTheme) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(theme.skyTop))
        let bands = 12
        for band in 0..<bands {
            let t = Double(band) / Double(bands - 1)
            let y = size.height * CGFloat(band) / CGFloat(bands)
            context.fill(
                Path(CGRect(x: 0, y: snap(y), width: size.width, height: size.height / CGFloat(bands) + 1)),
                with: .color(theme.skyBottom.opacity(t * 0.9))
            )
        }
    }

    private static func drawGround(context: GraphicsContext, size: CGSize, theme: PixelTheme, tick: Int) {
        let groundY = size.height * 0.62
        context.fill(
            Path(CGRect(x: 0, y: snap(groundY), width: size.width, height: size.height - snap(groundY))),
            with: .color(theme.ground)
        )
        // Speckled texture on the ground (static, deterministic).
        for i in 0..<90 {
            let gx = hashUnit(i * 3 + 11) * size.width
            let gy = snap(groundY) + hashUnit(i * 5 + 17) * (size.height - snap(groundY))
            let twinkle = theme.scene == .terminal ? 0.10 : 0.16
            fill(context, x: gx, y: gy, w: cell, h: cell, theme.text.opacity(twinkle))
        }
    }

    // MARK: - Shared scene parts

    private static func drawStars(context: GraphicsContext, size: CGSize, theme: PixelTheme, tick: Int) {
        for i in 0..<70 {
            let sx = hashUnit(i * 7 + 3) * size.width
            let sy = hashUnit(i * 13 + 5) * size.height * 0.55
            let twinkle = 0.25 + 0.6 * abs(sin(Double(tick) * 0.12 + Double(i) * 0.7))
            fill(context, x: sx, y: sy, w: cell, h: cell, theme.text.opacity(twinkle * 0.7))
        }
    }

    private static func drawMoon(context: GraphicsContext, size: CGSize, theme: PixelTheme) {
        let pattern = [
            ".XXX.",
            "XXXXX",
            "XXXXX",
            "XXXXX",
            ".XXX."
        ]
        let originX = snap(size.width * 0.80)
        let originY = snap(size.height * 0.12)
        for (row, line) in pattern.enumerated() {
            for (col, ch) in line.enumerated() where ch == "X" {
                fill(context,
                     x: originX + CGFloat(col) * cell,
                     y: originY + CGFloat(row) * cell,
                     w: cell, h: cell,
                     theme.text.opacity(0.85))
            }
        }
        // Soft glow ring
        fill(context, x: originX - cell * 2, y: originY - cell, w: cell, h: cell, theme.text.opacity(0.12))
        fill(context, x: originX + cell * 6, y: originY + cell * 2, w: cell, h: cell, theme.text.opacity(0.12))
    }

    private static func drawClouds(context: GraphicsContext, size: CGSize, theme: PixelTheme, tick: Int) {
        let pattern = [
            "...XXXX....",
            ".XXXXXXXX..",
            "XXXXXXXXXXX"
        ]
        let speeds: [Double] = [0.55, 0.9, 0.35]
        let starts: [CGFloat] = [0.05, 0.45, 0.75]
        let rows: [CGFloat] = [0.16, 0.30, 0.10]
        for cloud in 0..<3 {
            let travel = Double(tick) * speeds[cloud] * 0.5
            let width = cell * 11 + size.width * 0.25
            var x = starts[cloud] * size.width + CGFloat(travel)
            x = x.truncatingRemainder(dividingBy: width) - cell * 11
            let y = size.height * rows[cloud]
            for (row, line) in pattern.enumerated() {
                for (col, ch) in line.enumerated() where ch == "X" {
                    fill(context,
                         x: x + CGFloat(col) * cell,
                         y: y + CGFloat(row) * cell,
                         w: cell, h: cell,
                         theme.cloud.opacity(0.85))
                }
            }
        }
    }

    private static func drawScanlines(context: GraphicsContext, size: CGSize, theme: PixelTheme) {
        let rows = Int(size.height / cell) + 1
        for row in stride(from: 0, to: rows, by: 3) {
            context.fill(
                Path(CGRect(x: 0, y: CGFloat(row) * cell, width: size.width, height: cell)),
                with: .color(Color.black.opacity(0.045))
            )
        }
    }

    // MARK: - House scenes

    private static func drawHouse(context: GraphicsContext, size: CGSize, theme: PixelTheme, tick: Int, pumpkins: Bool) {
        let houseWidth = cell * 12
        let originX = size.width * 0.16
        let baseY = size.height * 0.62 - cell * 10

        // Roof: stacked rows widening downwards
        for row in 0..<5 {
            let widthCells = 4 + 2 * row
            let x = originX + CGFloat(12 - widthCells) / 2 * cell
            fill(context, x: x, y: baseY + CGFloat(row) * cell, w: CGFloat(widthCells) * cell, h: cell, theme.bg.opacity(0.95))
        }
        // Body
        fill(context, x: originX, y: baseY + cell * 5, w: houseWidth, h: cell * 5, theme.bg.opacity(0.95))

        // Chimney
        fill(context, x: originX + cell * 8, y: baseY - cell * 2, w: cell * 2, h: cell * 2, theme.bg.opacity(0.95))

        // Window glow (flickers)
        let flickerSteps: [Double] = [0.95, 0.75, 1.0, 0.85]
        let flicker = flickerSteps[(tick / 5) % flickerSteps.count]
        fill(context, x: originX + cell * 2, y: baseY + cell * 6, w: cell * 2, h: cell * 2, theme.glow.opacity(flicker))
        fill(context, x: originX + cell * 8, y: baseY + cell * 6, w: cell * 2, h: cell * 2, theme.glow.opacity(flicker * 0.85))
        // Door (dimmer)
        fill(context, x: originX + cell * 5, y: baseY + cell * 7, w: cell * 2, h: cell * 3, theme.glow.opacity(0.5))

        // Chimney smoke
        let smokeOffset = CGFloat((tick / 3) % 4)
        fill(context, x: originX + cell * 8.5 + smokeOffset, y: baseY - cell * (4 + smokeOffset), w: cell, h: cell, theme.text.opacity(0.18))

        if pumpkins {
            let pumpkinBaseY = size.height * 0.62 - cell * 2
            for i in 0..<2 {
                let px = originX + houseWidth + cell * CGFloat(2 + i * 4)
                let bob = CGFloat(abs(sin(Double(tick) * 0.05 + Double(i)))) 
                fill(context, x: px, y: pumpkinBaseY - bob * 2, w: cell * 3, h: cell * 2, theme.glow.opacity(0.85))
                fill(context, x: px + cell, y: pumpkinBaseY - cell * 1 - bob * 2, w: cell, h: cell, theme.accentSecondary.opacity(0.9))
            }
        }
    }

    // MARK: - Forest scene

    private static func drawPines(context: GraphicsContext, size: CGSize, theme: PixelTheme) {
        let widths = [3, 5, 5, 7, 7, 5, 3]
        let spots: [CGFloat] = [0.08, 0.22, 0.38, 0.55, 0.70, 0.84, 0.93]
        for (index, spot) in spots.enumerated() {
            let baseY = size.height * 0.62 - cell * 2
            let x = size.width * spot
            let height = widths[(index + 2) % widths.count]
            for row in 0..<height {
                let widthCells = max(1, (widths[(index + row) % widths.count] - abs(row - height / 2)) | 1)
                fill(context,
                     x: x - CGFloat(widthCells) / 2 * cell,
                     y: baseY - CGFloat(height - row) * cell,
                     w: CGFloat(widthCells) * cell, h: cell,
                     theme.bg.opacity(0.95))
            }
            fill(context, x: x - cell / 2, y: baseY, w: cell, h: cell * 2, theme.bg.opacity(0.95))
        }
    }

    private static func drawFireflies(context: GraphicsContext, size: CGSize, theme: PixelTheme, tick: Int) {
        for i in 0..<14 {
            let baseX = hashUnit(i * 11 + 3) * size.width
            let baseY = size.height * 0.35 + hashUnit(i * 17 + 9) * size.height * 0.35
            let dx = CGFloat(sin(Double(tick) * 0.06 + Double(i))) * cell * 2
            let dy = CGFloat(cos(Double(tick) * 0.05 + Double(i) * 1.3)) * cell
            let twinkle = 0.2 + 0.8 * abs(sin(Double(tick) * 0.15 + Double(i) * 0.9))
            fill(context, x: baseX + dx, y: baseY + dy, w: cell, h: cell, theme.glow.opacity(twinkle * 0.9))
        }
    }

    // MARK: - Vaporwave scene

    private static func drawVaporSun(context: GraphicsContext, size: CGSize, theme: PixelTheme, tick: Int) {
        let centerX = size.width * 0.5
        let centerY = size.height * 0.30
        let radius: CGFloat = 9
        for dy in -Int(radius)...Int(radius) {
            if (dy + Int(radius)) % 2 != 0 { continue }
            let halfWidth = Int(sqrt(max(0, radius * radius - CGFloat(dy * dy))))
            let x = centerX - CGFloat(halfWidth) * cell
            let w = CGFloat(halfWidth * 2) * cell
            let alpha = 0.35 + 0.55 * (1 - Double(abs(dy)) / Double(radius))
            fill(context, x: x, y: centerY + CGFloat(dy) * cell, w: w, h: cell, theme.accent.opacity(alpha))
        }
        // Sparkle pixels around the sun
        for i in 0..<8 {
            let angle = Double(i) * 0.8 + Double(tick) * 0.02
            fill(context,
                 x: centerX + CGFloat(cos(angle)) * cell * (radius + 3),
                 y: centerY + CGFloat(sin(angle)) * cell * (radius + 2),
                 w: cell, h: cell,
                 theme.accentSecondary.opacity(0.7))
        }
    }

    private static func drawGrid(context: GraphicsContext, size: CGSize, theme: PixelTheme, tick: Int) {
        let horizon = size.height * 0.55
        let below = size.height - horizon
        // Horizontal lines, spacing grows towards the viewer + slow scroll
        let offset = CGFloat((tick / 2) % 14)
        for k in 0..<9 {
            let y = horizon + CGFloat(k * k) * cell * 0.55 + offset
            if y < size.height {
                context.fill(
                    Path(CGRect(x: 0, y: snap(y), width: size.width, height: max(1, cell / 3))),
                    with: .color(theme.accentSecondary.opacity(0.40))
                )
            }
        }
        // Converging vertical lines
        for i in -10...10 {
            for step in 0..<10 {
                let frac = CGFloat(step) / 9
                let y = horizon + frac * frac * below
                let x = size.width / 2 + CGFloat(i) * 26 * (0.12 + frac)
                if x > -cell, x < size.width {
                    context.fill(
                        Path(CGRect(x: snap(x), y: snap(y), width: max(1, cell / 3), height: cell)),
                        with: .color(theme.accentSecondary.opacity(0.30))
                    )
                }
            }
        }
    }

    // MARK: - Terminal scene

    private static func drawRain(context: GraphicsContext, size: CGSize, theme: PixelTheme, tick: Int) {
        let columns = Int(size.width / (cell * 3))
        let rows = Int(size.height / cell) + 14
        for column in 0..<columns {
            let seed = hash(column * 31 + 7)
            let speed = 4 + seed % 7
            let head = (seed / 5 + tick * speed) % rows
            for trail in 0..<8 {
                let row = head - trail
                if row < 0 { continue }
                let alpha = 0.85 * (1 - Double(trail) / 8)
                context.fill(
                    Path(CGRect(x: CGFloat(column) * cell * 3, y: CGFloat(row) * cell, width: cell, height: cell)),
                    with: .color(theme.accent.opacity(alpha * 0.65))
                )
            }
        }
    }

    private static func drawCursor(context: GraphicsContext, size: CGSize, theme: PixelTheme, tick: Int) {
        if (tick / 4) % 2 == 0 {
            fill(context, x: size.width * 0.90, y: size.height * 0.48, w: cell * 2, h: cell, theme.accent.opacity(0.95))
        }
    }

    // MARK: - Calm (Classic)

    private static func drawCalm(context: GraphicsContext, size: CGSize, theme: PixelTheme) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(theme.bg))
        for row in stride(from: 0, to: Int(size.height / cell) + 1, by: 2) {
            for column in stride(from: 0, to: Int(size.width / cell) + 1, by: 2) {
                let seed = hash(row * 131 + column * 17)
                if seed % 7 == 0 {
                    context.fill(
                        Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)),
                        with: .color(Color.white.opacity(0.022))
                    )
                }
            }
        }
    }
}
