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
    static let card   = Color(red: 0.992, green: 0.984, blue: 0.965) // #fdfbf6
    static let ink    = Color(red: 0.082, green: 0.082, blue: 0.075) // #151513
    static let muted  = Color(red: 0.416, green: 0.392, blue: 0.337) // #6a6456
    static let accent = Color(red: 0.824, green: 0.231, blue: 0.149) // #d23b26

    // Welcome / onboarding tokens. Same paper ground; the auth and onboarding
    // run adds saturated cloth colours so the shelf reads as bound books.
    static let crimson = Color(hex: "C0271C") // primary CTA
    static let ochre   = Color(hex: "C9962B")
    static let forest  = Color(hex: "1B4B3C")
    static let cream   = Color(hex: "FFF6E9") // type on crimson / ink
    static let field   = Color(hex: "F6EFDF") // input wells
    static let sepia   = Color(hex: "7A4A2E") // serif italic sub-heads
    static let sage    = Color(hex: "2F7D5A") // "available" affirmation
    static let plank   = Color(hex: "3A2C1C") // shelf board and its shadow
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

// MARK: 4 — Brutal plate (static twin of BrutalButtonStyle)

private struct BrutalPlate: ViewModifier {
    var fill: Color
    var border: Color
    var borderWidth: CGFloat
    var offset: CGFloat

    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(Rectangle().strokeBorder(border, lineWidth: borderWidth))
            .background(alignment: .topLeading) {
                Rectangle().fill(border).offset(x: offset, y: offset)
            }
            // reserve the shadow's room so it can't clip against a sibling
            .padding(.trailing, offset)
            .padding(.bottom, offset)
    }
}

extension View {
    /// Flat fill, hard border, hard offset shadow — the non-interactive twin of
    /// `BrutalButtonStyle`, used for cards and section plates.
    func brutalPlate(
        fill: Color = BK.paper,
        border: Color = BK.ink,
        borderWidth: CGFloat = 2,
        offset: CGFloat = 5
    ) -> some View {
        modifier(BrutalPlate(fill: fill, border: border, borderWidth: borderWidth, offset: offset))
    }
}

// MARK: 5 — Hazard hatch

/// 45° stripe fill. Marks destructive controls without spending a colour on
/// them, so the palette stays monochrome.
struct HatchFill: View {
    var ink: Color = BK.ink
    var stripe: Color = Color(red: 0.200, green: 0.200, blue: 0.180) // #33332e
    var period: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(ink))
            let span = size.width + size.height
            var x = -size.height
            while x < span {
                let bar = Path { p in
                    p.move(to: CGPoint(x: x, y: size.height))
                    p.addLine(to: CGPoint(x: x + size.height, y: 0))
                    p.addLine(to: CGPoint(x: x + size.height + period / 2, y: 0))
                    p.addLine(to: CGPoint(x: x + period / 2, y: size.height))
                    p.closeSubpath()
                }
                context.fill(bar, with: .color(stripe))
                x += period
            }
        }
        .drawingGroup()
    }
}
