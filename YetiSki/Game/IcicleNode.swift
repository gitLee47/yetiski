import SpriteKit

/// A "telegraph then strike" hazard — distinct from the scroll-based
/// obstacles. A brief pulsing warning marker appears at a fixed lane/row,
/// then an icicle shard drops fast into place. `GameScene` drives this via
/// `advance(dt:)` and does a manual position check on impact (rather than
/// physics contact testing, since this is a discrete "moment of impact"
/// event, not something moving continuously into the skier).
final class IcicleNode: SKNode {
    enum Phase: Equatable {
        case telegraphing
        case falling
        case impacted
    }

    private(set) var phase: Phase = .telegraphing

    private var telegraphTimeRemaining: TimeInterval
    private var fallTimeRemaining: TimeInterval
    private let fallDuration: TimeInterval

    private let marker: SKShapeNode
    private let shard: SKSpriteNode
    private static let fallStartOffset: CGFloat = 70

    init(telegraphDuration: TimeInterval, fallDuration: TimeInterval) {
        self.telegraphTimeRemaining = telegraphDuration
        self.fallTimeRemaining = fallDuration
        self.fallDuration = fallDuration

        marker = SKShapeNode(ellipseOf: CGSize(width: 30, height: 14))
        marker.fillColor = SKColor.red.withAlphaComponent(0.3)
        marker.strokeColor = SKColor.red.withAlphaComponent(0.85)
        marker.lineWidth = 2

        // Hand-authored pixel-art shard (see `SpriteTextureLoader`) — no
        // ready-made icicle tile exists in the sourced Kenney pack.
        shard = SKSpriteNode(texture: SpriteTextureLoader.texture(named: "sprite_icicle"))
        shard.size = CGSize(width: 20, height: 32)
        shard.isHidden = true
        shard.position = CGPoint(x: 0, y: IcicleNode.fallStartOffset)

        super.init()
        addChild(marker)
        addChild(shard)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.15),
            SKAction.scale(to: 0.85, duration: 0.15),
        ])
        marker.run(.repeatForever(pulse))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Advances the telegraph/fall/impact sequence. Returns `true` exactly on
    /// the frame it impacts, so `GameScene` can check for a skier hit then.
    @discardableResult
    func advance(dt: TimeInterval) -> Bool {
        switch phase {
        case .telegraphing:
            telegraphTimeRemaining -= dt
            if telegraphTimeRemaining <= 0 {
                phase = .falling
                marker.removeAllActions()
                marker.isHidden = true
                shard.isHidden = false
            }
            return false

        case .falling:
            fallTimeRemaining -= dt
            let t = CGFloat(max(0, min(1, 1 - fallTimeRemaining / fallDuration)))
            shard.position.y = IcicleNode.fallStartOffset * (1 - t)
            if fallTimeRemaining <= 0 {
                phase = .impacted
                shard.position.y = 0
                return true
            }
            return false

        case .impacted:
            return false
        }
    }
}
