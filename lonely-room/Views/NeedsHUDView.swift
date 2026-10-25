import SwiftUI

// MARK: - Needs HUD
/// Ringkasan Energi / Mood / Tanaman + streak. Tap untuk detail.
struct NeedsHUDView: View {
    @ObservedObject var needs: NeedsStore
    var hasPlant: Bool
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Haptics.select()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    NeedMeter(icon: "bolt.fill", value: needs.energy, tint: .yellow)
                    NeedMeter(icon: "face.smiling.inverse", value: needs.mood, tint: .pink)
                    if hasPlant {
                        NeedMeter(icon: "leaf.fill", value: needs.plant, tint: .green)
                    }
                    if needs.streak > 1 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill").foregroundStyle(.orange)
                            Text("\(needs.streak)").monospacedDigit()
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color.hudFill, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Status: energi \(Int(needs.energy)) persen, mood \(Int(needs.mood)) persen\(hasPlant ? ", tanaman \(Int(needs.plant)) persen" : "")")
            .accessibilityHint("Ketuk untuk detail")

            if expanded {
                NeedsDetailCard(needs: needs, hasPlant: hasPlant)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let toast = needs.toast {
                Label(toast.text, systemImage: toast.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.green.opacity(0.75), in: Capsule())
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .id(toast.id)
                    .task(id: toast.id) {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        withAnimation(.easeOut(duration: 0.3)) {
                            if needs.toast?.id == toast.id { needs.toast = nil }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: needs.toast)
    }
}

// MARK: - Meter
private struct NeedMeter: View {
    let icon: String
    let value: Double
    let tint: Color

    private var color: Color { value < 25 ? .red : tint }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule().fill(color)
                    .frame(width: 34 * CGFloat(max(0.04, value / 100)))
            }
            .frame(width: 34, height: 5)
        }
    }
}

// MARK: - Detail Card
private struct NeedsDetailCard: View {
    @ObservedObject var needs: NeedsStore
    var hasPlant: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(needs.moodEmoji).font(.title3)
                Text(needs.hint)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider().overlay(Color.white.opacity(0.2))
            row("bolt.fill", "Energi", "\(Int(needs.energy))%", .yellow)
            row("face.smiling.inverse", "Mood", "\(Int(needs.mood))%", .pink)
            if hasPlant { row("leaf.fill", "Tanaman", "\(Int(needs.plant))%", .green) }
            row("flame.fill", "Streak", "\(needs.streak) hari", .orange)
            row("timer", "Fokus hari ini", "\(needs.focusMinutesToday) mnt · \(needs.focusSessionsToday) sesi", .cyan)
        }
        .padding(12)
        .frame(width: 250, alignment: .leading)
        .background(Color.hudFill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
    }

    private func row(_ icon: String, _ title: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 16)
            Text(title).foregroundStyle(.white.opacity(0.75))
            Spacer()
            Text(value).foregroundStyle(.white).monospacedDigit()
        }
        .font(.system(size: 12, weight: .semibold))
    }
}
