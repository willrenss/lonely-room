import AVFoundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Watering Sound Player
final class WateringPlayer {
    static let shared = WateringPlayer()

    private var player: AVAudioPlayer?

    private init() {
        #if canImport(UIKit)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        guard let asset = NSDataAsset(name: "watering") else {
            print("⚠️ WateringPlayer: asset 'watering' tidak ditemukan")
            return
        }
        if let p = try? AVAudioPlayer(data: asset.data, fileTypeHint: "mp3") {
            p.numberOfLoops = 0   // play sekali
            p.volume = 0.85
            p.prepareToPlay()
            player = p
        }
    }

    func start() {
        guard let player else { return }
        player.currentTime = 0
        player.play()
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
    }
}
