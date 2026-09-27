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
    /// A snarky one-liner picked when the run ends, shown on Game Over and
    /// folded into the share text — makes the death moment more memorable
    /// (and more shareable) than a bare stat.
    @Published var deathCaption: String = ""
    @Published var level: Int = 1
    /// Bumped every time a run (re)starts, whether from the menu or the
    /// in-game restart button. `GameContainerView` observes this — rather
    /// than `appState`, which doesn't change on a mid-run restart — to know
    /// when to tell the scene to reset and start over.
    @Published var runID: Int = 0
    /// Whether gameplay is currently paused. `GameContainerView` observes
    /// this to pause/resume the `GameScene`.
    @Published var isPaused: Bool = false
    /// Mirrors active powerup state each frame so the HUD can show buff icons.
    @Published var shieldActive: Bool = false
    @Published var speedBoostActive: Bool = false

    /// Banked revive tokens, earned via the daily login streak (or, later,
    /// watching a rewarded ad anytime). Spent at the continue-offer prompt.
    @Published var reviveTokens: Int = 0
    @Published var dailyStreak: Int = 0
    /// Set at launch when a new day's login reward hasn't been claimed yet.
    @Published var showDailyReward: Bool = false
    @Published var pendingDailyRewardDay: Int = 1
    @Published var pendingDailyRewardTokens: Int = 0

    /// True right when a run would otherwise end — offers a one-time-per-run
    /// continue (spend a token or watch an ad) instead of going straight to
    /// Game Over.
    @Published var isOfferingContinue: Bool = false
    /// Bumped when a continue is granted; `GameContainerView` observes this
    /// to tell the scene to resume in place (unlike `runID`, this does NOT
    /// reset distance/level).
    @Published var continueRunID: Int = 0

    /// Persistent cosmetic currency, earned from snowflake pickups. Spent in
    /// the Locker to unlock skier skins — purely visual, no gameplay effect.
    @Published var snowCoins: Int = 0
    @Published var selectedSkin: SkierSkin = .classic
    @Published var unlockedSkins: Set<SkierSkin> = [.classic]

    private var hasUsedContinueThisRun = false
    private var pendingCaughtByYeti = false

    private let highScoreStore = HighScoreStore()
    private let progressStore = PlayerProgressStore()

    init() {
        highScore = highScoreStore.bestDistance
        reviveTokens = progressStore.reviveTokens
        dailyStreak = progressStore.dailyStreak
        snowCoins = progressStore.snowCoins
        selectedSkin = progressStore.selectedSkin
        unlockedSkins = progressStore.unlockedSkins
        if progressStore.isDailyRewardAvailable {
            let info = progressStore.pendingRewardInfo()
            pendingDailyRewardDay = info.day
            pendingDailyRewardTokens = info.tokens
            showDailyReward = true
        }
    }

    /// Called by `GameScene` when the skier grabs a snowflake — banks 1 Snow
    /// Coin on top of the in-run distance bonus, feeding the cosmetic shop.
    func addSnowCoins(_ amount: Int) {
        snowCoins += amount
        progressStore.snowCoins = snowCoins
    }

    /// Spends Snow Coins to unlock a skin, then equips it. No-op if already
    /// unlocked or unaffordable.
    @discardableResult
    func purchaseSkin(_ skin: SkierSkin) -> Bool {
        guard !unlockedSkins.contains(skin), snowCoins >= skin.cost else { return false }
        snowCoins -= skin.cost
        unlockedSkins.insert(skin)
        progressStore.snowCoins = snowCoins
        progressStore.unlockedSkins = unlockedSkins
        HapticsManager.shared.powerup()
        SoundManager.shared.playPowerup()
        selectSkin(skin)
        return true
    }

    /// Equips an already-unlocked skin.
    func selectSkin(_ skin: SkierSkin) {
        guard unlockedSkins.contains(skin) else { return }
        selectedSkin = skin
        progressStore.selectedSkin = skin
    }

    /// Claims today's login reward, banking its tokens and advancing the streak.
    func claimDailyReward() {
        progressStore.claim()
        reviveTokens = progressStore.reviveTokens
        dailyStreak = progressStore.dailyStreak
        showDailyReward = false
        HapticsManager.shared.powerup()
        SoundManager.shared.playPowerup()
    }

    /// Resets run-specific state and (re)starts gameplay — used both for a
    /// fresh game from the menu and for restarting mid-run.
    func startNewGame() {
        distance = 0
        lives = GameConstants.startingLives
        wasCaughtByYeti = false
        level = 1
        isPaused = false
        shieldActive = false
        speedBoostActive = false
        isOfferingContinue = false
        hasUsedContinueThisRun = false
        appState = .playing
        runID += 1
    }

    /// Pauses the current run. No-op unless a run is actually in progress.
    func pause() {
        guard appState == .playing else { return }
        isPaused = true
    }

    func resume() {
        isPaused = false
    }

    /// Called by `GameScene` every time distance updates.
    func updateDistance(_ newDistance: Int) {
        distance = newDistance
    }

    /// Called by `GameScene` every frame to mirror active powerup state.
    func updateBuffs(shieldActive: Bool, speedBoostActive: Bool) {
        if self.shieldActive != shieldActive { self.shieldActive = shieldActive }
        if self.speedBoostActive != speedBoostActive { self.speedBoostActive = speedBoostActive }
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
            beginEndOfRun(caughtByYeti: false)
            return true
        }
        return false
    }

    /// Called by `GameScene` when the yeti catches the skier — always ends the run.
    func registerYetiCatch() {
        beginEndOfRun(caughtByYeti: true)
    }

    /// Called by `GameScene` when the skier grabs an extra-life pickup.
    /// Capped so lives can't stack up indefinitely.
    func grantExtraLife() {
        lives = min(GameConstants.maxLives, lives + 1)
    }

    /// Offers a one-time-per-run continue instead of ending the run outright,
    /// unless that offer's already been used this run.
    private func beginEndOfRun(caughtByYeti: Bool) {
        guard appState == .playing else { return }
        pendingCaughtByYeti = caughtByYeti
        if hasUsedContinueThisRun {
            endGame(caughtByYeti: caughtByYeti)
        } else {
            isOfferingContinue = true
        }
    }

    /// Spends a banked revive token to continue the current run in place.
    func useReviveToken() {
        guard reviveTokens > 0 else { return }
        reviveTokens -= 1
        progressStore.reviveTokens = reviveTokens
        resolveContinue()
    }

    /// Called once the (placeholder, for now) rewarded ad finishes playing.
    /// Swap in a real ad SDK's completion callback here when ready to
    /// monetize for real — the game-side effect is identical either way.
    func useAdRevive() {
        resolveContinue()
    }

    private func resolveContinue() {
        hasUsedContinueThisRun = true
        isOfferingContinue = false
        lives = 1
        continueRunID += 1
        HapticsManager.shared.powerup()
        SoundManager.shared.playPowerup()
    }

    /// Declines the continue offer (tapped "No Thanks" or the countdown ran out).
    func declineContinue() {
        isOfferingContinue = false
        endGame(caughtByYeti: pendingCaughtByYeti)
    }

    private func endGame(caughtByYeti: Bool) {
        guard appState == .playing else { return }
        wasCaughtByYeti = caughtByYeti
        deathCaption = (caughtByYeti ? Self.yetiCaptions : Self.crashCaptions).randomElement() ?? ""
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
        isPaused = false
    }

    private static let yetiCaptions = [
        "The yeti wanted a snack.",
        "Yeti: 1, You: 0.",
        "You just became yeti chow.",
        "The abominable snowman says thanks for lunch.",
        "Should've packed yeti spray.",
        "Well, that's one way to end a ski trip.",
    ]

    private static let crashCaptions = [
        "Gravity: undefeated.",
        "That tree didn't move. You did.",
        "Yard sale!",
        "Snow angels weren't on the itinerary.",
        "10/10 form. 0/10 outcome.",
        "The mountain wins again.",
    ]
}

/// Tunable top-level constants shared across the game layer.
enum GameConstants {
    static let startingLives = 3
    static let maxLives = 5
}
