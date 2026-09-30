import Foundation

/// A weapon usable during a Yeti War. Unlocked either by reaching
/// `unlockLevel` (a free "congrats" progression reward) or by spending Snow
/// Coins directly — every weapon has a coin price, but only some also have a
/// free level path, which is what makes `.iceCannon`/`.acidSprayer`/
/// `.gravityPulse`/`.pulseBlade` coin-only "premium" weapons (a deliberate
/// hook for real-money purchases later).
///
/// Four "standard" weapons (unlocked early) plus six "special" weapons
/// (higher level/coin gates) — each has genuinely different behavior via
/// `firingStyle` and the tuning properties below; see `GameScene`'s Yeti War
/// section (`activateWeapon()` and friends) for how each style is executed.
enum WeaponKind: String, CaseIterable, Identifiable, Hashable {
    // Standard tier
    case machineGun
    case shotgun
    case rocketLauncher
    case iceCannon
    // Special tier
    case feralClaws
    case opticBlast
    case wyrmsBreath
    case acidSprayer
    case gravityPulse
    case pulseBlade

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .machineGun: return "Machine Gun"
        case .shotgun: return "Shotgun"
        case .rocketLauncher: return "Rocket Launcher"
        case .iceCannon: return "Ice Cannon"
        case .feralClaws: return "Feral Claws"
        case .opticBlast: return "Optic Blast"
        case .wyrmsBreath: return "Wyrm's Breath"
        case .acidSprayer: return "Acid Sprayer"
        case .gravityPulse: return "Gravity Pulse"
        case .pulseBlade: return "Pulse Blade"
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
        case .feralClaws: return 20
        case .opticBlast: return 25
        case .wyrmsBreath: return 30
        case .acidSprayer: return nil
        case .gravityPulse: return nil
        case .pulseBlade: return nil
        }
    }

    /// Snow Coins to unlock immediately — the only path at all for the
    /// coin-only weapons (`.iceCannon`, `.acidSprayer`, `.gravityPulse`,
    /// `.pulseBlade`). `.machineGun` is always owned, so its cost is never
    /// actually spent.
    ///
    /// Priced by actual power, not by introduction order: the coin-only
    /// weapons carry a premium on top of their tier since they have no free
    /// path at all, and `.pulseBlade` — which removes death-by-contact
    /// entirely — stays the single most expensive item as the top "premium"
    /// weapon. See `CoinBundle` for how the real-money bundle sizes are
    /// anchored to these exact numbers.
    var coinCost: Int {
        switch self {
        case .machineGun: return 0
        case .shotgun: return 200
        case .rocketLauncher: return 400
        case .feralClaws: return 700
        case .opticBlast: return 850
        case .wyrmsBreath: return 1100
        case .iceCannon: return 1400
        case .acidSprayer: return 1500
        case .gravityPulse: return 2200
        case .pulseBlade: return 2800
        }
    }

    var iconName: String { "sprite_weapon_\(rawValue)" }

    // MARK: - Behavior

    /// How this weapon resolves a kill — see `GameScene.activateWeapon()`
    /// and `handleBulletContact(_:)` for how each case is actually executed.
    enum FiringStyle {
        /// One bullet, current lane, stops on the first yeti it hits.
        case singleShot
        /// Several bullets at once, spread across neighboring lanes.
        case spread
        /// One bullet; on impact, kills everything within `splashRadius`.
        case piercing
        /// One bullet that doesn't stop on a kill — keeps traveling,
        /// hitting every yeti in its lane.
        case splash
        /// No travel time — instantly kills the nearest yeti in the
        /// current lane.
        case hitscan
        /// No projectile — periodically kills anything within
        /// `meleeRangeY` of the skier, current lane ± 1.
        case melee
        /// No projectile — periodically kills anything within
        /// `meleeRangeY` of the skier, across *all* lanes.
        case coneBurst
        /// One bullet; on impact, leaves a lingering zone in that lane
        /// that kills anything passing through it for `acidZoneDuration`.
        case acidZone
        /// No projectile — periodically kills every currently-chasing
        /// horde yeti on screen (`YetiNode.chasesSkier`).
        case pulse
        /// Never actively fires — instead, `GameScene.didBegin(_:)`
        /// converts a skier/yeti contact into a kill instead of a hit.
        case passiveMelee
    }

    var firingStyle: FiringStyle {
        switch self {
        case .machineGun: return .singleShot
        case .shotgun: return .spread
        case .rocketLauncher: return .splash
        case .iceCannon: return .piercing
        case .feralClaws: return .melee
        case .opticBlast: return .hitscan
        case .wyrmsBreath: return .coneBurst
        case .acidSprayer: return .acidZone
        case .gravityPulse: return .pulse
        case .pulseBlade: return .passiveMelee
        }
    }

    /// Seconds between activations. Unused (and irrelevant) for
    /// `.passiveMelee`, which never actively fires.
    var fireInterval: TimeInterval {
        switch self {
        case .machineGun: return 0.35
        case .shotgun: return 0.6
        case .rocketLauncher: return 1.1
        case .iceCannon: return 0.5
        case .feralClaws: return 0.4
        case .opticBlast: return 0.25
        case .wyrmsBreath: return 0.9
        case .acidSprayer: return 0.5
        case .gravityPulse: return 3.0
        case .pulseBlade: return .infinity
        }
    }

    /// Bullet travel speed (points/second) — only meaningful for the
    /// bullet-based styles (`singleShot`, `spread`, `piercing`, `splash`,
    /// `acidZone`). Rocket Launcher is deliberately slower/"heavier";
    /// Ice Cannon is faster, reading more like a beam.
    var projectileSpeed: CGFloat {
        switch self {
        case .rocketLauncher: return 600
        case .iceCannon: return 1100
        default: return 900
        }
    }

    /// Kill radius around a Rocket Launcher's impact point. Zero for every
    /// other weapon (unused).
    var splashRadius: CGFloat {
        self == .rocketLauncher ? 70 : 0
    }

    /// Vertical range (points, around the skier's row) that `.melee`,
    /// `.coneBurst`, and `.passiveMelee`-adjacent proximity checks use.
    /// Zero for every weapon that doesn't use a proximity check.
    var meleeRangeY: CGFloat {
        switch self {
        case .feralClaws: return 70
        case .wyrmsBreath: return 110
        default: return 0
        }
    }

    /// How long an Acid Sprayer impact zone lingers. Zero for every other
    /// weapon (unused).
    var acidZoneDuration: TimeInterval {
        self == .acidSprayer ? 3.0 : 0
    }
}
