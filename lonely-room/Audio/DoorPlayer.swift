import AVFoundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class DoorPlayer {
    static let shared = DoorPlayer()

    private var player: AVAudioPlayer?

    private init() {
        #if canImport(UIKit)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        guard let asset = NSDataAsset(name: "door") else {
            print("⚠️ DoorPlayer: asset 'door' tidak ditemukan")
            return
        }
        if let p = try? AVAudioPlayer(data: asset.data, fileTypeHint: "mp3") {
            p.numberOfLoops = 0
            p.volume = 0.9
            p.prepareToPlay()
            player = p
        }
    }

    func play() {
        player?.stop()
        player?.currentTime = 0
        player?.play()
    }
}
