import SwiftUI

/// The four profile-dock icons as trimmable `Shape`s.
///
/// Hand-drawn rather than SF Symbols on purpose: `ProfileDockView` animates a
/// tab by trimming its icon's stroke away, and a symbol is a font glyph with no
/// path you can measure or partially draw. Coordinates are authored in a 20×20
/// box and scaled to whatever frame they're given.
///
/// `.trim` walks the subpaths in order, so a multi-part mark (the bookshelf's
/// three spines) erases one part after another rather than all at once. That
/// reads better than a simultaneous erase — deliberate, not a bug.
struct ProfileTabMark: Shape {
    enum Kind { case bookshelf, thoughts, lists, tbr }

    let kind: Kind

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = min(rect.width, rect.height) / 20
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        switch kind {
        case .bookshelf:
            // Three spines, the rightmost leaning.
            p.addRect(CGRect(x: rect.minX + 3.6 * s, y: rect.minY + 4.6 * s,
                             width: 2.9 * s, height: 11 * s))
            p.addRect(CGRect(x: rect.minX + 8.1 * s, y: rect.minY + 4.6 * s,
                             width: 2.9 * s, height: 11 * s))
            p.move(to: pt(13.1, 5.7))
            p.addLine(to: pt(15.9, 6.5))
            p.addLine(to: pt(13.4, 16.0))
            p.addLine(to: pt(10.6, 15.2))
            p.closeSubpath()

        case .thoughts:
            // Rounded speech bubble, tail, two text rules.
            let r: CGFloat = 2.7 * s
            let box = CGRect(x: rect.minX + 3 * s, y: rect.minY + 4.2 * s,
                             width: 14 * s, height: 9.6 * s)
            p.addRoundedRect(in: box, cornerSize: CGSize(width: r, height: r))
            p.move(to: pt(8.8, 13.8))
            p.addLine(to: pt(4.6, 16.3))
            p.addLine(to: pt(4.6, 13.7))
            p.move(to: pt(6.6, 7.5))
            p.addLine(to: pt(13.4, 7.5))
            p.move(to: pt(6.6, 10.1))
            p.addLine(to: pt(11.0, 10.1))

        case .lists:
            p.move(to: pt(7.4, 5.6));  p.addLine(to: pt(17, 5.6))
            p.move(to: pt(7.4, 10));   p.addLine(to: pt(17, 10))
            p.move(to: pt(7.4, 14.4)); p.addLine(to: pt(17, 14.4))

        case .tbr:
            // Bookmark: square shoulders, notched foot.
            p.move(to: pt(4.4, 4.7))
            p.addLine(to: pt(4.4, 16.3))
            p.addLine(to: pt(10, 12.9))
            p.addLine(to: pt(15.6, 16.3))
            p.addLine(to: pt(15.6, 4.7))
            p.closeSubpath()
        }
        return p
    }
}

/// The Lists bullets. Dots have no length to trim, so they fade with the tab's
/// opacity instead — otherwise a row of bullets sits there after the rules go.
struct ProfileTabListDots: View {
    let size: CGFloat
    var color: Color

    var body: some View {
        let s = size / 20
        Canvas { ctx, _ in
            for y in [5.6, 10.0, 14.4] as [CGFloat] {
                let r = 1.05 * s
                let rect = CGRect(x: 4 * s - r, y: y * s - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

extension ProfileTab {
    var mark: ProfileTabMark.Kind {
        switch self {
        case .bookshelf: return .bookshelf
        case .diary:     return .thoughts
        case .lists:     return .lists
        case .tbr:       return .tbr
        }
    }
}
