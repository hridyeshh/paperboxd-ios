import SwiftUI
import Combine

/// Scan & Know — brutalist design kit (light theme).
///
/// The post-scan flow mirrors the "Scan & Know" design system: raw BRUTALISM
/// (analyzing → reveal) resolving into calm MINIMALISM (the breakdown). Hard ink
/// frames, mono readouts and hard offset shadows give way to whitespace, hairlines
/// and serif. Monochrome by system — the book cover is the only color.
enum SK {
    // Paper backgrounds, softening across the arc (analyze → reveal → breakdown).
    static let bg       = Color(hex: 0xF4F3F0)
    static let bgSoft   = Color(hex: 0xF8F7F5)
    static let bgSofter = Color(hex: 0xFCFBFA)
    static let panel    = Color.white
    static let ink      = Color(hex: 0x141414)
    static let sub      = Color(hex: 0x6A665E)
    static let faint    = Color(hex: 0xA6A299)
    static let line     = Color(hex: 0x141414)
    /// Cover-green accent — pulled straight from the book cover.
    static let accent   = Color(hex: 0x5B8A4E)
    /// Game canvas paper.
    static let gameBg   = Color(hex: 0xFCFBF7)

    /// Hairline used in the minimalist breakdown.
    static let border   = Color(hex: 0x141414).opacity(0.10)
    static let track    = Color(hex: 0x141414).opacity(0.10)

    /// Deep jewel book-spine tones (covers = color), shared with the games.
    static let spines: [Color] = [
        Color(hex: 0x6B2A3A), Color(hex: 0x3A4A2A), Color(hex: 0x2A4A6A), Color(hex: 0x5A3A6A),
        Color(hex: 0x2A6A5A), Color(hex: 0x7A4A2A), Color(hex: 0x8A6A2A), Color(hex: 0x3A3A44),
    ]

    /// Linear cover gradient (158°) used by the tinted cover fallback.
    static let coverGradient = LinearGradient(
        colors: [Color(hex: 0x5B8A4E), Color(hex: 0x2C5132), Color(hex: 0x16271A)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Brutalist book cover (hard ink frame + optional offset shadow)

/// Book cover tile. Real artwork via `cover_url` when present; otherwise a green
/// editorial gradient with the title set in serif. Hard ink border + hard shadow
/// give the brutalist look used on the analyzing screen.
struct ScanCover: View {
    let result: ScanResult
    var width: CGFloat = 48
    var shadow: CGFloat = 0     // hard offset; 0 = none

    var body: some View {
        artwork
            .frame(width: width, height: width * 1.5)
            .overlay(Rectangle().strokeBorder(SK.line, lineWidth: 2))
            .background(
                Rectangle().fill(SK.line)
                    .offset(x: shadow, y: shadow)
            )
    }

    @ViewBuilder private var artwork: some View {
        if let raw = result.coverURL,
           let url = URL(string: raw.replacingOccurrences(of: "http://", with: "https://")) {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { tinted }
            }
            .clipped()
        } else {
            tinted
        }
    }

    private var tinted: some View {
        SK.coverGradient.overlay(alignment: .bottomLeading) {
            Text(result.title)
                .font(PB.serif(width * 0.155, .bold))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .padding(width * 0.12)
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(.white.opacity(0.28)).frame(width: 1).offset(x: width * 0.16)
        }
    }
}

// MARK: - Mono helpers

/// Wide-tracked uppercase mono label.
struct MonoLabel: View {
    let text: String
    var size: CGFloat = 10
    var tracking: CGFloat = 1.8
    var color: Color = SK.sub
    var weight: Font.Weight = .regular
    var body: some View {
        Text(text.uppercased())
            .font(PB.mono(size, weight))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

// MARK: - Count-up number

/// Eases 0 → `target` over `duration`, monospaced. Used by the orb core and the
/// analyzing source cells.
/// Placeholder that rolls random digits while the real number is still loading,
/// so the source cell reads as "tallying" rather than blank. Once the true value
/// arrives the parent swaps this for CountUpText, which settles on it.
struct RollingNumber: View {
    var font: Font = PB.mono(21, .semibold)
    var color: Color = SK.sub
    var digits: Int = 3

    @State private var value = 0
    private let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        Text("\(value)")
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(.numericText())
            .onReceive(timer) { _ in
                let upper = Int(pow(10.0, Double(digits)))
                withAnimation(.easeInOut(duration: 0.08)) { value = Int.random(in: 0..<upper) }
            }
    }
}

struct CountUpText: View {
    let target: Int
    var duration: Double = 1.8
    var font: Font = PB.mono(21, .semibold)
    var color: Color = SK.ink
    var grouping: Bool = true

    @State private var value = 0

    var body: some View {
        Text(grouping ? value.formatted(.number) : "\(value)")
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .onAppear(perform: run)
    }

    private func run() {
        guard target > 0 else { return }
        let steps = min(target, 60)
        for s in 1...steps {
            let p = Double(s) / Double(steps)
            let eased = 1 - pow(1 - p, 3)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * p) {
                value = Int(eased * Double(target))
                if s == steps { value = target }
            }
        }
    }
}

// MARK: - Crop-mark corners (brutalist frame accents)

struct CropCorners: View {
    var color: Color = SK.accent
    var length: CGFloat = 16
    var weight: CGFloat = 3
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { p in
                // top-left
                p.move(to: CGPoint(x: 0, y: length)); p.addLine(to: .zero); p.addLine(to: CGPoint(x: length, y: 0))
                // top-right
                p.move(to: CGPoint(x: w - length, y: 0)); p.addLine(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: length))
                // bottom-right
                p.move(to: CGPoint(x: w, y: h - length)); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: w - length, y: h))
                // bottom-left
                p.move(to: CGPoint(x: length, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: 0, y: h - length))
            }
            .stroke(color, lineWidth: weight)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Scrolling brutalist marquee

struct ScanMarquee: View {
    let text: String
    var speed: Double = 22   // points/sec

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(SK.line).frame(height: 2)
            GeometryReader { geo in
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let cell = text + "   "
                    Text(cell + cell)
                        .font(PB.mono(10.5))
                        .tracking(1.6)
                        .foregroundStyle(SK.ink)
                        .lineLimit(1)
                        .fixedSize()
                        .offset(x: -CGFloat((t * speed).truncatingRemainder(dividingBy: Double(cellWidth))))
                        .frame(width: geo.size.width, alignment: .leading)
                        .clipped()
                }
            }
            .frame(height: 22)
            Rectangle().fill(SK.line).frame(height: 2)
        }
    }

    // Rough advance width for one logical cell; the doubled string makes the wrap seamless.
    private var cellWidth: CGFloat { CGFloat(text.count + 3) * 7.2 }
}

// MARK: - Brutalist primary button (ink fill, hard offset shadow)

struct BruButton: View {
    let title: String
    var leading: String? = nil       // SF Symbol
    var trailing: String? = nil      // SF Symbol
    var glyph: String? = nil         // literal prefix glyph, e.g. "▶"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let glyph { Text(glyph) }
                if let leading { Image(systemName: leading).font(.system(size: 14, weight: .bold)) }
                Text(title.uppercased())
                    .font(PB.mono(13, .semibold))
                    .tracking(1.0)
                if let trailing { Image(systemName: trailing).font(.system(size: 14, weight: .bold)) }
            }
            .foregroundStyle(SK.panel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(SK.ink)
            .overlay(Rectangle().strokeBorder(SK.line, lineWidth: 1.875))
            .background(SK.ink.opacity(0.78).offset(x: 4, y: 4))
        }
        .buttonStyle(.plain)
    }
}
