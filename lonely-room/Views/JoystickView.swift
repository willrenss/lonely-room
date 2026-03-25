import SwiftUI

// MARK: - Joystick View
struct JoystickView: View {
    let size: CGFloat
    var onChange: (CGFloat, CGFloat) -> Void   // dx, dy (+dy = forward)
    var onEnd: () -> Void

    @State private var offset = CGSize.zero
    private var maxR: CGFloat { size / 2 - 16 }

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1.5))
                .frame(width: size, height: size)
            Circle()
                .fill(LinearGradient(colors: [Color.white.opacity(0.85), Color.white.opacity(0.4)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                .frame(width: size * 0.36, height: size * 0.36)
                .offset(offset)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let raw  = v.translation
                    let dist = hypot(raw.width, raw.height)
                    let clamped = dist > maxR
                        ? CGSize(width: raw.width/dist*maxR, height: raw.height/dist*maxR)
                        : raw
                    offset = clamped
                    // Swipe UP = negative SwiftUI Y = positive dy = move forward
                    onChange(clamped.width / maxR, -clamped.height / maxR)
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25)) { offset = .zero }
                    onEnd()
                }
        )
    }
}
