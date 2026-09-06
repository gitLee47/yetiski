import SpriteKit

/// Core gameplay scene: scrolls the slope, spawns obstacles and yeti ambushes,
/// handles left/right tap steering, and reports events back to `GameViewModel`.
final class GameScene: SKScene, SKPhysicsContactDelegate {
    weak var viewModel: GameViewModel?

    private let difficulty = DifficultyManager()

    private let laneCount = 5
    private var currentLane = 2
    private var skier: SkierNode!

    private var snowLines: [SKShapeNode] = []
    private let snowLineSpacing: CGFloat = 90

    private var obstacles: [ObstacleNode] = []
    private var activeYeti: YetiNode?
    private var yetiChaseElapsed: TimeInterval = 0
    private var yetiCheckTimer: TimeInterval = 0
    /// Time since the last ambush ended (or the run started, if none yet).
    /// Once this crosses `DifficultyManager.maxTimeBetweenAmbushes`, the next
    /// check forces a spawn regardless of the random roll, so a run can never
    /// go too long without seeing the yeti.
    private var timeSinceLastYeti: TimeInterval = 0
    private var obstacleSpawnTimer: TimeInterval = 0

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
        addChild(skier)
    }

    // MARK: - Run lifecycle

    /// Resets all run state and starts (or restarts) gameplay.
    func startRun() {
        setUpSceneIfNeeded()
        isPaused = false

        obstacles.forEach { $0.removeFromParent() }
        obstacles.removeAll()
        activeYeti?.removeFromParent()
        activeYeti = nil

        distancePoints = 0
        elapsedTime = 0
        currentLevel = 1
        currentLane = laneCount / 2
        skier.position = CGPoint(x: laneCenterX(currentLane), y: skierY)
        skier.alpha = 1
        skier.zRotation = 0

        obstacleSpawnTimer = difficulty.obstacleSpawnInterval(atLevel: currentLevel)
        yetiCheckTimer = difficulty.yetiCheckInterval
        yetiChaseElapsed = 0
        timeSinceLastYeti = 0
        lastUpdateTime = nil
        isPlaying = true

        SoundManager.shared.startBackgroundMusic()
    }

    func stopRun() {
        isPlaying = false
        SoundManager.shared.stopBackgroundMusic()
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
        skier.moveTo(x: laneCenterX(currentLane))
        HapticsManager.shared.laneChange()
    }

    private func laneCenterX(_ lane: Int) -> CGFloat {
        -playableHalfWidth + laneWidth * (CGFloat(lane) + 0.5)
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

        let speed = difficulty.totalScrollSpeed(atDistance: currentScore, level: currentLevel)
        let travel = speed * CGFloat(dt)
        distancePoints += travel
        viewModel?.updateDistance(currentScore)

        scrollBackground(by: travel)
        advanceObstacles(travel: travel, dt: dt)
        advanceYeti(dt: dt)
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

    // MARK: - Yeti

    private func advanceYeti(dt: TimeInterval) {
        guard let yeti = activeYeti else {
            yetiCheckTimer -= dt
            timeSinceLastYeti += dt
            let mustAmbush = timeSinceLastYeti >= difficulty.maxTimeBetweenAmbushes(atLevel: currentLevel)
            if yetiCheckTimer <= 0 || mustAmbush {
                yetiCheckTimer = difficulty.yetiCheckInterval
                if mustAmbush || Double.random(in: 0..<1) < difficulty.yetiAmbushProbability(atLevel: currentLevel) {
                    spawnYeti()
                }
            }
            return
        }

        yetiChaseElapsed += dt
        let speed = difficulty.totalScrollSpeed(atDistance: currentScore, level: currentLevel)
            + difficulty.yetiClosingSpeed(atDistance: currentScore)
        yeti.position.y += speed * CGFloat(dt)
        yeti.stepHoming(towardX: skier.position.x, deltaTime: dt)

        let despawnY = size.height / 2 + 80
        if yeti.position.y > despawnY || yetiChaseElapsed > difficulty.yetiChaseTimeout {
            despawnYeti()
        }
    }

    private func spawnYeti() {
        let yeti = YetiNode()
        yeti.position = CGPoint(x: skier.position.x, y: -size.height / 2 - 90)
        yeti.zPosition = 8
        yeti.turnSpeed = difficulty.yetiTurnSpeed(atDistance: currentScore)
        addChild(yeti)
        activeYeti = yeti
        yetiChaseElapsed = 0
        timeSinceLastYeti = 0
        SoundManager.shared.playYetiRoar()
    }

    private func despawnYeti() {
        activeYeti?.removeFromParent()
        activeYeti = nil
    }

    // MARK: - Collisions

    func didBegin(_ contact: SKPhysicsContact) {
        guard isPlaying, !skier.isInvincible else { return }
        let categories = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if categories & PhysicsCategory.yeti != 0 {
            despawnYeti()
            isPlaying = false
            SoundManager.shared.stopBackgroundMusic()
            viewModel?.registerYetiCatch()
            return
        }

        if categories & PhysicsCategory.obstacle != 0 {
            removeObstacle(from: contact)
            skier.playHitFlash()
            let ended = viewModel?.registerHit() ?? false
            if ended {
                isPlaying = false
                SoundManager.shared.stopBackgroundMusic()
            }
        }
    }

    private func removeObstacle(from contact: SKPhysicsContact) {
        for node in [contact.bodyA.node, contact.bodyB.node] {
            if let obstacle = node as? ObstacleNode {
                obstacle.removeFromParent()
                obstacles.removeAll { $0 === obstacle }
            }
        }
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
