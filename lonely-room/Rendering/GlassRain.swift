import SceneKit
import UIKit

// MARK: - Glass Rain
/// Tetesan & aliran air hujan di kaca jendela.
/// Dua plane tipis di depan tiap panel kaca: butiran air statis + aliran air yang
/// bergerak turun. Animasinya cukup menggeser contentsTransform tekstur (murah di GPU).
extension KostViewModel {

    /// Pasang layer hujan sebagai child panel kaca supaya ikut bergeser saat jendela dibuka.
    func attachGlassRain(to glass: SCNNode, width: CGFloat, height: CGFloat) {
        let beads = makeGlassRainPlane(width: width, height: height,
                                       image: Self.beadTexture, name: "glassRainBeads")
        beads.position = SCNVector3(0, 0, 0.006)
        let streaks = makeGlassRainPlane(width: width, height: height,
                                         image: Self.streakTexture, name: "glassRainStreaks")
        streaks.position = SCNVector3(0, 0, 0.007)
        [beads, streaks].forEach {
            $0.isHidden = true
            glass.addChildNode($0)
            glassRainNodes.append($0)
        }
    }

    /// Tampilkan/sembunyikan hujan di kaca. Saat jendela terbuka kaca bersih (panel digeser).
    func updateGlassRain(raining: Bool, heavy: Bool) {
        let visible = raining && !isWindowOpen
        for node in glassRainNodes {
            node.isHidden = !visible
            node.removeAction(forKey: "rainScroll")
            guard visible, node.name == "glassRainStreaks" else { continue }
            let duration: CGFloat = heavy ? 0.9 : 1.6
            node.opacity = heavy ? 1.0 : 0.8
            node.runAction(.repeatForever(.customAction(duration: duration) { n, t in
                let p = Float(t / duration)
                n.geometry?.firstMaterial?.diffuse.contentsTransform =
                    SCNMatrix4MakeTranslation(0, -p, 0)
            }), forKey: "rainScroll")
        }
        for node in glassRainNodes where node.name == "glassRainBeads" {
            node.opacity = heavy ? 1.0 : 0.75
        }
    }

    private func makeGlassRainPlane(width: CGFloat, height: CGFloat, image: UIImage, name: String) -> SCNNode {
        let plane = SCNPlane(width: width, height: height)
        let m = SCNMaterial()
        m.diffuse.contents = image
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.lightingModel = .constant
        m.blendMode = .alpha
        m.transparencyMode = .aOne
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        plane.materials = [m]
        let node = SCNNode(geometry: plane)
        node.name = name
        node.renderingOrder = 10   // setelah kaca (5), sebelum tirai (15)
        return node
    }

    // MARK: - Textures (dibuat sekali)

    private static func seededRandom(_ seed: inout UInt64) -> CGFloat {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(seed >> 11) / CGFloat(1 << 53)
    }

    /// Butiran air diam di kaca.
    static let beadTexture: UIImage = {
        let size = CGSize(width: 256, height: 256)
        var seed: UInt64 = 0xC0FFEE
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            // Ukuran besar karena 1 tile = selebar setengah jendela (±60pt di layar).
            for _ in 0..<26 {
                let r = 6 + seededRandom(&seed) * 9
                let x = seededRandom(&seed) * size.width
                let y = seededRandom(&seed) * size.height
                let rect = CGRect(x: x, y: y, width: r * 1.6, height: r * 2)
                cg.setFillColor(UIColor(white: 1, alpha: 0.35).cgColor)
                cg.fillEllipse(in: rect)
                cg.setStrokeColor(UIColor(red: 0.15, green: 0.25, blue: 0.4, alpha: 0.35).cgColor)
                cg.setLineWidth(2)
                cg.strokeEllipse(in: rect)
                // Kilau kecil
                cg.setFillColor(UIColor(white: 1, alpha: 0.8).cgColor)
                cg.fillEllipse(in: CGRect(x: x + r * 0.35, y: y + r * 0.3, width: r * 0.5, height: r * 0.5))
            }
        }
    }()

    /// Aliran air yang turun (tile vertikal seamless).
    static let streakTexture: UIImage = {
        let size = CGSize(width: 256, height: 256)
        var seed: UInt64 = 0xBEEF
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            cg.setLineCap(.round)
            for _ in 0..<9 {
                let x = seededRandom(&seed) * size.width
                let len = 50 + seededRandom(&seed) * 90
                let y = seededRandom(&seed) * size.height
                let w = 4 + seededRandom(&seed) * 3
                // Gambar dua kali (offset tinggi tile) supaya seamless saat di-wrap.
                for dy in [0, -size.height] {
                    cg.setStrokeColor(UIColor(white: 1, alpha: 0.6).cgColor)
                    cg.setLineWidth(w)
                    cg.move(to: CGPoint(x: x, y: y + dy))
                    cg.addLine(to: CGPoint(x: x + 1, y: y + dy + len))
                    cg.strokePath()
                    // Kepala tetes di ujung bawah
                    cg.setFillColor(UIColor(white: 1, alpha: 0.7).cgColor)
                    cg.fillEllipse(in: CGRect(x: x + 1 - w, y: y + dy + len - w, width: w * 2.2, height: w * 2.6))
                }
            }
        }
    }()
}
