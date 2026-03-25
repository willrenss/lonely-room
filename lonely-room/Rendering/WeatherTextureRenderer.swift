import UIKit
import SwiftUI

// MARK: - Weather Texture Renderer
struct WeatherTextureRenderer {

    static func draw(condition: WeatherCondition, size: CGSize, timeOfDay: TimeOfDay = .day) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let r   = ctx.cgContext
            let w   = size.width
            let h   = size.height
            let code   = condition.code
            let isDay  = condition.isDay
            let isRain = [51,53,55,61,63,65,80,81,82,95,96,99].contains(code)
            let isHeavyRain = [65,80,81,82,95,96,99].contains(code)
            let isStorm = [95,96,99].contains(code)
            let isFog   = [45,48].contains(code)
            let isSnow  = [71,73,75,77].contains(code)
            let horizonY = h * 0.58   // where sky meets ground

            // ── 1. SKY GRADIENT ──────────────────────────────────────────
            let skyTop: UIColor
            let skyBot: UIColor
            if !isDay || timeOfDay == .night {
                skyTop = UIColor(red:0.02, green:0.03, blue:0.12, alpha:1)
                skyBot = UIColor(red:0.06, green:0.08, blue:0.22, alpha:1)
            } else if timeOfDay == .dusk {
                skyTop = UIColor(red:0.55, green:0.20, blue:0.30, alpha:1)
                skyBot = UIColor(red:0.98, green:0.62, blue:0.22, alpha:1)
            } else if isStorm {
                skyTop = UIColor(red:0.10, green:0.11, blue:0.16, alpha:1)
                skyBot = UIColor(red:0.22, green:0.23, blue:0.30, alpha:1)
            } else if isHeavyRain {
                skyTop = UIColor(red:0.22, green:0.28, blue:0.38, alpha:1)
                skyBot = UIColor(red:0.35, green:0.42, blue:0.52, alpha:1)
            } else if isRain {
                skyTop = UIColor(red:0.30, green:0.38, blue:0.52, alpha:1)
                skyBot = UIColor(red:0.48, green:0.55, blue:0.66, alpha:1)
            } else if isFog {
                skyTop = UIColor(red:0.72, green:0.73, blue:0.75, alpha:1)
                skyBot = UIColor(red:0.86, green:0.87, blue:0.88, alpha:1)
            } else if code == 3 {
                skyTop = UIColor(red:0.42, green:0.45, blue:0.52, alpha:1)
                skyBot = UIColor(red:0.62, green:0.64, blue:0.68, alpha:1)
            } else if code == 2 {
                skyTop = UIColor(red:0.32, green:0.58, blue:0.90, alpha:1)
                skyBot = UIColor(red:0.62, green:0.82, blue:0.98, alpha:1)
            } else {
                // clear
                skyTop = UIColor(red:0.18, green:0.52, blue:0.95, alpha:1)
                skyBot = UIColor(red:0.50, green:0.80, blue:1.00, alpha:1)
            }
            drawGradient(r, from: skyTop, to: skyBot,
                         start: CGPoint(x:w/2,y:0), end: CGPoint(x:w/2,y:horizonY))

            // ── 2. CELESTIAL BODIES ───────────────────────────────────────
            if isDay && timeOfDay == .day && code <= 2 {
                // Sun
                let sx = w * 0.78, sy = h * 0.18, sr: CGFloat = code == 0 ? 28 : 22
                drawGlow(r, cx: sx, cy: sy, radius: sr * 2.5,
                         color: UIColor(red:1, green:0.95, blue:0.60, alpha:0.5))
                r.setFillColor(UIColor(red:1.0, green:0.96, blue:0.65, alpha:1).cgColor)
                r.fillEllipse(in: CGRect(x:sx-sr, y:sy-sr, width:sr*2, height:sr*2))
            } else if timeOfDay == .dusk && code <= 2 {
                // Sunset sun near horizon
                let sx = w*0.60, sy = horizonY - 18, sr: CGFloat = 24
                drawGlow(r, cx:sx, cy:sy, radius:sr*3,
                         color:UIColor(red:1,green:0.45,blue:0.10,alpha:0.65))
                r.setFillColor(UIColor(red:1.0, green:0.55, blue:0.12, alpha:1).cgColor)
                r.fillEllipse(in: CGRect(x:sx-sr, y:sy-sr, width:sr*2, height:sr*2))
            } else if !isDay {
                // Stars — only visible on clear/partly cloudy nights
                if code <= 2 {
                    var rng: UInt64 = 777
                    func srand() -> CGFloat {
                        rng = rng &* 6364136223846793005 &+ 1442695040888963407
                        return CGFloat(rng >> 33) / CGFloat(1 << 31)
                    }
                    for _ in 0..<60 {
                        let sx = srand() * w
                        let sy = srand() * horizonY * 0.85
                        let sr = srand() * 1.5 + 0.5
                        let alpha = srand() * 0.5 + 0.4
                        r.setFillColor(UIColor(white:1, alpha:alpha).cgColor)
                        r.fillEllipse(in: CGRect(x:sx-sr,y:sy-sr,width:sr*2,height:sr*2))
                    }
                }

                // Moon — always visible at night, dimmer behind clouds
                let moonAlpha: CGFloat = isStorm ? 0.10 : isHeavyRain ? 0.18 : isRain ? 0.28 : code == 3 ? 0.40 : 1.0
                let moonGlowAlpha: CGFloat = isStorm ? 0.0 : isHeavyRain ? 0.05 : isRain ? 0.08 : code == 3 ? 0.12 : 0.22
                let mx = w*0.72, my = h*0.16, mr: CGFloat = 20

                // Glow behind moon
                drawGlow(r, cx:mx, cy:my, radius:mr*3,
                         color:UIColor(white:0.9, alpha:moonGlowAlpha))

                // Moon body
                r.setFillColor(UIColor(red:0.96,green:0.96,blue:0.86,alpha:moonAlpha).cgColor)
                r.fillEllipse(in: CGRect(x:mx-mr,y:my-mr,width:mr*2,height:mr*2))

                // Crescent shadow (only when visible)
                if moonAlpha > 0.3 {
                    r.setFillColor(UIColor(red:0.03,green:0.04,blue:0.14,alpha:moonAlpha).cgColor)
                    r.fillEllipse(in: CGRect(x:mx-mr+9,y:my-mr-5,width:mr*2,height:mr*2))
                }
            }

            // ── 3. CLOUDS ─────────────────────────────────────────────────
            let cloudAlpha: CGFloat = isStorm ? 0.88 : isHeavyRain ? 0.82 : isRain ? 0.75 : code==3 ? 0.78 : 0.60
            let cloudColor = isStorm
                ? UIColor(red:0.25, green:0.26, blue:0.30, alpha:cloudAlpha)
                : isRain || code==3
                    ? UIColor(red:0.58, green:0.60, blue:0.64, alpha:cloudAlpha)
                    : UIColor(white:1, alpha:cloudAlpha)

            switch code {
            case 0:
                if isDay {
                    drawCloud(r, cx:w*0.15, cy:h*0.22, rx:55, ry:22, color:UIColor(white:1,alpha:0.55))
                }
            case 1:
                drawCloud(r, cx:w*0.18, cy:h*0.20, rx:70, ry:26, color:UIColor(white:1,alpha:0.72))
                drawCloud(r, cx:w*0.68, cy:h*0.28, rx:55, ry:20, color:UIColor(white:1,alpha:0.55))
            case 2:
                drawCloud(r, cx:w*0.12, cy:h*0.18, rx:80, ry:30, color:UIColor(white:1,alpha:0.82))
                drawCloud(r, cx:w*0.52, cy:h*0.14, rx:75, ry:28, color:UIColor(white:1,alpha:0.78))
                drawCloud(r, cx:w*0.82, cy:h*0.24, rx:60, ry:22, color:UIColor(white:1,alpha:0.65))
            case 3, 45, 48:
                drawCloud(r, cx:w*0.10, cy:h*0.12, rx:110, ry:42, color:cloudColor)
                drawCloud(r, cx:w*0.48, cy:h*0.08, rx:120, ry:46, color:cloudColor)
                drawCloud(r, cx:w*0.85, cy:h*0.15, rx:100, ry:38, color:cloudColor)
            case 51,53,55,61,63,65,80,81,82:
                drawCloud(r, cx:w*0.08, cy:h*0.10, rx:120, ry:44, color:cloudColor)
                drawCloud(r, cx:w*0.45, cy:h*0.06, rx:130, ry:50, color:cloudColor)
                drawCloud(r, cx:w*0.82, cy:h*0.12, rx:110, ry:42, color:cloudColor)
            case 95,96,99:
                // full stormy overcast
                r.setFillColor(UIColor(red:0.15,green:0.16,blue:0.20,alpha:0.92).cgColor)
                r.fill(CGRect(x:0,y:0,width:w,height:horizonY*0.7))
                drawCloud(r, cx:w*0.05, cy:h*0.08, rx:140, ry:55, color:cloudColor)
                drawCloud(r, cx:w*0.50, cy:h*0.04, rx:160, ry:62, color:cloudColor)
                drawCloud(r, cx:w*0.88, cy:h*0.10, rx:130, ry:50, color:cloudColor)
            default:
                drawCloud(r, cx:w*0.20, cy:h*0.20, rx:65, ry:24, color:UIColor(white:1,alpha:0.65))
            }

            // ── 4. GROUND BASE ────────────────────────────────────────────
            // Sky-to-ground blend strip
            let blendH = h * 0.06
            drawGradient(r,
                from: skyBot.withAlphaComponent(0),
                to:   skyBot.withAlphaComponent(0.5),
                start: CGPoint(x:w/2, y:horizonY - blendH),
                end:   CGPoint(x:w/2, y:horizonY))

            // Ground / grass base
            let grassFar: UIColor
            let grassNear: UIColor
            if !isDay || timeOfDay == .night {
                grassFar  = UIColor(red:0.04, green:0.08, blue:0.04, alpha:1)
                grassNear = UIColor(red:0.07, green:0.12, blue:0.06, alpha:1)
            } else if timeOfDay == .dusk {
                grassFar  = UIColor(red:0.20, green:0.14, blue:0.06, alpha:1)
                grassNear = UIColor(red:0.32, green:0.22, blue:0.08, alpha:1)
            } else if isStorm || isHeavyRain {
                grassFar  = UIColor(red:0.10, green:0.16, blue:0.10, alpha:1)
                grassNear = UIColor(red:0.14, green:0.22, blue:0.13, alpha:1)
            } else {
                grassFar  = UIColor(red:0.22, green:0.42, blue:0.16, alpha:1)
                grassNear = UIColor(red:0.30, green:0.55, blue:0.20, alpha:1)
            }
            drawGradient(r, from: grassFar, to: grassNear,
                         start: CGPoint(x:w/2, y:horizonY),
                         end:   CGPoint(x:w/2, y:h))

            // Road / path
            let roadY = horizonY + (h - horizonY) * 0.30
            let roadColor = isStorm
                ? UIColor(red:0.18,green:0.18,blue:0.20,alpha:1)
                : UIColor(red:0.30,green:0.30,blue:0.32,alpha:1)
            var roadPath = Path()
            // perspective trapezoid
            let roadMidW: CGFloat = w * 0.12
            let roadBotW: CGFloat = w * 0.55
            roadPath.move(to:    CGPoint(x: w/2 - roadMidW, y: roadY))
            roadPath.addLine(to: CGPoint(x: w/2 + roadMidW, y: roadY))
            roadPath.addLine(to: CGPoint(x: w/2 + roadBotW/2, y: h))
            roadPath.addLine(to: CGPoint(x: w/2 - roadBotW/2, y: h))
            roadPath.closeSubpath()
            r.setFillColor(roadColor.cgColor)
            r.addPath(roadPath.cgPath)
            r.fillPath()

            // Road center dashes
            let dashColor = UIColor(white:0.85, alpha: isStorm ? 0.3 : 0.6)
            r.setStrokeColor(dashColor.cgColor)
            r.setLineWidth(2)
            r.setLineDash(phase: 0, lengths: [12, 10])
            r.move(to: CGPoint(x:w/2, y:roadY + 4))
            r.addLine(to: CGPoint(x:w/2, y:h))
            r.strokePath()
            r.setLineDash(phase: 0, lengths: [])

            // ── 5. TREES ──────────────────────────────────────────────────
            // tree data: (x fraction, horizon fraction, scale, variant)
            // variant 0 = round tropical, 1 = tall palm, 2 = bushy
            let treeDefs: [(CGFloat, CGFloat, CGFloat, Int)] = [
                (0.04, 0.00, 0.55, 2),
                (0.10, 0.02, 0.65, 0),
                (0.20, 0.04, 0.80, 1),
                (0.28, 0.00, 0.60, 2),
                (0.38, 0.05, 0.90, 0),
                (0.62, 0.05, 0.88, 0),
                (0.72, 0.00, 0.62, 2),
                (0.80, 0.03, 0.82, 1),
                (0.90, 0.01, 0.68, 0),
                (0.96, 0.00, 0.58, 2),
            ]
            for (xf, yOff, scale, variant) in treeDefs {
                let tx = xf * w
                let ty = horizonY + yOff * h
                drawTree(r, x:tx, groundY:ty, scale:scale, variant:variant,
                         isDay:isDay, timeOfDay:timeOfDay, isRain:isRain, isStorm:isStorm)
            }

            // ── 6. FOREGROUND GRASS TUFTS ─────────────────────────────────
            let tuftColor = !isDay || timeOfDay == .night
                ? UIColor(red:0.05,green:0.10,blue:0.05,alpha:1)
                : timeOfDay == .dusk
                    ? UIColor(red:0.25,green:0.18,blue:0.05,alpha:1)
                    : UIColor(red:0.18,green:0.48,blue:0.12,alpha:1)
            var tx2: CGFloat = 0
            while tx2 < w {
                let th = CGFloat.random(in: 8...18)
                let tw: CGFloat = 6
                let ty2 = h - CGFloat.random(in: 0...20)
                var tuft = Path()
                tuft.move(to: CGPoint(x:tx2, y:ty2))
                tuft.addQuadCurve(to: CGPoint(x:tx2+tw/2, y:ty2-th),
                                  control: CGPoint(x:tx2-tw*0.3, y:ty2-th*0.7))
                tuft.addQuadCurve(to: CGPoint(x:tx2+tw, y:ty2),
                                  control: CGPoint(x:tx2+tw*1.3, y:ty2-th*0.7))
                r.setFillColor(tuftColor.cgColor)
                r.addPath(tuft.cgPath); r.fillPath()
                tx2 += CGFloat.random(in: 10...28)
            }

            // ── 7. WEATHER EFFECTS ────────────────────────────────────────

            // Fog overlay
            if isFog {
                let fogGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                    UIColor(white:0.88,alpha:0).cgColor,
                    UIColor(white:0.88,alpha:0.70).cgColor
                ] as CFArray, locations:[0,1])!
                r.drawLinearGradient(fogGrad,
                    start: CGPoint(x:w/2, y:horizonY*0.5),
                    end:   CGPoint(x:w/2, y:h), options:[])
            }

            // Rain drops
            if isRain || isStorm {
                let heavy = isHeavyRain
                let dropCount = isStorm ? 120 : heavy ? 90 : 45
                var rng: UInt64 = 54321
                func rd() -> CGFloat {
                    rng = rng &* 6364136223846793005 &+ 1442695040888963407
                    return CGFloat(rng >> 33) / CGFloat(1 << 31)
                }
                let dropAlpha: CGFloat = heavy ? 0.75 : 0.55
                r.setStrokeColor(UIColor(red:0.72,green:0.84,blue:0.96,alpha:dropAlpha).cgColor)
                for _ in 0..<dropCount {
                    let dx = rd() * w
                    let dy = rd() * h
                    let len: CGFloat = heavy ? CGFloat.random(in:14...22) : CGFloat.random(in:8...14)
                    let slant: CGFloat = heavy ? -5 : -3
                    r.setLineWidth(heavy ? CGFloat.random(in:1.0...1.8) : CGFloat.random(in:0.7...1.2))
                    r.move(to:    CGPoint(x:dx,       y:dy))
                    r.addLine(to: CGPoint(x:dx+slant, y:dy+len))
                    r.strokePath()
                }

                // Puddle reflections on road
                if heavy {
                    r.setFillColor(UIColor(red:0.55,green:0.70,blue:0.88,alpha:0.30).cgColor)
                    for _ in 0..<8 {
                        let px = (w/2 - roadBotW/4) + rd() * (roadBotW/2)
                        let py = roadY + rd() * (h - roadY)
                        let pr = rd() * 12 + 4
                        r.fillEllipse(in: CGRect(x:px-pr,y:py-pr*0.3,width:pr*2,height:pr*0.6))
                    }
                }
            }

            // Snow
            if isSnow {
                var rng: UInt64 = 11223
                func sd() -> CGFloat {
                    rng = rng &* 6364136223846793005 &+ 1442695040888963407
                    return CGFloat(rng >> 33) / CGFloat(1 << 31)
                }
                r.setFillColor(UIColor(white:1,alpha:0.85).cgColor)
                for _ in 0..<80 {
                    let sx2 = sd() * w, sy2 = sd() * h
                    let sr2 = sd() * 3 + 1.5
                    r.fillEllipse(in: CGRect(x:sx2-sr2,y:sy2-sr2,width:sr2*2,height:sr2*2))
                }
            }

            // Lightning bolt (storm)
            if isStorm {
                let lx = w * 0.42, ly = horizonY * 0.25
                r.setStrokeColor(UIColor(red:1,green:0.97,blue:0.65,alpha:0.95).cgColor)
                r.setLineWidth(2.5)
                r.move(to:    CGPoint(x:lx,      y:ly))
                r.addLine(to: CGPoint(x:lx-10,   y:ly+28))
                r.addLine(to: CGPoint(x:lx-2,    y:ly+28))
                r.addLine(to: CGPoint(x:lx-16,   y:ly+60))
                r.strokePath()
                // glow
                r.setStrokeColor(UIColor(red:1,green:0.97,blue:0.65,alpha:0.25).cgColor)
                r.setLineWidth(7)
                r.move(to:    CGPoint(x:lx,      y:ly))
                r.addLine(to: CGPoint(x:lx-16,   y:ly+60))
                r.strokePath()
            }

            // ── 8. VIGNETTE ───────────────────────────────────────────────
            let vigGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                UIColor.black.withAlphaComponent(0).cgColor,
                UIColor.black.withAlphaComponent(0.28).cgColor
            ] as CFArray, locations:[0,1])!
            r.drawRadialGradient(vigGrad,
                startCenter: CGPoint(x:w/2,y:h/2), startRadius: 0,
                endCenter:   CGPoint(x:w/2,y:h/2), endRadius:   max(w,h)*0.75,
                options: [.drawsAfterEndLocation])
        }
    }

    // MARK: - Helpers

    private static func drawGradient(_ r: CGContext,
                                     from: UIColor, to: UIColor,
                                     start: CGPoint, end: CGPoint) {
        guard let grad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [from.cgColor, to.cgColor] as CFArray,
            locations: [0, 1]) else { return }
        r.drawLinearGradient(grad, start: start, end: end, options: [])
    }

    private static func drawGlow(_ r: CGContext, cx: CGFloat, cy: CGFloat,
                                  radius: CGFloat, color: UIColor) {
        guard let grad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray,
            locations: [0,1]) else { return }
        r.drawRadialGradient(grad,
            startCenter: CGPoint(x:cx,y:cy), startRadius: 0,
            endCenter:   CGPoint(x:cx,y:cy), endRadius: radius, options:[])
    }

    private static func drawCloud(_ r: CGContext,
                                   cx: CGFloat, cy: CGFloat,
                                   rx: CGFloat, ry: CGFloat,
                                   color: UIColor) {
        let puffs: [(CGFloat,CGFloat,CGFloat,CGFloat)] = [
            (0,    0,    rx,      ry),
            (-rx*0.55, ry*0.2, rx*0.72, ry*0.82),
            ( rx*0.55, ry*0.2, rx*0.68, ry*0.78),
            (-rx*0.25,-ry*0.35, rx*0.60, ry*0.72),
            ( rx*0.25,-ry*0.30, rx*0.58, ry*0.70),
        ]
        r.setFillColor(color.cgColor)
        for (ox,oy,prx,pry) in puffs {
            r.fillEllipse(in: CGRect(x:cx+ox-prx, y:cy+oy-pry, width:prx*2, height:pry*2))
        }
    }

    private static func drawTree(_ r: CGContext,
                                  x: CGFloat, groundY: CGFloat, scale: CGFloat,
                                  variant: Int, isDay: Bool, timeOfDay: TimeOfDay,
                                  isRain: Bool, isStorm: Bool) {
        let trunkH = 38 * scale
        let trunkW = 7  * scale

        // Trunk color
        let trunkColor = !isDay || timeOfDay == .night
            ? UIColor(red:0.10,green:0.07,blue:0.04,alpha:1)
            : UIColor(red:0.38,green:0.24,blue:0.10,alpha:1)

        // Foliage color
        let leafColor: UIColor
        if !isDay || timeOfDay == .night {
            leafColor = UIColor(red:0.04,green:0.10,blue:0.04,alpha:1)
        } else if timeOfDay == .dusk {
            leafColor = UIColor(red:0.20,green:0.22,blue:0.08,alpha:1)
        } else if isStorm {
            leafColor = UIColor(red:0.10,green:0.20,blue:0.10,alpha:1)
        } else if isRain {
            leafColor = UIColor(red:0.12,green:0.28,blue:0.12,alpha:1)
        } else {
            leafColor = UIColor(red:0.15,green:0.42,blue:0.14,alpha:1)
        }
        let leafHighlight = leafColor.withAlphaComponent(0.6)

        r.setFillColor(trunkColor.cgColor)

        if variant == 1 {
            // ── Palm tree: curved trunk ──
            var path = Path()
            path.move(to:    CGPoint(x:x,          y:groundY))
            path.addCurve(to:CGPoint(x:x + 18*scale, y:groundY - trunkH),
                          control1: CGPoint(x:x + 5*scale,  y:groundY - trunkH*0.5),
                          control2: CGPoint(x:x + 20*scale, y:groundY - trunkH*0.7))
            path.addLine(to: CGPoint(x:x + 18*scale + trunkW*0.6, y:groundY - trunkH))
            path.addCurve(to:CGPoint(x:x + trunkW, y:groundY),
                          control1: CGPoint(x:x + 22*scale, y:groundY - trunkH*0.6),
                          control2: CGPoint(x:x + trunkW,   y:groundY - trunkH*0.4))
            r.addPath(path.cgPath); r.fillPath()

            // Palm fronds
            let topX = x + 18*scale, topY = groundY - trunkH
            let fronds: [(CGFloat,CGFloat)] = [
                (-55,-20),(-35,-38),(-10,-48),(15,-45),(38,-30),(50,-12),(30,5),(-5,8)
            ]
            r.setStrokeColor(leafColor.cgColor)
            r.setLineWidth(4*scale)
            for (fx,fy) in fronds {
                r.move(to: CGPoint(x:topX, y:topY))
                r.addQuadCurve(to: CGPoint(x:topX+fx*scale, y:topY+fy*scale),
                               control: CGPoint(x:topX+fx*scale*0.4, y:topY+fy*scale*1.2))
                r.strokePath()
            }
            // frond tips fill
            r.setFillColor(leafColor.cgColor)
            for (fx,fy) in fronds {
                let tipX = topX + fx*scale, tipY = topY + fy*scale
                r.fillEllipse(in: CGRect(x:tipX-5*scale,y:tipY-4*scale,
                                         width:10*scale,height:8*scale))
            }

        } else {
            // ── Round / bushy tree ──
            // trunk
            r.fill(CGRect(x:x - trunkW/2, y:groundY - trunkH,
                          width:trunkW, height:trunkH))

            let topY = groundY - trunkH
            if variant == 0 {
                // Round tropical canopy — layered ellipses
                let cr = 34 * scale
                r.setFillColor(leafColor.cgColor)
                r.fillEllipse(in: CGRect(x:x-cr, y:topY-cr*1.1, width:cr*2, height:cr*1.6))
                // highlight layer
                r.setFillColor(leafHighlight.cgColor)
                r.fillEllipse(in: CGRect(x:x-cr*0.55, y:topY-cr*1.05,
                                         width:cr*1.1, height:cr*0.9))
            } else {
                // Bushy: multiple overlapping blobs
                let br = 22 * scale
                r.setFillColor(leafColor.cgColor)
                let blobs: [(CGFloat,CGFloat,CGFloat,CGFloat)] = [
                    (0,   -br*1.2, br*1.2, br),
                    (-br*0.7, -br*0.7, br, br*0.9),
                    ( br*0.7, -br*0.7, br, br*0.9),
                    (-br*0.4, -br*1.8, br*0.9, br*0.85),
                    ( br*0.4, -br*1.8, br*0.9, br*0.85),
                ]
                for (bx,by,brx,bry) in blobs {
                    r.fillEllipse(in: CGRect(x:x+bx-brx, y:topY+by, width:brx*2, height:bry*1.6))
                }
            }
        }
    }
}

// MARK: - Path helper (CGContext quad curve)
private extension CGContext {
    func addQuadCurve(to end: CGPoint, control: CGPoint) {
        let cp1 = CGPoint(x: currentPointOfPath.x + (control.x - currentPointOfPath.x)*2/3,
                          y: currentPointOfPath.y + (control.y - currentPointOfPath.y)*2/3)
        let cp2 = CGPoint(x: end.x + (control.x - end.x)*2/3,
                          y: end.y  + (control.y - end.y)*2/3)
        addCurve(to: end, control1: cp1, control2: cp2)
    }
}
