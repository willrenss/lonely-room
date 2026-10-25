import AVFoundation
import MediaPlayer
import Combine

// MARK: - MusicPlayer (Asset Only)
final class MusicPlayer: NSObject, ObservableObject {
    static let shared = MusicPlayer()

    @Published var isPlaying:    Bool    = false
    @Published var isRepeating:  Bool    = false
    @Published var currentTitle: String = "Belum ada lagu"
    @Published var progress:     Double = 0
    @Published var duration:     Double = 0
    @Published var queueIndex:   Int    = 0
    @Published var queueCount:   Int    = 0

    private var player:        AVAudioPlayer?
    private var progressTimer: Timer?
    private var assetNames:    [String] = []
    private var assetTitles:   [String] = []
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
        setupRemoteCommandCenter()
        loadAssetQueue()

        AppSettings.shared.$musicVolume
            .sink { [weak self] v in self?.player?.volume = Float(v) }
            .store(in: &cancellables)

        // Telepon masuk / Siri dll — sinkronkan state tombol play.
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] note in
                guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
                self?.pause()
            }
            .store(in: &cancellables)
    }

    // MARK: - Asset queue
    func loadAssetQueue() {
        // Nama asset = nama folder .dataset (tanpa ekstensi)
        let entries: [(name: String, title: String)] = [
            ("radio-fassounds-lofi-study-calm-peaceful-chill-hop-112191", "Lofi Study"),
            ("radio-jumadiharyanto07-one-step-closer-207958",             "One Step Closer"),
            ("radio-pasajdijital-quiet-peaks-445423",                     "Quiet Peaks"),
            ("radio-top-flow-deep-breathing-148302",                      "Deep Breathing"),
            ("radio-watermello-lofi-chill-lofi-girl-lofi-488388",         "Lofi Chill"),
        ]
        // Cukup cek keberadaan via NSDataAsset tanpa menyimpan datanya di memori.
        let available = entries.filter { NSDataAsset(name: $0.name) != nil }
        assetNames  = available.map(\.name)
        assetTitles = available.map(\.title)
        queueCount  = assetNames.count
        queueIndex  = 0
    }

    // MARK: - Playback control
    func play() {
        AudioSessionManager.useMusicPlayback()
        if player == nil { playCurrentItem(); return }
        player?.play()
        isPlaying = true
        startProgressTimer()
        updateNowPlaying()
    }

    func pause() {
        guard isPlaying else { return }
        player?.pause()
        isPlaying = false
        stopProgressTimer()
        updateNowPlaying()
        // Kembalikan ke ambient supaya musik app lain bisa lanjut.
        AudioSessionManager.useAmbient()
    }

    func togglePlayPause() { isPlaying ? pause() : play() }

    func toggleRepeat() { isRepeating.toggle() }

    func next() {
        guard !assetNames.isEmpty else { return }
        queueIndex = (queueIndex + 1) % assetNames.count
        playCurrentItem()
    }

    func previous() {
        guard !assetNames.isEmpty else { return }
        if (player?.currentTime ?? 0) > 3 {
            player?.currentTime = 0
        } else {
            queueIndex = (queueIndex - 1 + assetNames.count) % assetNames.count
            playCurrentItem()
        }
    }

    // MARK: - Play
    private func playCurrentItem() {
        guard !assetNames.isEmpty else { return }
        let name = assetNames[queueIndex]
        guard let asset = NSDataAsset(name: name),
              let p = try? AVAudioPlayer(data: asset.data, fileTypeHint: "mp3")
        else { return }

        AudioSessionManager.useMusicPlayback()
        player?.stop()
        p.delegate = self
        p.volume = Float(AppSettings.shared.musicVolume)
        p.prepareToPlay()
        p.play()
        player       = p
        currentTitle = assetTitles[queueIndex]
        duration     = p.duration
        progress     = 0
        isPlaying    = true
        startProgressTimer()
        updateNowPlaying()
    }

    // MARK: - Progress
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let p = self.player, p.duration > 0 else { return }
            self.progress = p.currentTime / p.duration
        }
        progressTimer?.tolerance = 0.2
    }

    private func stopProgressTimer() { progressTimer?.invalidate(); progressTimer = nil }

    // MARK: - Lock Screen / Remote
    private func setupRemoteCommandCenter() {
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.addTarget          { [weak self] _ in self?.play();     return .success }
        cc.pauseCommand.addTarget         { [weak self] _ in self?.pause();    return .success }
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        cc.nextTrackCommand.addTarget     { [weak self] _ in self?.next();     return .success }
        cc.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
    }

    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle:                    currentTitle,
            MPMediaItemPropertyArtist:                   "Radio Kamar",
            MPMediaItemPropertyPlaybackDuration:         duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate:        isPlaying ? 1.0 : 0.0
        ]
    }
}

// MARK: - AVAudioPlayerDelegate
extension MusicPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else { return }
        if isRepeating {
            playCurrentItem()   // replay lagu yang sama
        } else {
            next()
        }
    }
}
