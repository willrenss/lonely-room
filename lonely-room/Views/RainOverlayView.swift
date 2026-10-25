import SwiftUI
import UIKit

// MARK: - Animated Rain Overlay
/// Hujan di layar memakai CAEmitterLayer: partikel dianimasikan Core Animation di GPU.
/// Versi lama memakai TimelineView + Canvas yang menggambar ulang 70–200 garis di
/// main thread setiap frame, bersaing dengan SceneKit dan bikin lag.
struct RainOverlayView: View {
    let condition: WeatherCondition?

    private var intensity: RainEmitterView.Intensity? {
        guard let c = condition else { return nil }
        if [95, 96, 99].contains(c.code) { return .storm }
        if [65, 80, 81, 82].contains(c.code) { return .heavy }
        if [51, 53, 55, 61, 63].contains(c.code) { return .light }
        return nil
    }

    var body: some View {
        if let intensity {
            RainEmitterView(intensity: intensity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Emitter
private struct RainEmitterView: UIViewRepresentable {
    enum Intensity { case light, heavy, storm }
    let intensity: Intensity

    func makeUIView(context: Context) -> EmitterHostView {
        let v = EmitterHostView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        v.configure(intensity)
        return v
    }

    func updateUIView(_ uiView: EmitterHostView, context: Context) {
        uiView.configure(intensity)
    }

    final class EmitterHostView: UIView {
        private let emitter = CAEmitterLayer()
        private var current: Intensity?

        override init(frame: CGRect) {
            super.init(frame: frame)
            emitter.emitterShape = .line
            emitter.renderMode = .additive
            layer.addSublayer(emitter)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            // Garis emitter sedikit di atas layar dan lebih lebar dari layar (untuk kemiringan).
            emitter.frame = bounds
            emitter.emitterPosition = CGPoint(x: bounds.midX + 40, y: -20)
            emitter.emitterSize = CGSize(width: bounds.width * 1.3, height: 1)
        }

        func configure(_ intensity: Intensity) {
            guard intensity != current else { return }
            current = intensity

            let (birth, speed, length, alpha): (Float, CGFloat, CGFloat, CGFloat) = {
                switch intensity {
                case .light: return (90,  700, 14, 0.30)
                case .heavy: return (180, 950, 22, 0.42)
                case .storm: return (260, 1150, 28, 0.52)
                }
            }()

            let cell = CAEmitterCell()
            cell.contents = Self.dropImage(length: length).cgImage
            cell.birthRate = birth
            cell.lifetime = 1.6
            cell.velocity = speed
            cell.velocityRange = speed * 0.2
            // Sedikit miring ke kiri seperti versi lama.
            cell.emissionLongitude = .pi / 2 + 0.12
            cell.scale = 1
            cell.scaleRange = 0.3
            cell.alphaSpeed = 0
            cell.color = UIColor(red: 0.72, green: 0.86, blue: 0.98, alpha: alpha).cgColor
            emitter.emitterCells = [cell]
        }

        private static func dropImage(length: CGFloat) -> UIImage {
            let size = CGSize(width: 2, height: length)
            return UIGraphicsImageRenderer(size: size).image { _ in
                UIColor.white.setFill()
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 1).fill()
            }
        }
    }
}
