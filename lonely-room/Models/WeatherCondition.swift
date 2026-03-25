import SwiftUI
import UIKit

// MARK: - Weather Condition
struct WeatherCondition {
    let code: Int       // WMO weather code
    let isDay: Bool
    let tempC: Double

    // Glass / sky color seen through window
    var glassColor: UIColor {
        switch code {
        case 0:
            return isDay
                ? UIColor(red:0.52, green:0.78, blue:0.98, alpha:1)
                : UIColor(red:0.05, green:0.07, blue:0.20, alpha:1)
        case 1, 2:
            return isDay
                ? UIColor(red:0.60, green:0.80, blue:0.98, alpha:1)
                : UIColor(red:0.07, green:0.09, blue:0.22, alpha:1)
        case 3:
            return UIColor(red:0.70, green:0.73, blue:0.78, alpha:1)
        case 45, 48:
            return UIColor(red:0.82, green:0.82, blue:0.84, alpha:1)
        case 51, 53, 55, 61, 63, 65, 80, 81, 82:
            return UIColor(red:0.50, green:0.60, blue:0.75, alpha:1)
        case 71, 73, 75, 77:
            return UIColor(red:0.88, green:0.92, blue:0.98, alpha:1)
        case 95, 96, 99:
            return UIColor(red:0.30, green:0.32, blue:0.40, alpha:1)
        default:
            return UIColor(red:0.60, green:0.82, blue:0.98, alpha:1)
        }
    }

    /// Returns a copy with isDay overridden by the given TimeOfDay.
    func applying(timeOfDay tod: TimeOfDay) -> WeatherCondition {
        WeatherCondition(code: code, isDay: tod.isDay, tempC: tempC)
    }

    var glassTransparency: CGFloat {
        switch code {
        case 0, 1:       return 0.82
        case 2:          return 0.78
        case 3:          return 0.70
        case 45, 48:     return 0.65
        case 95, 96, 99: return 0.55
        default:         return 0.72
        }
    }

    var icon: String {
        switch code {
        case 0:          return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1:          return isDay ? "sun.min.fill" : "moon.fill"
        case 2:          return "cloud.sun.fill"
        case 3:          return "cloud.fill"
        case 45, 48:     return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77: return "snowflake"
        case 95:         return "cloud.bolt.fill"
        case 96, 99:     return "cloud.bolt.rain.fill"
        default:         return "thermometer.medium"
        }
    }

    var iconColor: UIColor {
        switch code {
        case 0:          return isDay ? UIColor.systemYellow : UIColor(red:0.7,green:0.8,blue:1,alpha:1)
        case 1:          return isDay ? UIColor.systemYellow : UIColor(red:0.7,green:0.8,blue:1,alpha:1)
        case 2:          return UIColor(red:0.6,green:0.75,blue:1,alpha:1)
        case 3:          return UIColor(red:0.7,green:0.72,blue:0.76,alpha:1)
        case 45, 48:     return UIColor(red:0.75,green:0.75,blue:0.78,alpha:1)
        case 51, 53, 55: return UIColor(red:0.5,green:0.7,blue:0.95,alpha:1)
        case 61, 63, 65: return UIColor(red:0.4,green:0.6,blue:0.9,alpha:1)
        case 80, 81, 82: return UIColor(red:0.3,green:0.5,blue:0.85,alpha:1)
        case 71, 73, 75, 77: return UIColor(red:0.8,green:0.9,blue:1,alpha:1)
        case 95, 96, 99: return UIColor(red:0.8,green:0.75,blue:0.4,alpha:1)
        default:         return UIColor.white
        }
    }

    var labelText: String {
        switch code {
        case 0:          return isDay ? "Cerah" : "Malam Cerah"
        case 1:          return "Mostly Clear"
        case 2:          return "Berawan Sebagian"
        case 3:          return "Mendung"
        case 45, 48:     return "Berkabut"
        case 51, 53, 55: return "Gerimis"
        case 61, 63, 65: return "Hujan"
        case 80, 81, 82: return "Hujan Lebat"
        case 71...77:    return "Salju"
        case 95:         return "Badai"
        case 96, 99:     return "Badai Petir"
        default:         return "\(Int(tempC))°C"
        }
    }

    var label: String { labelText }

    var ambientIntensity: CGFloat {
        switch code {
        case 0, 1:       return isDay ? 0.95 : 0.70
        case 2:          return isDay ? 0.90 : 0.65
        case 3:          return 0.82
        case 45, 48:     return 0.78
        case 95, 96, 99: return 0.70
        default:         return 0.80
        }
    }
}


