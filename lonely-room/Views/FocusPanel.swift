import SwiftUI

// MARK: - Focus Panel (Pomodoro)
/// Muncul di tengah atas selama sesi fokus/istirahat berjalan.
struct FocusPanel: View {
    @ObservedObject var focus: FocusTimer
    var isSitting: Bool

    private var tint: Color { focus.phase == .rest ? .green : .orange }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: focus.progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: focus.progress)
                Image(systemName: focus.phase == .rest ? "cup.and.saucer.fill" : "brain.head.profile")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(focus.remainingText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 6) {
                if focus.phase == .focus {
                    circleButton(focus.isPaused ? "play.fill" : "pause.fill",
                                 label: focus.isPaused ? "Lanjutkan" : "Jeda") {
                        focus.isPaused ? focus.resume() : focus.pause()
                    }
                } else if focus.phase == .rest {
                    circleButton("forward.end.fill", label: "Lewati istirahat") { focus.skipRest() }
                }
                circleButton("xmark", label: "Akhiri sesi") {
                    Haptics.warning()
                    withAnimation(.spring(response: 0.35)) { focus.stop() }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.hudFill, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(tint.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .contain)
    }

    private var statusText: String {
        if focus.phase == .focus && focus.isPaused {
            return isSitting ? "Dijeda" : "Dijeda — duduk lagi untuk lanjut"
        }
        return focus.phase == .focus ? "Fokus · sesi \(focus.cyclesCompleted + 1)" : "Istirahat sebentar"
    }

    private func circleButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(); action() }) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Focus Start Sheet
/// Pilihan durasi cepat sebelum mulai fokus.
struct FocusStartCard: View {
    @ObservedObject var settings = AppSettings.shared
    var onStart: (Int) -> Void
    var onCancel: () -> Void

    private let presets = [15, 25, 45, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Sesi Fokus", systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tutup")
            }

            Text("Istirahat \(settings.breakMinutes) menit setelah sesi selesai.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { m in
                    Button {
                        Haptics.select()
                        settings.focusMinutes = m
                    } label: {
                        Text("\(m) mnt")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(settings.focusMinutes == m ? Color.orange.opacity(0.85) : Color.white.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            Toggle(isOn: $settings.autoLofiOnFocus) {
                Label("Putar lofi otomatis", systemImage: "music.note")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }
            .tint(.orange)

            Button {
                onStart(settings.focusMinutes)
            } label: {
                Text("Mulai \(settings.focusMinutes) menit")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(width: 340)
        .background(Color.hudFill, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 14, x: 0, y: 6)
    }
}
