import SwiftUI

// Fusion, Swiss cut: one grotesk, one accent, hairlines and a real grid. Port
// of the design prototype's fusion2/kit.jsx. Motion reuses the Wrapped
// primitives (PBRise, PBFade, PBSlide, PBStamp, PBRule, PBCount) so the
// share card's still mode works the same way.

enum FZ {
    static let bg = Color(hex: "f2efe9")
    static let ink = Color(hex: "16161a")
    static let accent = Color(hex: "e33d21")
    static let grey = Color(hex: "8c8c88")
    static let line = Color(hex: "16161a").opacity(0.16)
    static let lineOnDark = Color(hex: "f2efe9").opacity(0.2)
    static let muteOnDark = Color(hex: "f2efe9").opacity(0.56)

    /// Story pages are laid out on this width and scaled to the device.
    static let designWidth: CGFloat = 402

    static func heading(_ size: CGFloat) -> Font { .custom("HelveticaNeue-Bold", size: size) }
    static func medium(_ size: CGFloat) -> Font { .custom("HelveticaNeue-Medium", size: size) }
    static func body(_ size: CGFloat) -> Font { .custom("HelveticaNeue", size: size) }
    static func script(_ size: CGFloat) -> Font { .custom("SnellRoundhand-Bold", size: size) }

    /// Negative tracking grows with size, as in the kit.
    static func tracking(_ size: CGFloat) -> CGFloat {
        size * (size > 90 ? -0.055 : size > 44 ? -0.04 : -0.03)
    }
}

// MARK: - Type

struct FZHeading: View {
    let text: String
    var size: CGFloat = 34
    var color: Color = FZ.ink

    var body: some View {
        Text(text)
            .font(FZ.heading(size))
            .tracking(FZ.tracking(size))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct FZLabel: View {
    let text: String
    var size: CGFloat = 10
    var color: Color = FZ.grey

    var body: some View {
        Text(text.uppercased())
            .font(FZ.medium(size))
            .tracking(size * 0.17)
            .foregroundStyle(color)
    }
}

struct FZBody: View {
    let text: String
    var size: CGFloat = 14.5
    var color: Color = FZ.ink
    var opacity: Double = 0.78

    var body: some View {
        Text(text)
            .font(FZ.body(size))
            .lineSpacing(size * 0.3)
            .foregroundStyle(color.opacity(opacity))
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct FZNum: View {
    let text: String
    var size: CGFloat = 13
    var color: Color = FZ.ink
    var bold = true

    var body: some View {
        Text(text)
            .font(bold ? FZ.heading(size) : FZ.medium(size))
            .monospacedDigit()
            .foregroundStyle(color)
    }
}

// MARK: - Objects

/// Hairline that draws itself from the leading edge.
struct FZRule: View {
    var delay: Double = 0
    var dark = false
    var color: Color? = nil
    var height: CGFloat = 1

    var body: some View {
        PBRule(delay: delay, duration: 0.62, color: color ?? (dark ? FZ.lineOnDark : FZ.line), height: height)
    }
}

/// The square button every screen ends on.
struct FZPill: View {
    let title: String
    var solid = false
    /// For dark pages: bone fill or bone outline.
    var light = false
    var compact = false
    var fullWidth = true
    let action: () -> Void

    private var fg: Color { solid ? (light ? FZ.ink : FZ.bg) : (light ? FZ.bg : FZ.ink) }
    private var fill: Color { solid ? (light ? FZ.bg : FZ.ink) : .clear }
    private var stroke: Color { light ? FZ.bg.opacity(0.5) : FZ.ink }

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(FZ.medium(compact ? 9.5 : 11))
                .tracking(compact ? 0.95 : 1.1)
                .foregroundStyle(fg)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.horizontal, compact ? 12 : 18)
                .padding(.vertical, compact ? 9 : 15)
                .background(fill)
                .overlay(Rectangle().stroke(stroke, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A square initial. Accent is always the viewer's half.
struct FZMonogram: View {
    let initial: String
    var size: CGFloat = 40
    var accent = false
    var onDark = false

    var body: some View {
        Text(initial)
            .font(FZ.heading(size * 0.4))
            .foregroundStyle(onDark && !accent ? FZ.ink : FZ.bg)
            .frame(width: size, height: size)
            .background(accent ? FZ.accent : (onDark ? FZ.bg : FZ.ink))
    }
}

/// The two-disc mark: the only place the Fusion symbol appears.
struct FZDiscs: View {
    var delay: Double = 0

    var body: some View {
        PBStamp(delay: delay, duration: 0.42) {
            ZStack(alignment: .leading) {
                Circle().fill(FZ.accent).frame(width: 62, height: 62)
                Circle().fill(FZ.ink).frame(width: 62, height: 62).offset(x: 46).blendMode(.multiply)
            }
            .frame(width: 108, height: 62, alignment: .leading)
            .compositingGroup()
        }
    }
}

/// Two names printed on top of each other, accent under ink.
struct FZOverprint: View {
    let a: String
    let b: String
    var size: CGFloat = 44
    var delay: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: -size * 0.34) {
            PBRise(delay: delay) { FZHeading(text: a, size: size, color: FZ.accent) }
            PBRise(delay: delay + 0.11) { FZHeading(text: b, size: size, color: FZ.ink) }
                .padding(.leading, size * 0.5)
                .blendMode(.multiply)
        }
    }
}

/// Real cover art when the book has it; otherwise one uniform object: bone
/// board, ink type, a rule in whoever's colour owns it.
struct FZCover: View {
    enum Owner { case you, them, both }

    let book: FusionBook
    var width: CGFloat = 96
    var owner: Owner = .both
    var dark = false
    var delay: Double = 0
    var rotation: Double = 0

    var body: some View {
        PBStamp(delay: delay, duration: 0.42, rotation: rotation) {
            PBCoverArt(url: book.coverURL) { board }
                .frame(width: width, height: width * 1.5)
                .clipped()
                .overlay(Rectangle().stroke(dark ? FZ.bg.opacity(0.16) : .clear, lineWidth: 1))
                .shadow(color: dark ? .clear : FZ.ink.opacity(0.14), radius: 8, y: 6)
        }
    }

    private var board: some View {
            ZStack(alignment: .bottomLeading) {
                Rectangle().fill(dark ? Color(hex: "222227") : Color(hex: "e7e3db"))
                HStack(spacing: 0) {
                    Rectangle().fill(owner == .them ? FZ.ink : FZ.accent).frame(width: width * 0.055)
                    Spacer(minLength: 0)
                    if owner == .both {
                        Rectangle().fill(dark ? FZ.bg : FZ.ink).frame(width: width * 0.055)
                    }
                }
                VStack(alignment: .leading, spacing: width * 0.05) {
                    Text(book.title)
                        .font(FZ.heading(width * 0.125))
                        .foregroundStyle(dark ? FZ.bg : FZ.ink)
                        .lineLimit(4)
                    if !book.author.isEmpty {
                        Text(book.author.uppercased())
                            .font(FZ.medium(width * 0.07))
                            .tracking(width * 0.007)
                            .foregroundStyle(dark ? FZ.bg.opacity(0.6) : FZ.grey)
                            .lineLimit(2)
                    }
                }
                .padding(width * 0.09)
                .padding(.leading, width * 0.04)
            }
    }
}

/// A rating is a number, set tabular. Not five shapes.
struct FZRate: View {
    let who: String
    let n: Int
    var color: Color = FZ.ink
    var size: CGFloat = 13

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(who.uppercased())
                .font(FZ.medium(size * 0.66))
                .tracking(size * 0.08)
                .foregroundStyle(FZ.grey)
            FZNum(text: "\(n)", size: size, color: color)
        }
    }
}

/// Every page is the same grid: 30pt margins, a running head, a baseline.
struct FZScreen<Content: View>: View {
    var dark = false
    var top: CGFloat = 94
    var bottom: CGFloat = 112
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, top)
            .padding(.bottom, bottom)
            .padding(.horizontal, 30)
            .background((dark ? FZ.ink : FZ.bg).ignoresSafeArea())
    }
}

/// Split heading on the design's line breaks, with the last line optionally
/// in the accent.
struct FZStack: View {
    let lines: [String]
    var size: CGFloat = 34
    var color: Color = FZ.ink
    var accentLast = false
    var delay: Double = 0
    var step: Double = 0.08

    var body: some View {
        VStack(alignment: .leading, spacing: -size * 0.04) {
            ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                PBRise(delay: delay + Double(i) * step) {
                    FZHeading(text: line, size: size, color: accentLast && i == lines.count - 1 ? FZ.accent : color)
                }
            }
        }
    }
}

/// Toast chip used across Fusion screens.
struct FZToast: View {
    let message: String
    var bottom: CGFloat = 84

    var body: some View {
        Text(message.uppercased())
            .font(FZ.medium(10))
            .tracking(1)
            .foregroundStyle(FZ.bg)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(FZ.ink)
            .padding(.bottom, bottom)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

extension String {
    /// Two-digit index, "01".
    static func fzIndex(_ i: Int) -> String { String(format: "%02d", i) }
}
