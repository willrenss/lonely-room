import AVFoundation
import UIKit

// MARK: - Clock Ticking Player
final class ClockPlayer {
    static let shared = ClockPlayer()

    private var player: AVAudioPlayer?

    private init() {
        loadAsset()
    }

    private func loadAsset() {
        guard let asset = NSDataAsset(name: "clock") else {
            print("⚠️ ClockPlayer: asset 'clock' tidak ditemukan")
            return
        }
        if let p = try? AVAudioPlayer(data: asset.data, fileTypeHint: "mp3") {
            p.numberOfLoops = -1   // loop selamanya
            p.volume = 2
            p.prepareToPlay()
            player = p
        }
    }

    /// Nyalakan suara ticking jam — dipanggil tiap ada jam dinding di ruangan.
    func start() {
        guard player?.isPlaying == false else { return }
        player?.play()
    }

    /// Matikan suara — dipanggil saat semua jam dinding dihapus.
    func stop() {
        player?.pause()
        player?.currentTime = 0
    }
}
