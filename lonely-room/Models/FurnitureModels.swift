import SwiftUI
import SceneKit

// MARK: - Furniture Type
enum FurnitureType: String, CaseIterable, Codable {
    case bed       = "Kasur"
    case desk      = "Meja"
    case wardrobe  = "Lemari"
    case tv        = "TV"
    case plant     = "Tanaman"
    case rug       = "Karpet"
    case lamp      = "Lampu"
    case bag       = "Tas"
    case wallClock   = "Jam Dinding"
    case musicPlayer = "Radio"
    case chair       = "Kursi"
    case cat         = "Kucing"
    case dog         = "Anjing"
    case customImage = "Foto / Poster"
    case custom3D    = "Scan 3D Objek"
    case aiGenerated = "Buat AI 3D"

    var icon: String {
        switch self {
        case .bed:       return "bed.double.fill"
        case .desk:      return "desktopcomputer"
        case .wardrobe:  return "cabinet.fill"
        case .tv:        return "tv.fill"
        case .plant:     return "leaf.fill"
        case .rug:       return "rectangle.fill"
        case .lamp:      return "lamp.floor.fill"
        case .bag:       return "bag.fill"
        case .wallClock: return "clock.fill"
        case .musicPlayer: return "radio.fill"
        case .chair:       return "chair.lounge.fill"
        case .cat:         return "pawprint.fill"
        case .dog:         return "dog.fill"
        case .customImage: return "camera.fill"
        case .custom3D:    return "arkit"
        case .aiGenerated: return "sparkles"
        }
    }

    var tileColor: Color {
        switch self {
        case .bed:       return Color(red:0.20, green:0.40, blue:0.70)
        case .desk:      return Color(red:0.60, green:0.40, blue:0.20)
        case .wardrobe:  return Color(red:0.40, green:0.25, blue:0.10)
        case .tv:        return Color(red:0.20, green:0.20, blue:0.20)
        case .plant:     return Color(red:0.15, green:0.55, blue:0.15)
        case .rug:       return Color(red:0.65, green:0.15, blue:0.15)
        case .lamp:      return Color(red:0.70, green:0.60, blue:0.20)
        case .bag:       return Color(red:0.15, green:0.15, blue:0.55)
        case .wallClock: return Color(red:0.45, green:0.28, blue:0.12)
        case .musicPlayer: return Color(red:0.15, green:0.35, blue:0.55)
        case .chair:       return Color(red:0.45, green:0.30, blue:0.15)
        case .cat:         return Color.orange
        case .dog:         return Color.brown
        case .customImage: return Color.purple
        case .custom3D:    return Color(red:0.10, green:0.75, blue:0.85)
        case .aiGenerated: return Color.purple
        }
    }

    var footprint: CGSize {
        switch self {
        case .bed:       return CGSize(width:1.1, height:2.0)
        case .desk:      return CGSize(width:1.2, height:0.6)
        case .wardrobe:  return CGSize(width:1.0, height:0.5)
        case .tv:        return CGSize(width:1.1, height:0.4)
        case .plant:     return CGSize(width:0.4, height:0.4)
        case .rug:       return CGSize(width:2.0, height:1.4)
        case .lamp:      return CGSize(width:0.3, height:0.3)
        case .bag:       return CGSize(width:0.4, height:0.2)
        case .wallClock: return CGSize(width:0.35, height:0.05) // tipis karena di dinding
        case .musicPlayer: return CGSize(width:0.40, height:0.28)
        case .chair:       return CGSize(width:0.55, height:0.55)
        case .cat:         return CGSize(width:0.3, height:0.3)
        case .dog:         return CGSize(width:0.4, height:0.6)
        case .customImage: return CGSize(width:0.6, height:0.02)
        case .custom3D:    return CGSize(width:0.4, height:0.4)
        case .aiGenerated: return CGSize(width:0.4, height:0.4)
        }
    }

    var topHeight: Float {
        switch self {
        case .bed:       return 0.48
        case .desk:      return 0.745
        case .wardrobe:  return 1.80
        case .tv:        return 0.04
        case .plant:     return 0.55
        case .rug:       return 0.02
        case .lamp:      return 0.04
        case .bag:       return 0.28
        case .wallClock: return 0.0
        case .musicPlayer: return 0.32
        case .chair:       return 0.46
        case .cat:         return 0.2
        case .dog:         return 0.3
        case .customImage: return 0.6
        case .custom3D:    return 0.4
        case .aiGenerated: return 0.4
        }
    }

    var isWallMounted: Bool { self == .wallClock }

    var allowsMultiple: Bool {
        switch self {
        case .lamp, .plant, .rug, .bag, .wallClock, .musicPlayer, .chair, .cat, .dog, .customImage, .custom3D, .aiGenerated: return true
        default: return false
        }
    }

    var stackSize: Float {
        Float(footprint.width) * Float(footprint.height)
    }

    func canStack(_ other: FurnitureType) -> Bool {
        guard self != .rug, self != .lamp, self != .tv, self != .wallClock,
              self != .musicPlayer, self != .chair, self != .cat, self != .dog, self != .customImage, self != .custom3D, self != .aiGenerated else { return false }
        guard !other.isWallMounted else { return false }
        return stackSize > other.stackSize
    }
}

// MARK: - Furniture Item
struct FurnitureItem {
    let id   = UUID() // Always unique
    let type: FurnitureType
    var position: SCNVector3
    var node: SCNNode
    var savedID: UUID? = nil
    var stackedOnID: UUID? = nil
    var stackedItemID: UUID? = nil
    var customImagePath: String? = nil // Local path for custom photo
    var custom3DPath: String? = nil    // Local path for 3D scan USDZ
}
