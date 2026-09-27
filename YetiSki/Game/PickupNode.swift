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

/// A single grab-able pickup, styled as a colored badge with a simple icon —
/// distinct from `ObstacleNode`'s hazards and `RampNode`'s boost pad so it
/// reads clearly as "good to touch."
final class PickupNode: SKNode {
    let kind: PickupKind

    init(kind: PickupKind) {
        self.kind = kind
        super.init()
        switch kind {
        case .shield: buildBadge(radius: 18, color: SKColor.systemBlue, icon: Self.shieldPath(width: 18, height: 20))
        case .speedBoost: buildBadge(radius: 18, color: SKColor(red: 0.2, green: 0.75, blue: 0.35, alpha: 1), icon: Self.boltPath(width: 18, height: 26))
        case .yetiRepellent: buildFlameBadge()
        case .extraLife: buildBadge(radius: 18, color: SKColor(red: 0.95, green: 0.25, blue: 0.45, alpha: 1), icon: Self.heartPath(width: 18, height: 16))
        case .snowflake: buildSnowflake()
        }
        buildPhysics(radius: kind == .snowflake ? 11 : 18)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildBadge(radius: CGFloat, color: SKColor, icon: CGPath) {
        let badge = SKShapeNode(circleOfRadius: radius)
        badge.fillColor = color
        badge.strokeColor = .white
        badge.lineWidth = 2
        addChild(badge)

        let iconNode = SKShapeNode(path: icon)
        iconNode.fillColor = .white
        iconNode.strokeColor = .clear
        addChild(iconNode)
    }

    /// Two-tone flame (darker orange outer + lighter yellow inner) — a single
    /// flat teardrop reads ambiguously as a water drop, but layering a
    /// brighter "flame core" on top makes it unmistakably fire.
    private func buildFlameBadge() {
        let badge = SKShapeNode(circleOfRadius: 18)
        badge.fillColor = SKColor(red: 0.95, green: 0.35, blue: 0.15, alpha: 1)
        badge.strokeColor = .white
        badge.lineWidth = 2
        addChild(badge)

        let outerFlame = SKShapeNode(path: Self.flamePath(width: 17, height: 21))
        outerFlame.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1)
        outerFlame.strokeColor = .clear
        outerFlame.position = CGPoint(x: 0, y: -1)
        addChild(outerFlame)

        let innerFlame = SKShapeNode(path: Self.flamePath(width: 9, height: 12))
        innerFlame.fillColor = SKColor(red: 0.95, green: 0.35, blue: 0.15, alpha: 1)
        innerFlame.strokeColor = .clear
        innerFlame.position = CGPoint(x: 0, y: -4)
        addChild(innerFlame)
    }

    private func buildSnowflake() {
        let badge = SKShapeNode(circleOfRadius: 11)
        badge.fillColor = SKColor(white: 1, alpha: 0.85)
        badge.strokeColor = SKColor(red: 0.4, green: 0.7, blue: 0.95, alpha: 1)
        badge.lineWidth = 1.5
        addChild(badge)

        let flake = SKShapeNode(path: Self.snowflakePath(radius: 7))
        flake.strokeColor = SKColor(red: 0.25, green: 0.55, blue: 0.85, alpha: 1)
        flake.lineWidth = 1.6
        flake.lineCap = .round
        addChild(flake)
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

    // MARK: - Icon paths

    private static func shieldPath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width / 2, y: height / 2))
        path.addLine(to: CGPoint(x: width / 2, y: height / 2))
        path.addLine(to: CGPoint(x: width / 2, y: 0))
        path.addQuadCurve(to: CGPoint(x: 0, y: -height / 2), control: CGPoint(x: width / 2, y: -height / 3))
        path.addQuadCurve(to: CGPoint(x: -width / 2, y: 0), control: CGPoint(x: -width / 2, y: -height / 3))
        path.closeSubpath()
        return path
    }

    /// A bold zigzag lightning bolt — wider excursions than a subtle zigzag
    /// so it reads clearly at badge size instead of blurring into a blob.
    private static func boltPath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: width * 0.12, y: height * 0.5))
        path.addLine(to: CGPoint(x: -width * 0.5, y: -height * 0.05))
        path.addLine(to: CGPoint(x: -width * 0.05, y: -height * 0.05))
        path.addLine(to: CGPoint(x: -width * 0.12, y: -height * 0.5))
        path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.15))
        path.addLine(to: CGPoint(x: width * 0.05, y: height * 0.15))
        path.closeSubpath()
        return path
    }

    private static func flamePath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: height / 2))
        path.addQuadCurve(to: CGPoint(x: width / 2, y: -height / 4), control: CGPoint(x: width / 2, y: height / 4))
        path.addQuadCurve(to: CGPoint(x: 0, y: -height / 2), control: CGPoint(x: width / 4, y: -height / 2))
        path.addQuadCurve(to: CGPoint(x: -width / 2, y: -height / 4), control: CGPoint(x: -width / 4, y: -height / 2))
        path.addQuadCurve(to: CGPoint(x: 0, y: height / 2), control: CGPoint(x: -width / 2, y: height / 4))
        path.closeSubpath()
        return path
    }

    private static func heartPath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let lobeRadius = width / 4
        path.move(to: CGPoint(x: 0, y: -height / 2))
        path.addQuadCurve(to: CGPoint(x: -width / 2, y: height * 0.2), control: CGPoint(x: -width * 0.3, y: -height * 0.1))
        path.addArc(center: CGPoint(x: -lobeRadius, y: height * 0.2), radius: lobeRadius, startAngle: .pi, endAngle: 0, clockwise: true)
        path.addArc(center: CGPoint(x: lobeRadius, y: height * 0.2), radius: lobeRadius, startAngle: .pi, endAngle: 0, clockwise: true)
        path.addQuadCurve(to: CGPoint(x: 0, y: -height / 2), control: CGPoint(x: width * 0.3, y: -height * 0.1))
        path.closeSubpath()
        return path
    }

    /// Three spokes through the center plus small perpendicular ticks near
    /// each tip — a bare asterisk reads as a generic star; the ticks are
    /// what make it unmistakably a snowflake.
    private static func snowflakePath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let tickInset: CGFloat = radius * 0.62
        let tickHalf: CGFloat = radius * 0.24
        for i in 0..<3 {
            let angle = CGFloat(i) * (.pi / 3)
            let dirX = cos(angle), dirY = sin(angle)
            let perpX = -dirY, perpY = dirX

            path.move(to: CGPoint(x: -dirX * radius, y: -dirY * radius))
            path.addLine(to: CGPoint(x: dirX * radius, y: dirY * radius))

            for sign: CGFloat in [1, -1] {
                let baseX = sign * dirX * tickInset
                let baseY = sign * dirY * tickInset
                path.move(to: CGPoint(x: baseX - perpX * tickHalf, y: baseY - perpY * tickHalf))
                path.addLine(to: CGPoint(x: baseX + perpX * tickHalf, y: baseY + perpY * tickHalf))
            }
        }
        return path
    }
}
