import SwiftUI

// MARK: - Animated Rain Overlay
struct RainOverlayView: View {
    let condition: WeatherCondition?

    private var isRain: Bool {
        guard let c = condition else { return false }
        return [51,53,55,61,63,65,80,81,82,95,96,99].contains(c.code)
    }

    private var isHeavy: Bool {
        guard let c = condition else { return false }
        return [65,80,81,82,95,96,99].contains(c.code)
    }

    private var isStorm: Bool {
        guard let c = condition else { return false }
        return [95,96,99].contains(c.code)
    }

    var body: some View {
        if isRain {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    drawRain(ctx: ctx, size: size, time: t,
                             heavy: isHeavy, storm: isStorm)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // MARK: - Draw
    private func drawRain(ctx: GraphicsContext, size: CGSize,
                          time: Double, heavy: Bool, storm: Bool) {
        let dropCount  = storm ? 200 : heavy ? 140 : 70
        let speed      = storm ? 1.8  : heavy ? 1.4  : 0.9   // full-screen per second
        let lenBase    = storm ? 28.0 : heavy ? 20.0 : 12.0
        let slant      = storm ? -14.0 : heavy ? -9.0 : -5.0
        let alpha      = storm ? 0.55  : heavy ? 0.45 : 0.32
        let lineW      = storm ? 1.6   : heavy ? 1.2  : 0.85

        // seeded positions so drops stay consistent per-frame
        var rng: UInt64 = 0xDEADBEEF

        func next() -> Double {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            return Double(rng >> 11) / Double(1 << 53)
        }

        for _ in 0..<dropCount {
            let xFrac   = next()           // 0..1 horizontal position
            let yOffset = next()           // stagger start position
            let speedVar = next() * 0.4 + 0.8   // ±20% speed variation
            let lenVar   = next() * 0.5 + 0.75  // length variation

            let w = size.width
            let h = size.height

            // y position scrolls with time, wraps around
            let rawY = (yOffset + time * speed * speedVar).truncatingRemainder(dividingBy: 1.0)
            let y    = rawY * (h + lenBase) - lenBase

            let x    = xFrac * (w - 20) + 10

            let len  = lenBase * lenVar
            let from = CGPoint(x: x,            y: y)
            let to   = CGPoint(x: x + slant,    y: y + len)

            var path = Path()
            path.move(to: from)
            path.addLine(to: to)

            ctx.stroke(path,
                       with: .color(.init(red: 0.72, green: 0.86, blue: 0.98,
                                          opacity: alpha * lenVar)),
                       style: StrokeStyle(lineWidth: lineW,
                                          lineCap: .round))
        }

        // Drizzle mist layer (light rain only)
        if !heavy {
            let mistAlpha = 0.06 + 0.04 * sin(time * 0.8)
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(.init(white: 0.85, opacity: mistAlpha)))
        }
    }
}
