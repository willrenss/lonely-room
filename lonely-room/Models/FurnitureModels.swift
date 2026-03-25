import SwiftUI
import SceneKit

// MARK: - Furniture Type
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

// MARK: - Furniture Item
struct FurnitureItem {
    let id   = UUID()
    let type: FurnitureType
    var position: SCNVector3
    var node: SCNNode
}
