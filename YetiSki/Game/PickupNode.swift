import SpriteKit

/// The five grab-able beneficial pickups. Kept separate from `RampNode`,
/// which already has its own bespoke launch/jump behavior.
enum PickupKind: CaseIterable {
    case shield
    case speedBoost
    case yetiRepellent
    case extraLife
    case snowflake

    /// Relative spawn weight — snowflakes are common "currency", the
    /// powerups rarer, extra life rarest since it's the most impactful.
    var spawnWeight: Double {
        switch self {
        case .snowflake: return 55
        case .shield, .speedBoost, .yetiRepellent: return 13
        case .extraLife: return 6
        }
    }
}

/// A single grab-able pickup, styled as a hand-authored pixel-art badge (see
/// `SpriteTextureLoader`) — no ready-made powerup icons exist in the sourced
/// Kenney pack, so these are drawn in the same flat-color/dark-outline-halo
/// style as the rest of the world's sprites, distinct from `ObstacleNode`'s
/// hazards and `RampNode`'s boost pad so they read clearly as "good to touch."
final class PickupNode: SKNode {
    let kind: PickupKind

    init(kind: PickupKind) {
        self.kind = kind
        super.init()
        let sprite = SKSpriteNode(texture: SpriteTextureLoader.texture(named: kind.textureName))
        sprite.size = kind == .snowflake ? CGSize(width: 28, height: 28) : CGSize(width: 36, height: 36)
        addChild(sprite)

        // The snowflake is common "currency," so it gets a gold-coin look
        // (see `sprite_pickup_snowflake.png`) plus a slow spin-and-shimmer —
        // the other four are static badges since they read as "temporary
        // buff," not "collect me."
        if kind == .snowflake {
            let spin = SKAction.rotate(byAngle: .pi * 2, duration: 3.2)
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5),
            ])
            sprite.run(.repeatForever(spin))
            sprite.run(.repeatForever(pulse))
        }

        buildPhysics(radius: kind == .snowflake ? 12 : 18)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildPhysics(radius: CGFloat) {
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = false
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.pickup
        body.contactTestBitMask = PhysicsCategory.skier
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }
}

private extension PickupKind {
    var textureName: String {
        switch self {
        case .shield: return "sprite_pickup_shield"
        case .speedBoost: return "sprite_pickup_speed"
        case .yetiRepellent: return "sprite_pickup_repellent"
        case .extraLife: return "sprite_pickup_life"
        case .snowflake: return "sprite_pickup_snowflake"
        }
    }
}
