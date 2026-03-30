import SwiftUI

// MARK: - Hand POV View
struct HandView: View {
    var isWalking: Bool
    @State private var bobOffset: CGFloat = 0
    @State private var waterDrop1: CGFloat = 0
    @State private var waterDrop2: CGFloat = 0
    @State private var waterDrop3: CGFloat = 0
    @State private var waterOpacity1: Double = 0
    @State private var waterOpacity2: Double = 0
    @State private var waterOpacity3: Double = 0

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let handW = W * 0.07
            let handH = handW * 2.8

            ZStack {
                // Left hand
                SimpleHandShape(isLeft: true)
                    .fill(LinearGradient(
                        colors: [Color(red:0.91,green:0.75,blue:0.61), Color(red:0.70,green:0.55,blue:0.41)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(SimpleHandShape(isLeft: true)
                        .stroke(Color(red:0.50,green:0.36,blue:0.24).opacity(0.5), lineWidth: 1.0))
                    .frame(width: handW, height: handH)
                    .rotationEffect(.degrees(25))
                    .shadow(color: .black.opacity(0.28), radius: 5, x: 3, y: -3)
                    .position(x: handW * 0.55, y: H - handH * 0.18 + bobOffset)

                // ── Right hand holding watering can ──
                let canX = W - handW * 1.8
                let canY = H - handH * 0.5 - bobOffset

                WateringCanView(
                    waterDrop1: waterDrop1,
                    waterDrop2: waterDrop2,
                    waterDrop3: waterDrop3,
                    waterOpacity1: waterOpacity1,
                    waterOpacity2: waterOpacity2,
                    waterOpacity3: waterOpacity3
                )
                .frame(width: handW * 4.5, height: handW * 4.5)
                .rotationEffect(.degrees(-15))
                .shadow(color: .black.opacity(0.3), radius: 6, x: -3, y: 3)
                .position(x: canX, y: canY)

                // Right hand gripping the can handle
                SimpleHandShape(isLeft: false)
                    .fill(LinearGradient(
                        colors: [Color(red:0.91,green:0.75,blue:0.61), Color(red:0.70,green:0.55,blue:0.41)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(SimpleHandShape(isLeft: false)
                        .stroke(Color(red:0.50,green:0.36,blue:0.24).opacity(0.5), lineWidth: 1.0))
                    .frame(width: handW * 0.85, height: handH * 0.65)
                    .rotationEffect(.degrees(-30))
                    .shadow(color: .black.opacity(0.28), radius: 5, x: -3, y: -3)
                    .position(x: canX + handW * 0.4, y: canY - handH * 0.05)
            }
        }
        .clipped(antialiased: false)
        .allowsHitTesting(false)
        .onAppear {
            animateBob()
            animateWater()
        }
        .onChange(of: isWalking) { _, _ in animateBob() }
    }

    private func animateBob() {
        guard isWalking else {
            withAnimation(.spring(response: 0.3)) { bobOffset = 0 }
            return
        }
        withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
            bobOffset = 10
        }
    }

    private func animateWater() {
        animateDrop(delay: 0.0,  setDrop: { waterDrop1 = $0 },  setOpacity: { waterOpacity1 = $0 })
        animateDrop(delay: 0.18, setDrop: { waterDrop2 = $0 },  setOpacity: { waterOpacity2 = $0 })
        animateDrop(delay: 0.36, setDrop: { waterDrop3 = $0 },  setOpacity: { waterOpacity3 = $0 })
    }

    private func animateDrop(delay: Double,
                             setDrop: @escaping (CGFloat) -> Void,
                             setOpacity: @escaping (Double) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeIn(duration: 0.45)) {
                setOpacity(1.0)
                setDrop(28)
            }
            withAnimation(.easeIn(duration: 0.15).delay(0.35)) {
                setOpacity(0.0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                setDrop(0)
                setOpacity(0)
                animateDrop(delay: 0.05, setDrop: setDrop, setOpacity: setOpacity)
            }
        }
    }
}

// MARK: - Watering Can View
struct WateringCanView: View {
    var waterDrop1: CGFloat
    var waterDrop2: CGFloat
    var waterDrop3: CGFloat
    var waterOpacity1: Double
    var waterOpacity2: Double
    var waterOpacity3: Double

    var body: some View {
        Canvas { ctx, size in
            let W = size.width
            let H = size.height

            // ── Body ──
            let bodyRect = CGRect(x: W*0.18, y: H*0.30, width: W*0.52, height: H*0.42)
            var bodyPath = Path()
            bodyPath.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: 10, height: 10))
            ctx.fill(bodyPath, with: .linearGradient(
                Gradient(colors: [Color(red:0.30,green:0.72,blue:0.52), Color(red:0.18,green:0.52,blue:0.36)]),
                startPoint: CGPoint(x: W*0.18, y: H*0.30),
                endPoint:   CGPoint(x: W*0.70, y: H*0.72)
            ))
            ctx.stroke(bodyPath, with: .color(Color(red:0.12,green:0.38,blue:0.26).opacity(0.8)), lineWidth: 1.5)

            // ── Top lid (cap) ──
            var lidPath = Path()
            lidPath.addRoundedRect(
                in: CGRect(x: W*0.24, y: H*0.22, width: W*0.40, height: H*0.12),
                cornerSize: CGSize(width: 5, height: 5)
            )
            ctx.fill(lidPath, with: .color(Color(red:0.20,green:0.60,blue:0.42)))

            // ── Spout (nozzle arm going upper-left) ──
            var spoutPath = Path()
            spoutPath.move(to:    CGPoint(x: W*0.22, y: H*0.38))
            spoutPath.addLine(to: CGPoint(x: W*0.00, y: H*0.12))
            spoutPath.addLine(to: CGPoint(x: W*0.06, y: H*0.08))
            spoutPath.addLine(to: CGPoint(x: W*0.28, y: H*0.34))
            spoutPath.closeSubpath()
            ctx.fill(spoutPath, with: .color(Color(red:0.22,green:0.62,blue:0.44)))
            ctx.stroke(spoutPath, with: .color(Color(red:0.12,green:0.38,blue:0.26).opacity(0.7)), lineWidth: 1.0)

            // ── Rose (sprinkle head) ──
            var nosePath = Path()
            nosePath.addEllipse(in: CGRect(x: W*0.00, y: H*0.04, width: W*0.12, height: H*0.10))
            ctx.fill(nosePath, with: .color(Color(red:0.18,green:0.52,blue:0.36)))

            // ── Handle (arc on right side) ──
            var handlePath = Path()
            handlePath.move(to:    CGPoint(x: W*0.65, y: H*0.35))
            handlePath.addCurve(
                to:          CGPoint(x: W*0.65, y: H*0.68),
                control1:    CGPoint(x: W*1.00, y: H*0.28),
                control2:    CGPoint(x: W*1.00, y: H*0.75)
            )
            ctx.stroke(handlePath, with: .color(Color(red:0.18,green:0.52,blue:0.36)), style: StrokeStyle(lineWidth: 7, lineCap: .round))

            // ── Water highlight on body ──
            var hlPath = Path()
            hlPath.addRoundedRect(
                in: CGRect(x: W*0.24, y: H*0.36, width: W*0.10, height: H*0.22),
                cornerSize: CGSize(width: 4, height: 4)
            )
            ctx.fill(hlPath, with: .color(.white.opacity(0.18)))
        }
        .overlay(
            // Animated water drops from spout rose
            GeometryReader { geo in
                let W = geo.size.width
                let H = geo.size.height
                // Drops fan out from the rose tip area
                let baseX = W * 0.04
                let baseY = H * 0.09

                Group {
                    Circle()
                        .fill(Color(red:0.42,green:0.78,blue:0.95).opacity(waterOpacity1))
                        .frame(width: 5, height: 5)
                        .offset(x: baseX - 4,  y: baseY + waterDrop1)
                    Circle()
                        .fill(Color(red:0.42,green:0.78,blue:0.95).opacity(waterOpacity2))
                        .frame(width: 4, height: 4)
                        .offset(x: baseX + 2,  y: baseY + waterDrop2)
                    Circle()
                        .fill(Color(red:0.42,green:0.78,blue:0.95).opacity(waterOpacity3))
                        .frame(width: 5, height: 5)
                        .offset(x: baseX - 9,  y: baseY + waterDrop3 - 5)
                }
            }
        )
    }
}

// MARK: - Hand Shape
struct SimpleHandShape: Shape {
    var isLeft: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: rect)
        return p
    }
}
