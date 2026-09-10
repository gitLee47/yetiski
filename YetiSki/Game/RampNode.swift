import SpriteKit

/// A jump ramp: a bright boost-pad style marker (not a hazard). Hitting one
/// launches the skier briefly invincible to obstacles/the yeti and grants a
/// small burst of extra distance, styled clearly differently from the
/// stone/hole/tree hazards so it reads as something to seek out, not avoid.
final class RampNode: SKNode {
    private static let width: CGFloat = 42
    private static let height: CGFloat = 28

    override init() {
        super.init()
        buildVisuals()
        buildPhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildVisuals() {
        let pad = SKShapeNode(rectOf: CGSize(width: Self.width, height: Self.height), cornerRadius: 8)
        pad.fillColor = SKColor(red: 1.0, green: 0.62, blue: 0.13, alpha: 1)
        pad.strokeColor = SKColor(red: 0.72, green: 0.4, blue: 0.04, alpha: 1)
        pad.lineWidth = 2.5
        addChild(pad)

        // Chevrons pointing down-screen — new terrain always scrolls in from
        // the bottom of the screen, so that's "downhill, ahead of you", and
        // the chevrons point that way as a "launch this way" cue.
        for i in 0..<2 {
            let chevron = SKShapeNode(path: Self.chevronPath(width: 18, height: 7))
            chevron.strokeColor = .white
            chevron.lineWidth = 3
            chevron.lineCap = .round
            chevron.fillColor = .clear
            chevron.position = CGPoint(x: 0, y: -CGFloat(i) * 8 + 6)
            addChild(chevron)
        }
    }

    private static func chevronPath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width / 2, y: height / 2))
        path.addLine(to: CGPoint(x: 0, y: -height / 2))
        path.addLine(to: CGPoint(x: width / 2, y: height / 2))
        return path
    }

    private func buildPhysics() {
        let body = SKPhysicsBody(rectangleOf: CGSize(width: Self.width, height: Self.height))
        body.isDynamic = false
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.ramp
        body.contactTestBitMask = PhysicsCategory.skier
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }
}
