import Foundation
import Combine

/// Top-level app state driving which SwiftUI screen is shown.
enum AppState: Equatable {
    case menu
    case playing
    case gameOver
}

/// Shared observable state bridging the SpriteKit `GameScene` and the SwiftUI views.
/// `GameScene` writes to this on the main thread as gameplay events happen;
/// SwiftUI views read from it to render the HUD / menu / game-over screens.
final class GameViewModel: ObservableObject {
    @Published var appState: AppState = .menu
    @Published var distance: Int = 0
    @Published var lives: Int = GameConstants.startingLives
    @Published var highScore: Int = 0
    @Published var wasCaughtByYeti: Bool = false
    @Published var level: Int = 1

    private let highScoreStore = HighScoreStore()

    init() {
        highScore = highScoreStore.bestDistance
    }

    /// Resets run-specific state and switches to the playing screen.
    func startNewGame() {
        distance = 0
        lives = GameConstants.startingLives
        wasCaughtByYeti = false
        level = 1
        appState = .playing
    }

    /// Called by `GameScene` every time distance updates.
    func updateDistance(_ newDistance: Int) {
        distance = newDistance
    }

    /// Called by `GameScene` whenever the survival-time level advances.
    /// Triggers a small celebratory flourish so the ramp-up feels earned.
    func updateLevel(_ newLevel: Int) {
        guard newLevel != level else { return }
        level = newLevel
        HapticsManager.shared.levelUp()
        SoundManager.shared.playLevelUp()
    }

    /// Called by `GameScene` when the skier takes a hit (stone/hole/tree). Returns
    /// `true` if that hit ended the run (no lives left).
    @discardableResult
    func registerHit() -> Bool {
        lives = max(0, lives - 1)
        HapticsManager.shared.crashImpact()
        SoundManager.shared.playHit()
        if lives == 0 {
            endGame(caughtByYeti: false)
            return true
        }
        return false
    }

    /// Called by `GameScene` when the yeti catches the skier — always ends the run.
    func registerYetiCatch() {
        endGame(caughtByYeti: true)
    }

    private func endGame(caughtByYeti: Bool) {
        guard appState == .playing else { return }
        wasCaughtByYeti = caughtByYeti
        if distance > highScore {
            highScore = distance
            highScoreStore.bestDistance = distance
        }
        HapticsManager.shared.gameOverImpact()
        SoundManager.shared.playGameOver()
        GameCenterManager.shared.submit(distance: distance)
        appState = .gameOver
    }

    func returnToMenu() {
        appState = .menu
    }
}

/// Tunable top-level constants shared across the game layer.
enum GameConstants {
    static let startingLives = 3
}
