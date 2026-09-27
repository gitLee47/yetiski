import Foundation

/// A weapon usable during a Yeti War. Unlocked either by reaching
/// `unlockLevel` (a free "congrats" progression reward) or by spending Snow
/// Coins directly — every weapon has a coin price, but only some also have a
/// free level path, which is what makes `.iceCannon` a coin-only "premium"
/// weapon (a deliberate hook for real-money purchases later).
///
/// All cases currently fire identically (see `DifficultyManager.weaponFireInterval`
/// and `GameScene.advanceYetiWar`) — only name/icon/unlock path differ for now.
/// Distinct per-weapon behavior (spread shots, splash damage, etc.) is future work.
enum WeaponKind: String, CaseIterable, Identifiable, Hashable {
    case machineGun
    case shotgun
    case rocketLauncher
    case iceCannon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .machineGun: return "Machine Gun"
        case .shotgun: return "Shotgun"
        case .rocketLauncher: return "Rocket Launcher"
        case .iceCannon: return "Ice Cannon"
        }
    }

    /// Level at which this weapon unlocks for free. `nil` means there's no
    /// free path — it can only be unlocked by spending Snow Coins.
    var unlockLevel: Int? {
        switch self {
        case .machineGun: return nil
        case .shotgun: return 8
        case .rocketLauncher: return 15
        case .iceCannon: return nil
        }
    }

    /// Snow Coins to unlock immediately, skipping (or in `.iceCannon`'s
    /// case, substituting for) the level requirement. `.machineGun` is
    /// always owned, so its cost is never actually spent.
    var coinCost: Int {
        switch self {
        case .machineGun: return 0
        case .shotgun: return 150
        case .rocketLauncher: return 300
        case .iceCannon: return 500
        }
    }

    var iconName: String { "sprite_weapon_\(rawValue)" }
}
