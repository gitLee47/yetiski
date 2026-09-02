import SpriteKit

/// The yeti: spawns off-screen above, sprints downward while homing toward the
/// skier's x-position, and despawns if it catches the skier or times out.
final class YetiNode: SKNode {
    static let width: CGFloat = 46
    static let height: CGFloat = 58

    /// Max horizontal speed (points/second) while homing toward the skier.
    var turnSpeed: CGFloat = 260

    override init() {
        super.init()
        buildVisuals()
        buildPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildVisuals() {
        let body = SKShapeNode(ellipseOf: CGSize(width: Self.width, height: Self.height * 0.7))
        body.fillColor = SKColor(white: 0.96, alpha: 1)
        body.strokeColor = SKColor(white: 0.7, alpha: 1)
        body.lineWidth = 2
        body.position = CGPoint(x: 0, y: -6)
        addChild(body)

        let head = SKShapeNode(circleOfRadius: 14)
        head.fillColor = SKColor(white: 0.97, alpha: 1)
        head.strokeColor = SKColor(white: 0.7, alpha: 1)
        head.lineWidth = 2
        head.position = CGPoint(x: 0, y: Self.height / 2 - 12)
        addChild(head)

        for offset in [-5, 5] as [CGFloat] {
            let eye = SKShapeNode(circleOfRadius: 2.2)
            eye.fillColor = .red
            eye.strokeColor = .clear
            eye.position = CGPoint(x: offset, y: Self.height / 2 - 12)
            addChild(eye)
        }

        for offset in [-14, 14] as [CGFloat] {
            let arm = SKShapeNode(rectOf: CGSize(width: 10, height: 26), cornerRadius: 5)
            arm.fillColor = SKColor(white: 0.9, alpha: 1)
            arm.strokeColor = SKColor(white: 0.7, alpha: 1)
            arm.lineWidth = 1
            arm.position = CGPoint(x: offset, y: -2)
            arm.zRotation = offset > 0 ? -0.35 : 0.35
            addChild(arm)
        }
    }

    private func buildPhysics() {
        let physicsBody = SKPhysicsBody(circleOfRadius: Self.width / 2 - 4)
        physicsBody.isDynamic = true
        physicsBody.affectedByGravity = false
        physicsBody.allowsRotation = false
        physicsBody.categoryBitMask = PhysicsCategory.yeti
        physicsBody.contactTestBitMask = PhysicsCategory.skier
        physicsBody.collisionBitMask = PhysicsCategory.none
        self.physicsBody = physicsBody
    }

    /// Steers x toward `targetX` at up to `turnSpeed`, called every frame.
    func stepHoming(towardX targetX: CGFloat, deltaTime: TimeInterval) {
        let maxDelta = turnSpeed * CGFloat(deltaTime)
        let dx = (targetX - position.x).clamped(to: -maxDelta...maxDelta)
        position.x += dx
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
