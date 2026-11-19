import AVFoundation
import CoreGraphics

/// Music and sound effects. Everything is a small WAV made by tools/audio.js.
final class Sound {
    static let shared = Sound()

    private var loops: [String: AVAudioPlayer] = [:]
    private var cache: [String: Data] = [:]
    private var active: [AVAudioPlayer] = []
    private var started = false
    private(set) var enabled: Bool

    private init() {
        enabled = !UserDefaults.standard.bool(forKey: "evergreen.muted")
    }

    /// Loads the looping tracks. They all play at once; `mix` decides which you hear.
    func start() {
        guard !started else { return }
        started = true
        // Ambient: obeys the silent switch and does not stop the player's own music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        for name in ["music_day", "music_night", "wind"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            if enabled { player.play() }
            loops[name] = player
        }
    }

    /// Call when the app comes back to the front.
    func resume() {
        guard started, enabled else { return }
        for player in loops.values where !player.isPlaying {
            player.play()
        }
    }

    func setEnabled(_ on: Bool) {
        enabled = on
        UserDefaults.standard.set(!on, forKey: "evergreen.muted")
        for player in loops.values {
            if on {
                player.play()
            } else {
                player.pause()
            }
        }
    }

    /// `night` runs from 0 (day tune) to 1 (night tune).
    func mix(night: CGFloat, storm: Bool) {
        let n = Float(min(1, max(0, night)))
        loops["music_day"]?.volume = 0.45 * (1 - n)
        loops["music_night"]?.volume = 0.5 * n
        loops["wind"]?.volume = storm ? 0.5 : 0.05
    }

    func play(_ name: String, volume: Float = 1) {
        guard enabled, started else { return }
        if cache[name] == nil,
           let url = Bundle.main.url(forResource: name, withExtension: "wav"),
           let data = try? Data(contentsOf: url) {
            cache[name] = data
        }
        guard let data = cache[name], let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = volume
        player.play()
        active.append(player)
        if active.count > 14 {
            active.removeAll { !$0.isPlaying }
        }
    }
}
