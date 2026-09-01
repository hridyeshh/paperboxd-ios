import SwiftUI

// Print-in-motion primitives for Monthly Wrapped: type sets itself out of its
// own baseline, paper slides, ink stamps down. Port of the design prototype's
// wrapped/motion.jsx.

// MARK: - Palette + type

enum PBW {
    static let ink       = Color(hex: "1a1410")
    static let inkDeep   = Color(hex: "120e0b")
    static let cream     = Color(hex: "f5ede0")
    static let terra     = Color(hex: "d97757")
    static let terraDeep = Color(hex: "8c4a3a")
    static let brown     = Color(hex: "6b3520")
    static let amber     = Color(hex: "e8b04b")
    static let muted     = Color(hex: "8a7a68")

    /// The chapters are laid out against this width and scaled to the device.
    static let designWidth: CGFloat = 402

    /// Editorial serif for headlines and pull quotes.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func displayItalic(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif).italic()
    }
    /// Poster numerals — the biggest type in the story.
    static func poster(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .serif)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func script(_ size: CGFloat) -> Font {
        .custom("SnellRoundhand-Bold", size: size)
    }

    static let ease    = Animation.timingCurve(0.2, 0.9, 0.24, 1, duration: 0.62)
    static let easeInk = Animation.timingCurve(0.16, 1.0, 0.3, 1, duration: 0.42)

    static func ease(_ duration: Double) -> Animation {
        .timingCurve(0.2, 0.9, 0.24, 1, duration: duration)
    }
}

// MARK: - Still mode

private struct WrappedStillKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while rendering the share card. Every primitive draws its finished
    /// state instead of animating — `ImageRenderer` never runs an animation, so
    /// without this the exported card would be blank.
    var wrappedStill: Bool {
        get { self[WrappedStillKey.self] }
        set { self[WrappedStillKey.self] = newValue }
    }
}

/// Shared by every primitive: has the reveal happened, or should it be skipped
/// entirely because this is a still or the reader asked for less motion.
private struct RevealState {
    let still: Bool
    let reduceMotion: Bool
    var skip: Bool { still || reduceMotion }
}

// MARK: - Rise — a line rises out of its own baseline clip

struct PBRise<Content: View>: View {
    var delay: Double = 0
    var duration: Double = 0.62
    @ViewBuilder var content: Content

    @Environment(\.wrappedStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var lineHeight: CGFloat = 0

    private var settled: Bool { shown || still || reduceMotion }

    var body: some View {
        content
            .offset(y: settled ? 0 : lineHeight * 1.05)
            // The clip is the natural line box, so the type is hidden *below*
            // its own baseline rather than sliding in from off-screen.
            .frame(height: lineHeight > 0 ? lineHeight : nil, alignment: .top)
            .clipped()
            .background(alignment: .top) { measurer }
            .onChange(of: lineHeight) { _, height in
                guard height > 0 else { return }
                reveal()
            }
    }

    /// A hidden copy of the content, used once to learn the line box height.
    private var measurer: some View {
        content
            .hidden()
            .background {
                GeometryReader { geo in
                    Color.clear.onAppear {
                        if lineHeight == 0 { lineHeight = geo.size.height }
                    }
                }
            }
    }

    private func reveal() {
        guard !still, !reduceMotion, !shown else { return }
        withAnimation(PBW.ease(duration).delay(delay)) { shown = true }
    }
}

// MARK: - Fade, Slide, Stamp

struct PBFade<Content: View>: View {
    var delay: Double = 0
    var duration: Double = 0.7
    @ViewBuilder var content: Content

    @Environment(\.wrappedStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var settled: Bool { shown || still || reduceMotion }

    var body: some View {
        content
            .opacity(settled ? 1 : 0)
            .offset(y: settled ? 0 : 9)
            .onAppear {
                guard !settled else { return }
                withAnimation(PBW.ease(duration).delay(delay)) { shown = true }
            }
    }
}

struct PBSlide<Content: View>: View {
    enum From { case leading, trailing, top }

    var delay: Double = 0
    var duration: Double = 0.7
    var from: From = .leading
    var distance: CGFloat = 40
    @ViewBuilder var content: Content

    @Environment(\.wrappedStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var settled: Bool { shown || still || reduceMotion }

    var body: some View {
        content
            .opacity(settled ? 1 : 0)
            .offset(
                x: settled ? 0 : (from == .leading ? -distance : from == .trailing ? distance : 0),
                y: settled ? 0 : (from == .top ? -distance : 0)
            )
            .onAppear {
                guard !settled else { return }
                withAnimation(PBW.ease(duration).delay(delay)) { shown = true }
            }
    }
}

/// Ink stamps down: overshoot scale, hard settle, faint rotation.
struct PBStamp<Content: View>: View {
    var delay: Double = 0
    var duration: Double = 0.38
    var rotation: Double = 0
    @ViewBuilder var content: Content

    @Environment(\.wrappedStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var settled: Bool { shown || still || reduceMotion }

    var body: some View {
        content
            .rotationEffect(.degrees(rotation))
            .scaleEffect(settled ? 1 : 1.16)
            .opacity(settled ? 1 : 0)
            .onAppear {
                guard !settled else { return }
                withAnimation(.timingCurve(0.16, 1.0, 0.3, 1, duration: duration).delay(delay)) {
                    shown = true
                }
            }
    }
}

// MARK: - Rules and bars that draw themselves

struct PBRule: View {
    var delay: Double = 0
    var duration: Double = 0.7
    var color: Color = PBW.terra
    var height: CGFloat = 2

    @Environment(\.wrappedStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false

    private var settled: Bool { drawn || still || reduceMotion }

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: height)
            .scaleEffect(x: settled ? 1 : 0, anchor: .leading)
            .onAppear {
                guard !settled else { return }
                withAnimation(PBW.ease(duration).delay(delay)) { drawn = true }
            }
    }
}

/// A bar that grows from one edge. Used for genre blocks and every histogram.
struct PBGrow<Content: View>: View {
    var delay: Double = 0
    var duration: Double = 0.9
    var vertical: Bool = false
    @ViewBuilder var content: Content

    @Environment(\.wrappedStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    private var settled: Bool { grown || still || reduceMotion }

    var body: some View {
        content
            .scaleEffect(
                x: vertical ? 1 : (settled ? 1 : 0),
                y: vertical ? (settled ? 1 : 0) : 1,
                anchor: vertical ? .bottom : .leading
            )
            .onAppear {
                guard !settled else { return }
                withAnimation(PBW.ease(duration).delay(delay)) { grown = true }
            }
    }
}

// MARK: - Counting number — the press running off copies

struct PBCount: View {
    let value: Int
    var delay: Double = 0
    var duration: Double = 1.4
    var font: Font = PBW.poster(92)
    var color: Color = PBW.amber

    @Environment(\.wrappedStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        Text(shown.formatted(.number))
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .onAppear { run() }
    }

    private func run() {
        guard !still, !reduceMotion else {
            shown = value
            return
        }
        shown = 0
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            let steps = max(1, Int(duration / 0.04))
            for step in 1...steps {
                let p = Double(step) / Double(steps)
                // Cubic ease-out, so the number lands rather than stopping dead.
                shown = Int((Double(value) * (1 - pow(1 - p, 3))).rounded())
                try? await Task.sleep(for: .seconds(0.04))
            }
            shown = value
        }
    }
}

// MARK: - Small shared pieces

/// The running head on every page: mono, uppercase, wide tracking.
struct PBKicker: View {
    let text: String
    var color: Color = PBW.muted
    var delay: Double = 0

    var body: some View {
        PBFade(delay: delay, duration: 0.52) {
            Text(text.uppercased())
                .font(PBW.mono(10.5))
                .tracking(1.9)
                .foregroundStyle(color)
        }
    }
}

/// A book as printed matter: spine, board, no artwork.
struct PBBookBlock: View {
    let title: String
    var author: String = ""
    var spine: Color
    var accent: Color
    var width: CGFloat = 96
    var delay: Double = 0
    var rotation: Double = 0

    var body: some View {
        PBStamp(delay: delay, rotation: rotation) {
            ZStack(alignment: .topLeading) {
                spine
                LinearGradient(
                    colors: [.white.opacity(0.14), .clear],
                    startPoint: .topLeading, endPoint: .init(x: 0.42, y: 0.42)
                )
                Rectangle()
                    .fill(.black.opacity(0.22))
                    .frame(width: 1.5)
                    .offset(x: width * 0.055)

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(PBW.display(width * 0.125))
                        .foregroundStyle(accent)
                        .lineLimit(4)
                    Spacer(minLength: 6)
                    if !author.isEmpty {
                        Text(author.uppercased())
                            .font(PBW.mono(width * 0.072))
                            .tracking(0.5)
                            .foregroundStyle(accent.opacity(0.72))
                            .lineLimit(2)
                    }
                }
                .padding(width * 0.1)
                .padding(.leading, width * 0.05)
            }
            .frame(width: width, height: width * 1.52)
            .clipped()
            .shadow(color: .black.opacity(0.34), radius: 13, y: 10)
        }
    }
}

/// Every chapter sits on this: full-bleed colour, the design's page margins.
struct WrappedScreen<Content: View>: View {
    var background: Color = PBW.ink
    var foreground: Color = PBW.cream
    var topPadding: CGFloat = 76
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, topPadding)
            .padding(.horizontal, 30)
            .padding(.bottom, 112)
            .foregroundStyle(foreground)
        }
        .clipped()
    }
}

// MARK: - Colour assignment
//
// The backend sends no colours — spines and genre blocks are presentation, so
// the palette lives here and is assigned by position, which keeps a given
// chapter stable between launches.

enum PBWPalette {
    static let spines: [Color] = [
        Color(hex: "8c4a3a"), Color(hex: "5a6b4a"), Color(hex: "c9b48a"),
        Color(hex: "a85d6b"), Color(hex: "3d4a5c"), Color(hex: "7a5c8a"),
    ]
    static let spineAccents: [Color] = [
        Color(hex: "e8b04b"), Color(hex: "d9c77b"), Color(hex: "3a3a3a"),
        Color(hex: "f5ede0"), Color(hex: "d97757"), Color(hex: "efe6f2"),
    ]
    static let genres: [Color] = [PBW.cream, PBW.ink, PBW.amber, PBW.brown, PBW.terraDeep]

    static func spine(_ i: Int) -> Color { spines[i % spines.count] }
    static func spineAccent(_ i: Int) -> Color { spineAccents[i % spineAccents.count] }
    static func genre(_ i: Int) -> Color { genres[i % genres.count] }
}
