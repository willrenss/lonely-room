import SwiftUI

// MARK: - Room Photo
enum RoomPhoto {
    /// Tambahkan watermark kecil "Kost Simulator · tanggal" di pojok kanan bawah.
    static func compose(_ snapshot: UIImage) -> UIImage {
        let size = snapshot.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = snapshot.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            snapshot.draw(in: CGRect(origin: .zero, size: size))

            let f = DateFormatter()
            f.locale = Locale(identifier: "id_ID")
            f.dateFormat = "d MMM yyyy"
            let text = "Kost Simulator · \(f.string(from: Date()))"
            let fontSize = max(12, size.height * 0.032)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.white,
            ]
            let textSize = (text as NSString).size(withAttributes: attrs)
            let pad = fontSize * 0.7
            let rect = CGRect(x: size.width - textSize.width - pad * 3,
                              y: size.height - textSize.height - pad * 2.4,
                              width: textSize.width + pad * 2,
                              height: textSize.height + pad)
            UIColor.black.withAlphaComponent(0.35).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).fill()
            (text as NSString).draw(at: CGPoint(x: rect.minX + pad, y: rect.minY + pad / 2), withAttributes: attrs)
        }
    }
}

// MARK: - Photo Preview
struct PhotoPreviewView: View {
    let image: UIImage
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 16) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white, lineWidth: 4))
                    .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
                    .rotationEffect(.degrees(-1.5))
                    .accessibilityLabel("Foto kamar kost kamu")

                HStack(spacing: 12) {
                    Button("Tutup", action: onClose)
                        .buttonStyle(SecondaryPillStyle())
                    ShareLink(item: Image(uiImage: image),
                              preview: SharePreview("Kamar kost-ku", image: Image(uiImage: image))) {
                        Label("Bagikan / Simpan", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryPillStyle())
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 28)
        }
    }
}
