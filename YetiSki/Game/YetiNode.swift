import SpriteKit

/// The yeti: spawns off-screen, sprints toward the skier while homing on its
/// x-position, and despawns if it catches the skier or times out. Drawn as a
/// hulking, shaggy ape-like monster — jagged fur silhouette, angry glowing
/// eyes, fangs and claws — so it reads as a monster, not a snowman.
final class YetiNode: SKNode {
    static let width: CGFloat = 58
    static let height: CGFloat = 72

    /// Max horizontal speed (points/second) while homing toward the skier.
    var turnSpeed: CGFloat = 260
    /// Seconds since this yeti spawned — `GameScene` increments this each
    /// frame and despawns the yeti once it exceeds the chase timeout. Kept
    /// per-instance (rather than a single scalar in `GameScene`) so multiple
    /// yetis can be active with independent timeouts.
    var chaseElapsed: TimeInterval = 0

    private static let furColor = SKColor(white: 0.92, alpha: 1)
    private static let furShadow = SKColor(white: 0.74, alpha: 1)
    private static let outlineColor = SKColor(red: 0.32, green: 0.30, blue: 0.30, alpha: 1)
    private static let darkColor = SKColor(red: 0.16, green: 0.08, blue: 0.08, alpha: 1)

    override init() {
        super.init()
        buildVisuals()
        buildPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildVisuals() {
        let bodyY = -Self.height * 0.14
        let headY = Self.height * 0.30

        // Long, shaggy arms with clawed hands, angled forward as if reaching —
        // added first so the torso/head overlap them.
        for side in [-1, 1] as [CGFloat] {
            let arm = SKShapeNode(path: Self.jaggedBlobPath(radiusX: 8, radiusY: 22, spikeCount: 7, spikeDepth: 2))
            arm.fillColor = Self.furColor
            arm.strokeColor = Self.outlineColor
            arm.lineWidth = 1.5
            arm.position = CGPoint(x: side * Self.width * 0.44, y: bodyY - 4)
            arm.zRotation = side * 0.55
            arm.zPosition = 0
            addChild(arm)

            let handPosition = CGPoint(x: side * (Self.width * 0.44 + 8), y: bodyY - 24)
            for clawAngle in [-0.35, 0, 0.35] as [CGFloat] {
                let claw = SKShapeNode(path: Self.trianglePath(width: 3.5, height: 8))
                claw.fillColor = Self.darkColor
                claw.strokeColor = .clear
                claw.position = handPosition
                claw.zRotation = .pi + side * 0.3 + clawAngle
                claw.zPosition = 0.1
                addChild(claw)
            }
        }

        // Shaggy, hulking torso — jagged silhouette instead of a smooth blob.
        let torso = SKShapeNode(
            path: Self.jaggedBlobPath(radiusX: Self.width * 0.48, radiusY: Self.height * 0.4, spikeCount: 12, spikeDepth: 3.5)
        )
        torso.position = CGPoint(x: 0, y: bodyY)
        torso.fillColor = Self.furColor
        torso.strokeColor = Self.outlineColor
        torso.lineWidth = 2
        torso.zPosition = 1
        addChild(torso)

        // Shading on one side for volume.
        let shade = SKShapeNode(
            path: Self.jaggedBlobPath(radiusX: Self.width * 0.24, radiusY: Self.height * 0.34, spikeCount: 9, spikeDepth: 2.5)
        )
        shade.position = CGPoint(x: Self.width * 0.16, y: bodyY)
        shade.fillColor = Self.furShadow.withAlphaComponent(0.5)
        shade.strokeColor = .clear
        shade.zPosition = 1.1
        addChild(shade)

        // Stubby furry legs peeking out beneath the torso.
        for side in [-1, 1] as [CGFloat] {
            let leg = SKShapeNode(path: Self.jaggedBlobPath(radiusX: 7, radiusY: 10, spikeCount: 6, spikeDepth: 1.5))
            leg.fillColor = Self.furColor
            leg.strokeColor = Self.outlineColor
            leg.lineWidth = 1.5
            leg.position = CGPoint(x: side * Self.width * 0.2, y: -Self.height / 2 + 6)
            leg.zPosition = 0.5
            addChild(leg)
        }

        // Head — bigger and jagged, overlapping the top of the torso.
        let head = SKShapeNode(path: Self.jaggedBlobPath(radiusX: 18, radiusY: 16, spikeCount: 10, spikeDepth: 3))
        head.position = CGPoint(x: 0, y: headY)
        head.fillColor = Self.furColor
        head.strokeColor = Self.outlineColor
        head.lineWidth = 2
        head.zPosition = 2
        addChild(head)

        // Fur tufts crowning the head.
        for i in -1...1 {
            let tuft = SKShapeNode(path: Self.trianglePath(width: 6, height: 10))
            tuft.fillColor = Self.furColor
            tuft.strokeColor = Self.outlineColor
            tuft.lineWidth = 1
            tuft.position = CGPoint(x: CGFloat(i) * 8, y: headY + 13)
            tuft.zRotation = CGFloat(i) * 0.35
            tuft.zPosition = 1.9
            addChild(tuft)
        }

        // Protruding snout/muzzle.
        let snout = SKShapeNode(ellipseOf: CGSize(width: 20, height: 13))
        snout.position = CGPoint(x: 0, y: headY - 7)
        snout.fillColor = Self.furShadow
        snout.strokeColor = Self.outlineColor
        snout.lineWidth = 1.5
        snout.zPosition = 2.1
        addChild(snout)

        // Angry, furrowed brows.
        for side in [-1, 1] as [CGFloat] {
            let brow = SKShapeNode(rectOf: CGSize(width: 11, height: 3.5), cornerRadius: 1.5)
            brow.fillColor = Self.darkColor
            brow.strokeColor = .clear
            brow.position = CGPoint(x: side * 7, y: headY + 6)
            brow.zRotation = side * 0.5
            brow.zPosition = 2.3
            addChild(brow)
        }

        // Glowing, angry eyes.
        for side in [-1, 1] as [CGFloat] {
            let eye = SKShapeNode(circleOfRadius: 3)
            eye.fillColor = .red
            eye.strokeColor = .clear
            eye.position = CGPoint(x: side * 6.5, y: headY + 1)
            eye.zPosition = 2.3
            addChild(eye)
        }

        // Open, fanged mouth.
        let mouth = SKShapeNode(rectOf: CGSize(width: 13, height: 6), cornerRadius: 2)
        mouth.fillColor = Self.darkColor
        mouth.strokeColor = .clear
        mouth.position = CGPoint(x: 0, y: headY - 11)
        mouth.zPosition = 2.2
        addChild(mouth)

        for side in [-1, 1] as [CGFloat] {
            let fang = SKShapeNode(path: Self.trianglePath(width: 3.5, height: 5))
            fang.fillColor = .white
            fang.strokeColor = .clear
            fang.position = CGPoint(x: side * 4, y: headY - 10)
            fang.zRotation = .pi
            fang.zPosition = 2.4
            addChild(fang)
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

    // MARK: - Shape helpers

    /// A closed blob path that alternates between an outer and slightly
    /// inset radius around an ellipse, faking a shaggy fur silhouette
    /// without needing image assets.
    private static func jaggedBlobPath(radiusX: CGFloat, radiusY: CGFloat, spikeCount: Int, spikeDepth: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let pointCount = max(6, spikeCount) * 2
        for i in 0..<pointCount {
            let angle = (CGFloat(i) / CGFloat(pointCount)) * 2 * .pi
            let isOuter = i % 2 == 0
            let jitter = isOuter ? spikeDepth : -spikeDepth * 0.5
            let x = cos(angle) * (radiusX + jitter)
            let y = sin(angle) * (radiusY + jitter)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }

    /// An isosceles triangle, apex pointing along +y, base centered at the origin.
    private static func trianglePath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width / 2, y: 0))
        path.addLine(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
