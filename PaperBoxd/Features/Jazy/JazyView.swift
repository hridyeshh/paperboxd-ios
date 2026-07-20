import Combine
import SwiftUI

/// Ask Jazy — the merged vibe-search + Scan & Know entry.
///
/// A quiet page: vibe phrases drift up through the background behind hand-drawn
/// doodles; one hairline bar with the camera parked at its side. Typing slides the
/// camera away and a send arrow takes its place. Submitting raises the results deck
/// (one match card at a time). Tapping the camera raises the untouched brutalist
/// Scan & Know flow.
///
/// Design source: `Paperboxd design elements/ask-jazy/v3.jsx`.
enum JZ {
    static let bg     = Color(hex: 0xFBFAF7)
    static let card   = Color.white
    static let ink    = Color(hex: 0x37352F)
    static let sub    = Color(hex: 0x9B9891)
    static let faint  = Color(hex: 0xC4C1B8)
    static let accent = Color(hex: 0xB85C38)
    static let line   = Color(hex: 0x37352F).opacity(0.14)

    static let prompts = [
        "a cosy autumn mystery…",
        "something that will wreck me…",
        "found family in space…",
        "smart, but under 200 pages…",
        "like a warm hug…",
    ]
    static let chips = ["cosy", "will wreck me", "found family", "slow burn", "gothic"]
}

struct JazyView: View {
    let user: User

    @Environment(\.dismiss) private var dismiss
    @AppStorage("pb_scans_remaining") private var scansRemaining: Int = 7

    @State private var query = ""
    @FocusState private var focused: Bool
    @State private var promptIndex = 0
    @State private var showScan = false
    /// Pip startles for a beat before the scanner rises (design: `camTap`).
    @State private var camTapped = false
    @State private var matches: [VibeMatch] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showResults = false

    private let promptTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private var hasText: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    private var dimmed: Bool { focused || showResults || isSearching }

    /// The searching page holds for at least this long even when the backend
    /// answers sooner — a 300ms flash of book covers reads as a glitch.
    private static let minSearchDisplay: TimeInterval = 2.0

    var body: some View {
        ZStack {
            JZ.bg.ignoresSafeArea()
            JazyDriftField().opacity(dimmed ? 0.35 : 1)
            JazyDoodleField().opacity(dimmed ? 0.3 : 1)

            entryLayer
                .opacity(showResults || isSearching ? 0 : 1)
                .offset(y: showResults ? -36 : 0)

            if isSearching {
                JazySearchingView(query: query)
                    .transition(.opacity)
            }

            if showResults {
                JazyResultsDeck(query: query, matches: matches, user: user) {
                    withAnimation(.easeInOut(duration: 0.45)) { showResults = false }
                }
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut(duration: 0.45), value: dimmed)
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: $showScan) { ScanFlowView() }
        .onReceive(promptTimer) { _ in
            guard !hasText else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                promptIndex = (promptIndex + 1) % JZ.prompts.count
            }
        }
    }

    // MARK: - Entry layer

    private var entryLayer: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(JZ.ink)
                        .frame(width: 34, height: 34)
                        .background(JZ.card)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(JZ.line))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)

            // Both spacers have to be greedy for the block to sit centred. A
            // bare Spacer below a `maxHeight: .infinity` one loses the split,
            // and the whole page slides to the bottom of the screen.
            Spacer(minLength: 0)
                .frame(maxHeight: focused ? 60 : .infinity)

            VStack(spacing: 6) {
                PipFace(thinking: focused && hasText, excited: camTapped)
                    .scaleEffect(1.4)
                    .frame(width: 62, height: 62)

                Text(focused && hasText ? "Jazy is reading…" : "What are you in the mood for?")
                    .font(PB.serif(24, .semibold))
                    .foregroundStyle(JZ.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                if !focused {
                    Text("Describe a feeling — or scan a cover in the store.")
                        .font(.system(size: 13))
                        .foregroundStyle(JZ.sub)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)

            searchBar
                .padding(.horizontal, 24)
                .padding(.top, 24)

            chipRow
                .padding(.horizontal, 24)
                .padding(.top, 16)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12.5))
                    .foregroundStyle(JZ.accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
            }

            Spacer(minLength: 0)
                .frame(maxHeight: .infinity)

            Text("\(scansRemaining) free scans left")
                .font(.system(size: 11.5))
                .foregroundStyle(JZ.faint)
                .padding(.bottom, 26)
        }
        .padding(.top, 18)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ZStack(alignment: .leading) {
                    if !hasText {
                        Text(JZ.prompts[promptIndex])
                            .font(.system(size: 15))
                            .foregroundStyle(JZ.faint)
                            .lineLimit(1)
                            .id(promptIndex)
                            .transition(.opacity)
                    }
                    TextField("", text: $query)
                        .focused($focused)
                        .font(.system(size: 15))
                        .foregroundStyle(JZ.ink)
                        .tint(JZ.accent)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit(submit)
                }
                .frame(height: 24)

                Button(action: submit) {
                    Image(systemName: isSearching ? "ellipsis" : "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(JZ.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(isSearching)
                .frame(width: hasText ? 32 : 0)
                .opacity(hasText ? 1 : 0)
                .clipped()
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .padding(.vertical, 11)
            .background(JZ.card)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(focused ? Color(hex: 0x37352F).opacity(0.28) : JZ.line)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(focused ? 0.08 : 0.04), radius: focused ? 9 : 1, y: focused ? 4 : 1)

            // The camera — slides away the moment typing starts.
            Button {
                camTapped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    camTapped = false
                    showScan = true
                }
            } label: {
                Image(systemName: "camera")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(JZ.ink)
                    .frame(width: 48, height: 48)
                    .background(JZ.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(JZ.line))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scan a cover")
            .frame(width: hasText ? 0 : 48)
            .opacity(hasText ? 0 : 1)
            .clipped()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: hasText)
    }

    private var chipRow: some View {
        // ponytail: fixed two-row layout — the chip set is a constant five.
        VStack(spacing: 8) {
            HStack(spacing: 8) { ForEach(JZ.chips.prefix(3), id: \.self, content: chip) }
            HStack(spacing: 8) { ForEach(JZ.chips.dropFirst(3), id: \.self, content: chip) }
        }
        .opacity(showResults ? 0 : 1)
    }

    private func chip(_ text: String) -> some View {
        Button {
            query = query.isEmpty ? text : query.trimmingCharacters(in: .whitespaces) + " " + text
            focused = true
        } label: {
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(JZ.sub)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(JZ.card)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(JZ.line))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search

    private func submit() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isSearching else { return }
        focused = false
        errorMessage = nil
        withAnimation(.easeInOut(duration: 0.3)) { isSearching = true }
        let startedAt = Date()
        Task {
            do {
                let items = try await JazyService.vibeSearch(q)
                await holdSearchingPage(since: startedAt)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) { isSearching = false }
                    guard !items.isEmpty else {
                        errorMessage = "Jazy couldn't find anything for that. Try another vibe."
                        return
                    }
                    matches = items
                    withAnimation(.easeInOut(duration: 0.45)) { showResults = true }
                }
            } catch {
                await holdSearchingPage(since: startedAt)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) { isSearching = false }
                    errorMessage = (error as? APIError)?.errorDescription
                        ?? "Jazy is unavailable right now. Try again."
                }
            }
        }
    }

    private func holdSearchingPage(since startedAt: Date) async {
        let remaining = Self.minSearchDisplay - Date().timeIntervalSince(startedAt)
        guard remaining > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
    }
}

// MARK: - Searching

/// The wait while the backend embeds the query and Claude writes the reasons —
/// a couple of seconds, so it gets a page rather than a spinner. Covers riffle
/// off the top of a stack while the caption walks through what Jazy is doing.
private struct JazySearchingView: View {
    let query: String

    /// One cover's full trip from the back of the stack to off-screen.
    private static let tripDuration = 3.2
    private static let coverCount = 5

    private static let captions = [
        "Reading the shelves…",
        "Weighing the vibe…",
        "Writing your reasons…",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<Self.coverCount, id: \.self) { i in
                        cover(at: tripProgress(now: now, index: i))
                    }
                }
                .frame(width: 200, height: 190)
                .overlay(alignment: .bottom) { caption(now: now) }
            }

            Text("“\(query)”")
                .font(PB.serifItalic(15))
                .foregroundStyle(JZ.sub)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 40)
                .padding(.top, 34)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 0 = just joined the back of the stack, 1 = gone. Staggered per cover so
    /// the five are evenly spaced around the loop.
    private func tripProgress(now: TimeInterval, index: Int) -> Double {
        let offset = Double(index) / Double(Self.coverCount)
        return ((now / Self.tripDuration) + offset).truncatingRemainder(dividingBy: 1)
    }

    /// The last quarter of the trip is the flick off to the left; before that
    /// the cover is climbing the stack.
    private func cover(at t: Double) -> some View {
        let leaving = max(0, (t - 0.75) / 0.25)
        let climb = min(t, 0.75) / 0.75          // 0 at the back, 1 at the front

        return JazyLoadingCover()
            .frame(width: 96, height: 144)
            .scaleEffect(0.9 + 0.1 * climb)
            .rotationEffect(.degrees(-5 + 5 * climb - 24 * leaving))
            .offset(x: -190 * leaving, y: 22 * (1 - climb))
            .opacity(min(climb * 4, 1) * (1 - leaving))
            .zIndex(t)
    }

    private func caption(now: TimeInterval) -> some View {
        // One caption per third of the loop, so the words change with the covers.
        let slot = Int(now / Self.tripDuration * 3) % Self.captions.count
        return Text(Self.captions[slot])
            .font(.system(size: 13))
            .foregroundStyle(JZ.sub)
            .id(slot)
            .transition(.opacity)
            .offset(y: 34)
    }
}

/// A blank cover in the Ask Jazy palette — ruled lines standing in for a title.
private struct JazyLoadingCover: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(JZ.card)
            .overlay(alignment: .leading) {
                Rectangle().fill(JZ.accent.opacity(0.5)).frame(width: 5)
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 7) {
                    Capsule().fill(JZ.ink.opacity(0.16)).frame(width: 46, height: 6)
                    Capsule().fill(JZ.ink.opacity(0.16)).frame(width: 32, height: 6)
                    Capsule().fill(JZ.ink.opacity(0.09)).frame(width: 40, height: 5)
                }
                .padding(.leading, 18)
                .padding(.top, 22)
            }
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(JZ.line))
            .shadow(color: .black.opacity(0.12), radius: 14, y: 10)
    }
}

// MARK: - Background: drifting vibe phrases

private struct JazyDriftField: View {
    private struct Phrase {
        let text: String, x: CGFloat, y: CGFloat, size: CGFloat, duration: Double, delay: Double
    }

    private static let phrases: [Phrase] = [
        .init(text: "a gothic house", x: 0.06, y: 0.16, size: 21, duration: 17, delay: 0),
        .init(text: "slow burn, high stakes", x: 0.52, y: 0.11, size: 17, duration: 14, delay: 3.5),
        .init(text: "like a warm hug", x: 0.14, y: 0.38, size: 24, duration: 19, delay: 7),
        .init(text: "an unreliable narrator", x: 0.44, y: 0.52, size: 18, duration: 15, delay: 1.8),
        .init(text: "found family", x: 0.62, y: 0.31, size: 20, duration: 16, delay: 9.5),
        .init(text: "will wreck me", x: 0.10, y: 0.62, size: 19, duration: 18, delay: 5.2),
        .init(text: "under 200 pages", x: 0.48, y: 0.72, size: 17, duration: 14, delay: 11),
        .init(text: "cosy autumn mystery", x: 0.18, y: 0.84, size: 22, duration: 20, delay: 2.6),
    ]

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                ForEach(Array(Self.phrases.enumerated()), id: \.offset) { _, p in
                    // 0…1 progress through this phrase's own loop.
                    let t = ((now + p.delay).truncatingRemainder(dividingBy: p.duration)) / p.duration
                    Text(p.text)
                        .font(PB.serifItalic(p.size))
                        .foregroundStyle(JZ.ink.opacity(0.09))
                        .fixedSize()
                        .position(x: geo.size.width * p.x, y: geo.size.height * p.y)
                        .offset(y: 30 - 68 * t)
                        .opacity(t < 0.2 ? t / 0.2 : (t > 0.68 ? (1 - t) / 0.32 : 1))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Background: hand-drawn doodles

/// ponytail: static ink doodles with a slow bob — the design's ~5fps line-boil
/// (re-jittering every path every frame) isn't worth the redraw cost on device.
private struct JazyDoodleField: View {
    private struct Doodle {
        let kind: JazyDoodle.Kind, x: CGFloat, y: CGFloat, scale: CGFloat, rotation: Double, duration: Double
    }

    private static let doodles: [Doodle] = [
        .init(kind: .openBook, x: 0.06, y: 0.09, scale: 1.15, rotation: -9,  duration: 8),
        .init(kind: .sparkle,  x: 0.78, y: 0.13, scale: 0.7,  rotation: 12,  duration: 6),
        .init(kind: .moon,     x: 0.86, y: 0.30, scale: 0.85, rotation: 14,  duration: 9),
        .init(kind: .glasses,  x: 0.10, y: 0.28, scale: 0.95, rotation: 6,   duration: 7),
        .init(kind: .squiggle, x: 0.40, y: 0.21, scale: 0.8,  rotation: -4,  duration: 8),
        .init(kind: .cup,      x: 0.82, y: 0.56, scale: 1.0,  rotation: -7,  duration: 7),
        .init(kind: .heart,    x: 0.05, y: 0.52, scale: 0.75, rotation: -12, duration: 6),
        .init(kind: .bookmark, x: 0.30, y: 0.66, scale: 0.85, rotation: 8,   duration: 9),
        .init(kind: .asterisk, x: 0.68, y: 0.74, scale: 0.65, rotation: 0,   duration: 6),
        .init(kind: .openBook, x: 0.58, y: 0.88, scale: 0.9,  rotation: 7,   duration: 8),
        .init(kind: .sparkle,  x: 0.12, y: 0.80, scale: 0.6,  rotation: -15, duration: 7),
    ]

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 12)) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                ForEach(Array(Self.doodles.enumerated()), id: \.offset) { _, d in
                    let phase = (now.truncatingRemainder(dividingBy: d.duration)) / d.duration
                    JazyDoodle(kind: d.kind)
                        .stroke(JZ.ink.opacity(0.11),
                                style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                        .frame(width: 54 * d.scale, height: 54 * d.scale)
                        .rotationEffect(.degrees(d.rotation))
                        .position(x: geo.size.width * d.x, y: geo.size.height * d.y)
                        .offset(y: -7 * sin(phase * 2 * .pi))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// The doodle glyph set, drawn on the design's 48×48 canvas and scaled to fit.
private struct JazyDoodle: Shape {
    enum Kind { case openBook, sparkle, asterisk, moon, cup, heart, squiggle, glasses, bookmark }
    let kind: Kind

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 48
        var p = Path()

        func line(_ pts: [(CGFloat, CGFloat)], close: Bool = false) {
            guard let first = pts.first else { return }
            p.move(to: CGPoint(x: first.0 * s, y: first.1 * s))
            for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0 * s, y: pt.1 * s)) }
            if close { p.closeSubpath() }
        }
        // Quadratic smoothing through the midpoints — the design's a3Path().
        func curve(_ pts: [(CGFloat, CGFloat)]) {
            guard pts.count > 2 else { return line(pts) }
            p.move(to: CGPoint(x: pts[0].0 * s, y: pts[0].1 * s))
            for i in 1..<(pts.count - 1) {
                let c = CGPoint(x: pts[i].0 * s, y: pts[i].1 * s)
                let mid = CGPoint(x: (pts[i].0 + pts[i + 1].0) / 2 * s,
                                  y: (pts[i].1 + pts[i + 1].1) / 2 * s)
                p.addQuadCurve(to: mid, control: c)
            }
            let last = pts[pts.count - 1]
            p.addLine(to: CGPoint(x: last.0 * s, y: last.1 * s))
        }
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
            p.addEllipse(in: CGRect(x: (cx - r) * s, y: (cy - r) * s, width: r * 2 * s, height: r * 2 * s))
        }

        switch kind {
        case .openBook:
            curve([(4, 16), (13, 11), (23, 14)])
            curve([(23, 14), (33, 11), (42, 16)])
            curve([(4, 16), (4, 34), (13, 30), (23, 33)])
            curve([(42, 16), (42, 34), (33, 30), (23, 33)])
            line([(23, 14), (23, 33)])
        case .sparkle:
            line([(24, 10), (24, 38)])
            line([(10, 24), (38, 24)])
        case .asterisk:
            line([(24, 12), (24, 36)])
            line([(15, 18), (33, 32)])
            line([(33, 18), (15, 32)])
        case .moon:
            curve([(30, 8), (20, 12), (16, 24), (20, 36), (30, 40), (24, 33), (22, 24), (24, 15), (30, 8)])
        case .cup:
            curve([(13, 18), (15, 36), (31, 36), (33, 18)])
            line([(11, 18), (35, 18)])
            line([(20, 13), (23, 8)])
            line([(27, 13), (30, 8)])
        case .heart:
            curve([(24, 38), (10, 24), (12, 14), (20, 12), (24, 18), (28, 12), (36, 14), (38, 24), (24, 38)])
        case .squiggle:
            curve([(6, 24), (14, 18), (22, 28), (30, 18), (38, 26)])
        case .glasses:
            circle(13, 26, 7)
            circle(35, 26, 7)
            curve([(20, 25), (24, 23), (28, 25)])
        case .bookmark:
            line([(18, 8), (30, 8), (30, 36), (24, 28), (18, 36)], close: true)
        }
        return p
    }
}
