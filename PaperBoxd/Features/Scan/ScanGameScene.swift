import SpriteKit
import UIKit

/// Standalone breakout-style loading game for the "Scan & Know" flow.
///
/// A self-contained SpriteKit scene that plays while the backend scores a scan.
/// The game never stops on its own — `AnalyzingScreen` surfaces the result as a
/// "Results Ready" popup over the top, which is the real completion contract.
///
/// Aesthetic mirrors the app's editorial dark theme (see `PBStyle` / Assets):
/// near-black ground, muted warm/cool book-spine tones, paper-cream accents.
final class ScanGameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Physics categories

    private enum Category {
        static let ball:   UInt32 = 0x1 << 0
        static let paddle: UInt32 = 0x1 << 1
        static let brick:  UInt32 = 0x1 << 2
        static let wall:   UInt32 = 0x1 << 3
    }

    // MARK: - Palette (brutalist light theme by default; dark supported)

    /// Set by the host before presentation. Light = the "Scan & Know" paper theme.
    var dark = false

    /// Game canvas paper `#FCFBF7` (light) or near-black (dark).
    private var groundColor: SKColor {
        dark ? SKColor(red: 0.055, green: 0.055, blue: 0.059, alpha: 1)
             : SKColor(red: 0.988, green: 0.984, blue: 0.969, alpha: 1)
    }
    /// Ink `#141414` (light) / white (dark) — paddle, ball, HUD.
    private var textPrimary: SKColor {
        dark ? SKColor(white: 1, alpha: 1) : SKColor(red: 0.078, green: 0.078, blue: 0.078, alpha: 1)
    }
    private var textSecondary: SKColor {
        dark ? SKColor(white: 0.7, alpha: 1) : SKColor(red: 0.42, green: 0.40, blue: 0.37, alpha: 1)
    }
    /// The ball — ink on light, paper-cream on dark.
    private var ballColor: SKColor {
        dark ? SKColor(red: 0.909, green: 0.835, blue: 0.718, alpha: 1)
             : SKColor(red: 0.078, green: 0.078, blue: 0.078, alpha: 1)
    }

    /// Muted, editorial spine tones — warm/cool rotation, no pure primaries.
    private let spineColors: [SKColor] = [
        SKColor(red: 0.851, green: 0.467, blue: 0.341, alpha: 1), // terracotta   #d97757
        SKColor(red: 0.659, green: 0.404, blue: 0.302, alpha: 1), // clay
        SKColor(red: 0.909, green: 0.835, blue: 0.718, alpha: 1), // paper        #E8D5B7
        SKColor(red: 0.478, green: 0.518, blue: 0.435, alpha: 1), // sage
        SKColor(red: 0.408, green: 0.451, blue: 0.510, alpha: 1), // dusty slate-blue
        SKColor(red: 0.737, green: 0.604, blue: 0.353, alpha: 1), // muted gold
        SKColor(red: 0.545, green: 0.353, blue: 0.337, alpha: 1), // oxblood-brown
        SKColor(red: 0.353, green: 0.420, blue: 0.404, alpha: 1), // teal-slate
    ]

    // MARK: - Nodes

    private var paddle: SKSpriteNode!
    private var ball: SKSpriteNode!
    private var scoreLabel: SKLabelNode!

    // MARK: - Tuning

    /// Target ball speed (points/sec). The ball is re-normalised to this magnitude
    /// every frame so it never gradually slows or runs away after paddle "english".
    private let ballSpeed: CGFloat = 520
    private let ballDiameter: CGFloat = 22

    // MARK: - State

    private var score = 0
    private var lives = 3
    /// Live brick count per row, for row-clear haptic escalation.
    private var bricksRemainingInRow: [Int: Int] = [:]
    /// Once the scan result arrives we freeze input + gameplay.
    private var isResolving = false

    /// Pushes score + lives to the SwiftUI host, which draws the brutalist HUD bar.
    private func postHUD() {
        NotificationCenter.default.post(name: Notification.Name("ScanGameHUDChanged"),
                                        object: nil, userInfo: ["score": score, "lives": lives])
    }

    // MARK: - Haptics

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)

    /// Reused white particle texture for the page-scatter bursts.
    private lazy var particleTexture: SKTexture = circleTexture(diameter: 14, color: .white)

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = groundColor
        scaleMode = .resizeFill

        // Breakout, not a falling-object game — kill default gravity.
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        installWalls()
        setupScoreLabel()
        setupPaddle()
        setupBall()
        buildBricks()
        launchBall()

        lightHaptic.prepare()
        mediumHaptic.prepare()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    /// Left / top / right walls only — the bottom is left open so a missed ball
    /// falls out (and gets re-served), rather than bouncing back up.
    private func installWalls() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: size.width, y: 0))
        let body = SKPhysicsBody(edgeChainFrom: path)
        body.friction = 0
        body.restitution = 1.0
        body.categoryBitMask = Category.wall
        physicsBody = body
    }

    private func setupScoreLabel() {
        scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreLabel.fontSize = 13
        scoreLabel.fontColor = textSecondary
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .top
        // Proportional so the HUD sits right whether the scene is full-screen
        // (below the notch) or embedded in a shorter area (Analyzing screen).
        scoreLabel.position = CGPoint(x: 20, y: size.height - max(26, size.height * 0.075))
        scoreLabel.zPosition = 50
        scoreLabel.text = "BOOKS  0"
        scoreLabel.alpha = 0   // SwiftUI host renders the brutalist HUD bar instead
        addChild(scoreLabel)
    }

    private func setupPaddle() {
        let paddleSize = CGSize(width: 96, height: 16)
        let node = SKSpriteNode(
            texture: roundedRectTexture(size: paddleSize, cornerRadius: 8, color: textPrimary)
        )
        node.size = paddleSize
        node.position = CGPoint(x: size.width / 2, y: max(54, size.height * 0.11))
        node.zPosition = 10

        // Player-controlled, not physics-driven, but still collides with the ball.
        let body = SKPhysicsBody(rectangleOf: paddleSize)
        body.isDynamic = false
        body.friction = 0
        body.restitution = 1.0
        body.categoryBitMask = Category.paddle
        body.contactTestBitMask = Category.ball
        body.collisionBitMask = Category.ball
        node.physicsBody = body

        paddle = node
        addChild(node)
    }

    private func setupBall() {
        let node = SKSpriteNode(texture: circleTexture(diameter: ballDiameter, color: ballColor))
        node.size = CGSize(width: ballDiameter, height: ballDiameter)
        node.position = CGPoint(x: size.width / 2, y: size.height * 0.42)
        node.zPosition = 10

        // Decorative bookmark ribbon hanging below the head (no physics).
        let w = ballDiameter * 0.42
        let h = ballDiameter * 0.5
        let ribbonPath = CGMutablePath()
        ribbonPath.move(to: CGPoint(x: -w / 2, y: 0))
        ribbonPath.addLine(to: CGPoint(x: -w / 2, y: -h))
        ribbonPath.addLine(to: CGPoint(x: 0, y: -h * 0.55))
        ribbonPath.addLine(to: CGPoint(x: w / 2, y: -h))
        ribbonPath.addLine(to: CGPoint(x: w / 2, y: 0))
        ribbonPath.closeSubpath()
        let ribbon = SKShapeNode(path: ribbonPath)
        ribbon.fillColor = ballColor.withAlphaComponent(0.82)
        ribbon.strokeColor = .clear
        ribbon.position = CGPoint(x: 0, y: -ballDiameter * 0.28)
        ribbon.zPosition = -1
        node.addChild(ribbon)

        let body = SKPhysicsBody(circleOfRadius: ballDiameter / 2)
        body.isDynamic = true
        body.affectedByGravity = false
        body.restitution = 1.0          // perfectly elastic
        body.friction = 0
        body.linearDamping = 0          // critical: no energy loss over time
        body.angularDamping = 0
        body.allowsRotation = false     // keep the ribbon pointing down
        body.categoryBitMask = Category.ball
        body.collisionBitMask = Category.paddle | Category.brick | Category.wall
        body.contactTestBitMask = Category.paddle | Category.brick
        node.physicsBody = body

        ball = node
        addChild(node)
    }

    /// Lays out a packed "shelf" of tall, narrow spines across the upper ~60%.
    /// Geometry is derived from `size`, so it adapts to any device and is reused on refill.
    private func buildBricks() {
        bricksRemainingInRow.removeAll()

        let rows = 5
        let rowSpacing: CGFloat = 8
        let colSpacing: CGFloat = 7
        let sideInset: CGFloat = 14
        let topInset = max(56, size.height * 0.12)   // clear HUD; proportional for embedded use
        let gridBottom = size.height * 0.40          // spines fill the upper ~60%

        let gridTop = size.height - topInset
        let availableH = gridTop - gridBottom
        let brickH = (availableH - rowSpacing * CGFloat(rows - 1)) / CGFloat(rows)
        let nominalW = max(22, brickH / 2.2)    // book-spine ratio ~2.2:1

        let usableW = size.width - sideInset * 2
        let cols = max(4, Int((usableW + colSpacing) / (nominalW + colSpacing)))
        let brickW = (usableW - colSpacing * CGFloat(cols - 1)) / CGFloat(cols)

        for row in 0..<rows {
            bricksRemainingInRow[row] = cols
            let y = gridTop - brickH / 2 - CGFloat(row) * (brickH + rowSpacing)
            for col in 0..<cols {
                let x = sideInset + brickW / 2 + CGFloat(col) * (brickW + colSpacing)
                let brick = makeBrick(width: brickW, height: brickH, row: row)
                brick.position = CGPoint(x: x, y: y)
                addChild(brick)
            }
        }
    }

    private func makeBrick(width: CGFloat, height: CGFloat, row: Int) -> SKSpriteNode {
        // Rotate spine tones with a small per-brick brightness jitter for a
        // non-uniform, editorial shelf.
        let base = spineColors[(row * 3 + Int.random(in: 0...2)) % spineColors.count]
        let tint = base.adjustingBrightness(by: CGFloat.random(in: -0.05...0.05))

        let brick = SKSpriteNode(
            texture: roundedRectTexture(size: CGSize(width: width, height: height),
                                        cornerRadius: 2.5, color: tint)
        )
        brick.size = CGSize(width: width, height: height)
        brick.name = "brick"
        brick.zPosition = 5
        brick.userData = ["row": row, "tint": tint]

        // ~1 in 4 spines get a thin "title band" line near the top.
        if Int.random(in: 0..<4) == 0 {
            let band = SKShapeNode(rectOf: CGSize(width: width * 0.62, height: 1.5))
            band.fillColor = SKColor.black.withAlphaComponent(0.30)
            band.strokeColor = .clear
            band.position = CGPoint(x: 0, y: height * 0.32)
            band.zPosition = 1
            brick.addChild(band)
        }

        let body = SKPhysicsBody(rectangleOf: brick.size)
        body.isDynamic = false
        body.friction = 0
        body.restitution = 1.0
        body.categoryBitMask = Category.brick
        body.contactTestBitMask = Category.ball
        body.collisionBitMask = Category.ball
        brick.physicsBody = body
        return brick
    }

    // MARK: - Ball serving & speed

    private func launchBall() {
        guard let body = ball.physicsBody else { return }
        body.velocity = .zero
        // Upward cone, 54°..126° — never dead-vertical, never too horizontal.
        let angle = CGFloat.random(in: (.pi * 0.30)...(.pi * 0.70))
        let dx = cos(angle) * ballSpeed
        let dy = sin(angle) * ballSpeed
        body.applyImpulse(CGVector(dx: dx * body.mass, dy: dy * body.mass))
    }

    private func resetBall() {
        ball.removeAllActions()
        ball.position = CGPoint(x: size.width / 2, y: size.height * 0.42)
        ball.physicsBody?.velocity = .zero
        launchBall()
    }

    /// Holds the ball at a constant speed and keeps it from settling into a
    /// near-horizontal orbit that never returns to the paddle.
    private func maintainBallSpeed() {
        guard let body = ball.physicsBody else { return }
        var v = body.velocity
        let speed = sqrt(v.dx * v.dx + v.dy * v.dy)
        guard speed > 1 else { return }

        let minVertical = ballSpeed * 0.22
        if abs(v.dy) < minVertical {
            v.dy = (v.dy < 0 ? -1 : 1) * minVertical
        }
        let mag = sqrt(v.dx * v.dx + v.dy * v.dy)
        let scale = ballSpeed / mag
        body.velocity = CGVector(dx: v.dx * scale, dy: v.dy * scale)
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isResolving else { return }
        maintainBallSpeed()
        if ball.position.y < -ball.size.height {   // missed — fell off the bottom
            lives -= 1
            if lives <= 0 { lives = 3; score = 0; rebuildShelf() }
            postHUD()
            resetBall()
        }
    }

    /// Wipes the shelf and rebuilds it — used on a life-reset wipe.
    private func rebuildShelf() {
        children.filter { $0.name == "brick" }.forEach { $0.removeFromParent() }
        buildBricks()
    }

    // MARK: - Touch (paddle control)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        movePaddle(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        movePaddle(touches)
    }

    private func movePaddle(_ touches: Set<UITouch>) {
        guard !isResolving, let touch = touches.first else { return }
        let x = touch.location(in: self).x
        let half = paddle.size.width / 2
        paddle.position.x = max(half, min(size.width - half, x))
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        guard !isResolving else { return }
        let mask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if mask == (Category.ball | Category.brick) {
            let brickBody = contact.bodyA.categoryBitMask == Category.brick ? contact.bodyA : contact.bodyB
            if let brick = brickBody.node as? SKSpriteNode {
                destroyBrick(brick)
            }
        } else if mask == (Category.ball | Category.paddle) {
            applyPaddleEnglish()
        }
    }

    /// Adds a small horizontal impulse based on where the ball struck the paddle.
    /// Edge hits add noticeably more "english" than centre hits; speed re-normalises
    /// next frame, so the net effect is a direction change, not a slowdown/speedup.
    private func applyPaddleEnglish() {
        guard let body = ball.physicsBody else { return }
        let offset = ball.position.x - paddle.position.x
        let normalized = max(-1, min(1, offset / (paddle.size.width / 2)))
        body.applyImpulse(CGVector(dx: normalized * body.mass * ballSpeed * 0.45, dy: 0))
        // Make sure a paddle hit always sends the ball back upward.
        if body.velocity.dy < 0 {
            body.velocity = CGVector(dx: body.velocity.dx, dy: abs(body.velocity.dy))
        }
    }

    // MARK: - Brick destruction

    private func destroyBrick(_ brick: SKSpriteNode) {
        guard brick.parent != nil else { return }   // ignore duplicate contacts in one frame

        let row = brick.userData?["row"] as? Int ?? -1
        let tint = brick.userData?["tint"] as? SKColor ?? ballColor
        let position = brick.position
        let brickSize = brick.size

        brick.removeFromParent()

        score += 1
        scoreLabel.text = "BOOKS  \(score)"
        // Surface the running count to any SwiftUI host (e.g. the Analyzing screen's
        // "spines · N" label).
        NotificationCenter.default.post(name: Notification.Name("ScanGameScoreChanged"),
                                        object: nil, userInfo: ["score": score])
        postHUD()

        spawnFragments(at: position, size: brickSize, color: tint)
        emitPageBurst(at: position, color: tint)
        fireHaptic(lightHaptic)

        // Row-clear escalation.
        if row >= 0, let remaining = bricksRemainingInRow[row] {
            let left = remaining - 1
            bricksRemainingInRow[row] = left
            if left == 0 { fireHaptic(mediumHaptic) }
        }

        // Keep the loading screen alive: an empty shelf feels broken, so reseed it.
        if !isResolving && childNode(withName: "brick") == nil {
            run(.sequence([.wait(forDuration: 0.35), .run { [weak self] in self?.buildBricks() }]))
        }
    }

    /// 2-3 small rectangular shards flung outward + slightly down, then faded out.
    /// Purely decorative — they collide with nothing (`contactTestBitMask`/`collisionBitMask` 0).
    private func spawnFragments(at position: CGPoint, size: CGSize, color: SKColor) {
        for _ in 0..<Int.random(in: 2...3) {
            let fragSize = CGSize(width: size.width * CGFloat.random(in: 0.30...0.50),
                                  height: size.height * CGFloat.random(in: 0.16...0.28))
            let frag = SKSpriteNode(color: color, size: fragSize)
            frag.position = position
            frag.zPosition = 6

            let body = SKPhysicsBody(rectangleOf: fragSize)
            body.affectedByGravity = false
            body.linearDamping = 1.4
            body.categoryBitMask = 0
            body.collisionBitMask = 0
            body.contactTestBitMask = 0
            frag.physicsBody = body
            addChild(frag)

            let dx = CGFloat.random(in: -70...70)
            let dy = CGFloat.random(in: -90 ... -15)   // outward + slightly downward
            body.applyImpulse(CGVector(dx: dx * body.mass, dy: dy * body.mass))
            body.applyAngularImpulse(CGFloat.random(in: -0.0025...0.0025))

            frag.run(.sequence([.fadeOut(withDuration: 0.6), .removeFromParent()]))
        }
    }

    /// A short, low-count white burst to suggest scattering pages.
    private func emitPageBurst(at position: CGPoint, color: SKColor) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = particleTexture
        emitter.position = position
        emitter.zPosition = 7
        emitter.numParticlesToEmit = Int.random(in: 8...12)
        emitter.particleBirthRate = 700
        emitter.particleLifetime = 0.5
        emitter.particleLifetimeRange = 0.18
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 95
        emitter.particleSpeedRange = 55
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.7
        emitter.particleScale = 0.18
        emitter.particleScaleRange = 0.1
        emitter.particleScaleSpeed = -0.22
        emitter.particleColor = dark ? SKColor(white: 0.96, alpha: 1)
                                     : SKColor(white: 0.25, alpha: 1)   // pages: off-white on dark, charcoal on paper
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .alpha
        addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 0.7), .removeFromParent()]))
    }

    // MARK: - Haptics

    private func fireHaptic(_ generator: UIImpactFeedbackGenerator) {
        DispatchQueue.main.async {
            generator.impactOccurred()
            generator.prepare()
        }
    }

    // MARK: - Texture helpers

    private func roundedRectTexture(size: CGSize, cornerRadius: CGFloat, color: SKColor) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size),
                         cornerRadius: cornerRadius).fill()
        }
        return SKTexture(image: image)
    }

    private func circleTexture(diameter: CGFloat, color: SKColor) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            color.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        }
        return SKTexture(image: image)
    }
}

// MARK: - SKColor brightness jitter

private extension SKColor {
    func adjustingBrightness(by delta: CGFloat) -> SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let clamp: (CGFloat) -> CGFloat = { max(0, min(1, $0)) }
        return SKColor(red: clamp(r + delta), green: clamp(g + delta), blue: clamp(b + delta), alpha: a)
    }
}
