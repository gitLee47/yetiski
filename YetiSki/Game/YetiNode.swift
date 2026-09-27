import SpriteKit

/// The yeti: spawns off-screen, sprints toward the skier while homing on its
/// x-position, and despawns if it catches the skier or times out. Drawn as a
/// pixel-art sprite (Kenney's "Tiny Ski" pack, see `SpriteTextureLoader`),
/// cycling its 3 frames for a subtle idle/chase animation.
final class YetiNode: SKNode {
    static let width: CGFloat = 44
    static let height: CGFloat = 44

    /// Max horizontal speed (points/second) while homing toward the skier.
    var turnSpeed: CGFloat = 260
    /// Seconds since this yeti spawned — `GameScene` increments this each
    /// frame and despawns the yeti once it exceeds the chase timeout. Kept
    /// per-instance (rather than a single scalar in `GameScene`) so multiple
    /// yetis can be active with independent timeouts.
    var chaseElapsed: TimeInterval = 0
    /// True for a Yeti War horde member that actively homes toward the
    /// skier's lane (via `stepHoming`) rather than walking straight up its
    /// spawn lane. Set by `GameScene.advanceYetiWarSpawning`; a normal
    /// single/dual ambush yeti always homes regardless of this flag.
    var chasesSkier = false

    private let sprite = SKSpriteNode(texture: SpriteTextureLoader.texture(named: "sprite_yeti_1"))

    override init() {
        super.init()
        buildVisuals()
        buildPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildVisuals() {
        sprite.size = CGSize(width: Self.width, height: Self.height)
        addChild(sprite)

        let frames = [
            SpriteTextureLoader.texture(named: "sprite_yeti_1"),
            SpriteTextureLoader.texture(named: "sprite_yeti_2"),
            SpriteTextureLoader.texture(named: "sprite_yeti_3"),
        ]
        sprite.run(.repeatForever(.animate(with: frames, timePerFrame: 0.15)))
    }

    private func buildPhysics() {
        let physicsBody = SKPhysicsBody(circleOfRadius: Self.width / 2 - 4)
        physicsBody.isDynamic = true
        physicsBody.affectedByGravity = false
        physicsBody.allowsRotation = false
        physicsBody.categoryBitMask = PhysicsCategory.yeti
        // Includes `.bullet` so a Yeti War horde member (a plain YetiNode)
        // reports contact with a BulletNode, mirroring every other pair in
        // this game declaring the relationship on both sides.
        physicsBody.contactTestBitMask = PhysicsCategory.skier | PhysicsCategory.bullet
        physicsBody.collisionBitMask = PhysicsCategory.none
        self.physicsBody = physicsBody
    }

    /// Steers x toward `targetX` at up to `turnSpeed`, called every frame.
    func stepHoming(towardX targetX: CGFloat, deltaTime: TimeInterval) {
        let maxDelta = turnSpeed * CGFloat(deltaTime)
        let dx = (targetX - position.x).clamped(to: -maxDelta...maxDelta)
        position.x += dx
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
