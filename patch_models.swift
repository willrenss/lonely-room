import Foundation

let path = "lonely-room/Models/FurnitureModels.swift"
var c = try! String(contentsOfFile: path)

c = c.replacingOccurrences(of: "case custom3D    = \"Scan 3D Objek\"", with: "case custom3D    = \"Scan 3D Objek\"\n    case aiGenerated = \"Buat AI 3D\"")
c = c.replacingOccurrences(of: "case .custom3D:    return \"arkit\"", with: "case .custom3D:    return \"arkit\"\n        case .aiGenerated: return \"sparkles\"")
c = c.replacingOccurrences(of: "case .custom3D:    return Color(red:0.10, green:0.75, blue:0.85)", with: "case .custom3D:    return Color(red:0.10, green:0.75, blue:0.85)\n        case .aiGenerated: return Color.purple")
c = c.replacingOccurrences(of: "case .custom3D:    return CGSize(width:0.4, height:0.4)", with: "case .custom3D:    return CGSize(width:0.4, height:0.4)\n        case .aiGenerated: return CGSize(width:0.4, height:0.4)")
c = c.replacingOccurrences(of: "case .custom3D:    return 0.4\n        }", with: "case .custom3D:    return 0.4\n        case .aiGenerated: return 0.4\n        }")
c = c.replacingOccurrences(of: "case .lamp, .plant, .rug, .bag, .wallClock, .musicPlayer, .chair, .cat, .dog, .customImage, .custom3D: return true", with: "case .lamp, .plant, .rug, .bag, .wallClock, .musicPlayer, .chair, .cat, .dog, .customImage, .custom3D, .aiGenerated: return true")
c = c.replacingOccurrences(of: "self != .customImage, self != .custom3D else { return false }", with: "self != .customImage, self != .custom3D, self != .aiGenerated else { return false }")

try! c.write(toFile: path, atomically: true, encoding: .utf8)
