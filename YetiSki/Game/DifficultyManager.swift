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
}
