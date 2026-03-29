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

// MARK: - Music Player Panel
struct MusicPlayerPanel: View {
    @ObservedObject var music = MusicPlayer.shared

    var body: some View {
        VStack(spacing: 0) {

            // ── Info ──
            HStack(spacing: 12) {
                // Icon radio
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                    Image(systemName: "radio")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(music.currentTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if music.queueCount > 0 {
                        Text("Track \(music.queueIndex + 1) / \(music.queueCount)")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        Text("Tidak ada lagu di asset")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // ── Progress bar ──
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15)).frame(height: 3)
                    Capsule().fill(Color.white.opacity(0.7))
                        .frame(width: geo.size.width * CGFloat(music.progress), height: 3)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            // ── Controls ──
            HStack(spacing: 0) {
                Spacer()
                Button { music.previous() } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .padding(12)
                }
                .buttonStyle(.plain)
                .disabled(music.queueCount == 0)

                Spacer()

                Button { music.togglePlayPause() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(music.queueCount == 0)

                Spacer()

                Button { music.next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .padding(12)
                }
                .buttonStyle(.plain)
                .disabled(music.queueCount == 0)

                Spacer()

                // Repeat button
                Button { music.toggleRepeat() } label: {
                    Image(systemName: "repeat")
                        .font(.system(size: 16, weight: music.isRepeating ? .bold : .regular))
                        .foregroundStyle(music.isRepeating ? Color.yellow : Color.white.opacity(0.5))
                        .padding(10)
                        .background(
                            Circle()
                                .fill(music.isRepeating ? Color.yellow.opacity(0.2) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .disabled(music.queueCount == 0)

                Spacer()
            }
            .padding(.bottom, 10)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
        .frame(width: 260)
    }
}

// MARK: - Light Switch Panel
struct LightSwitchPanel: View {
    @ObservedObject var vm: KostViewModel
    @State private var sliderValue: Float = 0.85

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: vm.isLightOn ? "lightbulb.fill" : "lightbulb.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(vm.isLightOn ? Color.yellow : Color.white.opacity(0.5))
                Text("Lampu Kamar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) { vm.toggleLight() }
                } label: {
                    ZStack {
                        Capsule()
                            .fill(vm.isLightOn ? Color.yellow.opacity(0.85) : Color.white.opacity(0.15))
                            .frame(width: 48, height: 26)
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                            .offset(x: vm.isLightOn ? 10 : -10)
                            .shadow(radius: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            if vm.isLightOn {
                HStack(spacing: 8) {
                    Image(systemName: "sun.min.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                    Slider(value: Binding(
                        get: { Double(vm.roomBrightness) },
                        set: { vm.setBrightness(Float($0)) }
                    ), in: 0.05...1.0)
                    .tint(.yellow)
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        .frame(width: 220)
        .onAppear { sliderValue = vm.roomBrightness }
    }
}
