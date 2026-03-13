import SwiftUI
import SceneKit
import Combine

// MARK: - Time of Day
enum TimeOfDay {
    case day        // 06:00 – 17:00
    case dusk       // 17:00 – 19:00
    case night      // 19:00 – 06:00

    static func from(hour: Int) -> TimeOfDay {
        if hour >= 6 && hour < 17  { return .day  }
        if hour >= 17 && hour < 19 { return .dusk }
        return .night
    }

    var isDay: Bool { self == .day }
}

// MARK: - Weather
struct WeatherCondition {
    let code: Int       // WMO weather code
    let isDay: Bool
    let tempC: Double

    // Glass / sky color seen through window
    var glassColor: UIColor {
        switch code {
        case 0:                          // clear
            return isDay
                ? UIColor(red:0.52, green:0.78, blue:0.98, alpha:1)   // bright blue
                : UIColor(red:0.05, green:0.07, blue:0.20, alpha:1)   // night dark blue
        case 1, 2:                       // mainly clear / partly cloudy
            return isDay
                ? UIColor(red:0.65, green:0.82, blue:0.95, alpha:1)
                : UIColor(red:0.07, green:0.09, blue:0.22, alpha:1)
        case 3:                          // overcast
            return UIColor(red:0.62, green:0.65, blue:0.70, alpha:1)
        case 45, 48:                     // fog
            return UIColor(red:0.78, green:0.78, blue:0.78, alpha:1)
        case 51, 53, 55,                 // drizzle
             61, 63, 65,                 // rain
             80, 81, 82:                 // showers
            return UIColor(red:0.42, green:0.52, blue:0.65, alpha:1)
        case 71, 73, 75, 77:             // snow
            return UIColor(red:0.85, green:0.90, blue:0.98, alpha:1)
        case 95, 96, 99:                 // thunderstorm
            return UIColor(red:0.22, green:0.24, blue:0.32, alpha:1)
        default:
            return UIColor(red:0.60, green:0.82, blue:0.98, alpha:1)
        }
    }

    /// Returns a copy of this condition with isDay overridden by the current local time.
    func applying(timeOfDay tod: TimeOfDay) -> WeatherCondition {
        WeatherCondition(code: code, isDay: tod.isDay, tempC: tempC)
    }

    // Transparency — overcast/rainy = more opaque (less "see-through"), clear = more transparent
    var glassTransparency: CGFloat {
        switch code {
        case 0, 1: return 0.68
        case 2:    return 0.62
        case 3:    return 0.50
        case 45, 48: return 0.40
        case 95, 96, 99: return 0.30
        default:   return 0.55
        }
    }

    var label: String {
        switch code {
        case 0:          return isDay ? "☀️ Cerah" : "🌙 Malam Cerah"
        case 1:          return "🌤 Mostly Clear"
        case 2:          return "⛅️ Berawan Sebagian"
        case 3:          return "☁️ Mendung"
        case 45, 48:     return "🌫 Berkabut"
        case 51, 53, 55: return "🌦 Gerimis"
        case 61, 63, 65: return "🌧 Hujan"
        case 80, 81, 82: return "🌧 Hujan Lebat"
        case 71...77:    return "❄️ Salju"
        case 95:         return "⛈ Badai"
        case 96, 99:     return "⛈ Badai Petir"
        default:         return "🌡 \(Int(tempC))°C"
        }
    }

    var ambientIntensity: CGFloat {
        switch code {
        case 0, 1: return isDay ? 0.65 : 0.25
        case 2:    return 0.55
        case 3:    return 0.40
        case 45, 48: return 0.35
        case 95, 96, 99: return 0.20
        default:   return 0.50
        }
    }
}

class WeatherService: ObservableObject {
    @Published var condition: WeatherCondition?
    @Published var errorMessage: String?

    // Tangerang, Banten coordinates
    private let lat = -6.1781
    private let lon = 106.6298

    func fetch() {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code,is_day&timezone=Asia%2FJakarta"
        guard let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if let error = error { self.errorMessage = error.localizedDescription; return }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let current = json["current"] as? [String: Any],
                      let code = current["weather_code"] as? Int,
                      let isDay = current["is_day"] as? Int,
                      let temp = current["temperature_2m"] as? Double
                else { self.errorMessage = "Parse gagal"; return }
                self.condition = WeatherCondition(code: code, isDay: isDay == 1, tempC: temp)
            }
        }.resume()
    }
}

// MARK: - Weather Texture Renderer
struct WeatherTextureRenderer {
    static func draw(condition: WeatherCondition, size: CGSize, timeOfDay: TimeOfDay = .day) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let r = ctx.cgContext
            let w = size.width, h = size.height
            let code = condition.code
            let isDay = condition.isDay

            // ── Sky gradient ──
            let skyColors: [CGColor]
            if timeOfDay == .night || !isDay {
                // Night
                skyColors = [
                    UIColor(red:0.02, green:0.03, blue:0.12, alpha:1).cgColor,
                    UIColor(red:0.05, green:0.06, blue:0.20, alpha:1).cgColor
                ]
            } else if timeOfDay == .dusk {
                // Sunset / dusk
                skyColors = [
                    UIColor(red:0.90, green:0.40, blue:0.12, alpha:1).cgColor,
                    UIColor(red:0.98, green:0.72, blue:0.38, alpha:1).cgColor
                ]
            } else if code == 0 || code == 1 {
                // Clear / mainly clear
                skyColors = [
                    UIColor(red:0.25, green:0.58, blue:0.95, alpha:1).cgColor,
                    UIColor(red:0.55, green:0.82, blue:1.00, alpha:1).cgColor
                ]
            } else if code == 2 {
                // Partly cloudy
                skyColors = [
                    UIColor(red:0.38, green:0.62, blue:0.88, alpha:1).cgColor,
                    UIColor(red:0.65, green:0.80, blue:0.95, alpha:1).cgColor
                ]
            } else if code == 3 {
                // Overcast
                skyColors = [
                    UIColor(red:0.45, green:0.47, blue:0.52, alpha:1).cgColor,
                    UIColor(red:0.65, green:0.66, blue:0.70, alpha:1).cgColor
                ]
            } else if [45, 48].contains(code) {
                // Fog
                skyColors = [
                    UIColor(red:0.72, green:0.72, blue:0.74, alpha:1).cgColor,
                    UIColor(red:0.85, green:0.85, blue:0.86, alpha:1).cgColor
                ]
            } else if [95, 96, 99].contains(code) {
                // Thunderstorm
                skyColors = [
                    UIColor(red:0.10, green:0.10, blue:0.16, alpha:1).cgColor,
                    UIColor(red:0.25, green:0.25, blue:0.35, alpha:1).cgColor
                ]
            } else {
                // Rain / drizzle / showers
                skyColors = [
                    UIColor(red:0.28, green:0.35, blue:0.48, alpha:1).cgColor,
                    UIColor(red:0.48, green:0.55, blue:0.65, alpha:1).cgColor
                ]
            }
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: skyColors as CFArray,
                                      locations: [0, 1])!
            r.drawLinearGradient(gradient,
                                 start: CGPoint(x: w/2, y: 0),
                                 end:   CGPoint(x: w/2, y: h),
                                 options: [])

            // ── Sun (clear day) ──
            if isDay && timeOfDay == .day && (code == 0 || code == 1) {
                let sunR: CGFloat = 32
                let sunX = w * 0.75, sunY = h * 0.22
                // Glow
                let glowR: CGFloat = sunR * 1.8
                let glowGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                    UIColor(red:1,green:0.97,blue:0.75,alpha:0.6).cgColor,
                    UIColor(red:1,green:0.97,blue:0.75,alpha:0).cgColor
                ] as CFArray, locations: [0, 1])!
                r.drawRadialGradient(glowGrad,
                                     startCenter: CGPoint(x:sunX,y:sunY), startRadius: 0,
                                     endCenter:   CGPoint(x:sunX,y:sunY), endRadius: glowR, options: [])
                // Sun disc
                r.setFillColor(UIColor(red:1.0,green:0.95,blue:0.60,alpha:1).cgColor)
                r.fillEllipse(in: CGRect(x:sunX-sunR, y:sunY-sunR, width:sunR*2, height:sunR*2))
            }

            // ── Dusk / sunset sun ──
            if timeOfDay == .dusk && (code == 0 || code == 1 || code == 2) {
                let sunR: CGFloat = 26
                let sunX = w * 0.55, sunY = h * 0.62  // near horizon
                let glowR: CGFloat = sunR * 2.2
                let glowGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                    UIColor(red:1,green:0.55,blue:0.10,alpha:0.7).cgColor,
                    UIColor(red:1,green:0.55,blue:0.10,alpha:0).cgColor
                ] as CFArray, locations: [0, 1])!
                r.drawRadialGradient(glowGrad,
                                     startCenter: CGPoint(x:sunX,y:sunY), startRadius: 0,
                                     endCenter:   CGPoint(x:sunX,y:sunY), endRadius: glowR, options: [])
                r.setFillColor(UIColor(red:1.0,green:0.62,blue:0.15,alpha:1).cgColor)
                r.fillEllipse(in: CGRect(x:sunX-sunR, y:sunY-sunR, width:sunR*2, height:sunR*2))
            }

            // ── Moon (clear night) ──
            if !isDay && code <= 2 {
                let mx = w * 0.72, my = h * 0.20, mr: CGFloat = 20
                r.setFillColor(UIColor(red:0.95,green:0.95,blue:0.85,alpha:1).cgColor)
                r.fillEllipse(in: CGRect(x:mx-mr, y:my-mr, width:mr*2, height:mr*2))
                // crescent shadow
                r.setFillColor(UIColor(red:0.04,green:0.05,blue:0.18,alpha:1).cgColor)
                r.fillEllipse(in: CGRect(x:mx-mr+8, y:my-mr-4, width:mr*2, height:mr*2))
            }

            // ── Stars (night) ──
            if !isDay {
                r.setFillColor(UIColor(white:1,alpha:0.85).cgColor)
                let starPositions: [(CGFloat,CGFloat,CGFloat)] = [
                    (0.08,0.10,1.5),(0.18,0.05,2.0),(0.30,0.18,1.2),(0.42,0.08,1.8),
                    (0.55,0.14,1.0),(0.62,0.06,2.2),(0.80,0.12,1.4),(0.90,0.20,1.0),
                    (0.12,0.30,1.0),(0.35,0.28,1.6),(0.50,0.30,1.2),(0.68,0.25,1.8),
                    (0.85,0.32,1.0),(0.22,0.42,1.3),(0.78,0.38,1.5)
                ]
                for (sx, sy, sr) in starPositions {
                    r.fillEllipse(in: CGRect(x:sx*w-sr, y:sy*h-sr, width:sr*2, height:sr*2))
                }
            }

            // ── Clouds ──
            func drawCloud(cx: CGFloat, cy: CGFloat, scale: CGFloat, alpha: CGFloat) {
                r.setFillColor(UIColor(white:1, alpha:alpha).cgColor)
                let puffs: [(CGFloat,CGFloat,CGFloat)] = [
                    (0,0,22),(20,-10,18),(40,0,20),(-20,-8,16),(60,4,15)
                ]
                for (px,py,pr) in puffs {
                    let fr = pr * scale
                    r.fillEllipse(in: CGRect(x:cx+px*scale-fr, y:cy+py*scale-fr, width:fr*2, height:fr*2))
                }
            }

            switch code {
            case 0:  // Clear — one small distant cloud
                if isDay { drawCloud(cx:w*0.10, cy:h*0.35, scale:0.7, alpha:0.55) }
            case 1:  // Mainly clear
                drawCloud(cx:w*0.12, cy:h*0.30, scale:0.9, alpha:0.70)
                drawCloud(cx:w*0.65, cy:h*0.40, scale:0.75, alpha:0.55)
            case 2:  // Partly cloudy
                drawCloud(cx:w*0.10, cy:h*0.28, scale:1.1, alpha:0.85)
                drawCloud(cx:w*0.50, cy:h*0.22, scale:1.0, alpha:0.80)
                drawCloud(cx:w*0.80, cy:h*0.38, scale:0.85, alpha:0.70)
            case 3, 45, 48:  // Overcast / fog — dense cloud cover
                r.setFillColor(UIColor(white: code==3 ? 0.72 : 0.85, alpha: 0.92).cgColor)
                r.fill(CGRect(x:0, y:0, width:w, height:h*0.55))
                drawCloud(cx:w*0.05, cy:h*0.25, scale:1.4, alpha:0.88)
                drawCloud(cx:w*0.42, cy:h*0.18, scale:1.5, alpha:0.85)
                drawCloud(cx:w*0.75, cy:h*0.28, scale:1.3, alpha:0.82)
                if code == 45 || code == 48 {
                    // Fog layer
                    let fogColors = [UIColor(white:0.85,alpha:0).cgColor,
                                     UIColor(white:0.85,alpha:0.55).cgColor] as CFArray
                    let fogGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                             colors: fogColors, locations: [0,1])!
                    r.drawLinearGradient(fogGrad,
                                         start: CGPoint(x:w/2, y:h*0.4),
                                         end:   CGPoint(x:w/2, y:h),
                                         options: [])
                }
            case 51, 53, 55, 61, 63, 65, 80, 81, 82:  // Rain / drizzle
                drawCloud(cx:w*0.05, cy:h*0.15, scale:1.5, alpha:0.80)
                drawCloud(cx:w*0.44, cy:h*0.10, scale:1.6, alpha:0.85)
                drawCloud(cx:w*0.78, cy:h*0.18, scale:1.4, alpha:0.78)
                // Rain drops
                let heavy = [65, 80, 81, 82].contains(code)
                let dropCount = heavy ? 55 : 30
                r.setStrokeColor(UIColor(red:0.62,green:0.78,blue:0.92,alpha:0.70).cgColor)
                r.setLineWidth(heavy ? 1.5 : 1.0)
                var rng: UInt64 = 12345
                func nextRand() -> CGFloat {
                    rng = rng &* 6364136223846793005 &+ 1442695040888963407
                    return CGFloat(rng >> 33) / CGFloat(1 << 31)
                }
                for _ in 0..<dropCount {
                    let rx = nextRand() * w
                    let ry = h * 0.40 + nextRand() * h * 0.55
                    let len: CGFloat = heavy ? 14 : 9
                    r.move(to: CGPoint(x:rx, y:ry))
                    r.addLine(to: CGPoint(x:rx-3, y:ry+len))
                    r.strokePath()
                }
            case 95, 96, 99:  // Thunderstorm
                drawCloud(cx:w*0.02, cy:h*0.12, scale:1.8, alpha:0.72)
                drawCloud(cx:w*0.40, cy:h*0.08, scale:2.0, alpha:0.78)
                drawCloud(cx:w*0.75, cy:h*0.15, scale:1.7, alpha:0.70)
                // Heavy rain
                r.setStrokeColor(UIColor(red:0.55,green:0.68,blue:0.82,alpha:0.65).cgColor)
                r.setLineWidth(1.5)
                var rng2: UInt64 = 99887
                func nextRand2() -> CGFloat {
                    rng2 = rng2 &* 6364136223846793005 &+ 1442695040888963407
                    return CGFloat(rng2 >> 33) / CGFloat(1 << 31)
                }
                for _ in 0..<65 {
                    let rx = nextRand2() * w
                    let ry = h * 0.38 + nextRand2() * h * 0.58
                    r.move(to: CGPoint(x:rx, y:ry))
                    r.addLine(to: CGPoint(x:rx-4, y:ry+16))
                    r.strokePath()
                }
                // Lightning
                r.setStrokeColor(UIColor(red:1,green:0.97,blue:0.60,alpha:0.90).cgColor)
                r.setLineWidth(2.5)
                let lx = w * 0.55, ly = h * 0.38
                r.move(to: CGPoint(x:lx, y:ly))
                r.addLine(to: CGPoint(x:lx-12, y:ly+30))
                r.addLine(to: CGPoint(x:lx-4,  y:ly+30))
                r.addLine(to: CGPoint(x:lx-18, y:ly+60))
                r.strokePath()
            default:
                drawCloud(cx:w*0.15, cy:h*0.28, scale:1.0, alpha:0.75)
            }

            // ── Horizon / ground silhouette (buildings) ──
            let groundColor: UIColor
            switch timeOfDay {
            case .day:   groundColor = UIColor(red:0.18, green:0.20, blue:0.16, alpha:1)
            case .dusk:  groundColor = UIColor(red:0.12, green:0.10, blue:0.08, alpha:1)
            case .night: groundColor = UIColor(red:0.05, green:0.06, blue:0.08, alpha:1)
            }
            r.setFillColor(groundColor.cgColor)
            // Simple city skyline silhouette
            let groundY = h * 0.72
            let buildings: [(CGFloat,CGFloat,CGFloat,CGFloat)] = [
                (0,     h*0.15, w*0.10, groundY),
                (w*0.08, h*0.22, w*0.07, groundY),
                (w*0.14, h*0.10, w*0.08, groundY),
                (w*0.21, h*0.26, w*0.09, groundY),
                (w*0.30, h*0.18, w*0.06, groundY),
                (w*0.36, h*0.28, w*0.10, groundY),
                (w*0.46, h*0.12, w*0.07, groundY),
                (w*0.53, h*0.20, w*0.12, groundY),
                (w*0.64, h*0.15, w*0.08, groundY),
                (w*0.72, h*0.25, w*0.09, groundY),
                (w*0.80, h*0.08, w*0.10, groundY),
                (w*0.89, h*0.20, w*0.12, groundY)
            ]
            for (bx, by, bw, bh) in buildings {
                r.fill(CGRect(x:bx, y:by, width:bw, height:bh - by))
            }
            // Ground fill
            r.fill(CGRect(x:0, y:groundY, width:w, height:h-groundY))

            // Window lights on buildings (night / rainy)
            if timeOfDay != .day || code >= 3 {
                r.setFillColor(UIColor(red:1.0, green:0.92, blue:0.60, alpha:0.80).cgColor)
                let lights: [(CGFloat,CGFloat)] = [
                    (w*0.02,h*0.20),(w*0.04,h*0.27),(w*0.16,h*0.16),(w*0.16,h*0.22),
                    (w*0.47,h*0.18),(w*0.49,h*0.24),(w*0.55,h*0.26),(w*0.57,h*0.32),
                    (w*0.81,h*0.14),(w*0.83,h*0.20),(w*0.90,h*0.26),(w*0.93,h*0.30)
                ]
                for (lx2, ly2) in lights {
                    r.fill(CGRect(x:lx2, y:ly2, width:4, height:3))
                }
            }
        }
    }
}

// MARK: - Furniture Catalog
enum FurnitureType: String, CaseIterable {
    case bed      = "Kasur"
    case desk     = "Meja"
    case wardrobe = "Lemari"
    case tv       = "TV"
    case plant    = "Tanaman"
    case rug      = "Karpet"
    case lamp     = "Lampu"
    case bag      = "Tas"

    var icon: String {
        switch self {
        case .bed:      return "bed.double.fill"
        case .desk:     return "desktopcomputer"
        case .wardrobe: return "cabinet.fill"
        case .tv:       return "tv.fill"
        case .plant:    return "leaf.fill"
        case .rug:      return "rectangle.fill"
        case .lamp:     return "lamp.floor.fill"
        case .bag:      return "bag.fill"
        }
    }
    var tileColor: Color {
        switch self {
        case .bed:      return Color(red:0.20, green:0.40, blue:0.70)
        case .desk:     return Color(red:0.60, green:0.40, blue:0.20)
        case .wardrobe: return Color(red:0.40, green:0.25, blue:0.10)
        case .tv:       return Color(red:0.20, green:0.20, blue:0.20)
        case .plant:    return Color(red:0.15, green:0.55, blue:0.15)
        case .rug:      return Color(red:0.65, green:0.15, blue:0.15)
        case .lamp:     return Color(red:0.70, green:0.60, blue:0.20)
        case .bag:      return Color(red:0.15, green:0.15, blue:0.55)
        }
    }
    var footprint: CGSize {
        switch self {
        case .bed:      return CGSize(width:1.1, height:2.0)
        case .desk:     return CGSize(width:1.2, height:0.6)
        case .wardrobe: return CGSize(width:1.0, height:0.5)
        case .tv:       return CGSize(width:1.1, height:0.4)
        case .plant:    return CGSize(width:0.4, height:0.4)
        case .rug:      return CGSize(width:2.0, height:1.4)
        case .lamp:     return CGSize(width:0.3, height:0.3)
        case .bag:      return CGSize(width:0.4, height:0.2)
        }
    }
}

struct FurnitureItem {
    let id   = UUID()
    let type: FurnitureType
    var position: SCNVector3
    var node: SCNNode
}

// MARK: - ViewModel
class KostViewModel: ObservableObject {
    let cameraNode = SCNNode()
    var yaw: Float   = 0
    let eyeHeight: Float = 1.6
    let speed: Float     = 0.08
    let minX: Float = -2.5, maxX: Float =  2.5
    let minZ: Float = -1.5, maxZ: Float =  1.5

    @Published var isWalking         = false
    @Published var furnitureItems: [FurnitureItem] = []
    @Published var selectedFurniture: FurnitureItem?
    @Published var pendingType: FurnitureType? = nil
    @Published var weather: WeatherCondition?

    /// Called whenever selectedFurniture changes — used by ContentView to hide/show catalog
    var onSelectionChanged: ((FurnitureItem?) -> Void)?

    weak var scnView:      SCNView?
    weak var sceneRoot:    SCNNode?
    weak var glassNode:    SCNNode?   // window glass — updated by weather
    weak var ambientNode:  SCNNode?   // ambient light — updated by weather
    weak var winLightNode: SCNNode?   // window spot light — updated by weather
    weak var outsideNode:    SCNNode?   // plane behind window showing weather scene
    weak var rainParticleNode: SCNNode? // rain particle system outside window

    init() {
        let cam = SCNCamera()
        cam.zNear = 0.01; cam.zFar = 50; cam.fieldOfView = 80
        cameraNode.camera      = cam
        cameraNode.position    = SCNVector3(0, 1.6, 1.0)
        cameraNode.eulerAngles = SCNVector3(0, Float.pi, 0)
    }

    // dy: +1 = thumb pushed up = move forward
    func move(dx: Float, dy: Float) {
        let fwdX =  sin(yaw) * dy * speed
        let fwdZ =  cos(yaw) * dy * speed
        let strX = -cos(yaw) * dx * speed
        let strZ =  sin(yaw) * dx * speed
        let newX = cameraNode.position.x + fwdX + strX
        let newZ = cameraNode.position.z + fwdZ + strZ
        let moving = abs(dx) > 0.05 || abs(dy) > 0.05
        if isWalking != moving { isWalking = moving }
        cameraNode.position.x = max(minX, min(maxX, newX))
        cameraNode.position.z = max(minZ, min(maxZ, newZ))
        cameraNode.position.y = eyeHeight
    }

    func rotateCamera(by delta: Float) {
        yaw += delta
        cameraNode.eulerAngles.y = yaw + Float.pi
    }

    func startPlacing(type: FurnitureType) {
        // Each furniture type can only be placed once
        guard !furnitureItems.contains(where: { $0.type == type }) else { return }
        selectFurniture(nil)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            pendingType = type
        }
    }

    func placeFurniture(at worldPos: SCNVector3) {
        guard let type = pendingType, let root = sceneRoot else { return }
        let node = buildFurnitureNode(type: type)
        let clampedX = max(-2.5, min(2.5, worldPos.x))
        let clampedZ = max(-1.5, min(1.5, worldPos.z))
        node.position = SCNVector3(clampedX, 0, clampedZ)
        root.addChildNode(node)
        let item = FurnitureItem(type: type, position: node.position, node: node)
        furnitureItems.append(item)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            pendingType = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.selectFurniture(item)
        }
    }

    func selectFurniture(_ item: FurnitureItem?) {
        selectedFurniture?.node.childNodes
            .filter { $0.name == "sel_outline" }
            .forEach { $0.removeFromParentNode() }
        selectedFurniture = item
        guard let item = item else { return }
        // Use footprint size for reliable outline (bounding box from top-down can be wrong)
        let fp = item.type.footprint
        let w = CGFloat(fp.width) + 0.15
        let d = CGFloat(fp.height) + 0.15
        let geo = SCNBox(width: w, height: 0.02, length: d, chamferRadius: 0.04)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.65)
        mat.isDoubleSided = true
        mat.lightingModel = .constant
        geo.materials = [mat]
        let outline = SCNNode(geometry: geo)
        outline.name = "sel_outline"
        outline.position = SCNVector3(0, 0.02, 0)
        item.node.addChildNode(outline)
    }

    func moveFurniture(_ item: FurnitureItem, to worldPos: SCNVector3) {
        let clampedX = max(-2.5, min(2.5, worldPos.x))
        let clampedZ = max(-1.5, min(1.5, worldPos.z))
        item.node.position = SCNVector3(clampedX, 0, clampedZ)
        if let idx = furnitureItems.firstIndex(where: { $0.id == item.id }) {
            furnitureItems[idx].position = item.node.position
        }
    }

    func addTopLabel(to node: SCNNode, type: FurnitureType) {
        // Flat colored disc visible from top-down view
        let fp = type.footprint
        let discW = CGFloat(min(fp.width, fp.height)) * 0.7
        let disc = SCNBox(width: discW, height: 0.005, length: discW, chamferRadius: discW/2)
        let mat = SCNMaterial()
        // Use the furniture's tile color as disc color
        switch type {
        case .bed:      mat.diffuse.contents = UIColor(red:0.20,green:0.40,blue:0.70,alpha:0.85)
        case .desk:     mat.diffuse.contents = UIColor(red:0.60,green:0.40,blue:0.20,alpha:0.85)
        case .wardrobe: mat.diffuse.contents = UIColor(red:0.40,green:0.25,blue:0.10,alpha:0.85)
        case .tv:       mat.diffuse.contents = UIColor(red:0.20,green:0.20,blue:0.20,alpha:0.85)
        case .plant:    mat.diffuse.contents = UIColor(red:0.15,green:0.55,blue:0.15,alpha:0.85)
        case .rug:      mat.diffuse.contents = UIColor(red:0.65,green:0.15,blue:0.15,alpha:0.85)
        case .lamp:     mat.diffuse.contents = UIColor(red:0.70,green:0.60,blue:0.20,alpha:0.85)
        case .bag:      mat.diffuse.contents = UIColor(red:0.15,green:0.15,blue:0.55,alpha:0.85)
        }
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        disc.materials = [mat]
        let discNode = SCNNode(geometry: disc)
        discNode.name = "top_label"
        discNode.position = SCNVector3(0, 2.5, 0) // high up, visible from design camera
        node.addChildNode(discNode)
    }

    func deleteSelected() {
        guard let item = selectedFurniture else { return }
        item.node.removeFromParentNode()
        furnitureItems.removeAll { $0.id == item.id }
        selectedFurniture = nil
    }

    func rotateSelected(by angle: Float) {
        guard let item = selectedFurniture else { return }
        item.node.eulerAngles.y += angle
    }

    func applyWeather(_ w: WeatherCondition) {
        applyWeather(w, timeOfDay: TimeOfDay.from(hour: Calendar.current.component(.hour, from: Date())))
    }

    func applyWeather(_ w: WeatherCondition, timeOfDay tod: TimeOfDay) {
        let effective = w.applying(timeOfDay: tod)
        weather = effective
        // Update glass color
        if let geo = glassNode?.geometry as? SCNBox,
           let mat = geo.materials.first {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.5
            mat.diffuse.contents  = effective.glassColor
            mat.transparency      = effective.glassTransparency
            SCNTransaction.commit()
        }
        // Update ambient intensity
        ambientNode?.light?.color = UIColor(white: effective.ambientIntensity, alpha: 1)
        // Update window light intensity
        winLightNode?.light?.intensity = effective.code == 0 && effective.isDay ? 600 :
                                         effective.code <= 2 && effective.isDay ? 400 :
                                         effective.isDay ? 200 : 80
        // Update outside weather scene texture
        if let mat = outsideNode?.geometry?.firstMaterial {
            let tex = WeatherTextureRenderer.draw(condition: effective, size: CGSize(width: 512, height: 320), timeOfDay: tod)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 2.0
            mat.diffuse.contents = tex
            SCNTransaction.commit()
        }
        // Update rain particles
        let isRain = [51,53,55,61,63,65,80,81,82,95,96,99].contains(effective.code)
        let isHeavy = [65,80,81,82,95,96,99].contains(effective.code)
        if let ps = rainParticleNode?.particleSystems?.first {
            if isRain {
                ps.birthRate = isHeavy ? 800 : 300
                ps.isAffectedByGravity = true
                rainParticleNode?.isHidden = false
            } else {
                rainParticleNode?.isHidden = true
            }
        }
    }

    /// Call every minute to keep window synced with local time
    func applyTimeOfDay() {
        let hour = Calendar.current.component(.hour, from: Date())
        let tod = TimeOfDay.from(hour: hour)
        // Use current weather if available, else use a default clear condition
        let base = weather ?? WeatherCondition(code: 0, isDay: tod.isDay, tempC: 30)
        applyWeather(base, timeOfDay: tod)
    }

    func makeRainParticleSystem(heavy: Bool = true) -> SCNParticleSystem {
        let ps = SCNParticleSystem()

        // ── Particle appearance ──
        ps.particleSize     = 0.012
        ps.particleSizeVariation = 0.006
        // Blue-white raindrop color
        ps.particleColor    = UIColor(red: 0.72, green: 0.85, blue: 0.98, alpha: 0.75)
        ps.particleColorVariation = SCNVector4(0.05, 0.05, 0.05, 0.15)

        // ── Emission ──
        ps.birthRate        = heavy ? 800 : 300
        ps.birthRateVariation = 50
        ps.emissionDuration = CGFloat.greatestFiniteMagnitude  // forever
        ps.loops            = true

        // Emitter: a wide horizontal plane above the window
        ps.emitterShape     = SCNBox(width: 2.4, height: 0.01, length: 0.1, chamferRadius: 0)
        ps.birthLocation    = .surface

        // ── Motion ──
        ps.particleLifeSpan         = 0.65
        ps.particleLifeSpanVariation = 0.15
        // Shoot downward with slight angle (like rain)
        ps.particleVelocity          = 4.5
        ps.particleVelocityVariation = 0.8
        ps.isAffectedByGravity       = true
        ps.acceleration              = SCNVector3(0.3, -9.8, 0)   // slight wind

        // ── Rendering ──
        ps.blendMode          = .additive
        ps.orientationMode    = .free
        // Make drops look like streaks by stretching along velocity
        ps.stretchFactor      = 0.08

        return ps
    }

    func hitTestFloor(at point: CGPoint) -> SCNVector3? {
        guard let scnView = scnView else { return nil }
        // Ray cast from perspective camera to y=0 plane
        let near = scnView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
        let far  = scnView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
        let dir  = SCNVector3(far.x - near.x, far.y - near.y, far.z - near.z)
        guard abs(dir.y) > 1e-5 else { return nil }
        let t = -near.y / dir.y
        guard t > 0 else { return nil }  // intersection must be in front of camera
        return SCNVector3(near.x + dir.x * t, 0, near.z + dir.z * t)
    }

    func hitTestFurniture(at point: CGPoint) -> FurnitureItem? {
        guard let scnView = scnView else { return nil }
        let hits = scnView.hitTest(point, options: [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .boundingBoxOnly: false,
            .ignoreHiddenNodes: true
        ])
        // Build a set of furniture root nodes for O(1) lookup
        let rootMap: [ObjectIdentifier: FurnitureItem] = Dictionary(
            uniqueKeysWithValues: furnitureItems.map { (ObjectIdentifier($0.node), $0) }
        )
        for hit in hits {
            // Walk up the hierarchy from the hit node to the scene root
            var node: SCNNode? = hit.node
            while let n = node {
                if let item = rootMap[ObjectIdentifier(n)] { return item }
                node = n.parent
            }
        }
        return nil
    }

    // MARK: - Build Furniture Nodes
    func buildFurnitureNode(type: FurnitureType) -> SCNNode {
        let root = SCNNode()
        root.name = "furniture_\(type.rawValue)"
        let fp = type.footprint
        let w = CGFloat(fp.width), d = CGFloat(fp.height)

        switch type {
        case .bed:
            let frame = SCNBox(width: w, height: 0.3, length: d, chamferRadius: 0.05)
            frame.firstMaterial?.diffuse.contents = UIColor(red:0.72,green:0.53,blue:0.38,alpha:1)
            let frameNode = SCNNode(geometry: frame); frameNode.position.y = 0.15
            root.addChildNode(frameNode)
            let mattress = SCNBox(width: w-0.06, height: 0.12, length: d-0.25, chamferRadius: 0.04)
            mattress.firstMaterial?.diffuse.contents = UIColor(red:0.92,green:0.90,blue:0.88,alpha:1)
            let mNode = SCNNode(geometry: mattress); mNode.position = SCNVector3(0, 0.36, 0.05)
            root.addChildNode(mNode)
            let pillow = SCNBox(width: w-0.2, height: 0.08, length: 0.28, chamferRadius: 0.04)
            pillow.firstMaterial?.diffuse.contents = UIColor(red:0.95,green:0.85,blue:0.75,alpha:1)
            let pNode = SCNNode(geometry: pillow); pNode.position = SCNVector3(0, 0.44, -d/2 + 0.25)
            root.addChildNode(pNode)

        case .desk:
            let top = SCNBox(width: w, height: 0.05, length: d, chamferRadius: 0.02)
            top.firstMaterial?.diffuse.contents = UIColor(red:0.80,green:0.60,blue:0.35,alpha:1)
            let topNode = SCNNode(geometry: top); topNode.position.y = 0.72
            root.addChildNode(topNode)
            let legGeo = SCNBox(width: 0.05, height: 0.70, length: 0.05, chamferRadius: 0.01)
            legGeo.firstMaterial?.diffuse.contents = UIColor(red:0.55,green:0.38,blue:0.20,alpha:1)
            for xm in [-1.0, 1.0] { for zm in [-1.0, 1.0] {
                let leg = SCNNode(geometry: legGeo)
                leg.position = SCNVector3(Float(xm)*(Float(w)/2-0.05), 0.35, Float(zm)*(Float(d)/2-0.05))
                root.addChildNode(leg)
            }}
            let screen = SCNBox(width: 0.45, height: 0.28, length: 0.02, chamferRadius: 0.01)
            screen.firstMaterial?.diffuse.contents = UIColor(red:0.10,green:0.10,blue:0.15,alpha:1)
            let sNode = SCNNode(geometry: screen); sNode.position = SCNVector3(0.18, 1.06, d/2 - 0.04)
            root.addChildNode(sNode)

        case .wardrobe:
            let body = SCNBox(width: w, height: 1.8, length: d, chamferRadius: 0.03)
            body.firstMaterial?.diffuse.contents = UIColor(red:0.70,green:0.52,blue:0.32,alpha:1)
            let bNode = SCNNode(geometry: body); bNode.position.y = 0.9
            root.addChildNode(bNode)
            let line = SCNBox(width: 0.02, height: 1.78, length: 0.02, chamferRadius: 0)
            line.firstMaterial?.diffuse.contents = UIColor(red:0.40,green:0.28,blue:0.15,alpha:1)
            let lNode = SCNNode(geometry: line); lNode.position = SCNVector3(0, 0.89, d/2 + 0.01)
            root.addChildNode(lNode)
            for side in [-0.22, 0.22] as [Float] {
                let handle = SCNCylinder(radius: 0.015, height: 0.07)
                handle.firstMaterial?.diffuse.contents = UIColor(red:0.9,green:0.8,blue:0.5,alpha:1)
                let hn = SCNNode(geometry: handle); hn.eulerAngles.x = .pi/2
                hn.position = SCNVector3(side, 0.9, Float(1/2) + 0.03)
                root.addChildNode(hn)
            }

        case .tv:
            let stand = SCNCylinder(radius: 0.12, height: 0.04)
            stand.firstMaterial?.diffuse.contents = UIColor.darkGray
            let stNode = SCNNode(geometry: stand); stNode.position.y = 0.02
            root.addChildNode(stNode)
            let pole = SCNCylinder(radius: 0.025, height: 0.55)
            pole.firstMaterial?.diffuse.contents = UIColor.darkGray
            let plNode = SCNNode(geometry: pole); plNode.position.y = 0.295
            root.addChildNode(plNode)
            let screen = SCNBox(width: w, height: 0.58, length: 0.06, chamferRadius: 0.02)
            screen.firstMaterial?.diffuse.contents = UIColor(red:0.08,green:0.08,blue:0.12,alpha:1)
            let scNode = SCNNode(geometry: screen); scNode.position.y = 0.80
            root.addChildNode(scNode)

        case .plant:
            let pot = SCNCylinder(radius: 0.14, height: 0.18)
            pot.firstMaterial?.diffuse.contents = UIColor(red:0.72,green:0.42,blue:0.22,alpha:1)
            let ptNode = SCNNode(geometry: pot); ptNode.position.y = 0.09
            root.addChildNode(ptNode)
            let stem = SCNCylinder(radius: 0.02, height: 0.3)
            stem.firstMaterial?.diffuse.contents = UIColor(red:0.25,green:0.55,blue:0.15,alpha:1)
            let stNode = SCNNode(geometry: stem); stNode.position.y = 0.33
            root.addChildNode(stNode)
            for (angle, h) in [(0.0, 0.48), (2.09, 0.44), (4.19, 0.46)] as [(Float, Float)] {
                let leaf = SCNSphere(radius: 0.15)
                leaf.firstMaterial?.diffuse.contents = UIColor(red:0.15,green:0.60,blue:0.15,alpha:0.95)
                let ln = SCNNode(geometry: leaf)
                ln.position = SCNVector3(sin(angle)*0.10, h, cos(angle)*0.10)
                root.addChildNode(ln)
            }

        case .rug:
            let rug = SCNBox(width: w, height: 0.02, length: d, chamferRadius: 0.06)
            rug.firstMaterial?.diffuse.contents = UIColor(red:0.72,green:0.18,blue:0.18,alpha:1)
            let rNode = SCNNode(geometry: rug); rNode.position.y = 0.01
            root.addChildNode(rNode)
            let pattern = SCNBox(width: w-0.2, height: 0.025, length: d-0.2, chamferRadius: 0.04)
            pattern.firstMaterial?.diffuse.contents = UIColor(red:0.90,green:0.78,blue:0.55,alpha:0.6)
            let pNode2 = SCNNode(geometry: pattern); pNode2.position.y = 0.013
            root.addChildNode(pNode2)

        case .lamp:
            let base = SCNCylinder(radius: 0.12, height: 0.04)
            base.firstMaterial?.diffuse.contents = UIColor.darkGray
            let bNode = SCNNode(geometry: base); bNode.position.y = 0.02
            root.addChildNode(bNode)
            let pole = SCNCylinder(radius: 0.018, height: 1.4)
            pole.firstMaterial?.diffuse.contents = UIColor(red:0.6,green:0.6,blue:0.6,alpha:1)
            let plNode = SCNNode(geometry: pole); plNode.position.y = 0.74
            root.addChildNode(plNode)
            let shade = SCNCone(topRadius: 0.06, bottomRadius: 0.22, height: 0.28)
            shade.firstMaterial?.diffuse.contents = UIColor(red:0.95,green:0.88,blue:0.60,alpha:1)
            let shNode = SCNNode(geometry: shade); shNode.position.y = 1.58
            root.addChildNode(shNode)
            let omni = SCNLight(); omni.type = .omni
            omni.color = UIColor(red:1.0,green:0.92,blue:0.70,alpha:1)
            omni.intensity = 600
            omni.attenuationStartDistance = 0.3; omni.attenuationEndDistance = 3.0
            let lNode = SCNNode(); lNode.light = omni; lNode.position = SCNVector3(0, 1.55, 0)
            root.addChildNode(lNode)

        case .bag:
            let body = SCNBox(width: 0.36, height: 0.28, length: 0.14, chamferRadius: 0.04)
            body.firstMaterial?.diffuse.contents = UIColor(red:0.18,green:0.22,blue:0.65,alpha:1)
            let bNode = SCNNode(geometry: body); bNode.position.y = 0.14
            root.addChildNode(bNode)
            let handle = SCNTorus(ringRadius: 0.09, pipeRadius: 0.015)
            handle.firstMaterial?.diffuse.contents = UIColor(red:0.12,green:0.14,blue:0.45,alpha:1)
            let hNode = SCNNode(geometry: handle); hNode.eulerAngles.x = .pi/2
            hNode.position = SCNVector3(0, 0.36, 0)
            root.addChildNode(hNode)
        }

        return root
    }
}

// MARK: - Joystick
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
                    // Swipe UP in screen = negative SwiftUI Y = positive dy = move forward
                    onChange(clamped.width / maxR, -clamped.height / maxR)
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25)) { offset = .zero }
                    onEnd()
                }
        )
    }
}

// MARK: - SceneKit Bridge
struct SceneView: UIViewRepresentable {
    @ObservedObject var vm: KostViewModel

    func makeUIView(context: Context) -> SCNView {
        let scene = makeScene()
        let view  = SCNView()
        view.scene           = scene
        view.pointOfView     = vm.cameraNode
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false

        vm.scnView   = view
        vm.sceneRoot = scene.rootNode

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        // Pan gesture for dragging furniture in design mode
        // NOTE: Do NOT require(toFail:) here — that adds ~0.5s delay.
        // Instead, tap is cancelled by Coordinator if movement is detected.
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)

        context.coordinator.tapGesture = tap
        context.coordinator.panGesture = pan

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.pointOfView = vm.cameraNode
    }

    func makeCoordinator() -> Coordinator { Coordinator(vm: vm) }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let vm: KostViewModel
        weak var tapGesture: UITapGestureRecognizer?
        weak var panGesture: UIPanGestureRecognizer?

        /// Offset between finger world position and furniture centre, saved on drag start
        /// so the furniture doesn't "jump" to the finger position.
        private var dragOffset: SIMD2<Float> = .zero
        /// Whether the pan gesture has moved far enough to be a real drag (not a tap)
        private var panIsDragging = false

        init(vm: KostViewModel) { self.vm = vm }

        // Allow tap and pan to be recognised simultaneously —
        // we decide in handleTap whether to actually act on it.
        func gestureRecognizer(_ gr: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }

        // Only let the tap fire when it's NOT a drag-start.
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }

            // If pan gesture is in flight with real movement, ignore the tap
            if let pan = panGesture,
               (pan.state == .changed || pan.state == .began),
               panIsDragging { return }

            let pt = gesture.location(in: view)
            if vm.pendingType != nil {
                if let worldPos = vm.hitTestFloor(at: pt) {
                    vm.placeFurniture(at: worldPos)
                }
            } else {
                let hit = vm.hitTestFurniture(at: pt)
                vm.selectFurniture(hit)
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard vm.pendingType == nil else { return }
            guard let view = gesture.view as? SCNView else { return }
            let pt = gesture.location(in: view)

            switch gesture.state {
            case .began:
                panIsDragging = false
                dragOffset = .zero
                // Find furniture under finger immediately on touch-down
                if let hit = vm.hitTestFurniture(at: pt) {
                    vm.selectFurniture(hit)
                    // Save the XZ offset between finger and furniture centre
                    if let worldPos = vm.hitTestFloor(at: pt) {
                        let fp = hit.node.position
                        dragOffset = SIMD2<Float>(worldPos.x - fp.x, worldPos.z - fp.z)
                    }
                }

            case .changed:
                let translation = gesture.translation(in: view)
                let moveDist = hypot(translation.x, translation.y)
                if moveDist > 6 { panIsDragging = true }   // 6-pt threshold = real drag

                guard panIsDragging, let item = vm.selectedFurniture else { return }
                if let worldPos = vm.hitTestFloor(at: pt) {
                    // Subtract the saved offset so the furniture stays under the original touch point
                    let adjusted = SCNVector3(worldPos.x - dragOffset.x,
                                             0,
                                             worldPos.z - dragOffset.y)
                    vm.moveFurniture(item, to: adjusted)
                }

            case .ended, .cancelled:
                panIsDragging = false
                dragOffset = .zero

            default:
                break
            }
        }
    }

    func makeScene() -> SCNScene {
        let scene = SCNScene()
        let wallColor  = UIColor(red:0.98, green:0.97, blue:0.94, alpha:1)
        let floorColor = UIColor(red:0.76, green:0.62, blue:0.44, alpha:1)
        let ceilColor  = UIColor(red:0.99, green:0.98, blue:0.96, alpha:1)

        // Room dimensions — inner space
        let roomW: Float = 5.6
        let roomH: Float = 2.8
        let roomD: Float = 3.6
        let wT: Float = 0.18  // wall thickness

        // Inner boundary edges
        let innerLeft  = -roomW / 2
        let innerRight =  roomW / 2
        let innerFront =  roomD / 2
        let innerBack  = -roomD / 2

        // Helper: add a plain colored box
        func box(_ w: Float, _ h: Float, _ d: Float, color: UIColor, pos: SCNVector3) {
            let geo = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: 0)
            geo.firstMaterial?.diffuse.contents = color
            geo.firstMaterial?.lightingModel = .lambert
            let n = SCNNode(geometry: geo); n.position = pos
            scene.rootNode.addChildNode(n)
        }

        // ── Floor — use SCNPlane for reliable top-down hit testing ──
        let floorPlane = SCNPlane(width: CGFloat(roomW), height: CGFloat(roomD))
        floorPlane.firstMaterial?.diffuse.contents = floorColor
        floorPlane.firstMaterial?.lightingModel = .lambert
        floorPlane.firstMaterial?.isDoubleSided = true
        let floorNode = SCNNode(geometry: floorPlane)
        floorNode.name = "floor"
        floorNode.eulerAngles.x = -.pi / 2   // lay flat
        floorNode.position = SCNVector3(0, 0.001, 0)
        scene.rootNode.addChildNode(floorNode)

        // ── Grid lines on floor (visible in design mode) ──
        let gridMat = SCNMaterial()
        gridMat.diffuse.contents = UIColor(white: 0.4, alpha: 0.18)
        gridMat.lightingModel = .constant
        let gridStep: Float = 0.5
        let gridW = roomW, gridD = roomD
        // Draw lines along X axis
        var gz = -gridD/2
        while gz <= gridD/2 {
            let lineGeo = SCNBox(width: CGFloat(gridW), height: 0.004, length: 0.012, chamferRadius: 0)
            lineGeo.materials = [gridMat]
            let ln = SCNNode(geometry: lineGeo)
            ln.position = SCNVector3(0, 0.005, gz)
            scene.rootNode.addChildNode(ln)
            gz += gridStep
        }
        // Draw lines along Z axis
        var gx = -gridW/2
        while gx <= gridW/2 {
            let lineGeo = SCNBox(width: 0.012, height: 0.004, length: CGFloat(gridD), chamferRadius: 0)
            lineGeo.materials = [gridMat]
            let ln = SCNNode(geometry: lineGeo)
            ln.position = SCNVector3(gx, 0.005, 0)
            scene.rootNode.addChildNode(ln)
            gx += gridStep
        }

        // ── Ceiling ──
        box(roomW + wT*2, wT, roomD + wT*2, color: ceilColor,
            pos: SCNVector3(0, roomH + wT/2, 0))

        // ── Left wall (solid) ──
        // Center: innerLeft - wT/2, spans full room depth + overlap corners
        box(wT, roomH, roomD + wT*2, color: wallColor,
            pos: SCNVector3(innerLeft - wT/2, roomH/2, 0))

        // ── Right wall (solid) ──
        box(wT, roomH, roomD + wT*2, color: wallColor,
            pos: SCNVector3(innerRight + wT/2, roomH/2, 0))

        // ── Front wall — with DOOR cutout ──
        // Door params: 0.95 wide, 2.1 tall, centred at x = 1.5
        let dW: Float = 0.95, dH: Float = 2.1, dCx: Float = 1.5
        let dLeft  = dCx - dW/2  // left edge of door opening
        let dRight = dCx + dW/2  // right edge of door opening
        let fZ = innerFront + wT/2  // center Z of front wall

        // Panel left of door
        box(dLeft - innerLeft, roomH, wT, color: wallColor,
            pos: SCNVector3(innerLeft + (dLeft - innerLeft)/2, roomH/2, fZ))
        // Panel right of door
        box(innerRight - dRight, roomH, wT, color: wallColor,
            pos: SCNVector3(dRight + (innerRight - dRight)/2, roomH/2, fZ))
        // Panel above door
        box(dW, roomH - dH, wT, color: wallColor,
            pos: SCNVector3(dCx, dH + (roomH - dH)/2, fZ))

        // Door frame (inset slightly from wall face — no Z-fight)
        let frameColor = UIColor(red:0.42, green:0.28, blue:0.14, alpha:1)
        let faceZ = innerFront + 0.01  // slightly inside room
        box(0.06, dH, 0.10, color: frameColor, pos: SCNVector3(dLeft - 0.03, dH/2, faceZ))   // left jamb
        box(0.06, dH, 0.10, color: frameColor, pos: SCNVector3(dRight + 0.03, dH/2, faceZ))  // right jamb
        box(dW + 0.06, 0.06, 0.10, color: frameColor, pos: SCNVector3(dCx, dH + 0.03, faceZ)) // head

        // Door panel (sits in opening, inset from wall face)
        let doorPanelColor = UIColor(red:0.60, green:0.42, blue:0.24, alpha:1)
        box(dW - 0.08, dH - 0.04, 0.04, color: doorPanelColor,
            pos: SCNVector3(dCx, (dH - 0.04)/2, innerFront - 0.01))
        // Door handle
        let handleGeo = SCNCylinder(radius: 0.018, height: 0.10)
        handleGeo.firstMaterial?.diffuse.contents = UIColor(red:0.80, green:0.68, blue:0.28, alpha:1)
        let handleNode = SCNNode(geometry: handleGeo)
        handleNode.eulerAngles.z = .pi/2
        handleNode.position = SCNVector3(dLeft + 0.12, 1.0, innerFront + 0.04)
        scene.rootNode.addChildNode(handleNode)

        // ── Back wall — with WINDOW cutout ──
        let wW: Float = 1.1, wH: Float = 0.85, wCy: Float = 1.55, wCx: Float = -0.5
        let wBottom = wCy - wH/2, wTop = wCy + wH/2
        let wLeft   = wCx - wW/2, wRight = wCx + wW/2
        let bZ = innerBack - wT/2  // center Z of back wall

        // Panel left of window
        box(wLeft - innerLeft, roomH, wT, color: wallColor,
            pos: SCNVector3(innerLeft + (wLeft - innerLeft)/2, roomH/2, bZ))
        // Panel right of window
        box(innerRight - wRight, roomH, wT, color: wallColor,
            pos: SCNVector3(wRight + (innerRight - wRight)/2, roomH/2, bZ))
        // Panel below window
        box(wW, wBottom, wT, color: wallColor,
            pos: SCNVector3(wCx, wBottom/2, bZ))
        // Panel above window
        box(wW, roomH - wTop, wT, color: wallColor,
            pos: SCNVector3(wCx, wTop + (roomH - wTop)/2, bZ))

        // Window frame (inset from wall face — no Z-fight)
        let wFrameColor = UIColor(red:0.90, green:0.88, blue:0.82, alpha:1)
        let bFaceZ = innerBack - 0.01  // slightly inside room
        let ft: Float = 0.055
        box(wW + ft*2, ft, 0.10, color: wFrameColor, pos: SCNVector3(wCx, wBottom, bFaceZ)) // sill
        box(wW + ft*2, ft, 0.10, color: wFrameColor, pos: SCNVector3(wCx, wTop,    bFaceZ)) // head
        box(ft, wH, 0.10, color: wFrameColor, pos: SCNVector3(wLeft,  wCy, bFaceZ))         // left
        box(ft, wH, 0.10, color: wFrameColor, pos: SCNVector3(wRight, wCy, bFaceZ))         // right
        box(ft*0.5, wH, 0.08, color: wFrameColor, pos: SCNVector3(wCx, wCy, bFaceZ))        // centre bar

        // Window glass
        let glassGeo = SCNBox(width: CGFloat(wW), height: CGFloat(wH), length: 0.008, chamferRadius: 0)
        let glassMat = SCNMaterial()
        glassMat.diffuse.contents  = UIColor(red:0.60, green:0.82, blue:0.98, alpha:1)
        glassMat.transparency      = 0.72
        glassMat.isDoubleSided     = true
        glassMat.lightingModel     = .constant
        glassGeo.materials = [glassMat]
        let glassNode = SCNNode(geometry: glassGeo)
        glassNode.position = SCNVector3(wCx, wCy, innerBack + 0.02)
        scene.rootNode.addChildNode(glassNode)
        vm.glassNode = glassNode

        // ── Outside weather scene — plane behind the window ──
        let outsideW: Float = wW * 2.0   // wider than window for parallax
        let outsideH: Float = wH * 2.2
        let outsidePlane = SCNPlane(width: CGFloat(outsideW), height: CGFloat(outsideH))
        let outsideMat = SCNMaterial()
        // Default clear sky texture until weather loads
        let defaultCondition = WeatherCondition(code: 0, isDay: true, tempC: 30)
        let defaultTOD = TimeOfDay.from(hour: Calendar.current.component(.hour, from: Date()))
        outsideMat.diffuse.contents = WeatherTextureRenderer.draw(
            condition: defaultCondition, size: CGSize(width: 512, height: 320), timeOfDay: defaultTOD)
        outsideMat.lightingModel = .constant  // unaffected by room lights
        outsideMat.isDoubleSided = true
        outsidePlane.materials = [outsideMat]
        let outsideNode = SCNNode(geometry: outsidePlane)
        // Placed outside the room, centred on window
        outsideNode.position = SCNVector3(wCx, wCy, innerBack - wT - 0.05)
        scene.rootNode.addChildNode(outsideNode)
        vm.outsideNode = outsideNode

        // ── Rain particle system — outside window, initially hidden ──
        let rainPS = vm.makeRainParticleSystem(heavy: true)
        let rainNode = SCNNode()
        rainNode.addParticleSystem(rainPS)
        // Emitter sits just above and outside the window, falls down in front of bg plane
        rainNode.position = SCNVector3(wCx, wTop + 0.6, innerBack - wT - 0.04)
        rainNode.isHidden = true   // shown only when weather is rainy
        scene.rootNode.addChildNode(rainNode)
        vm.rainParticleNode = rainNode

        // ── Skirting boards (flush against inner wall face, no overlap) ──
        let skirtColor = UIColor(red:0.80, green:0.72, blue:0.58, alpha:1)
        let sh: Float = 0.09, sd: Float = 0.025
        // left
        box(sd, sh, roomD, color: skirtColor, pos: SCNVector3(innerLeft + sd/2, sh/2, 0))
        // right
        box(sd, sh, roomD, color: skirtColor, pos: SCNVector3(innerRight - sd/2, sh/2, 0))
        // front (split around door)
        box(dLeft - innerLeft, sh, sd, color: skirtColor,
            pos: SCNVector3(innerLeft + (dLeft - innerLeft)/2, sh/2, innerFront - sd/2))
        box(innerRight - dRight, sh, sd, color: skirtColor,
            pos: SCNVector3(dRight + (innerRight - dRight)/2, sh/2, innerFront - sd/2))
        // back (split around window base)
        box(wLeft - innerLeft, sh, sd, color: skirtColor,
            pos: SCNVector3(innerLeft + (wLeft - innerLeft)/2, sh/2, innerBack + sd/2))
        box(innerRight - wRight, sh, sd, color: skirtColor,
            pos: SCNVector3(wRight + (innerRight - wRight)/2, sh/2, innerBack + sd/2))

        scene.rootNode.addChildNode(vm.cameraNode)

        // ── Lighting ──
        let ambient = SCNLight(); ambient.type = .ambient
        ambient.color = UIColor(white: 0.55, alpha: 1)
        let ambNode = SCNNode(); ambNode.light = ambient
        scene.rootNode.addChildNode(ambNode)
        vm.ambientNode = ambNode

        let sun = SCNLight(); sun.type = .directional
        sun.color = UIColor(white: 0.80, alpha: 1)
        sun.castsShadow = true
        sun.shadowMode = .deferred
        sun.shadowSampleCount = 8
        sun.shadowRadius = 3
        let sunNode = SCNNode(); sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/6, 0)
        scene.rootNode.addChildNode(sunNode)

        // Soft window light
        let winLight = SCNLight(); winLight.type = .omni
        winLight.color = UIColor(red:1.0, green:0.97, blue:0.90, alpha:1)
        winLight.intensity = 500
        winLight.attenuationStartDistance = 0.5
        winLight.attenuationEndDistance   = 5.0
        let winLightNode = SCNNode(); winLightNode.light = winLight
        winLightNode.position = SCNVector3(wCx, wCy, innerBack + 0.5)
        scene.rootNode.addChildNode(winLightNode)
        vm.winLightNode = winLightNode

        return scene
    }
}

// MARK: - Hand POV View
struct HandView: View {
    var isWalking: Bool
    @State private var bobOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let handW = W * 0.07    // smaller
            let handH = handW * 2.8 // slim tall oval

            ZStack {
                // Left hand — bottom-left corner, tilted right (~25°)
                SimpleHandShape(isLeft: true)
                    .fill(LinearGradient(
                        colors: [Color(red:0.91,green:0.75,blue:0.61), Color(red:0.70,green:0.55,blue:0.41)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(SimpleHandShape(isLeft: true)
                        .stroke(Color(red:0.50,green:0.36,blue:0.24).opacity(0.5), lineWidth: 1.0))
                    .frame(width: handW, height: handH)
                    .rotationEffect(.degrees(25))   // tilt right
                    .shadow(color: .black.opacity(0.28), radius: 5, x: 3, y: -3)
                    .position(x: handW * 0.55, y: H - handH * 0.18 + bobOffset)

                // Right hand — bottom-right corner, tilted left (~-25°)
                SimpleHandShape(isLeft: false)
                    .fill(LinearGradient(
                        colors: [Color(red:0.91,green:0.75,blue:0.61), Color(red:0.70,green:0.55,blue:0.41)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(SimpleHandShape(isLeft: false)
                        .stroke(Color(red:0.50,green:0.36,blue:0.24).opacity(0.5), lineWidth: 1.0))
                    .frame(width: handW, height: handH)
                    .rotationEffect(.degrees(-25))  // tilt left
                    .shadow(color: .black.opacity(0.28), radius: 5, x: -3, y: -3)
                    .position(x: W - handW * 0.55, y: H - handH * 0.18 - bobOffset)
            }
        }
        .clipped(antialiased: false)
        .allowsHitTesting(false)
        .onAppear { animateBob() }
        .onChange(of: isWalking) { _, _ in animateBob() }
    }

    func animateBob() {
        guard isWalking else {
            withAnimation(.spring(response: 0.3)) { bobOffset = 0 }
            return
        }
        withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
            bobOffset = 10
        }
    }
}

// Slim oval hand shape
struct SimpleHandShape: Shape {
    var isLeft: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Just a slim vertical ellipse — clean and simple
        p.addEllipse(in: rect)
        return p
    }
}

// MARK: - Furniture Catalog Panel
struct FurnitureCatalogView: View {
    @ObservedObject var vm: KostViewModel
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sofa.fill").foregroundStyle(.orange)
                Text("Furnitur").bold().foregroundStyle(.primary)
                Spacer()
                if vm.pendingType != nil {
                    Button(action: { vm.pendingType = nil }) {
                        Label("Batal", systemImage: "xmark.circle")
                            .font(.caption).foregroundStyle(.red)
                    }
                    .padding(.trailing, 6)
                }
                Button(action: { onDismiss?() }) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.title3).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            Divider()

            // Catalog scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FurnitureType.allCases, id: \.self) { ft in
                        let alreadyPlaced = vm.furnitureItems.contains(where: { $0.type == ft })
                        let isSelected = vm.selectedFurniture?.type == ft
                        Button(action: {
                            if alreadyPlaced {
                                // Select the existing item in the scene
                                if let existing = vm.furnitureItems.first(where: { $0.type == ft }) {
                                    vm.selectFurniture(existing)
                                }
                            } else {
                                vm.startPlacing(type: ft)
                            }
                        }) {
                            VStack(spacing: 5) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(ft.tileColor.opacity(
                                            alreadyPlaced ? (isSelected ? 1.0 : 0.55) :
                                            (vm.pendingType == ft ? 1.0 : 0.72)
                                        ))
                                        .frame(width: 54, height: 54)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    isSelected ? Color.yellow :
                                                    (vm.pendingType == ft ? Color.yellow : Color.clear),
                                                    lineWidth: 2.5
                                                )
                                        )
                                        .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 2)
                                    Image(systemName: ft.icon)
                                        .font(.system(size: 22))
                                        .foregroundStyle(.white.opacity(alreadyPlaced ? 0.65 : 1.0))
                                }
                                .overlay(alignment: .topTrailing) {
                                    // Checkmark badge di pojok kanan atas
                                    if alreadyPlaced {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                            .background(Circle().fill(ft.tileColor).padding(-1))
                                            .offset(x: 6, y: -6)
                                    }
                                }
                                Text(ft.rawValue)
                                    .font(.caption2).bold()
                                    .foregroundStyle(alreadyPlaced ? .secondary : .primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }

            // Selected furniture actions
            if let sel = vm.selectedFurniture {
                Divider()
                HStack(spacing: 14) {
                    Image(systemName: sel.type.icon).foregroundStyle(sel.type.tileColor)
                    Text(sel.type.rawValue).bold().foregroundStyle(.primary)
                    Spacer()
                    Button(action: { vm.rotateSelected(by: -.pi/4) }) {
                        Image(systemName: "rotate.left")
                            .font(.title3).foregroundStyle(.blue)
                    }
                    Button(action: { vm.rotateSelected(by: .pi/4) }) {
                        Image(systemName: "rotate.right")
                            .font(.title3).foregroundStyle(.blue)
                    }
                    Button(action: { vm.deleteSelected() }) {
                        Image(systemName: "trash")
                            .font(.title3).foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Furniture Action Bubbles
struct FurnitureActionBubbles: View {
    let selected: FurnitureItem
    var onRotateLeft:  () -> Void
    var onRotateRight: () -> Void
    var onDelete:      () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 14) {
            // Label nama furnitur
            HStack(spacing: 6) {
                Image(systemName: selected.type.icon)
                    .foregroundStyle(selected.type.tileColor)
                Text(selected.type.rawValue)
                    .font(.subheadline).bold()
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            .scaleEffect(appeared ? 1 : 0.6, anchor: .bottomTrailing)
            .opacity(appeared ? 1 : 0)

            // 3 bubble buttons
            HStack(spacing: 14) {
                // Rotate kiri
                BubbleButton(
                    icon: "rotate.left",
                    color: Color(red: 0.25, green: 0.50, blue: 0.95),
                    action: onRotateLeft
                )
                .scaleEffect(appeared ? 1 : 0.4, anchor: .bottomTrailing)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.38, dampingFraction: 0.65).delay(0.05), value: appeared)

                // Rotate kanan
                BubbleButton(
                    icon: "rotate.right",
                    color: Color(red: 0.25, green: 0.50, blue: 0.95),
                    action: onRotateRight
                )
                .scaleEffect(appeared ? 1 : 0.4, anchor: .bottomTrailing)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.38, dampingFraction: 0.65).delay(0.10), value: appeared)

                // Delete
                BubbleButton(
                    icon: "trash",
                    color: Color(red: 0.88, green: 0.22, blue: 0.22),
                    action: onDelete
                )
                .scaleEffect(appeared ? 1 : 0.4, anchor: .bottomTrailing)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.38, dampingFraction: 0.65).delay(0.15), value: appeared)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

struct BubbleButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.opacity(pressed ? 0.95 : 0.82))
                    .frame(width: 58, height: 58)
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1.5))
                    .shadow(color: color.opacity(0.55), radius: pressed ? 4 : 10, x: 0, y: pressed ? 2 : 5)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(pressed ? 0.90 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.08)) { pressed = true } }
                .onEnded   { _ in withAnimation(.spring(response: 0.3)) { pressed = false } }
        )
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var vm = KostViewModel()
    @StateObject private var weatherService = WeatherService()
    @State private var moveDX: CGFloat = 0
    @State private var moveDY: CGFloat = 0
    @State private var rotateDX: CGFloat = 0
    @State private var lastLookX: CGFloat = 0
    @State private var currentTime: Date = Date()
    @State private var lastTODHour: Int = -1
    @State private var showCatalog: Bool = false
    /// Simpan state katalog sebelum item di-select, supaya bisa di-restore saat deselect
    @State private var catalogWasOpen: Bool = false

    let timer      = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()
    let clockTimer = Timer.publish(every: 1.0,      on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // ── 3D Scene ──
            SceneView(vm: vm).ignoresSafeArea()

            // ── Swipe-to-look (right half of screen) ──
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { v in
                                guard v.startLocation.x > geo.size.width / 2 else { return }
                                let delta = v.translation.width - lastLookX
                                rotateDX = delta / geo.size.width * 6.0
                                lastLookX = v.translation.width
                            }
                            .onEnded { _ in rotateDX = 0; lastLookX = 0 }
                    )
            }
            .ignoresSafeArea()
            .allowsHitTesting(!showCatalog)

            // ── Hands ──
            HandView(isWalking: vm.isWalking).ignoresSafeArea()
                .allowsHitTesting(false)

            // ── Placement hint pill ──
            if let pending = vm.pendingType {
                Text("🫳 Tap lantai untuk meletakkan \(pending.rawValue)")
                    .font(.subheadline).bold().foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 72)
                    .allowsHitTesting(false)
            }

            // ── Bottom controls ──
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    // Joystick — kiri (hidden saat placing)
                    if vm.pendingType == nil {
                        JoystickView(size: 130) { dx, dy in
                            moveDX = dx; moveDY = dy
                        } onEnd: {
                            moveDX = 0; moveDY = 0
                        }
                        .padding(.leading, 28).padding(.bottom, 32)
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottomLeading)))
                    }

                    Spacer()

                    // Tombol furnitur — kanan (hidden saat placing atau ada item selected)
                    if vm.pendingType == nil && vm.selectedFurniture == nil {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                showCatalog.toggle()
                                if !showCatalog {
                                    vm.pendingType = nil
                                    vm.selectFurniture(nil)
                                }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(showCatalog ? Color.orange : Color.white.opacity(0.92))
                                    .frame(width: 60, height: 60)
                                    .shadow(color: .black.opacity(0.30), radius: 8, x: 0, y: 4)
                                Image(systemName: showCatalog ? "xmark" : "sofa.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(showCatalog ? .white : .black)
                            }
                        }
                        .padding(.trailing, 28).padding(.bottom, 32)
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottomTrailing)))
                    }
                }

                // ── Furniture catalog panel ──
                if showCatalog && vm.pendingType == nil && vm.selectedFurniture == nil {
                    FurnitureCatalogView(vm: vm, onDismiss: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            showCatalog = false
                            vm.pendingType = nil
                            vm.selectFurniture(nil)
                        }
                    })
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // ── Action bubbles — muncul di kanan bawah saat ada item terselect ──
            if let sel = vm.selectedFurniture, vm.pendingType == nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FurnitureActionBubbles(
                            selected: sel,
                            onRotateLeft:  { vm.rotateSelected(by: -.pi/4) },
                            onRotateRight: { vm.rotateSelected(by:  .pi/4) },
                            onDelete: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    vm.deleteSelected()
                                }
                            }
                        )
                        .padding(.trailing, 24)
                        .padding(.bottom, 40)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(true)
            }

            // ── Top bar ──
            VStack {
                HStack(alignment: .top) {
                    WeatherBadgeView(condition: vm.weather, error: weatherService.errorMessage)
                        .padding(.top, 16).padding(.leading, 20)
                    Spacer()
                    ClockView(date: currentTime)
                        .padding(.top, 16)
                    Spacer()
                    Color.clear.frame(width: 100, height: 1)
                        .padding(.trailing, 20)
                }
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            // Wire selection callback
            vm.onSelectionChanged = { item in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    if item != nil {
                        // Simpan state katalog lalu tutup
                        catalogWasOpen = showCatalog
                        showCatalog = false
                    } else {
                        // Restore state katalog sebelumnya
                        showCatalog = catalogWasOpen
                    }
                }
            }
            weatherService.fetch()
            lastTODHour = Calendar.current.component(.hour, from: Date())
        }
        .onReceive(timer) { _ in
            if abs(moveDX) > 0.02 || abs(moveDY) > 0.02 {
                vm.move(dx: Float(moveDX), dy: Float(moveDY))
            }
            if abs(rotateDX) > 0.001 {
                vm.rotateCamera(by: Float(rotateDX))
                rotateDX = 0
            }
        }
        .onReceive(clockTimer) { date in
            currentTime = date
            let hour = Calendar.current.component(.hour, from: date)
            if hour != lastTODHour {
                lastTODHour = hour
                vm.applyTimeOfDay()
            }
        }
        .onReceive(weatherService.$condition.compactMap { $0 }) { w in
            vm.applyWeather(w)
        }
    }
}

// MARK: - Clock View
struct ClockView: View {
    var date: Date

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "EEE, d MMM"
        return f.string(from: date)
    }

    private var tod: TimeOfDay {
        TimeOfDay.from(hour: Calendar.current.component(.hour, from: date))
    }

    private var todIcon: String {
        switch tod {
        case .day:   return "sun.max.fill"
        case .dusk:  return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    private var todColor: Color {
        switch tod {
        case .day:   return .yellow
        case .dusk:  return .orange
        case .night: return Color(red: 0.6, green: 0.7, blue: 1.0)
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: todIcon)
                    .font(.caption.bold())
                    .foregroundStyle(todColor)
                Text(timeString)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            Text(dateString)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Weather Badge
struct WeatherBadgeView: View {
    var condition: WeatherCondition?
    var error: String?

    var body: some View {
        HStack(spacing: 6) {
            if let w = condition {
                Text(w.label)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Text("· \(Int(w.tempC))°C")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Text("· Tangerang")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            } else if error != nil {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text("Cuaca offline")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.white)
                Text("Memuat cuaca…")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

#Preview {
    ContentView()
}
