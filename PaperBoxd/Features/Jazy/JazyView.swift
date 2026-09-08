import Combine
import SwiftUI

/// Ask Jazy — the merged vibe-search + Scan & Know entry, as a shelf.
///
/// The feature runs the same four beats the Scan flow already runs, so the two
/// halves read as one thing rather than two design systems behind one bar:
///
///   01 raw      Shelf label  — write a feeling on a label, hard ink frames
///   02 machine  Pulling      — the shelf runs past, log, marquee
///   03 hinge    The pull     — one spine turns face-out, borders thin
///   04 calm     The match    — whitespace, hairlines, serif  (JazyResultsDeck)
///
/// One kit: `SK`, which is the app's own light palette. There is no `JZ`.
enum JZ {
    /// The five phrases behind the tabs clipped to the shelf label.
    /// ponytail: four fit the card edge at 390pt; the fifth lives here for the
    /// day someone makes the row scroll.
    static let tabs = ["cosy", "wreck me", "found family", "gothic"]
}

struct JazyView: View {
    let user: User

    @Environment(\.dismiss) private var dismiss
    @AppStorage("pb_scans_remaining") private var scansRemaining: Int = 7

    @State private var query = ""
    @FocusState private var focused: Bool
    @State private var showScan = false
    @State private var matches: [VibeMatch] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showResults = false
    /// Bookshelf + TBR size, loaded once per open. Nil = unknown, and unknown
    /// always lets the scan through.
    @State private var shelfSize: Int?
    @State private var showTasteGate = false

    private var hasText: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Not thinking-theatre: the shelf has to be on screen long enough to read
    /// as a shelf. Under this it flashes and looks like a glitch.
    private static let minPullDisplay: TimeInterval = 0.8

    var body: some View {
        ZStack {
            SK.bg.ignoresSafeArea()

            if showResults {
                JazyResultsDeck(query: query, matches: matches, user: user) {
                    withAnimation(.easeInOut(duration: 0.4)) { showResults = false }
                }
                .transition(.opacity)
            } else if isSearching {
                JazyPullingView(query: query)
                    .transition(.opacity)
            } else {
                entryLayer
                    .transition(.opacity)
            }
        }
        .overlay {
            if showTasteGate {
                JazyTasteGateSheet(shelfSize: shelfSize ?? 0) {
                    withAnimation(.easeInOut(duration: 0.2)) { showTasteGate = false }
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: $showScan) { ScanFlowView() }
        // Loaded up front so tapping the camera never waits on the network.
        .task { shelfSize = await JazyTaste.shelfSize(username: user.username) }
    }

    /// Scan & Know scores a book against what you already read, so it needs a
    /// shelf to score against. Under `JazyTaste.minimumShelf` the camera asks
    /// for a few books first. Unknown shelf size (offline, request failed)
    /// always lets the scan through — a hiccup must not remove a feature.
    private func openScan() {
        if let shelfSize, shelfSize < JazyTaste.minimumShelf {
            withAnimation(.easeInOut(duration: 0.2)) { showTasteGate = true }
        } else {
            showScan = true
        }
    }

    // MARK: - 01 · Shelf label

    private var entryLayer: some View {
        ZStack(alignment: .bottom) {
            // The wall at rest: context, not the reading surface.
            JazyShelfWall(running: false)
                .frame(height: 470)
                .opacity(0.30)
                .saturation(0.55)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Rectangle().fill(SK.ink).frame(height: 2)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                tabRow
                    .padding(.horizontal, 20)
                    .padding(.top, focused ? 18 : 34)

                shelfLabel
                    .padding(.horizontal, 20)

                actions
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                if let errorMessage {
                    Text(errorMessage)
                        .font(PB.mono(10.5))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(SK.accent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                }

                Spacer(minLength: 0)

                HStack {
                    MonoLabel(text: "\(scansRemaining) free scans left", size: 9.5, tracking: 1.8, color: SK.sub)
                    Spacer()
                    MonoLabel(text: "01 / label", size: 9.5, tracking: 1.8, color: SK.faint)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: focused)
    }

    private var header: some View {
        HStack {
            MonoLabel(text: "Ask Jazy", size: 10, tracking: 2.4, color: SK.ink, weight: .semibold)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SK.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(BrutalButtonStyle(fill: SK.panel, shadowColor: SK.ink, border: SK.ink,
                                           borderWidth: 2, offset: 3))
            .accessibilityLabel("Close Ask Jazy")
        }
    }

    /// The old suggestion chips, re-read as index-card dividers clipped to the
    /// top edge of the label. Same job, none of the chat-assistant reading.
    private var tabRow: some View {
        HStack(spacing: 6) {
            ForEach(JZ.tabs, id: \.self) { tab in
                Button {
                    let trimmed = query.trimmingCharacters(in: .whitespaces)
                    query = trimmed.isEmpty ? tab : trimmed + " " + tab
                    focused = true
                } label: {
                    MonoLabel(text: tab, size: 9.5, tracking: 1.2, color: SK.ink)
                        .padding(.horizontal, 10)
                        // The bottom 14pt tuck behind the label card, so the tap
                        // target stays 44 while only the tab reads as visible.
                        .frame(height: 44, alignment: .top)
                        .padding(.top, 8)
                        .background(Color(hex: 0xE9E2D1))
                        .overlay(Rectangle().strokeBorder(SK.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 4)
        .padding(.bottom, -14)
    }

    private var shelfLabel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                MonoLabel(text: "Shelf label", size: 9.5, tracking: 2.2, color: SK.faint)
                Spacer()
                PipFace(thinking: hasText)
                    .frame(width: 30, height: 32)
                    .offset(x: 2, y: -4)
            }

            Text("What shelf are you\nlooking for?")
                .font(PB.serif(25, .semibold))
                .foregroundStyle(SK.ink)
                .lineSpacing(2)
                .padding(.top, 8)

            HStack(spacing: 2) {
                ZStack(alignment: .leading) {
                    if !hasText {
                        Text("a cosy autumn mystery…")
                            .font(PB.serifItalic(16))
                            .foregroundStyle(SK.faint)
                            .lineLimit(1)
                    }
                    TextField("", text: $query)
                        .focused($focused)
                        .font(PB.serifItalic(16))
                        .foregroundStyle(SK.ink)
                        .tint(SK.accent)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit(submit)
                }
                .frame(height: 24)
            }
            .padding(.top, 18)
            .padding(.bottom, 9)
            .overlay(alignment: .bottom) { Rectangle().fill(SK.ink).frame(height: 2) }

            MonoLabel(text: "Write a feeling, not a title", size: 9, tracking: 1.6, color: SK.faint)
                .padding(.top, 9)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SK.panel)
        .overlay(Rectangle().strokeBorder(SK.ink, lineWidth: 2))
        .background(Rectangle().fill(SK.ink).offset(x: 4, y: 4))
        .padding(.trailing, 4)
        .padding(.bottom, 4)
    }

    /// Vibe search and Scan are siblings — same frame, same height, same weight.
    /// The camera no longer hides behind a soft glyph at the side of a pill.
    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: submit) {
                HStack(spacing: 8) {
                    MonoLabel(text: "Pull the shelf", size: 12.5, tracking: 1.4,
                              color: SK.panel, weight: .semibold)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(SK.panel)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(BrutalButtonStyle(fill: SK.ink, shadowColor: SK.ink.opacity(0.78),
                                           border: SK.ink, borderWidth: 2, offset: 4))
            .disabled(!hasText || isSearching)
            .opacity(hasText ? 1 : 0.45)

            Button(action: openScan) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(SK.ink)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(BrutalButtonStyle(fill: SK.panel, shadowColor: SK.ink,
                                           border: SK.ink, borderWidth: 2, offset: 4))
            .accessibilityLabel("Scan a cover")
        }
        .padding(.trailing, 4)
        .padding(.bottom, 4)
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
                await holdPullingPage(since: startedAt)
                await MainActor.run {
                    guard !items.isEmpty else {
                        withAnimation(.easeInOut(duration: 0.3)) { isSearching = false }
                        errorMessage = "Nothing on this shelf — try dropping a word"
                        return
                    }
                    matches = items
                    withAnimation(.easeInOut(duration: 0.45)) {
                        isSearching = false
                        showResults = true
                    }
                }
            } catch {
                await holdPullingPage(since: startedAt)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) { isSearching = false }
                    errorMessage = (error as? APIError)?.errorDescription ?? "Shelf jammed — try again"
                }
            }
        }
    }

    private func holdPullingPage(since startedAt: Date) async {
        let remaining = Self.minPullDisplay - Date().timeIntervalSince(startedAt)
        guard remaining > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
    }
}

// MARK: - 02 · Pulling the shelf

/// The wait, as a machine at work rather than a thinking indicator: the shelf
/// runs past under a fixed reading rule, and the log says what is actually
/// happening. No skeleton covers, no "weighing the vibe…".
private struct JazyPullingView: View {
    let query: String

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    MonoLabel(text: "Pulling the shelf", size: 10, tracking: 2.4,
                              color: SK.ink, weight: .semibold)
                    Spacer()
                    MonoLabel(text: "02 / pull", size: 9.5, tracking: 1.8, color: SK.faint)
                }
                Rectangle().fill(SK.ink).frame(height: 2).padding(.top, 14)

                HStack(spacing: 11) {
                    PaperBoxdMark()
                        .fill(SK.ink, style: FillStyle(eoFill: true))
                        .frame(width: 25, height: 18)
                    Text("“\(query)”")
                        .font(PB.serifItalic(15))
                        .foregroundStyle(SK.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(SK.panel)
                .overlay(Rectangle().strokeBorder(SK.ink, lineWidth: 2))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            JazyShelfWall(running: true)
                .frame(height: 246)
                .padding(.top, 26)

            log.padding(.horizontal, 20).padding(.top, 22)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(JazyShelfWall.flaggedCount)")
                    .font(PB.mono(30, .medium))
                    .foregroundStyle(SK.ink)
                MonoLabel(text: "spines flagged", size: 9.5, tracking: 2, color: SK.sub)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer(minLength: 0)

            ScanMarquee(text: "Pulling —")
                .padding(.bottom, 8)
        }
    }

    private var log: some View {
        VStack(spacing: 0) {
            HStack {
                MonoLabel(text: "Log", size: 9, tracking: 1.8, color: SK.sub)
                Spacer()
                MonoLabel(text: "live", size: 9, tracking: 1.8, color: SK.faint)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .overlay(alignment: .bottom) { Rectangle().fill(SK.ink).frame(height: 2) }

            VStack(alignment: .leading, spacing: 4) {
                logLine("> embedding query", color: SK.faint)
                logLine("> reading the shelves", color: SK.sub)
                logLine("> scoring pace · tone · length", color: SK.ink, caret: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.top, 11)
            .padding(.bottom, 13)
        }
        .background(SK.panel)
        .overlay(Rectangle().strokeBorder(SK.ink, lineWidth: 2))
    }

    private func logLine(_ text: String, color: Color, caret: Bool = false) -> some View {
        HStack(spacing: 3) {
            Text(text).font(PB.mono(11)).foregroundStyle(color)
            if caret { Rectangle().fill(SK.ink).frame(width: 7, height: 12) }
        }
    }
}

// MARK: - The shelf

/// Two ranks of spines running at different speeds. The speed difference is the
/// whole effect — it reads as a deep shelf being gone through, not a strip
/// sliding sideways. Nothing here loads: it is geometry, so the wait costs
/// nothing and cannot itself be slow.
struct JazyShelfWall: View {
    /// False on the entry screen — the same wall, parked.
    var running: Bool = true

    private struct Spine {
        let width: CGFloat, height: CGFloat, color: Color, flagged: Bool
    }

    private struct Rank {
        let spines: [Spine]
        /// Points per second. Fast enough to read as a lot of books going by.
        let speed: CGFloat
        let opacity: Double
        /// How far above the shelf board this rank stands.
        let lift: CGFloat
        let border: CGFloat

        var cellWidth: CGFloat { spines.reduce(0) { $0 + $1.width } }
    }

    static let flaggedCount = 5

    /// Deterministic — the shelf is the same shelf every time it opens.
    private static func rank(count: Int,
                             widths: ClosedRange<CGFloat>,
                             heights: ClosedRange<CGFloat>,
                             flagEvery: Int?,
                             seed: UInt64) -> [Spine] {
        var state = seed
        func next(_ range: ClosedRange<CGFloat>) -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let unit = CGFloat((state >> 33) % 1000) / 1000
            return (range.lowerBound + unit * (range.upperBound - range.lowerBound)).rounded()
        }
        return (0..<count).map { i in
            Spine(width: next(widths),
                  height: next(heights),
                  color: SK.spines[i % SK.spines.count],
                  flagged: flagEvery.map { i % $0 == 1 } ?? false)
        }
    }

    private static let near = Rank(
        spines: rank(count: 26, widths: 14...36, heights: 150...220, flagEvery: 5, seed: 20260905),
        speed: 150, opacity: 1, lift: 0, border: 2
    )
    private static let far = Rank(
        spines: rank(count: 30, widths: 10...22, heights: 92...138, flagEvery: nil, seed: 77),
        speed: 46, opacity: 0.28, lift: 30, border: 1.5
    )

    var body: some View {
        TimelineView(.animation(paused: !running)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                draw(Self.far, in: ctx, size: size, t: t)
                draw(Self.near, in: ctx, size: size, t: t)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(SK.ink).frame(height: 3).padding(.bottom, 13)
            }
            .overlay(alignment: .top) { if running { readingRule } }
            .overlay(alignment: .leading) { edgeFade(.leading) }
            .overlay(alignment: .trailing) { edgeFade(.trailing) }
            .clipped()
        }
    }

    /// The shelf moves; the scanner does not.
    private var readingRule: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle().fill(SK.accent)
                .frame(height: 3)
                .padding(.top, 104)
            MonoLabel(text: "reading", size: 9, tracking: 1.6, color: SK.panel)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(SK.accent)
                .padding(.top, 82)
        }
    }

    private func edgeFade(_ edge: HorizontalAlignment) -> some View {
        LinearGradient(colors: [SK.bg, SK.bg.opacity(0)],
                       startPoint: edge == .leading ? .leading : .trailing,
                       endPoint: edge == .leading ? .trailing : .leading)
            .frame(width: 40)
    }

    private func draw(_ rank: Rank, in ctx: GraphicsContext, size: CGSize, t: TimeInterval) {
        let base = size.height - 13 - rank.lift
        // Rank opacity rides on the colours rather than the shared context, so
        // the near rank can't inherit the far rank's fade.
        let a = rank.opacity
        // One cell scrolls fully out, then repeats — so the loop has no seam.
        var x = -CGFloat((t * Double(rank.speed)).truncatingRemainder(dividingBy: Double(rank.cellWidth)))
        while x < size.width {
            for spine in rank.spines {
                defer { x += spine.width }
                guard x + spine.width > 0, x < size.width else { continue }

                let rect = CGRect(x: x, y: base - spine.height, width: spine.width, height: spine.height)
                ctx.fill(Path(rect), with: .color(spine.color.opacity(a)))
                ctx.stroke(Path(rect), with: .color(SK.ink.opacity(a)), lineWidth: rank.border)

                // Head and tail bands — what makes a coloured bar read as a spine.
                for inset in [CGFloat(13), spine.height - 17] {
                    ctx.fill(Path(CGRect(x: rect.minX, y: rect.minY + inset,
                                         width: rect.width, height: 1)),
                             with: .color(.white.opacity(0.24 * a)))
                }

                if spine.flagged {
                    ctx.stroke(Path(rect.insetBy(dx: 1.5, dy: 1.5)),
                               with: .color(SK.accent.opacity(a)), lineWidth: 3)
                    ctx.fill(Path(CGRect(x: rect.midX - 3.5, y: rect.minY - 9, width: 7, height: 7)),
                             with: .color(SK.accent.opacity(a)))
                }
            }
        }
    }
}

// MARK: - The mark

/// The PaperBoxd mark, traced from `public/paperboxd.svg` (viewBox 276.08×199.6).
struct PaperBoxdMark: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width / 276.08, rect.height / 199.6)
        let dx = (rect.width - 276.08 * s) / 2, dy = (rect.height - 199.6 * s) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: dx + x * s, y: dy + y * s) }

        var path = Path()
        // Outer body: the two overlapping rounded boxes, as one silhouette.
        path.move(to: p(200.95, 79.8))
        path.addCurve(to: p(204.01, 67.11), control1: p(202.97, 75.7), control2: p(204.01, 71.46))
        path.addCurve(to: p(167.39, 39.17), control1: p(204.01, 50.76), control2: p(192.38, 39.17))
        path.addLine(to: p(111.71, 39.17))
        path.addCurve(to: p(50.46, 88.74), control1: p(66.48, 39.17), control2: p(50.46, 59.31))
        path.addCurve(to: p(110.62, 137.84), control1: p(50.46, 118.17), control2: p(66.23, 137.52))
        path.addLine(to: p(110.62, 142.58))
        path.addCurve(to: p(127.91, 159.87), control1: p(110.62, 153.82), control2: p(116.67, 159.87))
        path.addLine(to: p(189.72, 159.87))
        path.addCurve(to: p(239.72, 118.19), control1: p(224.07, 159.87), control2: p(239.72, 143.01))
        path.addCurve(to: p(200.95, 79.8), control1: p(239.72, 96.48), control2: p(223.38, 81.23))
        path.closeSubpath()

        // The two punched circles. They only read as holes under an even-odd
        // fill — draw this with `.fill(colour, style: FillStyle(eoFill: true))`.
        func hole(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
            let origin = p(cx - rx, cy - ry)
            path.addEllipse(in: CGRect(origin: origin,
                                       size: CGSize(width: rx * 2 * s, height: ry * 2 * s)))
        }
        hole(93.73, 95.67, 15.41, 14.63)
        hole(196.79, 132.77, 14.05, 13.33)
        return path
    }
}
