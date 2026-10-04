import SpriteKit

/// Core gameplay scene: scrolls the slope, spawns obstacles, ramps, and yeti
/// ambushes, handles left/right tap steering, and reports events back to
/// `GameViewModel`.
final class GameScene: SKScene, SKPhysicsContactDelegate {
    weak var viewModel: GameViewModel?

    private let difficulty = DifficultyManager()

    private let laneCount = 5
    private var currentLane = 2
    private var skier: SkierNode!

    private var snowLines: [SKShapeNode] = []
    private let snowLineSpacing: CGFloat = 90

    private var obstacles: [ObstacleNode] = []
    private var ramps: [RampNode] = []
    private var rampSpawnTimer: TimeInterval = 0
    private var pickups: [PickupNode] = []
    private var pickupSpawnTimer: TimeInterval = 0
    private var icicles: [IcicleNode] = []
    private var icicleSpawnTimer: TimeInterval = 0
    private var snowboarders: [SnowboarderNode] = []
    private var snowboarderSpawnTimer: TimeInterval = 0
    /// Extra scroll speed (points/second) from an active speed-boost pickup,
    /// counted down each frame; folded into `update(_:)`'s speed calc while > 0.
    private var speedBoostTimeRemaining: TimeInterval = 0
    /// Mirrors the shield pickup's duration purely so the HUD knows when to
    /// show its buff icon — the actual invincibility/visual lives on `skier`.
    private var shieldTimeRemaining: TimeInterval = 0
    /// While > 0 (set by an ice-patch hit), `steer(by:)` uses a longer,
    /// sluggish move duration.
    private var slipTimeRemaining: TimeInterval = 0
    /// Usually holds at most one yeti; a second can join concurrently past
    /// `DifficultyManager.dualYetiMinLevel`.
    private var activeYetis: [YetiNode] = []
    private var yetiCheckTimer: TimeInterval = 0
    /// While > 0 (set by the yeti-repellent pickup), ambush checks are
    /// skipped entirely — a real "safe window", not just a delay on the
    /// pity-timer, so a lucky probability roll can't sneak an ambush through.
    private var yetiSuppressedTimeRemaining: TimeInterval = 0
    /// Time since the last ambush ended (or the run started, if none yet).
    /// Once this crosses `DifficultyManager.maxTimeBetweenAmbushes`, the next
    /// check forces a spawn regardless of the random roll, so a run can never
    /// go too long without seeing the yeti.
    private var timeSinceLastYeti: TimeInterval = 0
    private var obstacleSpawnTimer: TimeInterval = 0

    // MARK: - Yeti War
    /// Poll cadence + pity-timer pair for deciding when a war starts, same
    /// shape as `yetiCheckTimer`/`timeSinceLastYeti` above.
    private var yetiWarCheckTimer: TimeInterval = 0
    private var timeSinceLastYetiWar: TimeInterval = 0
    private var isYetiWarActive = false
    private var yetiWarTimeRemaining: TimeInterval = 0
    private var yetiWarTotalDuration: TimeInterval = 0
    private var yetiWarYetisRemainingToSpawn = 0
    private var yetiWarSpawnTimer: TimeInterval = 0
    private var hordeYetis: [YetiNode] = []
    private var yetiWarKillCount = 0
    private var bullets: [BulletNode] = []
    /// Counts down to the next weapon activation — gates any `activateWeapon()`
    /// call, not just literal bullets (melee/hitscan/pulse etc. use it too).
    private var weaponCooldownTimer: TimeInterval = 0
    /// Lingering Acid Sprayer impact zones: `(lane, secondsRemaining, visual)`.
    private var acidZones: [(lane: Int, timeRemaining: TimeInterval, visual: SKShapeNode)] = []
    private var currentWeapon: WeaponKind = .machineGun

    private var distancePoints: CGFloat = 0
    private var currentScore: Int { Int(distancePoints / 10) }

    /// Seconds survived this run; drives the discrete difficulty "level"
    /// (obstacle/yeti frequency), independent of the continuous speed ramp.
    private var elapsedTime: TimeInterval = 0
    private var currentLevel = 1

    private var lastUpdateTime: TimeInterval?
    private(set) var isPlaying = false

    private var playableHalfWidth: CGFloat { size.width * 0.42 }
    private var laneWidth: CGFloat { (playableHalfWidth * 2) / CGFloat(laneCount) }
    /// Skier stays fixed near the top third of the screen; obstacles and the
    /// yeti enter from below and scroll up past it, matching the original
    /// SkiFree-style downhill view.
    private var skierY: CGFloat { size.height / 2 - size.height * 0.22 }

    private var didSetUpScene = false

    override func didMove(to view: SKView) {
        setUpSceneIfNeeded()
    }

    /// Builds the one-time scene contents (background, skier). Safe to call
    /// from both `didMove(to:)` and `startRun()` since SpriteKit doesn't
    /// guarantee `didMove` has already run by the time SwiftUI's `onAppear`
    /// calls `startRun()` on a freshly created scene.
    private func setUpSceneIfNeeded() {
        guard !didSetUpScene else { return }
        didSetUpScene = true

        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = SKColor(red: 0.85, green: 0.92, blue: 0.98, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        buildSnowBackground()

        skier = SkierNode()
        skier.zPosition = 10
        skier.applySkin(viewModel?.selectedSkin ?? .classic)
        addChild(skier)
    }

    // MARK: - Run lifecycle

    /// Resets all run state and starts (or restarts) gameplay.
    func startRun() {
        setUpSceneIfNeeded()
        // Re-apply in case the skin changed (via the Locker) since this
        // scene's skier was first built — it's reused across runs.
        skier.applySkin(viewModel?.selectedSkin ?? .classic)
        isPaused = false

        obstacles.forEach { $0.removeFromParent() }
        obstacles.removeAll()
        ramps.forEach { $0.removeFromParent() }
        ramps.removeAll()
        pickups.forEach { $0.removeFromParent() }
        pickups.removeAll()
        icicles.forEach { $0.removeFromParent() }
        icicles.removeAll()
        snowboarders.forEach { $0.removeFromParent() }
        snowboarders.removeAll()
        speedBoostTimeRemaining = 0
        shieldTimeRemaining = 0
        slipTimeRemaining = 0
        skier.setSlipping(false)
        activeYetis.forEach { $0.removeFromParent() }
        activeYetis.removeAll()
        hordeYetis.forEach { $0.removeFromParent() }
        hordeYetis.removeAll()
        bullets.forEach { $0.removeFromParent() }
        bullets.removeAll()
        acidZones.forEach { $0.visual.removeFromParent() }
        acidZones.removeAll()
        isYetiWarActive = false
        yetiWarTimeRemaining = 0
        yetiWarKillCount = 0
        yetiWarCheckTimer = 0
        timeSinceLastYetiWar = 0

        distancePoints = 0
        elapsedTime = 0
        currentLevel = 1
        currentLane = laneCount / 2
        skier.position = CGPoint(x: laneCenterX(currentLane), y: skierY)
        skier.alpha = 1
        skier.zRotation = 0

        obstacleSpawnTimer = difficulty.obstacleSpawnInterval(atLevel: currentLevel)
        rampSpawnTimer = difficulty.rampSpawnInterval(atLevel: currentLevel)
        pickupSpawnTimer = difficulty.pickupSpawnInterval(atLevel: currentLevel)
        icicleSpawnTimer = difficulty.icicleSpawnInterval(atLevel: currentLevel)
        snowboarderSpawnTimer = difficulty.snowboarderSpawnInterval(atLevel: currentLevel)
        yetiCheckTimer = difficulty.yetiCheckInterval
        timeSinceLastYeti = 0
        yetiSuppressedTimeRemaining = 0
        yetiWarCheckTimer = difficulty.yetiWarCheckInterval
        lastUpdateTime = nil
        isPlaying = true

        SoundManager.shared.startBackgroundMusic()
    }

    func stopRun() {
        isPlaying = false
        SoundManager.shared.stopBackgroundMusic()
    }

    /// Resumes the current run in place after the player spends a revive
    /// token or watches an ad at the continue-offer prompt. Unlike
    /// `startRun()`, this does NOT reset distance/level/elapsed time — only
    /// the immediate hazards are cleared and the skier gets a grace-period
    /// shield so it isn't hit again the instant play resumes. Ramps/pickups
    /// are left in place since they're harmless.
    func continueRun() {
        obstacles.forEach { $0.removeFromParent() }
        obstacles.removeAll()
        icicles.forEach { $0.removeFromParent() }
        icicles.removeAll()
        snowboarders.forEach { $0.removeFromParent() }
        snowboarders.removeAll()
        despawnAllYetis()
        hordeYetis.forEach { $0.removeFromParent() }
        hordeYetis.removeAll()
        bullets.forEach { $0.removeFromParent() }
        bullets.removeAll()
        acidZones.forEach { $0.visual.removeFromParent() }
        acidZones.removeAll()
        isYetiWarActive = false
        yetiWarTimeRemaining = 0
        yetiWarKillCount = 0

        currentLane = laneCount / 2
        skier.position = CGPoint(x: laneCenterX(currentLane), y: skierY)
        skier.alpha = 1
        skier.zRotation = 0
        skier.setSlipping(false)
        slipTimeRemaining = 0

        let graceDuration: TimeInterval = 3.0
        skier.playShield(duration: graceDuration)
        shieldTimeRemaining = graceDuration

        lastUpdateTime = nil
        isPlaying = true
        SoundManager.shared.startBackgroundMusic()
    }

    /// Called by `GameContainerView` once the player confirms a weapon on the
    /// Yeti War banner — actually starts the horde after `triggerYetiWar()`
    /// paused everything and handed off to the SwiftUI weapon-select overlay.
    func beginYetiWar(weapon: WeaponKind) {
        currentWeapon = weapon
        isYetiWarActive = true
        yetiWarTotalDuration = difficulty.yetiWarDuration(atLevel: currentLevel)
        yetiWarTimeRemaining = yetiWarTotalDuration
        yetiWarYetisRemainingToSpawn = difficulty.yetiWarHordeCount(atLevel: currentLevel)
        yetiWarSpawnTimer = 0
        yetiWarKillCount = 0
        weaponCooldownTimer = 0
        lastUpdateTime = nil
        isPlaying = true
        SoundManager.shared.startBackgroundMusic()
    }

    /// Freezes the simulation (actions, physics, `update(_:)`) and steering
    /// input in place. Uses `SKScene`'s own `isPaused`, which SpriteKit
    /// already respects for the update loop — we just also need to guard
    /// `touchesBegan` ourselves, since raw touch delivery isn't affected by it.
    func pauseRun() {
        isPaused = true
        SoundManager.shared.pauseBackgroundMusic()
    }

    func resumeRun() {
        isPaused = false
        SoundManager.shared.resumeBackgroundMusic()
    }

    // MARK: - Background

    private func buildSnowBackground() {
        let lineCount = Int(ceil(size.height / snowLineSpacing)) + 2
        for i in 0..<lineCount {
            let line = SKShapeNode(rectOf: CGSize(width: size.width, height: 3))
            line.fillColor = SKColor(white: 1, alpha: 0.6)
            line.strokeColor = .clear
            line.zPosition = 1
            line.position = CGPoint(x: 0, y: -size.height / 2 + CGFloat(i) * snowLineSpacing)
            addChild(line)
            snowLines.append(line)
        }
    }

    private func scrollBackground(by distance: CGFloat) {
        let totalHeight = CGFloat(snowLines.count) * snowLineSpacing
        for line in snowLines {
            line.position.y += distance
            if line.position.y > size.height / 2 + snowLineSpacing {
                line.position.y -= totalHeight
            }
        }
    }

    // MARK: - Steering

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isPlaying, !isPaused, let touch = touches.first else { return }
        let x = touch.location(in: self).x
        if x < 0 {
            steer(by: -1)
        } else {
            steer(by: 1)
        }
    }

    private func steer(by delta: Int) {
        let newLane = min(max(currentLane + delta, 0), laneCount - 1)
        guard newLane != currentLane else { return }
        currentLane = newLane
        let duration = slipTimeRemaining > 0 ? difficulty.iceSlipMoveDuration : difficulty.normalSteerDuration
        skier.moveTo(x: laneCenterX(currentLane), duration: duration)
        HapticsManager.shared.laneChange()
    }

    private func laneCenterX(_ lane: Int) -> CGFloat {
        -playableHalfWidth + laneWidth * (CGFloat(lane) + 0.5)
    }

    /// Inverse of `laneCenterX(_:)` — recovers which lane a hazard is
    /// sitting in from its x position, so an ice-patch hit can redirect the
    /// skier toward one without each hazard needing to store its own lane.
    private func laneIndex(forX x: CGFloat) -> Int {
        let raw = Int((((x + playableHalfWidth) / laneWidth) - 0.5).rounded())
        return min(max(raw, 0), laneCount - 1)
    }

    /// The lane of the hazard (obstacle, rival skier, or live icicle) closest
    /// to the skier — preferring one still approaching from below, since
    /// that's the one an ice-patch slip should throw the skier toward.
    /// Ice patches themselves don't count as a "hazard" to slip into.
    private func nearestHazardLane() -> Int? {
        var candidates: [(y: CGFloat, x: CGFloat)] = []
        for obstacle in obstacles where obstacle.kind != .icePatch {
            candidates.append((obstacle.position.y, obstacle.position.x))
        }
        for snowboarder in snowboarders {
            candidates.append((snowboarder.position.y, snowboarder.position.x))
        }
        for icicle in icicles where icicle.phase != .impacted {
            candidates.append((icicle.position.y, icicle.position.x))
        }

        let approaching = candidates.filter { $0.y <= skierY }
        let pool = approaching.isEmpty ? candidates : approaching
        guard let nearest = pool.min(by: { abs($0.y - skierY) < abs($1.y - skierY) }) else { return nil }
        return laneIndex(forX: nearest.x)
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        guard isPlaying else { return }
        let dt = min(lastUpdateTime.map { currentTime - $0 } ?? 0, 1.0 / 30.0)
        guard dt > 0 else { return }

        elapsedTime += dt
        currentLevel = difficulty.level(atTime: elapsedTime)
        viewModel?.updateLevel(currentLevel)

        if speedBoostTimeRemaining > 0 {
            speedBoostTimeRemaining = max(0, speedBoostTimeRemaining - dt)
        }
        if shieldTimeRemaining > 0 {
            shieldTimeRemaining = max(0, shieldTimeRemaining - dt)
        }
        if slipTimeRemaining > 0 {
            slipTimeRemaining = max(0, slipTimeRemaining - dt)
            if slipTimeRemaining == 0 {
                skier.setSlipping(false)
            }
        }
        viewModel?.updateBuffs(shieldActive: shieldTimeRemaining > 0, speedBoostActive: speedBoostTimeRemaining > 0)

        let boost = speedBoostTimeRemaining > 0 ? difficulty.speedBoostExtraSpeed : 0
        let speed = difficulty.totalScrollSpeed(atDistance: currentScore, level: currentLevel) + boost
        let travel = speed * CGFloat(dt)
        distancePoints += travel
        viewModel?.updateDistance(currentScore)

        scrollBackground(by: travel)

        if isYetiWarActive {
            advanceYetiWar(dt: dt)
        } else {
            advanceObstacles(travel: travel, dt: dt)
            advanceRamps(travel: travel, dt: dt)
            advancePickups(travel: travel, dt: dt)
            advanceIcicles(dt: dt)
            advanceSnowboarders(travel: travel, dt: dt)
            advanceYeti(dt: dt)
        }
        advanceYetiWarTrigger(dt: dt)
        viewModel?.updateYetiWar(active: isYetiWarActive, timeRemaining: yetiWarTimeRemaining, kills: yetiWarKillCount)
    }

    // MARK: - Obstacles

    private func advanceObstacles(travel: CGFloat, dt: TimeInterval) {
        obstacleSpawnTimer -= dt
        if obstacleSpawnTimer <= 0 {
            spawnObstacle()
            obstacleSpawnTimer = difficulty.obstacleSpawnInterval(atLevel: currentLevel)
        }

        let despawnY = size.height / 2 + 60
        for obstacle in obstacles {
            obstacle.position.y += travel
        }
        let (remaining, despawned) = obstacles.partitioned { $0.position.y > despawnY }
        despawned.forEach { $0.removeFromParent() }
        obstacles = remaining
    }

    private func spawnObstacle() {
        let lane = Int.random(in: 0..<laneCount)
        let kind = ObstacleKind.allCases.randomElement() ?? .stone
        let obstacle = ObstacleNode(kind: kind)
        obstacle.position = CGPoint(x: laneCenterX(lane), y: -size.height / 2 - 40)
        obstacle.zPosition = 5
        addChild(obstacle)
        obstacles.append(obstacle)
    }

    // MARK: - Ramps

    private func advanceRamps(travel: CGFloat, dt: TimeInterval) {
        rampSpawnTimer -= dt
        if rampSpawnTimer <= 0 {
            spawnRamp()
            rampSpawnTimer = difficulty.rampSpawnInterval(atLevel: currentLevel)
        }

        let despawnY = size.height / 2 + 60
        for ramp in ramps {
            ramp.position.y += travel
        }
        let (remaining, despawned) = ramps.partitioned { $0.position.y > despawnY }
        despawned.forEach { $0.removeFromParent() }
        ramps = remaining
    }

    private func spawnRamp() {
        let lane = Int.random(in: 0..<laneCount)
        let ramp = RampNode()
        ramp.position = CGPoint(x: laneCenterX(lane), y: -size.height / 2 - 40)
        ramp.zPosition = 4
        addChild(ramp)
        ramps.append(ramp)
    }

    // MARK: - Pickups

    private func advancePickups(travel: CGFloat, dt: TimeInterval) {
        pickupSpawnTimer -= dt
        if pickupSpawnTimer <= 0 {
            spawnPickup()
            pickupSpawnTimer = difficulty.pickupSpawnInterval(atLevel: currentLevel)
        }

        let despawnY = size.height / 2 + 60
        for pickup in pickups {
            pickup.position.y += travel
        }
        let (remaining, despawned) = pickups.partitioned { $0.position.y > despawnY }
        despawned.forEach { $0.removeFromParent() }
        pickups = remaining
    }

    private func spawnPickup() {
        let lane = Int.random(in: 0..<laneCount)
        let kind = Self.randomPickupKind()
        let pickup = PickupNode(kind: kind)
        pickup.position = CGPoint(x: laneCenterX(lane), y: -size.height / 2 - 40)
        pickup.zPosition = 4
        addChild(pickup)
        pickups.append(pickup)
    }

    /// Weighted random pick across `PickupKind.spawnWeight`.
    private static func randomPickupKind() -> PickupKind {
        let totalWeight = PickupKind.allCases.reduce(0) { $0 + $1.spawnWeight }
        var roll = Double.random(in: 0..<totalWeight)
        for kind in PickupKind.allCases {
            if roll < kind.spawnWeight { return kind }
            roll -= kind.spawnWeight
        }
        return .snowflake
    }

    // MARK: - Icicles

    private func advanceIcicles(dt: TimeInterval) {
        icicleSpawnTimer -= dt
        if icicleSpawnTimer <= 0 {
            spawnIcicle()
            icicleSpawnTimer = difficulty.icicleSpawnInterval(atLevel: currentLevel)
        }

        for icicle in icicles where icicle.advance(dt: dt) {
            checkIcicleImpact(icicle)
        }

        let (remaining, finished) = icicles.partitioned { $0.phase == .impacted }
        finished.forEach { $0.removeFromParent() }
        icicles = remaining
    }

    private func spawnIcicle() {
        let lane = Int.random(in: 0..<laneCount)
        let icicle = IcicleNode(
            telegraphDuration: difficulty.icicleTelegraphDuration,
            fallDuration: difficulty.icicleFallDuration
        )
        icicle.position = CGPoint(x: laneCenterX(lane), y: skierY)
        icicle.zPosition = 9
        addChild(icicle)
        icicles.append(icicle)
    }

    private func checkIcicleImpact(_ icicle: IcicleNode) {
        guard !skier.isInvincible else { return }
        let hitRadius: CGFloat = 22
        guard abs(icicle.position.x - skier.position.x) < hitRadius else { return }
        registerObstacleHit()
    }

    // MARK: - Snowboarder

    private func advanceSnowboarders(travel: CGFloat, dt: TimeInterval) {
        snowboarderSpawnTimer -= dt
        if snowboarderSpawnTimer <= 0 {
            spawnSnowboarder()
            snowboarderSpawnTimer = difficulty.snowboarderSpawnInterval(atLevel: currentLevel)
        }

        let despawnY = size.height / 2 + 60
        for snowboarder in snowboarders {
            snowboarder.position.y += travel
            snowboarder.stepDrift(dt: dt)
            // Keep it on the visible slope even if drift would carry an
            // outer-lane spawn past the edge.
            snowboarder.position.x = min(max(snowboarder.position.x, -playableHalfWidth), playableHalfWidth)
        }
        let (remaining, despawned) = snowboarders.partitioned { $0.position.y > despawnY }
        despawned.forEach { $0.removeFromParent() }
        snowboarders = remaining
    }

    private func spawnSnowboarder() {
        let lane = Int.random(in: 0..<laneCount)
        let snowboarder = SnowboarderNode(
            centerX: laneCenterX(lane),
            driftAmplitude: difficulty.snowboarderDriftAmplitude,
            driftPeriod: difficulty.snowboarderDriftPeriod
        )
        snowboarder.position = CGPoint(x: laneCenterX(lane), y: -size.height / 2 - 40)
        snowboarder.zPosition = 5
        addChild(snowboarder)
        snowboarders.append(snowboarder)
    }

    // MARK: - Yeti

    private func advanceYeti(dt: TimeInterval) {
        advanceYetiAmbushScheduling(dt: dt)

        guard !activeYetis.isEmpty else { return }

        let speed = difficulty.totalScrollSpeed(atDistance: currentScore, level: currentLevel)
            + difficulty.yetiClosingSpeed(atDistance: currentScore)
        let despawnY = size.height / 2 + 80

        for yeti in activeYetis {
            yeti.chaseElapsed += dt
            yeti.position.y += speed * CGFloat(dt)
            yeti.stepHoming(towardX: skier.position.x, deltaTime: dt)
        }

        let (remaining, finished) = activeYetis.partitioned {
            $0.position.y > despawnY || $0.chaseElapsed > difficulty.yetiChaseTimeout
        }
        finished.forEach { $0.removeFromParent() }
        activeYetis = remaining
    }

    /// Decides whether a new ambush should start this frame — either the
    /// first yeti of a fresh ambush, or (past `dualYetiMinLevel`) a second
    /// one joining an already-active chase.
    private func advanceYetiAmbushScheduling(dt: TimeInterval) {
        if yetiSuppressedTimeRemaining > 0 {
            yetiSuppressedTimeRemaining = max(0, yetiSuppressedTimeRemaining - dt)
            timeSinceLastYeti = 0
            return
        }

        yetiCheckTimer -= dt
        timeSinceLastYeti += dt
        let mustAmbush = activeYetis.isEmpty
            && timeSinceLastYeti >= difficulty.maxTimeBetweenAmbushes(atLevel: currentLevel)
        guard yetiCheckTimer <= 0 || mustAmbush else { return }
        yetiCheckTimer = difficulty.yetiCheckInterval

        if activeYetis.isEmpty {
            if mustAmbush || Double.random(in: 0..<1) < difficulty.yetiAmbushProbability(atLevel: currentLevel) {
                spawnYeti()
            }
        } else if activeYetis.count == 1 {
            if Double.random(in: 0..<1) < difficulty.dualYetiAmbushProbability(atLevel: currentLevel) {
                spawnYeti()
            }
        }
    }

    private func spawnYeti() {
        let lane = Int.random(in: 0..<laneCount)
        let yeti = YetiNode()
        yeti.position = CGPoint(x: laneCenterX(lane), y: -size.height / 2 - 90)
        yeti.zPosition = 8
        yeti.turnSpeed = difficulty.yetiTurnSpeed(atDistance: currentScore)
        addChild(yeti)
        activeYetis.append(yeti)
        timeSinceLastYeti = 0
        SoundManager.shared.playYetiRoar()
    }

    private func despawnAllYetis() {
        activeYetis.forEach { $0.removeFromParent() }
        activeYetis.removeAll()
    }

    // MARK: - Yeti War

    /// Decides whether a Yeti War should start this frame — same poll-cadence
    /// + pity-timer shape as `advanceYetiAmbushScheduling`, just for a much
    /// bigger, rarer event.
    private func advanceYetiWarTrigger(dt: TimeInterval) {
        guard !isYetiWarActive, currentLevel >= difficulty.yetiWarMinLevel else { return }

        yetiWarCheckTimer -= dt
        timeSinceLastYetiWar += dt
        let mustTrigger = timeSinceLastYetiWar >= difficulty.maxTimeBetweenYetiWars(atLevel: currentLevel)
        guard yetiWarCheckTimer <= 0 || mustTrigger else { return }
        yetiWarCheckTimer = difficulty.yetiWarCheckInterval

        guard mustTrigger || Double.random(in: 0..<1) < difficulty.yetiWarProbability(atLevel: currentLevel) else { return }
        triggerYetiWar()
    }

    /// Clears the slope and hands off to the SwiftUI weapon-select banner
    /// (`GameViewModel.beginYetiWar()`) — `beginYetiWar(weapon:)` above is
    /// what actually resumes play once a weapon's chosen.
    private func triggerYetiWar() {
        despawnAllYetis()
        obstacles.forEach { $0.removeFromParent() }
        obstacles.removeAll()
        ramps.forEach { $0.removeFromParent() }
        ramps.removeAll()
        pickups.forEach { $0.removeFromParent() }
        pickups.removeAll()
        icicles.forEach { $0.removeFromParent() }
        icicles.removeAll()
        snowboarders.forEach { $0.removeFromParent() }
        snowboarders.removeAll()

        timeSinceLastYetiWar = 0
        stopRun()
        viewModel?.beginYetiWar()
    }

    /// Drives an active war: horde spawn pacing, horde/bullet movement, and
    /// the equipped weapon's auto-fire. Called from `update(_:)` instead of
    /// the normal hazard `advance*` calls while `isYetiWarActive`.
    private func advanceYetiWar(dt: TimeInterval) {
        yetiWarTimeRemaining -= dt
        if yetiWarTimeRemaining <= 0 {
            endYetiWar()
            return
        }

        advanceYetiWarSpawning(dt: dt)
        advanceYetiWarWeapon(dt: dt)
        advanceHordeYetis(dt: dt)
    }

    private func advanceYetiWarSpawning(dt: TimeInterval) {
        guard yetiWarYetisRemainingToSpawn > 0 else { return }
        yetiWarSpawnTimer -= dt
        guard yetiWarSpawnTimer <= 0 else { return }

        // Occasionally land a whole row across several lanes at once instead
        // of always a single yeti — reads as a wave hitting the slope.
        let isRowSpawn = Double.random(in: 0..<1) < difficulty.yetiWarRowSpawnProbability
        let rowSize = isRowSpawn ? Int.random(in: difficulty.yetiWarRowSpawnRange) : 1
        let spawnCount = min(rowSize, yetiWarYetisRemainingToSpawn, laneCount)

        var usedLanes: Set<Int> = []
        for _ in 0..<spawnCount {
            var lane = Int.random(in: 0..<laneCount)
            while usedLanes.contains(lane) {
                lane = Int.random(in: 0..<laneCount)
            }
            usedLanes.insert(lane)

            let yeti = YetiNode()
            yeti.position = CGPoint(x: laneCenterX(lane), y: -size.height / 2 - 90)
            yeti.zPosition = 8
            // A minority actively chase the skier's lane instead of walking
            // straight up, so the horde isn't purely a passive shooting
            // gallery — a few of them genuinely come at you.
            if Double.random(in: 0..<1) < difficulty.yetiWarChaserProbability(atLevel: currentLevel) {
                yeti.chasesSkier = true
                yeti.turnSpeed = difficulty.yetiWarChaserTurnSpeed(atLevel: currentLevel)
            }
            addChild(yeti)
            hordeYetis.append(yeti)
        }
        yetiWarYetisRemainingToSpawn -= spawnCount

        // Pace the remaining spawns evenly across whatever's left of the war.
        let remainingSlots = max(1, yetiWarYetisRemainingToSpawn)
        yetiWarSpawnTimer = max(0.3, yetiWarTimeRemaining / TimeInterval(remainingSlots + 1))
    }

    /// Ticks the equipped weapon's cooldown (skipped entirely for
    /// `.passiveMelee`, which never actively fires — see `didBegin(_:)`),
    /// then advances any live bullets and Acid Sprayer zones regardless of
    /// which weapon is currently equipped, since either could still be
    /// mid-flight/mid-duration from an earlier activation.
    private func advanceYetiWarWeapon(dt: TimeInterval) {
        if currentWeapon.firingStyle != .passiveMelee {
            weaponCooldownTimer -= dt
            if weaponCooldownTimer <= 0 {
                activateWeapon()
                weaponCooldownTimer = currentWeapon.fireInterval
            }
        }
        advanceBullets(dt: dt)
        advanceAcidZones(dt: dt)
    }

    /// Dispatches to the equipped weapon's effect. Bullet-based styles all
    /// go through `fireBullet(at:)`; the differences between them (splash,
    /// piercing, leaving an acid zone) are resolved on impact in
    /// `handleBulletContact(_:)`, not here. The proximity/instant "ability"
    /// styles resolve immediately and never touch `bullets`.
    private func activateWeapon() {
        switch currentWeapon.firingStyle {
        case .singleShot, .splash, .piercing, .acidZone:
            fireBullet(at: [currentLane])
        case .spread:
            let lanes = [currentLane - 1, currentLane, currentLane + 1].filter { (0..<laneCount).contains($0) }
            fireBullet(at: lanes)
        case .hitscan:
            activateHitscan()
        case .melee:
            activateMelee()
        case .coneBurst:
            activateConeBurst()
        case .pulse:
            activatePulse()
        case .passiveMelee:
            break
        }
    }

    /// Spawns one `BulletNode` per lane, tinted/sized to the equipped
    /// weapon so different weapons' shots read differently on screen even
    /// though they share the one `sprite_bullet` texture (same
    /// color-blend-tint technique `SkierNode.applySkin` uses for skins).
    private func fireBullet(at lanes: [Int]) {
        for lane in lanes {
            let bullet = BulletNode()
            bullet.position = CGPoint(x: laneCenterX(lane), y: skier.position.y - 20)
            bullet.zPosition = 7
            switch currentWeapon {
            case .rocketLauncher:
                bullet.applyStyle(scaleX: 1.8, scaleY: 1.8, tint: SKColor(red: 1.0, green: 0.45, blue: 0.15, alpha: 1))
            case .iceCannon:
                bullet.applyStyle(scaleX: 1.0, scaleY: 1.6, tint: SKColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1))
            case .acidSprayer:
                bullet.applyStyle(tint: SKColor(red: 0.4, green: 0.85, blue: 0.2, alpha: 1))
            default:
                break
            }
            addChild(bullet)
            bullets.append(bullet)
        }
    }

    /// Moves every live bullet at the equipped weapon's `projectileSpeed`
    /// and despawns anything that's scrolled off the top. Bullets travel
    /// toward negative y — new terrain (and the horde) always scrolls in
    /// from the bottom of the screen, so that's "downhill, ahead of the
    /// skier," not up toward where things have already passed.
    private func advanceBullets(dt: TimeInterval) {
        let despawnY = -size.height / 2 - 40
        for bullet in bullets {
            bullet.position.y -= currentWeapon.projectileSpeed * CGFloat(dt)
        }
        let (remaining, despawned) = bullets.partitioned { $0.position.y < despawnY }
        despawned.forEach { $0.removeFromParent() }
        bullets = remaining
    }

    /// Leaves a lingering, visible kill-zone in `lane` for an Acid Sprayer
    /// impact — no new node class needed, a plain translucent rect reads
    /// fine for a "hazardous puddle" effect.
    private func spawnAcidZone(lane: Int) {
        let visual = SKShapeNode(rectOf: CGSize(width: laneWidth * 0.9, height: 60), cornerRadius: 8)
        visual.fillColor = SKColor(red: 0.4, green: 0.85, blue: 0.2, alpha: 0.35)
        visual.strokeColor = SKColor(red: 0.4, green: 0.85, blue: 0.2, alpha: 0.7)
        visual.lineWidth = 2
        visual.position = CGPoint(x: laneCenterX(lane), y: skierY)
        visual.zPosition = 6
        addChild(visual)
        acidZones.append((lane, currentWeapon.acidZoneDuration, visual))
    }

    /// Ticks down and despawns every active Acid Sprayer zone; while a zone
    /// is alive, kills any horde yeti passing through its lane near the
    /// skier's row.
    private func advanceAcidZones(dt: TimeInterval) {
        for i in acidZones.indices.reversed() {
            acidZones[i].timeRemaining -= dt
            if acidZones[i].timeRemaining <= 0 {
                acidZones[i].visual.removeFromParent()
                acidZones.remove(at: i)
                continue
            }
            let lane = acidZones[i].lane
            hordeYetis
                .filter { laneIndex(forX: $0.position.x) == lane && abs($0.position.y - skierY) < 40 }
                .forEach { killHordeYeti($0) }
        }
    }

    /// Brief expanding-ring flash for the non-projectile "ability" weapons
    /// (melee/cone/pulse) — visual feedback that something happened, since
    /// those styles have no traveling bullet of their own.
    private func showEffectRing(at position: CGPoint, radius: CGFloat, color: SKColor) {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = color
        ring.lineWidth = 3
        ring.fillColor = color.withAlphaComponent(0.15)
        ring.position = position
        ring.zPosition = 9
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.3, duration: 0.25), .fadeOut(withDuration: 0.25)]),
            .removeFromParent(),
        ]))
    }

    /// Feral Claws: kills anything within melee range, current lane ± 1.
    private func activateMelee() {
        let laneRange = (currentLane - 1)...(currentLane + 1)
        hordeYetis
            .filter { abs($0.position.y - skierY) <= currentWeapon.meleeRangeY && laneRange.contains(laneIndex(forX: $0.position.x)) }
            .forEach { killHordeYeti($0) }
        showEffectRing(at: CGPoint(x: skier.position.x, y: skierY), radius: 60, color: .orange)
    }

    /// Wyrm's Breath: same proximity check as melee, but across every lane.
    private func activateConeBurst() {
        hordeYetis
            .filter { abs($0.position.y - skierY) <= currentWeapon.meleeRangeY }
            .forEach { killHordeYeti($0) }
        showEffectRing(at: CGPoint(x: 0, y: skierY), radius: playableHalfWidth, color: .red)
    }

    /// Optic Blast: instantly kills the nearest yeti in the current lane —
    /// no travel time, no bullet.
    private func activateHitscan() {
        guard let target = hordeYetis
            .filter({ laneIndex(forX: $0.position.x) == currentLane })
            .min(by: { abs($0.position.y - skierY) < abs($1.position.y - skierY) })
        else { return }
        killHordeYeti(target)
    }

    /// Gravity Pulse: clears every currently-chasing horde yeti on screen,
    /// regardless of lane or distance.
    private func activatePulse() {
        hordeYetis.filter { $0.chasesSkier }.forEach { killHordeYeti($0) }
        showEffectRing(at: CGPoint(x: 0, y: skierY), radius: playableHalfWidth, color: .purple)
    }

    /// Most horde yetis walk straight up their spawn lane — deliberately not
    /// homing toward the skier like a normal ambush, so they read as fair
    /// shooting-gallery targets — but a minority (`chasesSkier`, rolled at
    /// spawn) actively home in, so the horde isn't purely passive.
    private func advanceHordeYetis(dt: TimeInterval) {
        let speed = difficulty.totalScrollSpeed(atDistance: currentScore, level: currentLevel)
            + difficulty.yetiWarYetiSpeed(atLevel: currentLevel)
        let despawnY = size.height / 2 + 80
        for yeti in hordeYetis {
            yeti.position.y += speed * CGFloat(dt)
            if yeti.chasesSkier {
                yeti.stepHoming(towardX: skier.position.x, deltaTime: dt)
            }
        }
        let (remaining, despawned) = hordeYetis.partitioned { $0.position.y > despawnY }
        despawned.forEach { $0.removeFromParent() }
        hordeYetis = remaining
    }

    private func endYetiWar() {
        isYetiWarActive = false
        hordeYetis.forEach { $0.removeFromParent() }
        hordeYetis.removeAll()
        bullets.forEach { $0.removeFromParent() }
        bullets.removeAll()

        let bonus = yetiWarKillCount * difficulty.yetiWarClearBonusPerKill
        if bonus > 0 {
            viewModel?.addSnowCoins(bonus)
        }
        viewModel?.reportYetiWarResult(kills: yetiWarKillCount, bonusCoins: bonus)
        yetiWarKillCount = 0

        // Re-prime the normal spawn timers so hazards don't all fire at once
        // the instant normal play resumes.
        obstacleSpawnTimer = difficulty.obstacleSpawnInterval(atLevel: currentLevel)
        rampSpawnTimer = difficulty.rampSpawnInterval(atLevel: currentLevel)
        pickupSpawnTimer = difficulty.pickupSpawnInterval(atLevel: currentLevel)
        icicleSpawnTimer = difficulty.icicleSpawnInterval(atLevel: currentLevel)
        snowboarderSpawnTimer = difficulty.snowboarderSpawnInterval(atLevel: currentLevel)
        yetiCheckTimer = difficulty.yetiCheckInterval
        timeSinceLastYeti = 0
    }

    /// Finds (without removing) the horde yeti in a contact. Used by both
    /// `didBegin(_:)`'s skier-touched-a-yeti path (which then either removes
    /// it itself and costs a life, or — for `.passiveMelee` — routes it
    /// through `killHordeYeti(_:)` instead) and `handleBulletContact(_:)`'s
    /// weapon-killed-a-yeti path, which needs the yeti to still be in
    /// `hordeYetis` when a `.splash` style looks for nearby targets.
    private func hordeYeti(from contact: SKPhysicsContact) -> YetiNode? {
        for node in [contact.bodyA.node, contact.bodyB.node] {
            if let yeti = node as? YetiNode, hordeYetis.contains(where: { $0 === yeti }) {
                return yeti
            }
        }
        return nil
    }

    @discardableResult
    private func removeBullet(from contact: SKPhysicsContact) -> BulletNode? {
        for node in [contact.bodyA.node, contact.bodyB.node] {
            if let bullet = node as? BulletNode {
                bullet.removeFromParent()
                bullets.removeAll { $0 === bullet }
                return bullet
            }
        }
        return nil
    }

    /// Kills a horde yeti via a weapon (as opposed to the skier bumping
    /// into one) — removes it and awards the standard kill reward. Shared
    /// by every firing style so the reward logic lives in exactly one
    /// place regardless of how the kill was resolved.
    private func killHordeYeti(_ yeti: YetiNode) {
        guard let index = hordeYetis.firstIndex(where: { $0 === yeti }) else { return }
        hordeYetis.remove(at: index)
        yeti.removeFromParent()
        yetiWarKillCount += 1
        distancePoints += difficulty.yetiWarKillDistanceBonus
        viewModel?.addSnowCoins(difficulty.yetiWarKillCoinBonus)
        showFloatingText("+1", color: SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1), at: yeti.position)
    }

    /// Resolves a bullet hitting a horde yeti, differently per firing
    /// style: `.piercing` kills but keeps the bullet alive so it can hit
    /// the next yeti in its lane; `.splash` kills everything within
    /// `splashRadius`; `.acidZone` leaves a lingering zone behind; every
    /// other bullet style just kills the one yeti hit.
    private func handleBulletContact(_ contact: SKPhysicsContact) {
        guard let yeti = hordeYeti(from: contact) else { return }
        switch currentWeapon.firingStyle {
        case .piercing:
            killHordeYeti(yeti)
        case .splash:
            let radius = currentWeapon.splashRadius
            let caught = hordeYetis.filter {
                $0 === yeti || hypot($0.position.x - yeti.position.x, $0.position.y - yeti.position.y) <= radius
            }
            caught.forEach { killHordeYeti($0) }
            removeBullet(from: contact)
        case .acidZone:
            let lane = laneIndex(forX: yeti.position.x)
            killHordeYeti(yeti)
            spawnAcidZone(lane: lane)
            removeBullet(from: contact)
        default:
            killHordeYeti(yeti)
            removeBullet(from: contact)
        }
    }

    // MARK: - Collisions

    func didBegin(_ contact: SKPhysicsContact) {
        guard isPlaying else { return }
        let categories = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        // Ramps and pickups always register, even mid-invincibility (e.g.
        // chaining a second jump or grabbing a shield while already
        // invincible) — only obstacle/yeti damage respects invincibility.
        if categories & PhysicsCategory.ramp != 0 {
            handleRampContact(contact)
            return
        }
        if categories & PhysicsCategory.pickup != 0 {
            handlePickupContact(contact)
            return
        }
        // Bullets always register too — shooting down a horde yeti shouldn't
        // depend on the skier's own invincibility state.
        if categories & PhysicsCategory.bullet != 0 {
            handleBulletContact(contact)
            return
        }
        guard !skier.isInvincible else { return }

        if categories & PhysicsCategory.yeti != 0 {
            // A Yeti War horde member costs a life, like an obstacle, rather
            // than ending the run outright — only a normal single/dual
            // ambush yeti is an instant catch. Pulse Blade (.passiveMelee)
            // inverts this further: it never actively fires, so a skier/yeti
            // contact IS its attack — the yeti dies and the player is
            // rewarded instead of losing a life.
            if let yeti = hordeYeti(from: contact) {
                if currentWeapon.firingStyle == .passiveMelee {
                    killHordeYeti(yeti)
                } else {
                    hordeYetis.removeAll { $0 === yeti }
                    yeti.removeFromParent()
                    registerObstacleHit()
                }
                return
            }
            despawnAllYetis()
            stopRun()
            viewModel?.registerYetiCatch()
            return
        }

        if categories & PhysicsCategory.obstacle != 0 {
            if let obstacle = removeObstacle(from: contact) {
                if obstacle.kind == .icePatch {
                    slipTimeRemaining = difficulty.iceSlipDuration
                    skier.setSlipping(true)
                    showFloatingText("Slippery!", color: SKColor(red: 0.0, green: 0.55, blue: 0.95, alpha: 1), at: obstacle.position)
                    // The actual "losing control" moment: the slip throws the
                    // skier toward whatever hazard is nearest, rather than
                    // just quietly making the player's own next tap sluggish.
                    if let targetLane = nearestHazardLane(), targetLane != currentLane {
                        currentLane = targetLane
                        skier.moveTo(x: laneCenterX(currentLane), duration: difficulty.iceSlipMoveDuration)
                    }
                    return
                }
                registerObstacleHit()
                return
            }
            if removeSnowboarder(from: contact) != nil {
                registerObstacleHit()
                return
            }
        }
    }

    /// Shared "took a hit" flow for stones/holes/trees/snowboarders — flashes
    /// the skier, deducts a life, and ends the run if that was the last one.
    private func registerObstacleHit() {
        skier.playHitFlash()
        let ended = viewModel?.registerHit() ?? false
        if ended {
            stopRun()
        }
    }

    @discardableResult
    private func removeObstacle(from contact: SKPhysicsContact) -> ObstacleNode? {
        for node in [contact.bodyA.node, contact.bodyB.node] {
            if let obstacle = node as? ObstacleNode {
                obstacle.removeFromParent()
                obstacles.removeAll { $0 === obstacle }
                return obstacle
            }
        }
        return nil
    }

    @discardableResult
    private func removeSnowboarder(from contact: SKPhysicsContact) -> SnowboarderNode? {
        for node in [contact.bodyA.node, contact.bodyB.node] {
            if let snowboarder = node as? SnowboarderNode {
                snowboarder.removeFromParent()
                snowboarders.removeAll { $0 === snowboarder }
                return snowboarder
            }
        }
        return nil
    }

    private func handleRampContact(_ contact: SKPhysicsContact) {
        guard let ramp = removeRamp(from: contact) else { return }
        distancePoints += difficulty.rampJumpDistanceBonus
        skier.playJump(duration: difficulty.rampJumpDuration)
        showFloatingText("Jump!", color: SKColor(red: 1.0, green: 0.62, blue: 0.13, alpha: 1), at: ramp.position)
        SoundManager.shared.playJump()
        HapticsManager.shared.jump()
    }

    @discardableResult
    private func removeRamp(from contact: SKPhysicsContact) -> RampNode? {
        for node in [contact.bodyA.node, contact.bodyB.node] {
            if let ramp = node as? RampNode {
                ramp.removeFromParent()
                ramps.removeAll { $0 === ramp }
                return ramp
            }
        }
        return nil
    }

    // MARK: - Pickup effects

    private func handlePickupContact(_ contact: SKPhysicsContact) {
        guard let pickup = removePickup(from: contact) else { return }
        switch pickup.kind {
        case .shield:
            shieldTimeRemaining = difficulty.shieldDuration
            skier.playShield(duration: difficulty.shieldDuration)
            showFloatingText("Shield!", color: SKColor.systemBlue, at: pickup.position)
            SoundManager.shared.playPowerup()
            HapticsManager.shared.powerup()
        case .speedBoost:
            speedBoostTimeRemaining = difficulty.speedBoostDuration
            showFloatingText("Speed Boost!", color: SKColor(red: 0.2, green: 0.75, blue: 0.35, alpha: 1), at: pickup.position)
            SoundManager.shared.playPowerup()
            HapticsManager.shared.powerup()
        case .yetiRepellent:
            if !activeYetis.isEmpty {
                despawnAllYetis()
            }
            yetiSuppressedTimeRemaining = difficulty.yetiRepellentCooldownBonus
            showFloatingText("Yeti Repelled!", color: SKColor(red: 0.95, green: 0.35, blue: 0.15, alpha: 1), at: pickup.position)
            SoundManager.shared.playPowerup()
            HapticsManager.shared.powerup()
        case .extraLife:
            viewModel?.grantExtraLife()
            showFloatingText("+1 Life!", color: SKColor(red: 0.95, green: 0.25, blue: 0.45, alpha: 1), at: pickup.position)
            SoundManager.shared.playPowerup()
            HapticsManager.shared.powerup()
        case .snowflake:
            distancePoints += difficulty.snowflakeDistanceBonus
            viewModel?.addSnowCoins(1)
            showFloatingText(
                "+\(Int(difficulty.snowflakeDistanceBonus / 10))m",
                color: SKColor(red: 0.25, green: 0.55, blue: 0.85, alpha: 1),
                at: pickup.position
            )
            SoundManager.shared.playSnowflake()
            HapticsManager.shared.snowflake()
        }
    }

    @discardableResult
    private func removePickup(from contact: SKPhysicsContact) -> PickupNode? {
        for node in [contact.bodyA.node, contact.bodyB.node] {
            if let pickup = node as? PickupNode {
                pickup.removeFromParent()
                pickups.removeAll { $0 === pickup }
                return pickup
            }
        }
        return nil
    }

    /// A short label that rises and fades at a pickup's position, explaining
    /// what it just did — entirely self-contained in SpriteKit, no SwiftUI
    /// state needed.
    private func showFloatingText(_ text: String, color: SKColor, at position: CGPoint) {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 17
        label.fontColor = color
        label.position = CGPoint(x: position.x, y: position.y + 20)
        label.zPosition = 15
        addChild(label)

        let rise = SKAction.moveBy(x: 0, y: 34, duration: 0.85)
        rise.timingMode = .easeOut
        let fade = SKAction.sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.5)])
        label.run(.sequence([.group([rise, fade]), .removeFromParent()]))
    }
}

private extension Array {
    /// Splits the array into (elements failing `predicate`, elements matching `predicate`).
    func partitioned(by predicate: (Element) -> Bool) -> (kept: [Element], removed: [Element]) {
        var kept: [Element] = []
        var removed: [Element] = []
        for element in self {
            if predicate(element) {
                removed.append(element)
            } else {
                kept.append(element)
            }
        }
        return (kept, removed)
    }
}
