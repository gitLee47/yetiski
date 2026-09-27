import SpriteKit

/// A single auto-fired projectile during a Yeti War. Purely a visual +
/// physics-body shell — `GameScene.advanceYetiWar` drives its movement by
/// mutating `position.y` directly each frame, the same way `advanceObstacles`
/// moves `ObstacleNode`s, rather than the node animating itself.
final class BulletNode: SKNode {
    override init() {
        super.init()
        buildVisuals()
        buildPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildVisuals() {
        let sprite = SKSpriteNode(texture: SpriteTextureLoader.texture(named: "sprite_bullet"))
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
}
