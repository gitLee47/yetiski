import SpriteKit

/// A moving hazard: scrolls up like a normal obstacle but also drifts
/// sideways sinusoidally, so it's harder to predict than a fixed-lane
/// hazard. Drawn as the Kenney pack's alt-color skier (see
/// `SpriteTextureLoader`) — a reckless rival skier crossing your line — kept
/// visually distinct from `SkierNode`'s own color scheme so it doesn't read
/// as another instance of the player. Shares `PhysicsCategory.obstacle` —
/// `GameScene` distinguishes it from `ObstacleNode` by type when handling
/// contact.
final class SnowboarderNode: SKNode {
    private var driftElapsed: TimeInterval = 0
    private let driftAmplitude: CGFloat
    private let driftPeriod: TimeInterval
    private let centerX: CGFloat

    init(centerX: CGFloat, driftAmplitude: CGFloat, driftPeriod: TimeInterval) {
        self.centerX = centerX
        self.driftAmplitude = driftAmplitude
        self.driftPeriod = driftPeriod
        super.init()
        buildVisuals()
        buildPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildVisuals() {
        let sprite = SKSpriteNode(texture: SpriteTextureLoader.texture(named: "sprite_rival_skier_1"))
        sprite.size = CGSize(width: 34, height: 34)
        addChild(sprite)

        let frames = [
            SpriteTextureLoader.texture(named: "sprite_rival_skier_1"),
            SpriteTextureLoader.texture(named: "sprite_rival_skier_2"),
        ]
        sprite.run(.repeatForever(.animate(with: frames, timePerFrame: 0.18)))
    }

    private func buildPhysics() {
        let body = SKPhysicsBody(circleOfRadius: 16)
        body.isDynamic = false
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.obstacle
        body.contactTestBitMask = PhysicsCategory.skier
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }

    /// Advances the sideways drift; `GameScene` handles the vertical scroll separately.
    func stepDrift(dt: TimeInterval) {
        driftElapsed += dt
        let phase = (driftElapsed / driftPeriod) * (2 * .pi)
        position.x = centerX + driftAmplitude * CGFloat(sin(phase))
    }
}
