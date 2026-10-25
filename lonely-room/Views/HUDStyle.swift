import SwiftUI

// MARK: - HUD Style
extension Color {
    /// Latar panel HUD. Sengaja warna transparan biasa, bukan `.ultraThinMaterial`:
    /// material blur di atas SCNView harus mem-blur ulang scene 3D setiap frame
    /// (±10 panel = beban GPU besar dan bikin game terasa lag).
    static let hudFill = Color.black.opacity(0.38)
}
