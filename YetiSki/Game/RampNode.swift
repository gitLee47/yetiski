import SpriteKit

/// A jump ramp: a bright boost-pad style marker (not a hazard). Hitting one
/// launches the skier briefly invincible to obstacles/the yeti and grants a
/// small burst of extra distance, styled clearly differently from the
/// stone/hole/tree hazards so it reads as something to seek out, not avoid.
/// Drawn as a hand-authored pixel-art wooden kicker plank (see
/// `SpriteTextureLoader`) — no ready-made ramp tile exists in the sourced
/// Kenney pack — with a white chevron baked into the sprite pointing
/// down-screen, since new terrain always scrolls in from the bottom.
final class RampNode: SKNode {
    private static let width: CGFloat = 42
    private static let height: CGFloat = 28

    override init() {
        super.init()
        buildVisuals()
        buildPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildVisuals() {
        let sprite = SKSpriteNode(texture: SpriteTextureLoader.texture(named: "sprite_ramp"))
        sprite.size = CGSize(width: Self.width, height: Self.height)
        addChild(sprite)
    }

    private func buildPhysics() {
        let body = SKPhysicsBody(rectangleOf: CGSize(width: Self.width, height: Self.height))
        body.isDynamic = false
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.ramp
        body.contactTestBitMask = PhysicsCategory.skier
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }
}
