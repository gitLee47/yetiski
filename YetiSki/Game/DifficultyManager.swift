import CoreGraphics
import Foundation

/// Pure logic mapping distance/time survived to gameplay tuning — scroll
/// speed, obstacle spawn frequency, and yeti ambush frequency. Centralized
/// here so the difficulty curve can be tuned without touching `GameScene`.
struct DifficultyManager {
    /// Points per second at the very start of a run.
    private let baseScrollSpeed: CGFloat = 220
    /// Points per second the scroll speed approaches as distance grows.
    private let maxScrollSpeed: CGFloat = 620
    /// Distance (in score units) over which the scroll speed ramps toward its cap.
    private let rampDistance: CGFloat = 6000

    /// 0...1 progress toward maximum speed, eased so the ramp is smooth and
    /// gradual rather than a set of hard thresholds.
    private func speedProgress(atDistance distance: Int) -> CGFloat {
        let t = min(1, CGFloat(distance) / rampDistance)
        // Ease-out so early game ramps faster than the long tail.
        return 1 - pow(1 - t, 2)
    }

    func scrollSpeed(atDistance distance: Int) -> CGFloat {
        let t = speedProgress(atDistance: distance)
        return baseScrollSpeed + (maxScrollSpeed - baseScrollSpeed) * t
    }

    /// Extra scroll speed (points/second) awarded per level survived — a
    /// small, noticeable bump each time you level up, on top of the smooth
    /// distance-based ramp above. Capped at `maxLevel`, like the other
    /// level-driven curves, so it doesn't grow unbounded on a very long run.
    func levelSpeedBonus(atLevel level: Int) -> CGFloat {
        let cappedLevel = min(level, maxLevel)
        return CGFloat(cappedLevel - 1) * 6
    }

    /// Total forward scroll speed — the continuous distance-based ramp plus
    /// the per-level bonus — the actual speed the world/skier moves at.
    func totalScrollSpeed(atDistance distance: Int, level: Int) -> CGFloat {
        scrollSpeed(atDistance: distance) + levelSpeedBonus(atLevel: level)
    }

    /// Extra speed (points/second) the yeti moves *above* the world scroll
    /// speed while sprinting — this is what closes the gap toward the skier.
    /// Kept as a flat add-on rather than a multiplier on scroll speed, so it
    /// doesn't compound into an unbeatable sprint once the slope gets fast;
    /// early on this gives several seconds of visible approach to react to,
    /// and even at the hardest setting there's still a couple of seconds.
    func yetiClosingSpeed(atDistance distance: Int) -> CGFloat {
        let t = speedProgress(atDistance: distance)
        return 110 + (220 - 110) * t
    }

    /// How fast (points/second) the yeti can correct its x position toward
    /// the skier. Deliberately capped below the skier's own dash speed
    /// between lanes so a well-timed last-second dodge can actually work,
    /// instead of the yeti tracking every move perfectly.
    func yetiTurnSpeed(atDistance distance: Int) -> CGFloat {
        let t = speedProgress(atDistance: distance)
        return 140 + (230 - 140) * t
    }

    // MARK: - Levels (obstacle/yeti frequency)

    /// Seconds of survival between level-ups. Every level bumps obstacle and
    /// yeti-ambush frequency a notch, and is surfaced to the player as
    /// "Level N" in the HUD.
    let levelInterval: TimeInterval = 15

    /// Level at which the frequency curves reach their hardest setting.
    private let maxLevel = 10

    /// 1, 2, 3, ... — increments every `levelInterval` seconds of survival.
    func level(atTime time: TimeInterval) -> Int {
        1 + Int(time / levelInterval)
    }

    private func levelProgress(_ level: Int) -> CGFloat {
        min(1, CGFloat(level - 1) / CGFloat(maxLevel - 1))
    }

    /// Seconds between obstacle spawns — shrinks as the level rises, so
    /// obstacles show up more often the longer you survive.
    func obstacleSpawnInterval(atLevel level: Int) -> TimeInterval {
        let t = Double(levelProgress(level))
        let base: TimeInterval = 1.35
        let floor: TimeInterval = 0.45
        return base - (base - floor) * t
    }

    /// How long an ice-patch hit makes steering sluggish for.
    let iceSlipDuration: TimeInterval = 2.5
    /// `moveTo` duration used while slipping, vs. the normal 0.16s.
    let iceSlipMoveDuration: TimeInterval = 0.4

    /// Chance per spawn-check tick (see `GameScene`'s yeti timer) that a yeti
    /// ambush starts, if one isn't already active — grows with level so
    /// ambushes become more frequent over time.
    func yetiAmbushProbability(atLevel level: Int) -> Double {
        let t = Double(levelProgress(level))
        return 0.12 + 0.38 * t
    }

    /// Hard cap on how long the skier can go without a yeti ambush. The random
    /// probability above can theoretically whiff for a while, so this forces
    /// an ambush once this much time has passed since the last one — bad luck
    /// alone can never skip the feature. Shrinks as the level rises.
    func maxTimeBetweenAmbushes(atLevel level: Int) -> TimeInterval {
        let t = Double(levelProgress(level))
        let base: TimeInterval = 16
        let floor: TimeInterval = 7
        return base - (base - floor) * t
    }

    /// Max chase duration before the yeti gives up and retreats if it hasn't
    /// caught the skier. Set comfortably above the worst-case closing time so
    /// this is a safety net, not the thing usually ending the chase — most
    /// ambushes resolve by either catching the skier or scrolling past.
    let yetiChaseTimeout: TimeInterval = 7.5

    /// How often (seconds) `GameScene` rolls the dice on starting a yeti ambush.
    let yetiCheckInterval: TimeInterval = 3.0

    /// Level at which a second yeti can start ambushing concurrently with
    /// the first — a late-game spike in tension, not a new yeti variant.
    let dualYetiMinLevel = 7

    /// Chance per check tick that a second yeti joins an already-active
    /// ambush, once past `dualYetiMinLevel`. Deliberately much rarer than the
    /// normal single-ambush probability.
    func dualYetiAmbushProbability(atLevel level: Int) -> Double {
        guard level >= dualYetiMinLevel else { return 0 }
        let t = Double(levelProgress(level))
        return 0.05 + 0.15 * t
    }

    // MARK: - Ramps

    /// Seconds between ramp spawns. Kept on its own, much slower cadence than
    /// obstacles — a ramp is an escape tool, not just another obstacle
    /// flavor — and gets slightly *more* frequent at higher levels so there
    /// are more escape opportunities to offset the rising difficulty.
    func rampSpawnInterval(atLevel level: Int) -> TimeInterval {
        let t = Double(levelProgress(level))
        let base: TimeInterval = 8.0
        let floor: TimeInterval = 5.5
        return base - (base - floor) * t
    }

    /// How long a ramp jump's invincibility (and hop animation) lasts — long
    /// enough to clear an obstacle or duck past an active yeti.
    let rampJumpDuration: TimeInterval = 1.3

    /// Flat distance bonus awarded the instant a ramp is used, representing
    /// ground covered while airborne.
    let rampJumpDistanceBonus: CGFloat = 220

    // MARK: - Pickups

    /// Seconds between pickup spawns — one shared cadence for all five kinds
    /// (`PickupKind`), independent of the obstacle/ramp timers, slightly
    /// faster at higher levels.
    func pickupSpawnInterval(atLevel level: Int) -> TimeInterval {
        let t = Double(levelProgress(level))
        let base: TimeInterval = 4.0
        let floor: TimeInterval = 2.5
        return base - (base - floor) * t
    }

    /// How long the shield powerup's invincibility lasts.
    let shieldDuration: TimeInterval = 4.0

    /// How long the speed boost powerup lasts, and the flat extra speed
    /// (points/second) it adds on top of the normal total scroll speed.
    let speedBoostDuration: TimeInterval = 4.0
    let speedBoostExtraSpeed: CGFloat = 220

    /// How much extra time (seconds) the yeti repellent adds to the "safe"
    /// window before the next ambush can start, on top of the normal reset.
    let yetiRepellentCooldownBonus: TimeInterval = 8.0

    /// Distance bonus for grabbing a snowflake — much smaller than a ramp's,
    /// since snowflakes are common.
    let snowflakeDistanceBonus: CGFloat = 50

    // MARK: - Icicles

    /// Seconds between icicle telegraph-then-strike events, independent of
    /// the other obstacle cadences.
    func icicleSpawnInterval(atLevel level: Int) -> TimeInterval {
        let t = Double(levelProgress(level))
        let base: TimeInterval = 6.0
        let floor: TimeInterval = 3.0
        return base - (base - floor) * t
    }

    /// How long the warning marker pulses before the icicle drops.
    let icicleTelegraphDuration: TimeInterval = 0.6
    /// How long the actual drop animation takes once it starts falling.
    let icicleFallDuration: TimeInterval = 0.22

    // MARK: - Snowboarder

    /// Seconds between drifting-snowboarder spawns, independent of the other
    /// obstacle cadences.
    func snowboarderSpawnInterval(atLevel level: Int) -> TimeInterval {
        let t = Double(levelProgress(level))
        let base: TimeInterval = 7.0
        let floor: TimeInterval = 4.0
        return base - (base - floor) * t
    }

    /// How far (points) the snowboarder drifts from its spawn lane, each way.
    let snowboarderDriftAmplitude: CGFloat = 70
    /// Seconds for one full left-right-left drift cycle.
    let snowboarderDriftPeriod: TimeInterval = 2.2
}
