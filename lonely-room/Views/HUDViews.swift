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
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Text("·")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
            Text(dateString)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 13).padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
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
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
                Text("\(Int(w.tempC))°C")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
                Text("Tangsel")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            } else if error != nil {
                Image(systemName: "wifi.slash")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                Text("Cuaca offline")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
            } else {
                ProgressView().scaleEffect(0.65).tint(.white)
                Text("Memuat cuaca…")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
    }
}
