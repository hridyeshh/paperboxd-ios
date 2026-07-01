import SpriteKit
import UIKit

/// Two more endless "while-you-wait" games for the Scan & Know analysis screen,
/// alongside the Breakout scene. Both are light brutalist by default and report
/// score/lives to the SwiftUI host via the shared `ScanGameHUDChanged` notification.
/// Book covers / spines provide the only color.

private let kScanSpines: [SKColor] = [
    SKColor(red: 0.420, green: 0.165, blue: 0.227, alpha: 1),
    SKColor(red: 0.227, green: 0.290, blue: 0.165, alpha: 1),
    SKColor(red: 0.165, green: 0.290, blue: 0.416, alpha: 1),
    SKColor(red: 0.353, green: 0.227, blue: 0.416, alpha: 1),
    SKColor(red: 0.165, green: 0.416, blue: 0.353, alpha: 1),
    SKColor(red: 0.478, green: 0.290, blue: 0.165, alpha: 1),
    SKColor(red: 0.541, green: 0.416, blue: 0.165, alpha: 1),
    SKColor(red: 0.227, green: 0.227, blue: 0.267, alpha: 1),
]

private func postScanHUD(score: Int, lives: Int, best: Int) {
    NotificationCenter.default.post(name: Notification.Name("ScanGameHUDChanged"),
                                    object: nil, userInfo: ["score": score, "lives": lives, "best": best])
}

// ════════════════════════════════════════════════════════════════════════════
// CATCH — drag the shelf; catch falling books before they hit the floor.
// ════════════════════════════════════════════════════════════════════════════
final class ScanCatchScene: SKScene {
    var dark = false

    private var ink: SKColor { dark ? .white : SKColor(red: 0.078, green: 0.078, blue: 0.078, alpha: 1) }
    private var paper: SKColor { dark ? SKColor(red: 0.055, green: 0.055, blue: 0.059, alpha: 1)
                                       : SKColor(red: 0.988, green: 0.984, blue: 0.969, alpha: 1) }

    private let shelfW: CGFloat = 92
    private let shelfH: CGFloat = 12
    private var shelfY: CGFloat { 34 }

    private struct Falling { let node: SKSpriteNode; var vy: CGFloat; let w: CGFloat; let h: CGFloat }
    private var shelf: SKSpriteNode!
    private var books: [Falling] = []
    private var score = 0, lives = 3
    private var spawnTick = 0
    private var rate = 64.0
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    override func didMove(to view: SKView) {
        backgroundColor = paper
        scaleMode = .resizeFill

        shelf = SKSpriteNode(color: ink, size: CGSize(width: shelfW, height: shelfH))
        shelf.position = CGPoint(x: size.width / 2, y: shelfY)
        addChild(shelf)
        haptic.prepare()
        postScanHUD(score: score, lives: lives, best: 0)
    }

    private func spawn() {
        let w = CGFloat.random(in: 20...32), h = w * 1.45
        let node = SKSpriteNode(color: kScanSpines.randomElement()!, size: CGSize(width: w, height: h))
        let x = CGFloat.random(in: (12 + w / 2)...(size.width - 12 - w / 2))
        node.position = CGPoint(x: x, y: size.height + h)
        node.zRotation = CGFloat.random(in: -0.22...0.22)
        addChild(node)
        let vy = 1.5 + CGFloat.random(in: 0...1.0) + CGFloat(score) * 0.004
        books.append(Falling(node: node, vy: vy, w: w, h: h))
    }

    override func update(_ currentTime: TimeInterval) {
        spawnTick += 1
        if CGFloat(spawnTick) >= rate { spawnTick = 0; spawn(); if rate > 34 { rate -= 0.4 } }

        let shelfTop = shelf.position.y + shelfH / 2 + 8
        for i in books.indices.reversed() {
            var b = books[i]
            b.node.position.y -= b.vy
            books[i] = b
            let cx = b.node.position.x
            let bottom = b.node.position.y - b.h / 2
            if bottom <= shelfTop && bottom >= shelf.position.y - 6 &&
                abs(cx - shelf.position.x) <= shelfW / 2 + 6 {
                score += 1
                b.node.removeFromParent()
                books.remove(at: i)
                haptic.impactOccurred(); haptic.prepare()
                postScanHUD(score: score, lives: lives, best: 0)
            } else if b.node.position.y < -b.h {
                b.node.removeFromParent()
                books.remove(at: i)
                lives -= 1
                if lives <= 0 { lives = 3; score = 0; rate = 64; books.forEach { $0.node.removeFromParent() }; books.removeAll() }
                postScanHUD(score: score, lives: lives, best: 0)
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { moveShelf(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { moveShelf(touches) }
    private func moveShelf(_ touches: Set<UITouch>) {
        guard let t = touches.first else { return }
        let x = t.location(in: self).x
        let half = shelfW / 2
        shelf.position.x = max(half, min(size.width - half, x))
    }
}

// ════════════════════════════════════════════════════════════════════════════
// STACK — tap to drop the sliding book; overlap trims it. Build the tower.
// ════════════════════════════════════════════════════════════════════════════
final class ScanStackScene: SKScene {
    var dark = false

    private var ink: SKColor { dark ? .white : SKColor(red: 0.078, green: 0.078, blue: 0.078, alpha: 1) }
    private var paper: SKColor { dark ? SKColor(red: 0.055, green: 0.055, blue: 0.059, alpha: 1)
                                       : SKColor(red: 0.988, green: 0.984, blue: 0.969, alpha: 1) }

    private let blockH: CGFloat = 26
    private let baseW: CGFloat = 150

    private let world = SKNode()
    private var blocks: [SKSpriteNode] = []
    private var moving: SKSpriteNode?
    private var dir: CGFloat = 1
    private var slideSpeed: CGFloat = 2.3
    private var camTarget: CGFloat = 0
    private var score = 0, best = 0
    private var resetting = false
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    override func didMove(to view: SKView) {
        backgroundColor = paper
        scaleMode = .resizeFill
        addChild(world)
        haptic.prepare()
        reset()
    }

    private func centerY(level: Int) -> CGFloat { 40 + blockH / 2 + CGFloat(level) * blockH }

    private func reset() {
        resetting = false
        world.position = .zero
        camTarget = 0
        blocks.forEach { $0.removeFromParent() }
        blocks.removeAll()
        moving?.removeFromParent(); moving = nil
        score = 0

        let base = makeBlock(width: baseW, color: kScanSpines[0])
        base.position = CGPoint(x: size.width / 2, y: centerY(level: 0))
        world.addChild(base); blocks.append(base)
        newMover()
        postScanHUD(score: score, lives: -1, best: best)
    }

    private func makeBlock(width: CGFloat, color: SKColor) -> SKSpriteNode {
        SKSpriteNode(color: color, size: CGSize(width: width, height: blockH))
    }

    private func newMover() {
        guard let top = blocks.last else { return }
        slideSpeed = 2.3 + CGFloat(score) * 0.05
        dir = blocks.count % 2 == 0 ? -1 : 1
        let m = makeBlock(width: top.size.width, color: kScanSpines[blocks.count % kScanSpines.count])
        m.position = CGPoint(x: dir > 0 ? -top.size.width / 2 : size.width + top.size.width / 2,
                             y: centerY(level: blocks.count))
        world.addChild(m); moving = m
    }

    private func drop() {
        guard let m = moving, let top = blocks.last, !resetting else { return }
        let left = max(m.position.x - m.size.width / 2, top.position.x - top.size.width / 2)
        let right = min(m.position.x + m.size.width / 2, top.position.x + top.size.width / 2)
        let overlap = right - left
        if overlap <= 2 {
            resetting = true
            m.run(.sequence([.group([.moveBy(x: 0, y: -size.height, duration: 0.6),
                                     .rotate(byAngle: 0.6, duration: 0.6)]),
                             .removeFromParent()]))
            moving = nil
            best = max(best, score)
            postScanHUD(score: score, lives: -1, best: best)
            run(.sequence([.wait(forDuration: 0.65), .run { [weak self] in self?.reset() }]))
            return
        }
        m.size = CGSize(width: overlap, height: blockH)
        m.position.x = (left + right) / 2
        blocks.append(m)
        moving = nil
        score += 1; best = max(best, score)
        haptic.impactOccurred(); haptic.prepare()

        let towerTop = centerY(level: blocks.count - 1) + blockH / 2
        if towerTop > size.height * 0.55 { camTarget = towerTop - size.height * 0.55 }
        newMover()
        postScanHUD(score: score, lives: -1, best: best)
    }

    override func update(_ currentTime: TimeInterval) {
        if let m = moving, !resetting {
            m.position.x += dir * slideSpeed
            let half = m.size.width / 2
            if m.position.x + half > size.width { m.position.x = size.width - half; dir = -1 }
            if m.position.x - half < 0 { m.position.x = half; dir = 1 }
        }
        world.position.y += (-camTarget - world.position.y) * 0.12
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { drop() }
}
