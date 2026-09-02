import SpriteKit

/// The player's skier, drawn as simple programmatic shapes (no image assets).
/// Exposes discrete lane-shift steering and a hit-flash/invincibility helper.
final class SkierNode: SKNode {
    static let width: CGFloat = 34
    static let height: CGFloat = 46

    private(set) var isInvincible = false
    private let bodyContainer = SKNode()

    override init() {
        super.init()
        buildVisuals()
        buildPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildVisuals() {
        addChild(bodyContainer)

        // Skis
        let skiLength: CGFloat = 30
        for offset in [-8, 8] as [CGFloat] {
            let ski = SKShapeNode(rectOf: CGSize(width: 5, height: skiLength), cornerRadius: 2)
            ski.fillColor = .red
            ski.strokeColor = .clear
            ski.position = CGPoint(x: offset, y: -Self.height / 2 + 4)
            bodyContainer.addChild(ski)
        }

        // Legs
        let legs = SKShapeNode(rectOf: CGSize(width: 16, height: 14), cornerRadius: 3)
        legs.fillColor = .darkGray
        legs.strokeColor = .clear
        legs.position = CGPoint(x: 0, y: -Self.height / 2 + 16)
        bodyContainer.addChild(legs)

        // Torso
        let torso = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 6)
        torso.fillColor = .systemBlue
        torso.strokeColor = .clear
        torso.position = CGPoint(x: 0, y: -2)
        bodyContainer.addChild(torso)

        // Head
        let head = SKShapeNode(circleOfRadius: 8)
        head.fillColor = .systemOrange
        head.strokeColor = .clear
        head.position = CGPoint(x: 0, y: Self.height / 2 - 10)
        bodyContainer.addChild(head)

        // Poles
        for offset in [-16, 16] as [CGFloat] {
            let pole = SKShapeNode(rectOf: CGSize(width: 3, height: 24))
            pole.fillColor = .gray
            pole.strokeColor = .clear
            pole.position = CGPoint(x: offset, y: 0)
            pole.zRotation = offset > 0 ? -0.2 : 0.2
            bodyContainer.addChild(pole)
        }
    }

    private func buildPhysics() {
        let body = SKPhysicsBody(rectangleOf: CGSize(width: Self.width, height: Self.height))
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = PhysicsCategory.skier
        body.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.yeti
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }

    /// Slides the skier to a new x position with a quick easing animation and a
    /// slight lean, then updates the physics body.
    func moveTo(x: CGFloat, duration: TimeInterval = 0.16) {
        removeAction(forKey: "move")
        let lean: CGFloat = x > position.x ? -0.18 : (x < position.x ? 0.18 : 0)
        let move = SKAction.moveTo(x: x, duration: duration)
        move.timingMode = .easeOut
        let leanAction = SKAction.sequence([
            SKAction.rotate(toAngle: lean, duration: duration * 0.5, shortestUnitArc: true),
            SKAction.rotate(toAngle: 0, duration: duration * 0.5, shortestUnitArc: true),
        ])
        run(.group([move, leanAction]), withKey: "move")
    }

    /// Flashes the skier and grants brief invincibility after taking a hit.
    func playHitFlash(duration: TimeInterval = 1.0) {
        isInvincible = true
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.08),
            SKAction.fadeAlpha(to: 1.0, duration: 0.08),
        ])
        let blinkCount = Int(duration / 0.16)
        bodyContainer.run(.repeat(blink, count: max(1, blinkCount))) { [weak self] in
            self?.isInvincible = false
        }
    }
}
