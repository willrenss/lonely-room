import Foundation
import Combine
import UserNotifications
import AudioToolbox

// MARK: - Focus Timer (Pomodoro)
/// Timer berbasis tanggal-akhir (bukan hitung mundur per detik) sehingga tetap akurat
/// walau app di-background. Notifikasi lokal dijadwalkan untuk akhir tiap fase.
final class FocusTimer: ObservableObject {
    enum Phase: Equatable {
        case idle, focus, rest

        var title: String {
            switch self {
            case .idle:  return "Siap fokus"
            case .focus: return "Fokus"
            case .rest:  return "Istirahat"
            }
        }
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var total: TimeInterval = 1
    @Published private(set) var isPaused = false
    @Published private(set) var cyclesCompleted = 0

    /// Dipanggil saat sesi fokus selesai penuh (menit).
    var onFocusCompleted: ((Int) -> Void)?

    private var endDate: Date?
    private var ticker: Timer?
    private var focusMinutes = 25
    private static let notificationID = "focus.phase.end"

    var isActive: Bool { phase != .idle }

    var progress: Double {
        guard total > 0 else { return 0 }
        return 1 - remaining / total
    }

    var remainingText: String {
        let s = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    // MARK: - Control

    func startFocus(minutes: Int) {
        focusMinutes = minutes
        requestNotificationPermissionIfNeeded()
        begin(.focus, duration: TimeInterval(minutes * 60))
        Haptics.thump()
    }

    func pause() {
        guard isActive, !isPaused, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        isPaused = true
        endDate = nil
        ticker?.invalidate(); ticker = nil
        cancelNotification()
    }

    func resume() {
        guard isActive, isPaused else { return }
        isPaused = false
        endDate = Date().addingTimeInterval(remaining)
        startTicker()
        scheduleNotification()
    }

    func stop() {
        ticker?.invalidate(); ticker = nil
        cancelNotification()
        phase = .idle
        isPaused = false
        endDate = nil
        remaining = 0
    }

    func skipRest() {
        guard phase == .rest else { return }
        stop()
    }

    /// Hitung ulang sisa waktu (mis. saat kembali dari background).
    func refresh() {
        guard isActive, !isPaused, let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0 { phaseFinished() }
    }

    // MARK: - Private

    private func begin(_ p: Phase, duration: TimeInterval) {
        phase = p
        total = duration
        remaining = duration
        isPaused = false
        endDate = Date().addingTimeInterval(duration)
        startTicker()
        scheduleNotification()
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        ticker?.tolerance = 0.1
    }

    private func phaseFinished() {
        ticker?.invalidate(); ticker = nil
        AudioServicesPlaySystemSound(1013)
        Haptics.success()
        switch phase {
        case .focus:
            cyclesCompleted += 1
            onFocusCompleted?(focusMinutes)
            begin(.rest, duration: TimeInterval(AppSettings.shared.breakMinutes * 60))
        case .rest:
            stop()
        case .idle:
            break
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermissionIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    private func scheduleNotification() {
        guard let end = endDate else { return }
        let content = UNMutableNotificationContent()
        switch phase {
        case .focus:
            content.title = "Sesi fokus selesai 🎉"
            content.body  = "Kerja bagus! Waktunya istirahat \(AppSettings.shared.breakMinutes) menit."
        case .rest:
            content.title = "Istirahat selesai"
            content.body  = "Siap lanjut fokus lagi? Kursimu menunggu."
        case .idle:
            return
        }
        content.sound = .default
        let interval = max(1, end.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }
}
