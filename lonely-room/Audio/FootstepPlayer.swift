import AVFoundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
final class FootstepPlayer {
    static let shared = FootstepPlayer()

    private var player: AVAudioPlayer?

    private init() {
        #if canImport(UIKit)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        guard let asset = NSDataAsset(name: "footStep") else {
            print("⚠️ FootstepPlayer: asset 'footStep' tidak ditemukan")
            return
        }
        if let p = try? AVAudioPlayer(data: asset.data, fileTypeHint: "mp3") {
            p.numberOfLoops = -1  // loop selamanya
            p.volume = 0.75
            p.prepareToPlay()
            player = p
        }
    }

    /// Mulai footstep timer, play setiap 0.38 detik (sinkron dengan animasi bob)
    func start(interval: TimeInterval = 0.38) {
        guard player?.isPlaying == false else { return }
        player?.play()
    }

    /// Pause — hentikan timer dan pause player di posisi sekarang
    func stop() {
        player?.pause()
    }
}
