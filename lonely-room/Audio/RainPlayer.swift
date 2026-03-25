import AVFoundation
import UIKit

// MARK: - Rain Sound Player
final class RainPlayer {
    static let shared = RainPlayer()

    private var player: AVAudioPlayer?

    private init() {
        guard let asset = NSDataAsset(name: "hujan") else {
            print("⚠️ RainPlayer: asset 'hujan' tidak ditemukan")
            return
        }
        if let p = try? AVAudioPlayer(data: asset.data, fileTypeHint: "mp3") {
            p.numberOfLoops = -1   // loop selamanya
            p.volume = -5
            p.prepareToPlay()
            player = p
        }
    }

    /// Mulai suara hujan dengan fade-in.
    func start(heavy: Bool = false) {
        guard let player else { return }
        let targetVolume: Float = heavy ? 0.85 : 0.55
        if !player.isPlaying {
            player.volume = 0
            player.play()
        }
        fade(to: targetVolume, duration: 2.0)
    }

    /// Hentikan suara hujan dengan fade-out.
    func stop() {
        fade(to: 0, duration: 2.5) { [weak self] in
            self?.player?.pause()
            self?.player?.currentTime = 0
        }
    }

    // MARK: - Fade helpers

    private var fadeTimer: Timer?

    private func fade(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        guard let player else { return }
        let steps: Float = 60
        let interval = duration / Double(steps)
        let delta = (target - player.volume) / steps
        var remaining = steps

        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            remaining -= 1
            self.player?.volume = max(0, min(1, (self.player?.volume ?? 0) + delta))
            if remaining <= 0 {
                self.player?.volume = target
                t.invalidate()
                self.fadeTimer = nil
                completion?()
            }
        }
    }
}
