import SwiftUI

// MARK: - Hand POV View
struct HandView: View {
    var isWalking: Bool
    @State private var bobOffset: CGFloat = 0

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

                // Right hand
                SimpleHandShape(isLeft: false)
                    .fill(LinearGradient(
                        colors: [Color(red:0.91,green:0.75,blue:0.61), Color(red:0.70,green:0.55,blue:0.41)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(SimpleHandShape(isLeft: false)
                        .stroke(Color(red:0.50,green:0.36,blue:0.24).opacity(0.5), lineWidth: 1.0))
                    .frame(width: handW, height: handH)
                    .rotationEffect(.degrees(-25))
                    .shadow(color: .black.opacity(0.28), radius: 5, x: -3, y: -3)
                    .position(x: W - handW * 0.55, y: H - handH * 0.18 - bobOffset)
            }
        }
        .clipped(antialiased: false)
        .allowsHitTesting(false)
        .onAppear { animateBob() }
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
