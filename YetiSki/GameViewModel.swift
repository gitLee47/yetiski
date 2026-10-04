import Foundation
import Combine

/// Top-level app state driving which SwiftUI screen is shown.
enum AppState: Equatable {
    case menu
    case playing
    case gameOver
}

/// Summary shown in a brief toast when a Yeti War ends.
struct YetiWarResult: Equatable {
    let kills: Int
    let bonusCoins: Int
}

/// Shared observable state bridging the SpriteKit `GameScene` and the SwiftUI views.
/// `GameScene` writes to this on the main thread as gameplay events happen;
/// SwiftUI views read from it to render the HUD / menu / game-over screens.
final class GameViewModel: ObservableObject {
    @Published var appState: AppState = .menu
    @Published var distance: Int = 0
    @Published var lives: Int = GameConstants.startingLives
    @Published var highScore: Int = 0
    /// Best distance so far in the current calendar week — resets
    /// automatically each week so there's always a winnable competition,
    /// even once the all-time board is dominated by early high scores.
    @Published var weeklyBest: Int = 0
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

    /// Weapons unlocked either by reaching a level (free) or spending Snow
    /// Coins — unlike skins, these have a real gameplay effect during a
    /// Yeti War, so they're not purely cosmetic.
    @Published var selectedWeapon: WeaponKind = .machineGun
    @Published var unlockedWeapons: Set<WeaponKind> = [.machineGun]
    /// Set for a moment right after `updateLevel(_:)` auto-unlocks a weapon,
    /// so `HUDView` can show a "Congrats, unlocked!" banner — consumed the
    /// same way it already reacts to `level` changing for `LevelUpBanner`.
    @Published var weaponJustUnlocked: WeaponKind?

    /// True the moment a Yeti War wants to start — `GameContainerView` shows
    /// the weapon-select banner instead of gameplay while this is set,
    /// mirroring `isOfferingContinue`.
    @Published var isYetiWarBannerShown: Bool = false
    /// Bumped once a weapon's confirmed; `GameContainerView` observes this to
    /// tell the scene to actually start the war (mirrors `continueRunID`).
    @Published var yetiWarStartID: Int = 0
    /// Mirrors war-in-progress state each frame, like `shieldActive`, so the
    /// HUD can show a countdown + kill count.
    @Published var yetiWarActive: Bool = false
    @Published var yetiWarTimeRemaining: TimeInterval = 0
    @Published var yetiWarKillCount: Int = 0
    /// Set once when a war ends, for a brief result toast; consumed the same
    /// way `weaponJustUnlocked` is.
    @Published var yetiWarResult: YetiWarResult?

    private var hasUsedContinueThisRun = false
    private var pendingCaughtByYeti = false

    private let highScoreStore = HighScoreStore()
    private let progressStore = PlayerProgressStore()

    init() {
        highScore = highScoreStore.bestDistance
        weeklyBest = progressStore.currentWeeklyBest()
        reviveTokens = progressStore.reviveTokens
        dailyStreak = progressStore.dailyStreak
        snowCoins = progressStore.snowCoins
        selectedSkin = progressStore.selectedSkin
        unlockedSkins = progressStore.unlockedSkins
        selectedWeapon = progressStore.selectedWeapon
        unlockedWeapons = progressStore.unlockedWeapons
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

    /// Called by `CoinShopView` once `StoreManager.purchase(_:)` reports a
    /// real, verified StoreKit transaction completed — never call this
    /// speculatively before that succeeds.
    func purchaseCoinBundle(_ bundle: CoinBundle) {
        addSnowCoins(bundle.coinAmount)
        HapticsManager.shared.powerup()
        SoundManager.shared.playPowerup()
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

    /// Spends Snow Coins to unlock a weapon, then equips it. No-op if already
    /// unlocked or unaffordable. Same shape as `purchaseSkin(_:)`.
    @discardableResult
    func purchaseWeapon(_ weapon: WeaponKind) -> Bool {
        guard !unlockedWeapons.contains(weapon), snowCoins >= weapon.coinCost else { return false }
        snowCoins -= weapon.coinCost
        unlockedWeapons.insert(weapon)
        progressStore.snowCoins = snowCoins
        progressStore.unlockedWeapons = unlockedWeapons
        HapticsManager.shared.powerup()
        SoundManager.shared.playPowerup()
        selectWeapon(weapon)
        return true
    }

    /// Equips an already-unlocked weapon.
    func selectWeapon(_ weapon: WeaponKind) {
        guard unlockedWeapons.contains(weapon) else { return }
        selectedWeapon = weapon
        progressStore.selectedWeapon = weapon
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
        isYetiWarBannerShown = false
        yetiWarActive = false
        yetiWarTimeRemaining = 0
        yetiWarKillCount = 0
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
        checkWeaponLevelUnlocks(newLevel)
    }

    /// Auto-unlocks (for free) any weapon whose `unlockLevel` this level just
    /// reached, and flags it for `HUDView`'s "Congrats, unlocked!" banner.
    private func checkWeaponLevelUnlocks(_ newLevel: Int) {
        for weapon in WeaponKind.allCases {
            guard let unlockLevel = weapon.unlockLevel,
                  newLevel >= unlockLevel,
                  !unlockedWeapons.contains(weapon)
            else { continue }
            unlockedWeapons.insert(weapon)
            progressStore.unlockedWeapons = unlockedWeapons
            weaponJustUnlocked = weapon
            HapticsManager.shared.powerup()
            SoundManager.shared.playPowerup()
        }
    }

    /// Called by `GameScene` when its Yeti War trigger fires — shows the
    /// weapon-select banner instead of gameplay, mirroring `beginEndOfRun`'s
    /// role for the continue-offer overlay.
    func beginYetiWar() {
        guard appState == .playing else { return }
        isYetiWarBannerShown = true
    }

    /// Called when the player confirms a weapon choice on the Yeti War
    /// banner. Equips the weapon and bumps `yetiWarStartID` so
    /// `GameContainerView` tells the scene to actually start the war.
    func confirmYetiWarWeapon(_ weapon: WeaponKind) {
        guard unlockedWeapons.contains(weapon) else { return }
        selectWeapon(weapon)
        isYetiWarBannerShown = false
        yetiWarStartID += 1
    }

    /// Called by `GameScene` every frame while a Yeti War is active.
    func updateYetiWar(active: Bool, timeRemaining: TimeInterval, kills: Int) {
        yetiWarActive = active
        yetiWarTimeRemaining = timeRemaining
        yetiWarKillCount = kills
    }

    /// Called by `GameScene` once a Yeti War ends, for the result toast.
    func reportYetiWarResult(kills: Int, bonusCoins: Int) {
        yetiWarResult = YetiWarResult(kills: kills, bonusCoins: bonusCoins)
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
        if progressStore.recordWeeklyDistance(distance) {
            weeklyBest = distance
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
