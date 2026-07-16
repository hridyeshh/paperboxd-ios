import Combine
import SwiftUI

// Full-screen celebration takeovers, ported from the "Motion & Celebration"
// takeover design: slab wipes, poster type, mono chrome. Timeline mirrors the
// web phase machine — lead slab wipes up, poster holds ~2.1s, wipes out.
//   .shelved  — Bookshelf (paper) / TBR (ink) / Read (paper) cover poster
//   .streak   — ink poster, giant number roll N-1 → N
//   .levelUp  — ink poster, gold sheen level name, roman numeral behind

enum Celebration: Hashable {
    case shelved(shelf: BookDetailViewModel.LibraryShelf, title: String, author: String, coverURL: String?)
    case streak(days: Int)
    case levelUp(level: Int)
}

/// Reader levels, mirroring the design's tier ladder.
enum ReaderLevel {
    static let names = ["Apprentice", "Reader", "Bibliophile", "Scholar", "Sage", "Luminary"]
    static let numerals = ["I", "II", "III", "IV", "V", "VI"]
    static func name(_ level: Int) -> String { names[max(0, min(level - 1, names.count - 1))] }
    static func numeral(_ level: Int) -> String { numerals[max(0, min(level - 1, numerals.count - 1))] }
}

@MainActor
final class CelebrationCenter: ObservableObject {
    static let shared = CelebrationCenter()
    @Published var current: Celebration?

    private init() {}

    func show(_ celebration: Celebration) {
        current = celebration
    }

    func dismiss() {
        current = nil
    }

    // MARK: - Increment detection (streak / level)

    private var streakKey: String { "celebrated_streak" }
    private var levelKey: String { "celebrated_level" }

    /// Celebrate when the server-computed streak grows past the last one seen.
    func checkStreak(_ new: Int) {
        let d = UserDefaults.standard
        let old = d.integer(forKey: streakKey)
        d.set(new, forKey: streakKey)
        // old == 0 means first run — record silently, don't celebrate stale state.
        if old > 0, new > old { show(.streak(days: new)) }
    }

    /// Celebrate when the user's level rises past the last one seen.
    func checkLevel(_ new: Int?) {
        guard let new, new > 0 else { return }
        let d = UserDefaults.standard
        let old = d.integer(forKey: levelKey)
        d.set(new, forKey: levelKey)
        if old > 0, new > old { show(.levelUp(level: new)) }
    }
}

// MARK: - Design tokens (takeover/styles.css)

private enum TK {
    static let ink    = Color(red: 0.067, green: 0.067, blue: 0.067) // #111
    static let paper  = Color(red: 0.980, green: 0.973, blue: 0.957) // #faf8f4
    static let sienna = Color(red: 0.722, green: 0.361, blue: 0.220) // #b85c38
    static let gold   = Color(red: 0.659, green: 0.537, blue: 0.247) // #a8893f
    static let gold2  = Color(red: 0.831, green: 0.690, blue: 0.416) // #d4b06a
}

// MARK: - Root overlay (mount once, above the tab bar)

struct CelebrationOverlayView: View {
    @ObservedObject private var center = CelebrationCenter.shared

    var body: some View {
        ZStack {
            if let c = center.current {
                TakeoverScaffold(config: TakeoverConfig(for: c)) {
                    switch c {
                    case .shelved(let shelf, let title, let author, let coverURL):
                        ShelvedPoster(shelf: shelf, title: title, author: author, coverURL: coverURL)
                    case .streak(let days):
                        StreakPoster(days: days)
                    case .levelUp(let level):
                        LevelUpPoster(level: level)
                    }
                } onDone: {
                    center.dismiss()
                }
                .id(c) // restart the phase machine if a new celebration lands
            }
        }
    }
}

// MARK: - Takeover config per moment

private struct TakeoverConfig {
    let bg: Color        // poster background (ink or paper)
    let fg: Color        // chrome/current color on that background
    let lead: Color      // the slab that wipes through first
    let rightText: String
    let footText: String

    init(for c: Celebration) {
        switch c {
        case .shelved(let shelf, let title, let author, _):
            switch shelf {
            case .tbr:
                bg = TK.ink; fg = TK.paper; lead = TK.sienna
                rightText = "To be read"
            case .bookshelf:
                bg = TK.paper; fg = TK.ink; lead = TK.ink
                rightText = "Bookshelf"
            case .read:
                bg = TK.paper; fg = TK.ink; lead = TK.ink
                rightText = "Read"
            }
            footText = author.isEmpty ? title : "\(title) — \(author)"
        case .streak:
            bg = TK.ink; fg = TK.paper; lead = TK.sienna
            rightText = "Daily log"
            footText = "Read every day"
        case .levelUp(let level):
            bg = TK.ink; fg = TK.paper; lead = TK.gold
            rightText = "Tier change"
            footText = "The Reading Order · Tier \(ReaderLevel.numeral(level)) of VI"
        }
    }
}

// MARK: - Scaffold: slab wipe in → poster hold → wipe out

// Phase timeline (ms), mirroring takeover/shared.jsx:
//   0      lead slab starts rising from the bottom
//   150    poster bg wipes in beneath it
//   700    lead has exited through the top; content entrances play (their own delays)
//   2960   whole takeover wipes out toward the top
//   3520   done
private struct TakeoverScaffold<Content: View>: View {
    let config: TakeoverConfig
    @ViewBuilder let content: () -> Content
    let onDone: () -> Void

    @State private var leadPhase = 0      // 0 below screen · 1 covering · 2 exited top
    @State private var bgRevealed = false
    @State private var wipedOut = false

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack {
                // Poster background + content, revealed bottom-up behind the lead.
                ZStack {
                    config.bg.ignoresSafeArea()
                    chrome
                    content()
                }
                .compositingGroup()
                .mask(alignment: .bottom) {
                    Rectangle()
                        .frame(height: bgRevealed ? h : 0)
                        .animation(.timingCurve(0.72, 0.06, 0.2, 1, duration: 0.46).delay(0.15), value: bgRevealed)
                }

                // Lead slab: rises to cover, then exits through the top.
                config.lead
                    .ignoresSafeArea()
                    .offset(y: leadPhase == 0 ? h : (leadPhase == 1 ? 0 : -h))
            }
            // Wipe-out: viewport collapses toward the top edge.
            .mask(alignment: .top) {
                Rectangle()
                    .frame(height: wipedOut ? 0 : h)
                    .animation(.timingCurve(0.78, 0, 0.2, 1, duration: 0.52), value: wipedOut)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { onDone() } // tap to skip
        .onAppear { runTimeline() }
        .environment(\.colorScheme, config.bg == TK.ink ? .dark : .light)
    }

    private func runTimeline() {
        withAnimation(.timingCurve(0.74, 0.04, 0.22, 1, duration: 0.32)) { leadPhase = 1 }
        bgRevealed = true
        Task {
            try? await Task.sleep(nanoseconds: 320_000_000)
            withAnimation(.timingCurve(0.74, 0.04, 0.22, 1, duration: 0.38)) { leadPhase = 2 }
            try? await Task.sleep(nanoseconds: 2_640_000_000) // hold until t≈2960ms
            wipedOut = true
            try? await Task.sleep(nanoseconds: 560_000_000)
            onDone()
        }
    }

    // Brutalist chrome: grid, inset frame, corner ticks, top row, foot.
    private var chrome: some View {
        ZStack {
            GridLines(color: config.fg)
            Rectangle()
                .strokeBorder(config.fg.opacity(0.16), lineWidth: 1)
                .padding(12)
            CornerTicks(color: config.fg)

            VStack {
                HStack {
                    Text("PAPERBOXD")
                    Spacer()
                    Text(config.rightText.uppercased())
                }
                .font(PB.mono(8)).tracking(2.2)
                .opacity(0.55)
                .padding(.horizontal, 22)
                .padding(.top, 58)
                .entrance(.fade, delay: 0.38 + 0.7)

                Spacer()

                Text(config.footText.uppercased())
                    .font(PB.mono(8)).tracking(2)
                    .opacity(0.55)
                    .lineLimit(1)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 40)
                    .entrance(.fade, delay: 0.7 + 0.7)
            }
            .foregroundStyle(config.fg)
        }
    }
}

private struct GridLines: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var x: CGFloat = 39
            while x < size.width { path.move(to: .init(x: x, y: 0)); path.addLine(to: .init(x: x, y: size.height)); x += 39 }
            var y: CGFloat = 41
            while y < size.height { path.move(to: .init(x: 0, y: y)); path.addLine(to: .init(x: size.width, y: y)); y += 41 }
            ctx.stroke(path, with: .color(color.opacity(0.055)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

private struct CornerTicks: View {
    let color: Color
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<4, id: \.self) { i in
                let x: CGFloat = (i % 2 == 0) ? 18 : geo.size.width - 18
                let y: CGFloat = (i < 2) ? 62 : geo.size.height - 62
                ZStack {
                    Rectangle().frame(width: 1, height: 9)
                    Rectangle().frame(width: 9, height: 1)
                }
                .foregroundStyle(color.opacity(0.6))
                .position(x: x, y: y)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Entrance modifiers (rise / slam / fade / rule)

private enum EntranceKind { case rise, slam, fade }

private struct Entrance: ViewModifier {
    let kind: EntranceKind
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: kind == .rise && !shown ? 26 : 0)
            .scaleEffect(kind == .slam && !shown ? 1.32 : 1)
            .animation(animation.delay(delay), value: shown)
            .onAppear { shown = true }
    }

    private var animation: Animation {
        switch kind {
        case .rise: return .timingCurve(0.22, 0.9, 0.26, 1, duration: 0.48)
        case .slam: return .spring(response: 0.5, dampingFraction: 0.72)
        case .fade: return .easeInOut(duration: 0.42)
        }
    }
}

private extension View {
    // Content entrances are authored relative to takeover mount (t≈0.7s in the
    // shared timeline) — callers pass design delay + 0.7.
    func entrance(_ kind: EntranceKind, delay: Double) -> some View {
        modifier(Entrance(kind: kind, delay: delay))
    }
}

/// Horizontal rule that draws in from its edge, flanking a mono label.
private struct RuleLabel: View {
    let label: String
    let color: Color
    var delay: Double
    @State private var drawn = false

    var body: some View {
        HStack(spacing: 14) {
            rule(anchor: .leading)
            Text(label.uppercased())
                .font(PB.mono(10)).tracking(4)
                .fixedSize()
                .entrance(.fade, delay: delay + 0.04)
            rule(anchor: .trailing)
        }
        .foregroundStyle(color)
        .onAppear { drawn = true }
    }

    private func rule(anchor: UnitPoint) -> some View {
        Rectangle()
            .frame(height: 1)
            .scaleEffect(x: drawn ? 1 : 0, anchor: anchor)
            .animation(.timingCurve(0.7, 0, 0.2, 1, duration: 0.52).delay(delay), value: drawn)
    }
}

// MARK: - Streak poster (ink · sienna lead · giant number roll)

private struct StreakPoster: View {
    let days: Int
    @State private var rolled = false
    @State private var flicker = false

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "flame")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(TK.sienna)
                .scaleEffect(flicker ? 1.05 : 1, anchor: .bottom)
                .rotationEffect(.degrees(flicker ? -1.2 : 0.8))
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: flicker)
                .entrance(.slam, delay: 0.36 + 0.7)

            // Giant number roll: previous day count slides up out, new count in.
            let fontSize: CGFloat = 150
            VStack(spacing: 0) {
                rollDigits("\(days - 1)", size: fontSize)
                rollDigits("\(days)", size: fontSize)
            }
            .frame(height: fontSize, alignment: .top)
            .offset(y: rolled ? -fontSize : 0)
            .animation(.timingCurve(0.85, 0, 0.13, 1, duration: 0.64).delay(0.56 + 0.7), value: rolled)
            .clipped()
            .padding(.top, 6)

            RuleLabel(label: "Day streak", color: TK.paper, delay: 0.82 + 0.7)
                .frame(width: 230)
                .padding(.top, 12)

            Text("+1 · STREAK KEPT")
                .font(PB.mono(9)).tracking(2)
                .foregroundStyle(TK.sienna)
                .padding(.top, 18)
                .entrance(.rise, delay: 0.98 + 0.7)
        }
        .onAppear { rolled = true; flicker = true }
    }

    private func rollDigits(_ s: String, size: CGFloat) -> some View {
        Text(s)
            .font(PB.serif(size, .semibold))
            .tracking(-3)
            .foregroundStyle(TK.paper)
            .frame(height: size)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

// MARK: - Shelved / TBR / Read poster (cover slam + rules)

private struct ShelvedPoster: View {
    let shelf: BookDetailViewModel.LibraryShelf
    let title: String
    let author: String
    let coverURL: String?

    private var label: String {
        switch shelf {
        case .bookshelf: return "Shelved"
        case .tbr:       return "Want to read"
        case .read:      return "Read"
        }
    }
    private var sub: String {
        switch shelf {
        case .bookshelf: return "Added to your bookshelf"
        case .tbr:       return "Patience is literary"
        case .read:      return "Another spine on the shelf"
        }
    }
    private var fg: Color { shelf == .tbr ? TK.paper : TK.ink }
    private var coverGradient: LinearGradient {
        switch shelf {
        case .tbr:       return LinearGradient(colors: [Color(red: 0.29, green: 0.35, blue: 0.23), Color(red: 0.14, green: 0.18, blue: 0.09)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .bookshelf: return LinearGradient(colors: [Color(red: 0.48, green: 0.29, blue: 0.18), Color(red: 0.24, green: 0.13, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .read:      return LinearGradient(colors: [Color(red: 0.23, green: 0.29, blue: 0.42), Color(red: 0.08, green: 0.11, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    private var shadow: Color { shelf == .tbr ? TK.sienna.opacity(0.9) : TK.ink.opacity(0.92) }

    var body: some View {
        VStack(spacing: 0) {
            // The book's real cover slamming in, hard offset shadow.
            ZStack(alignment: .topLeading) {
                Rectangle().fill(shadow)
                    .frame(width: 186, height: 274)
                    .offset(x: 12, y: 12)
                cover
                    .frame(width: 186, height: 274)
                    .background(coverGradient)
                    .clipped() // square-cornered: keep the brutalist slab edge
            }
            .rotationEffect(.degrees(shelf == .tbr ? 2.5 : -2.5))
            .entrance(.slam, delay: 0.42 + 0.7)

            RuleLabel(label: label, color: fg, delay: 0.82 + 0.7)
                .frame(width: 250)
                .padding(.top, 34)

            Text(sub.uppercased())
                .font(PB.mono(9)).tracking(2)
                .foregroundStyle(fg.opacity(0.6))
                .padding(.top, 16)
                .entrance(.rise, delay: 0.98 + 0.7)
        }
    }

    /// Real artwork when the book has it; poster type while loading or on failure.
    @ViewBuilder private var cover: some View {
        if let urlStr = coverURL,
           let url = URL(string: urlStr.replacingOccurrences(of: "http://", with: "https://")) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    typographicCover
                }
            }
        } else {
            typographicCover
        }
    }

    /// The original poster-type cover — stands in until the artwork lands.
    private var typographicCover: some View {
        VStack {
            HStack {
                Spacer()
                Text(author.uppercased())
                    .font(PB.mono(8)).tracking(1.6)
                    .opacity(0.75)
                    .lineLimit(1)
            }
            Spacer()
            Text(title)
                .font(PB.serif(28, .semibold))
                .tracking(-0.5)
                .lineLimit(4)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .foregroundStyle(.white)
        .frame(width: 186, height: 274)
        .overlay(alignment: .leading) {
            Rectangle().fill(.white.opacity(0.28)).frame(width: 1).padding(.leading, 9)
        }
    }
}

// MARK: - Level up poster (ink · gold lead · sheen name)

private struct LevelUpPoster: View {
    let level: Int
    @State private var sheenX: CGFloat = 1

    var body: some View {
        ZStack {
            // Giant faint roman numeral behind everything.
            Text(ReaderLevel.numeral(level))
                .font(PB.serif(280, .semibold))
                .foregroundStyle(TK.gold2.opacity(0.14))
                .offset(y: -30)
                .entrance(.fade, delay: 0.3 + 0.7)

            VStack(spacing: 0) {
                Text("LEVEL \(ReaderLevel.numeral(level)) REACHED")
                    .font(PB.mono(9)).tracking(4)
                    .foregroundStyle(TK.paper.opacity(0.65))
                    .entrance(.rise, delay: 0.42 + 0.7)

                // Gold sheen sweeps across the level name.
                sheenText(ReaderLevel.name(level))
                    .padding(.top, 10)
                    .entrance(.slam, delay: 0.52 + 0.7)

                RuleLabel(label: fromToLine, color: TK.paper, delay: 0.88 + 0.7)
                    .frame(width: 260)
                    .padding(.top, 22)

                Text("Where pages turn into prestige.")
                    .font(PB.serifItalic(14))
                    .foregroundStyle(TK.paper.opacity(0.6))
                    .padding(.top, 20)
                    .entrance(.rise, delay: 1.04 + 0.7)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).delay(0.98 + 0.7)) { sheenX = -1 }
        }
    }

    private var fromToLine: String {
        level > 1 ? "\(ReaderLevel.name(level - 1))  →  \(ReaderLevel.name(level))" : ReaderLevel.name(level)
    }

    private func sheenText(_ s: String) -> some View {
        let base = Text(s)
            .font(PB.serif(72, .semibold))
            .tracking(-1.5)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        return base
            .foregroundStyle(TK.gold)
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, TK.gold2, Color(red: 0.95, green: 0.89, blue: 0.68), TK.gold2, .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.7)
                    .offset(x: sheenX * geo.size.width)
                }
                .mask(base)
            }
    }
}
