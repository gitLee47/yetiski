import SpriteKit

enum ObstacleKind: CaseIterable {
    case stone
    case hole
    case tree
    /// Non-damaging: doesn't cost a life, but temporarily makes steering
    /// sluggish (see `GameScene`'s slip handling). Kept in the same
    /// obstacle-spawn rotation for variety beyond instant-hit hazards.
    case icePatch
}

/// A single obstacle (stone, hole, tree, or ice patch). All four now use
/// pixel-art sprites (see `SpriteTextureLoader`) — hole and ice patch are
/// hand-authored in the same palette/outline style as the sourced Kenney art
/// (no ready-made "pit" or "icy patch" tile exists in that pack).
final class ObstacleNode: SKNode {
    let kind: ObstacleKind

    init(kind: ObstacleKind) {
        self.kind = kind
        super.init()
        switch kind {
        case .stone: buildStone()
        case .hole: buildHole()
        case .tree: buildTree()
        case .icePatch: buildIcePatch()
        }
        buildPhysics(radius: kind.physicsRadius)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildStone() {
        let sprite = SKSpriteNode(texture: SpriteTextureLoader.texture(named: "sprite_rock"))
        sprite.size = CGSize(width: 30, height: 30)
        addChild(sprite)
    }

    private func buildHole() {
        let sprite = SKSpriteNode(texture: SpriteTextureLoader.texture(named: "sprite_hole"))
        sprite.size = CGSize(width: 34, height: 34)
        addChild(sprite)
    }

    private func buildTree() {
        let sprite = SKSpriteNode(texture: SpriteTextureLoader.texture(named: "sprite_tree"))
        sprite.size = CGSize(width: 38, height: 38)
        addChild(sprite)
    }

    private func buildIcePatch() {
        let sprite = SKSpriteNode(texture: SpriteTextureLoader.texture(named: "sprite_ice_patch"))
        sprite.size = CGSize(width: 38, height: 30)
        addChild(sprite)
    }

    private func buildPhysics(radius: CGFloat) {
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = false
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.obstacle
        body.contactTestBitMask = PhysicsCategory.skier
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }
}

private extension ObstacleKind {
    var physicsRadius: CGFloat {
        switch self {
        case .stone: return 13
        case .hole: return 15
        case .tree: return 16
        case .icePatch: return 16
        }
    }
}
