import SpriteKit

enum ObstacleKind: CaseIterable {
    case stone
    case hole
    case tree
}

/// A single obstacle (stone, hole, or tree) drawn as simple programmatic shapes.
final class ObstacleNode: SKNode {
    let kind: ObstacleKind

    init(kind: ObstacleKind) {
        self.kind = kind
        super.init()
        switch kind {
        case .stone: buildStone()
        case .hole: buildHole()
        case .tree: buildTree()
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
        }
    }
}
