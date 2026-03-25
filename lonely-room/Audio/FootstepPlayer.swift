import AVFoundation
import UIKit

// MARK: - Footstep Player
final class FootstepPlayer {
    static let shared = FootstepPlayer()

    // Dua player bergantian (ping-pong) supaya setiap langkah
    // bisa langsung diputar tanpa tunggu yang sebelumnya selesai
    private var players: [AVAudioPlayer] = []
    private var currentIndex = 0
    private var stepTimer: Timer?

    private init() {
        guard let asset = NSDataAsset(name: "footStep") else {
            print("⚠️ FootstepPlayer: asset 'footStep' tidak ditemukan")
            return
        }
        for _ in 0..<2 {
            if let p = try? AVAudioPlayer(data: asset.data, fileTypeHint: "mp3") {
                p.prepareToPlay()
                p.volume = 0.7
                players.append(p)
            }
        }
    }

    /// Mulai footstep dengan interval sinkron terhadap animasi bob (0.38s per langkah)
    func start(interval: TimeInterval = 0.38) {
        guard stepTimer == nil else { return }
        playStep()
        stepTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.playStep()
        }
    }

    func stop() {
        stepTimer?.invalidate()
        stepTimer = nil
        players.forEach { $0.stop() }
    }

    private func playStep() {
        guard !players.isEmpty else { return }
        let p = players[currentIndex % players.count]
        p.currentTime = 0
        p.play()
        currentIndex += 1
    }
}
