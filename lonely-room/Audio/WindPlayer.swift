import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Wind Sound Player
final class WindPlayer {
    static let shared = WindPlayer()

    private var player: AVAudioPlayer?

    private init() { loadAsset() }

    private func loadAsset() {
        guard let asset = NSDataAsset(name: "wind") else {
            print("⚠️ WindPlayer: asset 'wind' tidak ditemukan")
            return
        }
        if let p = try? AVAudioPlayer(data: asset.data, fileTypeHint: "mp3") {
            p.numberOfLoops = -1   // loop selamanya
            p.volume        = 0.0
            p.prepareToPlay()
            player = p
        }
    }

    func start() {
        guard let p = player else { return }
        if !p.isPlaying { p.play() }
        fade(to: 0.55, duration: 1.2)
    }

    func stop() {
        fade(to: 0.0, duration: 1.0) { [weak self] in
            self?.player?.pause()
            self?.player?.currentTime = 0
        }
    }

    // MARK: - Fade helper
    private func fade(to volume: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        guard let p = player else { return }
        let steps    = 20
        let interval = duration / Double(steps)
        let delta    = (volume - p.volume) / Float(steps)
        var current  = 0

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            current += 1
            p.volume = max(0, min(1, p.volume + delta))
            if current >= steps {
                timer.invalidate()
                p.volume = volume
                completion?()
            }
        }
    }
}
