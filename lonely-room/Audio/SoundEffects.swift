import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Audio Queue
/// Semua operasi audio yang bisa memblokir (load file, setCategory, play) jalan di sini,
/// supaya tidak menghentikan main thread dan bikin game tersendat.
nonisolated enum AudioQueue {
    static let shared = DispatchQueue(label: "kost.audio", qos: .userInitiated)
}

nonisolated final class AudioPlayerBox: @unchecked Sendable {
    let player: AVAudioPlayer

    private init(player: AVAudioPlayer) { self.player = player }

    /// Panggil dari AudioQueue: membaca file dari Asset Catalog.
    static func make(asset name: String, loops: Int) -> AudioPlayerBox? {
        guard let asset = NSDataAsset(name: name),
              let p = try? AVAudioPlayer(data: asset.data, fileTypeHint: "mp3") else {
            print("⚠️ Audio: asset '\(name)' tidak ditemukan")
            return nil
        }
        p.numberOfLoops = loops
        p.prepareToPlay()
        return AudioPlayerBox(player: p)
    }
}

// MARK: - Audio Session
/// Satu tempat untuk mengatur kategori AVAudioSession.
/// Sebelumnya tiap player men-set kategori sendiri (.ambient vs .playback) sehingga
/// hasil akhirnya tergantung player mana yang terakhir di-init.
enum AudioSessionManager {
    /// Default: efek suara bercampur dengan musik app lain & ikut tombol silent.
    static func useAmbient() {
        #if canImport(UIKit)
        AudioQueue.shared.async {
            let s = AVAudioSession.sharedInstance()
            try? s.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try? s.setActive(true)
        }
        #endif
    }

    /// Saat radio diputar: kategori playback agar tetap bunyi di background & muncul di lock screen.
    static func useMusicPlayback() {
        #if canImport(UIKit)
        AudioQueue.shared.async {
            let s = AVAudioSession.sharedInstance()
            try? s.setCategory(.playback, mode: .default, options: [])
            try? s.setActive(true)
        }
        #endif
    }
}

// MARK: - Preload
enum SoundEffects {
    /// Muat semua efek di background saat app dibuka, jadi pemakaian pertama tidak tersendat.
    static func preload() {
        _ = ClockPlayer.shared
        _ = DoorPlayer.shared
        _ = FootstepPlayer.shared
        _ = WateringPlayer.shared
        _ = RainPlayer.shared
        _ = WindPlayer.shared
    }
}

// MARK: - Base Sound Effect Player
/// Player efek suara generik: file dimuat di AudioQueue, volume mengikuti
/// slider "Efek Suara" di Pengaturan, dan punya helper fade tanpa timer bocor.
class SoundEffectPlayer {
    private var box: AudioPlayerBox?
    /// Perintah yang masuk sebelum file selesai dimuat.
    private var pendingActions: [@Sendable (AudioPlayerBox) -> Void] = []
    private let baseVolume: Float
    /// Level fade 0...1 relatif terhadap baseVolume.
    private var gain: Float
    private var fadeTimer: Timer?
    private var settingsSink: AnyCancellable?
    private var isActive = false

    init(asset name: String, baseVolume: Float, loops: Bool, startSilent: Bool = false) {
        self.baseVolume = baseVolume
        self.gain = startSilent ? 0 : 1
        settingsSink = AppSettings.shared.$sfxVolume
            .dropFirst()
            .sink { [weak self] v in self?.applyVolume(sfx: v) }
        AudioQueue.shared.async { [weak self] in
            guard let loaded = AudioPlayerBox.make(asset: name, loops: loops ? -1 : 0) else { return }
            Task { @MainActor [weak self] in self?.attach(loaded) }
        }
    }

    private func attach(_ loaded: AudioPlayerBox) {
        box = loaded
        applyVolume()
        let actions = pendingActions
        pendingActions.removeAll()
        actions.forEach { action in AudioQueue.shared.async { action(loaded) } }
    }

    private func perform(_ action: @escaping @Sendable (AudioPlayerBox) -> Void) {
        if let box {
            AudioQueue.shared.async { action(box) }
        } else {
            pendingActions.append(action)
        }
    }

    var isPlaying: Bool { isActive }

    private func applyVolume(sfx: Double = AppSettings.shared.sfxVolume) {
        box?.player.volume = baseVolume * gain * Float(sfx)
    }

    /// Mulai loop jika belum berjalan.
    func startLoop() {
        guard !isActive else { return }
        isActive = true
        perform { if !$0.player.isPlaying { $0.player.play() } }
    }

    /// Mainkan dari awal (one-shot).
    func playOnce() {
        perform {
            $0.player.stop()
            $0.player.currentTime = 0
            $0.player.play()
        }
    }

    func pause() {
        isActive = false
        perform { $0.player.pause() }
    }

    /// Stop dan kembalikan ke awal.
    func halt() {
        fadeTimer?.invalidate(); fadeTimer = nil
        isActive = false
        perform {
            $0.player.stop()
            $0.player.currentTime = 0
        }
    }

    /// Fade gain ke `target` (0...1). Fade sebelumnya otomatis dibatalkan.
    func fade(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        let steps = max(1, Int(duration * 30))
        let delta = (target - gain) / Float(steps)
        var remaining = steps
        fadeTimer = Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            remaining -= 1
            self.gain = remaining <= 0 ? target : max(0, min(1, self.gain + delta))
            self.applyVolume()
            if remaining <= 0 {
                t.invalidate()
                self.fadeTimer = nil
                completion?()
            }
        }
    }
}

// MARK: - Concrete Players

/// Detak jam dinding — loop selama ada jam di kamar.
final class ClockPlayer: SoundEffectPlayer {
    static let shared = ClockPlayer()
    private init() { super.init(asset: "clock", baseVolume: 0.09, loops: true) }
    func start() { startLoop() }
    func stop()  { halt() }
}

final class DoorPlayer: SoundEffectPlayer {
    static let shared = DoorPlayer()
    private init() { super.init(asset: "door", baseVolume: 0.9, loops: false) }
    func play() { playOnce() }
}

/// Langkah kaki — di-pause (bukan reset) supaya ritmenya natural saat jalan lagi.
final class FootstepPlayer: SoundEffectPlayer {
    static let shared = FootstepPlayer()
    private init() { super.init(asset: "footStep", baseVolume: 0.75, loops: true) }
    func start() { startLoop() }
    func stop()  { pause() }
}

final class WateringPlayer: SoundEffectPlayer {
    static let shared = WateringPlayer()
    private init() { super.init(asset: "watering", baseVolume: 0.85, loops: false) }
    func start() { playOnce() }
    func stop()  { halt() }
}

final class RainPlayer: SoundEffectPlayer {
    static let shared = RainPlayer()
    private init() { super.init(asset: "hujan", baseVolume: 0.85, loops: true, startSilent: true) }

    func start(heavy: Bool = false) {
        startLoop()
        fade(to: heavy ? 1.0 : 0.65, duration: 2.0)
    }

    func stop() {
        guard isPlaying else { return }
        fade(to: 0, duration: 2.5) { [weak self] in self?.halt() }
    }
}

final class WindPlayer: SoundEffectPlayer {
    static let shared = WindPlayer()
    private init() { super.init(asset: "wind", baseVolume: 0.55, loops: true, startSilent: true) }

    func start() {
        startLoop()
        fade(to: 1.0, duration: 1.2)
    }

    func stop() {
        guard isPlaying else { return }
        fade(to: 0, duration: 1.0) { [weak self] in self?.halt() }
    }
}
