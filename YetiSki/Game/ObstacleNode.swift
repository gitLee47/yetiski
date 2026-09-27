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

/// A single obstacle (stone, hole, tree, or ice patch) drawn as simple
/// programmatic shapes.
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
        let shape = SKShapeNode(circleOfRadius: 14)
        shape.fillColor = SKColor(white: 0.55, alpha: 1)
        shape.strokeColor = SKColor(white: 0.35, alpha: 1)
        shape.lineWidth = 2
        addChild(shape)
        let highlight = SKShapeNode(circleOfRadius: 5)
        highlight.fillColor = SKColor(white: 0.75, alpha: 1)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -4, y: 4)
        addChild(highlight)
    }

    private func buildHole() {
        let shape = SKShapeNode(ellipseOf: CGSize(width: 34, height: 22))
        shape.fillColor = SKColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 1)
        shape.strokeColor = SKColor(white: 0.9, alpha: 0.6)
        shape.lineWidth = 2
        addChild(shape)
    }

    private func buildTree() {
        let trunk = SKShapeNode(rectOf: CGSize(width: 8, height: 14), cornerRadius: 2)
        trunk.fillColor = SKColor(red: 0.36, green: 0.24, blue: 0.14, alpha: 1)
        trunk.strokeColor = .clear
        trunk.position = CGPoint(x: 0, y: -14)
        addChild(trunk)

        let tiers: [(y: CGFloat, radius: CGFloat)] = [(0, 20), (14, 16), (26, 11)]
        for tier in tiers {
            let cone = SKShapeNode(path: Self.trianglePath(radius: tier.radius, height: 20))
            cone.fillColor = SKColor(red: 0.10, green: 0.42, blue: 0.22, alpha: 1)
            cone.strokeColor = SKColor(red: 0.06, green: 0.28, blue: 0.15, alpha: 1)
            cone.lineWidth = 1
            cone.position = CGPoint(x: 0, y: tier.y)
            addChild(cone)
        }
    }

    private func buildIcePatch() {
        let patch = SKShapeNode(ellipseOf: CGSize(width: 38, height: 22))
        patch.fillColor = SKColor(red: 0.68, green: 0.9, blue: 0.99, alpha: 0.9)
        patch.strokeColor = SKColor(red: 0.15, green: 0.55, blue: 0.85, alpha: 1)
        patch.lineWidth = 2
        addChild(patch)

        // Jagged crack lines — the key cue that this is cracked ice, not
        // just a patch of lighter snow.
        let crack1 = CGMutablePath()
        crack1.move(to: CGPoint(x: -13, y: 5))
        crack1.addLine(to: CGPoint(x: -4, y: -1))
        crack1.addLine(to: CGPoint(x: 2, y: 4))
        crack1.addLine(to: CGPoint(x: 12, y: -4))
        let crackNode1 = SKShapeNode(path: crack1)
        crackNode1.strokeColor = SKColor(red: 0.1, green: 0.4, blue: 0.65, alpha: 0.8)
        crackNode1.lineWidth = 1.2
        addChild(crackNode1)

        let crack2 = CGMutablePath()
        crack2.move(to: CGPoint(x: -2, y: 4))
        crack2.addLine(to: CGPoint(x: -6, y: -6))
        let crackNode2 = SKShapeNode(path: crack2)
        crackNode2.strokeColor = SKColor(red: 0.1, green: 0.4, blue: 0.65, alpha: 0.8)
        crackNode2.lineWidth = 1.2
        addChild(crackNode2)

        // A glossy highlight streak to sell "slippery."
        let streak = SKShapeNode(rectOf: CGSize(width: 14, height: 3), cornerRadius: 1.5)
        streak.fillColor = SKColor(white: 1, alpha: 0.9)
        streak.strokeColor = .clear
        streak.zRotation = 0.3
        streak.position = CGPoint(x: 8, y: 6)
        addChild(streak)
    }

    private static func trianglePath(radius: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: height / 2))
        path.addLine(to: CGPoint(x: radius, y: -height / 2))
        path.addLine(to: CGPoint(x: -radius, y: -height / 2))
        path.closeSubpath()
        return path
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
