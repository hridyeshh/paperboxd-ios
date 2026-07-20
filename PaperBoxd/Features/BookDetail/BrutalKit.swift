import SwiftUI

// MARK: - Book-page fixed light palette
//
// The book page is light-mode only. Asset-catalog Color("…") resolve against the
// device trait collection (so dark-mode variants leak through even when the SwiftUI
// environment is forced to .light). Using fixed values guarantees light, and mirrors
// the design tokens in "Book Page - Brutalist Mobile.html".
enum BK {
    static let paper  = Color(red: 0.949, green: 0.929, blue: 0.882) // #f2ede1
    static let paper2 = Color(red: 0.914, green: 0.886, blue: 0.820) // #e9e2d1
    static let ink    = Color(red: 0.082, green: 0.082, blue: 0.075) // #151513
    static let muted  = Color(red: 0.416, green: 0.392, blue: 0.337) // #6a6456
    static let accent = Color(red: 0.824, green: 0.231, blue: 0.149) // #d23b26
}

// MARK: - Shared brutalist animation primitives
//
// Three reusable pieces, mirroring the design spec:
//   1. popEffect        — scale 0.6→1.35→1.0 + rotate -12°→4°→0°, ease-out ~0.3s.
//                         Reused for: like-on, star-fill.
//   2. BrutalButtonStyle — offset hard shadow; on press the face translates into
//                         its own shadow (shadow collapses to 0). Instant, no easing.
//   3. brutalReveal      — quick drop-in transition for the rate / review panels.

// MARK: 1 — Pop keyframe

private struct PopValues {
    var scale: CGFloat = 1.0
    var rotation: CGFloat = 0.0
}

private struct PopEffect: ViewModifier {
    /// Bump this to fire the pop once (e.g. an Int incremented only on like-on).
    var trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: PopValues(), trigger: trigger) { view, val in
            view.scaleEffect(val.scale).rotationEffect(.degrees(val.rotation))
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.6,  duration: 0.001)
                SpringKeyframe(1.35, duration: 0.14, spring: .snappy)
                SpringKeyframe(1.0,  duration: 0.18, spring: .bouncy)
            }
            KeyframeTrack(\.rotation) {
                CubicKeyframe(-12, duration: 0.001)
                CubicKeyframe(4,   duration: 0.14)
                CubicKeyframe(0,   duration: 0.18)
            }
        }
    }
}

extension View {
    /// Fires the shared pop keyframe each time `trigger` changes.
    func popEffect(trigger: Int) -> some View { modifier(PopEffect(trigger: trigger)) }
}

// MARK: 2 — Brutal offset-shadow button

struct BrutalButtonStyle: ButtonStyle {
    var fill: Color
    var shadowColor: Color = BK.ink
    var border: Color = BK.ink
    var borderWidth: CGFloat = 2.5
    var offset: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .background(fill)
            .overlay(Rectangle().strokeBorder(border, lineWidth: borderWidth))
            // hard offset shadow sits behind the face; collapses to 0 on press
            .background(alignment: .topLeading) {
                Rectangle()
                    .fill(shadowColor)
                    .offset(x: pressed ? 0 : offset, y: pressed ? 0 : offset)
            }
            // face pushes into its own shadow
            .offset(x: pressed ? offset : 0, y: pressed ? offset : 0)
            .animation(nil, value: pressed) // instant, brutalist
    }
}

// MARK: 3 — Panel reveal transition

extension AnyTransition {
    /// Quick drop-in used by both the rate and review panels.
    static var brutalReveal: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        )
    }
}
