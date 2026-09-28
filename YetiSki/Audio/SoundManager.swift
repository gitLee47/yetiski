import AVFoundation

/// Plays background music and one-shot sound effects.
///
/// Drop the real audio files into `YetiSki/Resources/Sounds` using the filenames
/// referenced below (e.g. `crash.caf`, `yeti_roar.caf`, `game_over.caf`,
/// `music_loop.mp3`). Until those files exist, every call here is a safe no-op —
/// missing audio never crashes or blocks gameplay.
final class SoundManager {
    static let shared = SoundManager()

    private var musicPlayer: AVAudioPlayer?
    private var effectPlayers: [AVAudioPlayer] = []

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    func startBackgroundMusic() {
        guard musicPlayer == nil, let url = resourceURL(named: "music_loop") else { return }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = 0.5
        player?.play()
        musicPlayer = player
    }

    func stopBackgroundMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
    }

    /// Pauses the music in place (e.g. while the game is paused), unlike
    /// `stopBackgroundMusic()` which discards the player entirely.
    func pauseBackgroundMusic() {
        musicPlayer?.pause()
    }

    func resumeBackgroundMusic() {
        musicPlayer?.play()
    }

    func playHit() { play("crash") }
    func playYetiRoar() { play("yeti_roar") }
    func playGameOver() { play("game_over") }
    func playLevelUp() { play("level_up") }
    func playJump() { play("jump") }
    func playSnowflake() { play("snowflake") }
    func playPowerup() { play("powerup") }

    private func play(_ name: String) {
        guard let url = resourceURL(named: name) else { return }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.play()
        effectPlayers.append(player)
        effectPlayers.removeAll { !$0.isPlaying }
    }

    private func resourceURL(named name: String) -> URL? {
        let extensions = ["caf", "wav", "mp3", "m4a"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
