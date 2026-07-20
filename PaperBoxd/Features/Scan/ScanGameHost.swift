import SwiftUI
import SpriteKit

/// The three "while-you-wait" games, with their brutalist chrome.
enum ScanGameKind: CaseIterable {
    case breakout, catchDrops, stack

    var title: String {
        switch self {
        case .breakout:   return "Break some spines"
        case .catchDrops: return "Catch the drops"
        case .stack:      return "Stack the shelf"
        }
    }
    var sub: String {
        switch self {
        case .breakout:   return "drag to move the paddle · tap to serve"
        case .catchDrops: return "drag the shelf · don't let them fall"
        case .stack:      return "tap to drop · line them up to build higher"
        }
    }
    var hudLabel: String {
        switch self {
        case .breakout:   return "spines"
        case .catchDrops: return "caught"
        case .stack:      return "height"
        }
    }
    /// `true` → HUD hint shows hearts (lives); `false` → shows "best N".
    var usesLives: Bool { self != .stack }

    func makeScene() -> SKScene {
        let scene: SKScene
        switch self {
        case .breakout:   let s = ScanGameScene(); s.dark = false; scene = s
        case .catchDrops: let s = ScanCatchScene(); s.dark = false; scene = s
        case .stack:      let s = ScanStackScene(); s.dark = false; scene = s
        }
        scene.scaleMode = .resizeFill
        return scene
    }
}

/// Fullscreen brutalist game overlay. A random game is picked when it opens; ↻ NEW
/// swaps to a different one; ✕ returns to the analyzing screen. The game never stops
/// on its own — the analysis result lands as a popup over the top.
struct ScanGameHost: View {
    let onClose: () -> Void

    @State private var kind: ScanGameKind
    @State private var scene: SKScene
    @State private var score = 0
    @State private var lives = 3
    @State private var best = 0

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let k = ScanGameKind.allCases.randomElement() ?? .breakout
        _kind = State(initialValue: k)
        _scene = State(initialValue: k.makeScene())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            shell
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .frame(maxHeight: .infinity)
            footer
        }
        .padding(.top, 8)
        .background(SK.bgSoft.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ScanGameHUDChanged"))) { note in
            if let s = note.userInfo?["score"] as? Int { score = s }
            if let l = note.userInfo?["lives"] as? Int { lives = l }
            if let b = note.userInfo?["best"] as? Int { best = b }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    BlinkDot(color: SK.accent, size: 7)
                    MonoLabel(text: "Analyzing · Background", size: 9, tracking: 1.6, color: SK.accent)
                }
                Text(kind.title)
                    .font(PB.serif(19, .bold))
                    .foregroundStyle(SK.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: newGame) {
                Text("↻ NEW")
                    .font(PB.mono(11))
                    .tracking(1.0)
                    .foregroundStyle(SK.ink)
                    .frame(height: 40)
                    .padding(.horizontal, 12)
                    .overlay(Rectangle().strokeBorder(SK.line, lineWidth: 2))
            }
            .buttonStyle(.plain)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SK.panel)
                    .frame(width: 40, height: 40)
                    .background(SK.ink)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(SK.line).frame(height: 2) }
    }

    // MARK: - Game shell (HUD bar + framed canvas)

    private var shell: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(kind.hudLabel.uppercased())  ·  \(score)")
                    .font(PB.mono(11)).tracking(1.0)
                    .foregroundStyle(SK.panel)
                Spacer()
                Text(hint)
                    .font(PB.mono(10.5)).tracking(0.8)
                    .foregroundStyle(SK.panel.opacity(0.7))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(SK.ink)

            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .id(ObjectIdentifier(scene))   // force a fresh SpriteView when the game swaps
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SK.gameBg)
        }
        .overlay(Rectangle().strokeBorder(SK.line, lineWidth: 2))
        .background(SK.ink.opacity(0.55).offset(x: 5, y: 5))
    }

    private var hint: String {
        if kind.usesLives {
            let l = max(0, lives)
            return String(repeating: "♥", count: l) + String(repeating: "·", count: 3 - l)
        }
        return "BEST \(best)"
    }

    // MARK: - Footer

    private var footer: some View {
        Text("\(kind.sub.uppercased()) · NEVER STOPS ON ITS OWN")
            .font(PB.mono(9.5)).tracking(1.0)
            .foregroundStyle(SK.faint)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
    }

    private func newGame() {
        let next = ScanGameKind.allCases.filter { $0 != kind }.randomElement() ?? kind
        kind = next
        scene = next.makeScene()
        score = 0; lives = 3; best = 0
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// Small blinking square dot used across the brutalist chrome.
struct BlinkDot: View {
    var color: Color = SK.accent
    var size: CGFloat = 8
    @State private var on = true
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(on ? 1 : 0.25)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { on = false }
            }
    }
}
