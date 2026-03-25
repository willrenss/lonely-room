import SwiftUI

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
        HStack(spacing: 6) {
            Image(systemName: todIcon)
                .font(.caption.bold())
                .foregroundStyle(todColor)
            Text(timeString)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Text("·")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
            Text(dateString)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Weather Badge View
struct WeatherBadgeView: View {
    var condition: WeatherCondition?
    var error: String?

    var body: some View {
        HStack(spacing: 6) {
            if let w = condition {
                Image(systemName: w.icon)
                    .font(.caption.bold())
                    .foregroundStyle(Color(w.iconColor))
                Text(w.labelText)
                    .font(.caption.bold()).foregroundStyle(.white)
                Text("· \(Int(w.tempC))°C")
                    .font(.caption).foregroundStyle(.white.opacity(0.8))
                Text("· Tangerang")
                    .font(.caption2).foregroundStyle(.white.opacity(0.6))
            } else if error != nil {
                Image(systemName: "wifi.slash")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                Text("Cuaca offline")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
            } else {
                ProgressView().scaleEffect(0.7).tint(.white)
                Text("Memuat cuaca…")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
