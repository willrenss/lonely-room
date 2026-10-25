import Foundation
import Combine

// MARK: - Needs Context
/// Snapshot kondisi kamar yang mempengaruhi kebutuhan karakter.
struct NeedsContext {
    var isLyingDown   = false
    var isWalking     = false
    var isFocusing    = false
    var musicPlaying  = false
    var windowOpen    = false
    var niceWeather   = false
    var roomIsDim     = false
}

// MARK: - Needs Store
/// Statistik Energi, Mood, dan Tanaman + streak harian & statistik fokus.
/// Semua nilai 0...100. Berkurang perlahan secara real-time (termasuk saat app ditutup,
/// tapi dengan batas bawah supaya tidak menghukum user yang jarang buka).
final class NeedsStore: ObservableObject {
    @Published private(set) var energy: Double
    @Published private(set) var mood:   Double
    @Published private(set) var plant:  Double
    @Published private(set) var streak: Int
    @Published private(set) var focusMinutesToday:  Int
    @Published private(set) var focusSessionsToday: Int
    @Published private(set) var focusMinutesTotal:  Int
    /// Feedback singkat ("+8 Mood") untuk ditampilkan HUD.
    @Published var toast: NeedsToast?

    private let defaults = UserDefaults.standard
    private var lastUpdate: Date

    // Laju per menit (in-app)
    private enum Rate {
        static let energyRestLying: Double  = 6.0
        static let energyRestDimBonus: Double = 3.0
        static let energyDrainIdle: Double  = 0.25
        static let energyDrainWalk: Double  = 0.6
        static let energyDrainFocus: Double = 0.5
        static let moodMusic: Double        = 1.5
        static let moodNiceWindow: Double   = 1.0
        static let moodDecay: Double        = 0.35
        static let moodTiredPenalty: Double = 0.5
        /// Tanaman kering dari 100 → 0 dalam ±36 jam.
        static let plantDecay: Double       = 100.0 / (36 * 60)
    }

    private enum Keys {
        static let energy   = "needs.energy"
        static let mood     = "needs.mood"
        static let plant    = "needs.plant"
        static let streak   = "needs.streak"
        static let lastDay  = "needs.lastDay"
        static let last     = "needs.lastUpdate"
        static let focusDay = "needs.focusDay"
        static let focusMin = "needs.focusMinutes"
        static let focusCnt = "needs.focusSessions"
        static let focusTot = "needs.focusTotal"
    }

    init() {
        let d = UserDefaults.standard
        d.register(defaults: [Keys.energy: 80.0, Keys.mood: 70.0, Keys.plant: 80.0])
        energy = d.double(forKey: Keys.energy)
        mood   = d.double(forKey: Keys.mood)
        plant  = d.double(forKey: Keys.plant)
        streak = d.integer(forKey: Keys.streak)
        focusMinutesTotal = d.integer(forKey: Keys.focusTot)
        lastUpdate = (d.object(forKey: Keys.last) as? Date) ?? Date()

        let today = Self.dayKey(Date())
        if d.string(forKey: Keys.focusDay) == today {
            focusMinutesToday  = d.integer(forKey: Keys.focusMin)
            focusSessionsToday = d.integer(forKey: Keys.focusCnt)
        } else {
            focusMinutesToday  = 0
            focusSessionsToday = 0
        }

        applyOfflineDecay()
        updateStreak()
        persist()
    }

    // MARK: - Labels

    var moodEmoji: String {
        switch mood {
        case 80...:   return "😄"
        case 55..<80: return "🙂"
        case 30..<55: return "😐"
        default:      return "😔"
        }
    }

    var hint: String {
        if plant < 30  { return "Tanamanmu layu — siram ya!" }
        if energy < 25 { return "Capek nih. Rebahan dulu di kasur." }
        if mood < 35   { return "Putar radio atau main sama hewan peliharaan." }
        if focusSessionsToday == 0 { return "Duduk di kursi untuk mulai sesi fokus." }
        return "Kamu lagi on fire hari ini!"
    }

    // MARK: - Ticking

    /// Dipanggil berkala oleh view model (mis. tiap 5 detik).
    func tick(seconds: TimeInterval, context c: NeedsContext) {
        let m = seconds / 60

        var dEnergy: Double
        if c.isLyingDown {
            dEnergy = Rate.energyRestLying + (c.roomIsDim ? Rate.energyRestDimBonus : 0)
        } else {
            dEnergy = -(c.isWalking ? Rate.energyDrainWalk : Rate.energyDrainIdle)
        }
        if c.isFocusing { dEnergy -= Rate.energyDrainFocus }

        var dMood = -Rate.moodDecay
        if c.musicPlaying { dMood += Rate.moodMusic }
        if c.windowOpen && c.niceWeather { dMood += Rate.moodNiceWindow }
        if energy < 20 { dMood -= Rate.moodTiredPenalty }

        energy = clamp(energy + dEnergy * m)
        mood   = clamp(mood + dMood * m)
        plant  = clamp(plant - Rate.plantDecay * m)
        lastUpdate = Date()
        rolloverDayIfNeeded()
        persist()
    }

    // MARK: - Events

    func petInteraction() { boost(mood: 6, label: "Mood", icon: "pawprint.fill") }

    func wateredPlant() {
        let gained = Int(100 - plant)
        plant = 100
        boost(mood: 3, label: gained > 0 ? "Tanaman segar" : "Mood", icon: "leaf.fill")
    }

    func focusCompleted(minutes: Int) {
        rolloverDayIfNeeded()
        focusMinutesToday  += minutes
        focusSessionsToday += 1
        focusMinutesTotal  += minutes
        energy = clamp(energy - Double(minutes) * 0.2)
        boost(mood: 10, label: "Sesi fokus selesai", icon: "checkmark.seal.fill")
    }

    func resetAll() {
        energy = 80; mood = 70; plant = 80
        focusMinutesToday = 0; focusSessionsToday = 0; focusMinutesTotal = 0
        streak = 1
        persist()
    }

    // MARK: - Private

    private func boost(mood amount: Double, label: String, icon: String) {
        mood = clamp(mood + amount)
        toast = NeedsToast(text: "\(label) +\(Int(amount))", icon: icon)
        persist()
    }

    private func applyOfflineDecay() {
        let hours = max(0, Date().timeIntervalSince(lastUpdate) / 3600)
        guard hours > 0.05 else { return }
        // Saat app ditutup diasumsikan karakter juga istirahat — energi & mood turun pelan
        // dengan batas bawah, tanaman tetap mengering normal.
        energy = max(min(energy, 25), energy - hours * 3)
        mood   = max(min(mood, 30), mood - hours * 3)
        plant  = clamp(plant - Rate.plantDecay * hours * 60)
        lastUpdate = Date()
    }

    private func updateStreak() {
        let today = Self.dayKey(Date())
        let last  = defaults.string(forKey: Keys.lastDay)
        guard last != today else { if streak == 0 { streak = 1 }; return }
        let yesterday = Self.dayKey(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        streak = (last == yesterday) ? streak + 1 : 1
        defaults.set(today, forKey: Keys.lastDay)
    }

    private func rolloverDayIfNeeded() {
        let today = Self.dayKey(Date())
        guard defaults.string(forKey: Keys.focusDay) != today else { return }
        defaults.set(today, forKey: Keys.focusDay)
        focusMinutesToday  = 0
        focusSessionsToday = 0
        updateStreak()
    }

    private func persist() {
        defaults.set(energy, forKey: Keys.energy)
        defaults.set(mood,   forKey: Keys.mood)
        defaults.set(plant,  forKey: Keys.plant)
        defaults.set(streak, forKey: Keys.streak)
        defaults.set(lastUpdate, forKey: Keys.last)
        defaults.set(Self.dayKey(Date()), forKey: Keys.focusDay)
        defaults.set(focusMinutesToday,  forKey: Keys.focusMin)
        defaults.set(focusSessionsToday, forKey: Keys.focusCnt)
        defaults.set(focusMinutesTotal,  forKey: Keys.focusTot)
    }

    private func clamp(_ v: Double) -> Double { max(0, min(100, v)) }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String { dayFormatter.string(from: date) }
}

// MARK: - Toast
struct NeedsToast: Equatable, Identifiable {
    let id = UUID()
    let text: String
    let icon: String
}
