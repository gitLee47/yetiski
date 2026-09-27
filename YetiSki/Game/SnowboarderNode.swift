import SpriteKit

/// A moving hazard: scrolls up like a normal obstacle but also drifts
/// sideways sinusoidally, so it's harder to predict than a fixed-lane
/// hazard. Deliberately silhouetted differently from `SkierNode` (a single
/// angled board, no poles) so it doesn't read as another player character.
/// Shares `PhysicsCategory.obstacle` — `GameScene` distinguishes it from
/// `ObstacleNode` by type when handling contact.
final class SnowboarderNode: SKNode {
    private var driftElapsed: TimeInterval = 0
    private let driftAmplitude: CGFloat
    private let driftPeriod: TimeInterval
    private let centerX: CGFloat

    init(centerX: CGFloat, driftAmplitude: CGFloat, driftPeriod: TimeInterval) {
        self.centerX = centerX
        self.driftAmplitude = driftAmplitude
        self.driftPeriod = driftPeriod
        super.init()
        buildVisuals()
        buildPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildVisuals() {
        let board = SKShapeNode(rectOf: CGSize(width: 11, height: 34), cornerRadius: 5.5)
        board.fillColor = SKColor(red: 0.9, green: 0.25, blue: 0.35, alpha: 1)
        board.strokeColor = SKColor(red: 0.6, green: 0.12, blue: 0.18, alpha: 1)
        board.lineWidth = 1.5
        board.zRotation = 0.35
        board.position = CGPoint(x: 0, y: -16)
        addChild(board)

        let legs = SKShapeNode(rectOf: CGSize(width: 15, height: 12), cornerRadius: 3)
        legs.fillColor = .darkGray
        legs.strokeColor = .clear
        legs.position = CGPoint(x: 0, y: -6)
        addChild(legs)

        let torso = SKShapeNode(rectOf: CGSize(width: 18, height: 18), cornerRadius: 5)
        torso.fillColor = SKColor(red: 0.5, green: 0.28, blue: 0.75, alpha: 1)
        torso.strokeColor = .clear
        torso.position = CGPoint(x: 0, y: 7)
        addChild(torso)

        let head = SKShapeNode(circleOfRadius: 7)
        head.fillColor = SKColor(red: 0.93, green: 0.78, blue: 0.62, alpha: 1)
        head.strokeColor = .clear
        head.position = CGPoint(x: 0, y: 18)
        addChild(head)

        let beanie = SKShapeNode(path: Self.beaniePath())
        beanie.fillColor = SKColor(red: 0.15, green: 0.55, blue: 0.85, alpha: 1)
        beanie.strokeColor = .clear
        beanie.position = CGPoint(x: 0, y: 21)
        addChild(beanie)
    }

    private static func beaniePath() -> CGPath {
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: 7.5, startAngle: 0, endAngle: .pi, clockwise: false)
        path.closeSubpath()
        return path
    }

    private func buildPhysics() {
        let body = SKPhysicsBody(circleOfRadius: 16)
        body.isDynamic = false
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.obstacle
        body.contactTestBitMask = PhysicsCategory.skier
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }

    /// Advances the sideways drift; `GameScene` handles the vertical scroll separately.
    func stepDrift(dt: TimeInterval) {
        driftElapsed += dt
        let phase = (driftElapsed / driftPeriod) * (2 * .pi)
        position.x = centerX + driftAmplitude * CGFloat(sin(phase))
    }
}
