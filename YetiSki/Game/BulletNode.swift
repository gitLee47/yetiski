import SpriteKit

/// A single auto-fired projectile during a Yeti War. Purely a visual +
/// physics-body shell — `GameScene.advanceYetiWar` drives its movement by
/// mutating `position.y` directly each frame, the same way `advanceObstacles`
/// moves `ObstacleNode`s, rather than the node animating itself.
final class BulletNode: SKNode {
    private let sprite = SKSpriteNode(texture: SpriteTextureLoader.texture(named: "sprite_bullet"))

    override init() {
        super.init()
        buildVisuals()
        buildPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildVisuals() {
        sprite.size = CGSize(width: 10, height: 18)
        addChild(sprite)
    }

    private func buildPhysics() {
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 8, height: 14))
        body.isDynamic = true
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.bullet
        body.contactTestBitMask = PhysicsCategory.yeti
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }

    /// Restyles the shared bullet sprite per-weapon (bigger/redder for a
    /// Rocket Launcher's heavy shot, tall/cyan for Ice Cannon's beam-like
    /// shot, etc.) via a color-blend tint — the same technique
    /// `SkierNode.applySkin` uses to recolor its one base sprite, so no new
    /// bullet art is needed per weapon.
    func applyStyle(scaleX: CGFloat = 1, scaleY: CGFloat = 1, tint: SKColor? = nil) {
        sprite.xScale = scaleX
        sprite.yScale = scaleY
        if let tint {
            sprite.color = tint
            sprite.colorBlendFactor = 0.75
        }
    }
}
