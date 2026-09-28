import SpriteKit

/// The player's skier — a pixel-art sprite (Kenney's "Tiny Ski" pack, see
/// `SpriteTextureLoader`) animated between its 2 pole-push frames.
/// Exposes discrete lane-shift steering and hit-flash/jump invincibility helpers.
final class SkierNode: SKNode {
    static let width: CGFloat = 34
    static let height: CGFloat = 46

    /// True while any of the three invincibility sources below is active.
    /// Tracked as separate flags rather than one shared boolean — hit-flash,
    /// jump, and shield each run on their own independent timer, so if a
    /// ramp jump (which "always registers, even mid-invincibility" — see
    /// `GameScene.didBegin`) fires while a shield is still active, the
    /// jump's shorter duration used to clear the flag early and silently
    /// end the shield's protection while its bubble was still visibly
    /// pulsing on screen.
    var isInvincible: Bool { hitFlashActive || jumpActive || shieldActive }
    private var hitFlashActive = false
    private var jumpActive = false
    private var shieldActive = false
    private let bodyContainer = SKNode()
    private let shieldBubble = SKShapeNode(circleOfRadius: SkierNode.width * 0.85)
    private let slipIndicator = SKShapeNode(circleOfRadius: SkierNode.width * 0.8)

    /// The skier's sprite — recolored by `applySkin(_:)` via a color blend
    /// tint (the source art is a single fixed color scheme).
    private let sprite = SKSpriteNode(texture: SpriteTextureLoader.texture(named: "sprite_skier_1"))

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

        // Shield bubble — built once, hidden until `playShield` shows it.
        shieldBubble.fillColor = SKColor.systemBlue.withAlphaComponent(0.18)
        shieldBubble.strokeColor = SKColor.systemBlue.withAlphaComponent(0.9)
        shieldBubble.lineWidth = 2.5
        shieldBubble.alpha = 0
        shieldBubble.zPosition = -1
        addChild(shieldBubble)

        // Ice-slip indicator — a saturated cyan ring with a dashed-looking
        // stroke, hidden until `setSlipping`. Deliberately more vivid than a
        // pale "icy" tint would be, since that blended into the background.
        slipIndicator.fillColor = .clear
        slipIndicator.strokeColor = SKColor(red: 0.0, green: 0.55, blue: 0.95, alpha: 1)
        slipIndicator.lineWidth = 3.5
        slipIndicator.alpha = 0
        slipIndicator.zPosition = -1
        addChild(slipIndicator)

        // Sprite, animated between its 2 pole-push frames for a skiing bob.
        sprite.size = CGSize(width: 34, height: 34)
        bodyContainer.addChild(sprite)

        let frames = [
            SpriteTextureLoader.texture(named: "sprite_skier_1"),
            SpriteTextureLoader.texture(named: "sprite_skier_2"),
        ]
        sprite.run(.repeatForever(.animate(with: frames, timePerFrame: 0.18)))
    }

    private func buildPhysics() {
        let body = SKPhysicsBody(rectangleOf: CGSize(width: Self.width, height: Self.height))
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = PhysicsCategory.skier
        body.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.yeti | PhysicsCategory.ramp | PhysicsCategory.pickup
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }

    /// Slides the skier to a new x position with a quick easing animation and a
    /// slight lean, then updates the physics body. No default for `duration` —
    /// both call sites (normal steer vs. ice-slip steer) pass a value from
    /// `DifficultyManager` deliberately, so a silently-wrong default can't
    /// drift out of sync with the tuning that actually governs steering feel.
    func moveTo(x: CGFloat, duration: TimeInterval) {
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
        hitFlashActive = true
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.08),
            SKAction.fadeAlpha(to: 1.0, duration: 0.08),
        ])
        let blinkCount = Int(duration / 0.16)
        bodyContainer.run(.repeat(blink, count: max(1, blinkCount))) { [weak self] in
            self?.hitFlashActive = false
        }
    }

    /// Launches off a ramp: a hop-and-spin flourish, with invincibility to
    /// obstacles/the yeti for the duration so the jump can actually be used
    /// to clear them. Animates `bodyContainer` only (not `self`), so it never
    /// fights with `moveTo(x:)`'s lane-steering action on the node itself.
    func playJump(duration: TimeInterval) {
        jumpActive = true
        bodyContainer.removeAction(forKey: "jump")

        let riseHeight: CGFloat = 20
        let up = SKAction.moveBy(x: 0, y: riseHeight, duration: duration * 0.3)
        up.timingMode = .easeOut
        let down = SKAction.moveBy(x: 0, y: -riseHeight, duration: duration * 0.3)
        down.timingMode = .easeIn
        let hop = SKAction.sequence([up, .wait(forDuration: duration * 0.4), down])

        let scaleUp = SKAction.scale(to: 1.3, duration: duration * 0.3)
        let scaleDown = SKAction.scale(to: 1.0, duration: duration * 0.3)
        let scaleSeq = SKAction.sequence([scaleUp, .wait(forDuration: duration * 0.4), scaleDown])

        let spin = SKAction.rotate(byAngle: .pi * 2, duration: duration)

        let finish = SKAction.run { [weak self] in self?.jumpActive = false }
        bodyContainer.run(.sequence([.group([hop, scaleSeq, spin]), finish]), withKey: "jump")
    }

    /// Activates the shield powerup: invincibility to obstacles/the yeti for
    /// the duration, shown as a pulsing translucent bubble around the skier —
    /// a distinct visual from the hit-flash blink and the ramp's hop/spin.
    func playShield(duration: TimeInterval) {
        shieldActive = true
        shieldBubble.removeAllActions()

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.12, duration: 0.4),
            SKAction.scale(to: 1.0, duration: 0.4),
        ])
        let show = SKAction.fadeAlpha(to: 1.0, duration: 0.15)
        let hide = SKAction.fadeAlpha(to: 0, duration: 0.25)
        let finish = SKAction.run { [weak self] in self?.shieldActive = false }

        shieldBubble.run(.sequence([
            show,
            .repeat(pulse, count: max(1, Int(duration / 0.8))),
            hide,
            finish,
        ]))
    }

    /// Toggles the ice-patch slip visual. Doesn't touch `isInvincible` — an
    /// ice patch doesn't cost a life or grant protection, it just makes
    /// `GameScene.steer(by:)` use a longer, sluggish move duration while active.
    func setSlipping(_ slipping: Bool) {
        slipIndicator.removeAllActions()
        slipIndicator.run(.fadeAlpha(to: slipping ? 1.0 : 0, duration: 0.2))
    }

    /// Recolors the skier to match a cosmetic skin. Purely visual — no
    /// gameplay effect. Safe to call anytime, including on an already-built
    /// skier reused across runs (skins can change between runs via the Locker).
    /// The source art is a single fixed-color sprite, so this tints it via a
    /// color blend rather than recoloring separate body-part shapes.
    func applySkin(_ skin: SkierSkin) {
        sprite.color = skin.jacketColor
        sprite.colorBlendFactor = skin == .classic ? 0 : 0.55
    }
}
