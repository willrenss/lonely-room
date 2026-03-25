import Foundation

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
