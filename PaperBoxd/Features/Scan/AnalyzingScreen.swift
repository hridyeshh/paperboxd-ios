import SwiftUI
import Combine

/// 02 — Analyzing · BRUTALIST. The whole screen is a machine at work: a framed 3D
/// knowledge-graph, count-up source cells, a live terminal log, a status marquee.
/// Tap into a fullscreen game while the backend scores the scan. When the result
/// lands a "RESULTS READY" popup slides up; the game never stops on its own.
///
/// `book == nil` → still scoring. `book != nil` → done (reveal available).
struct AnalyzingScreen: View {
    let book: ScanResult?
    /// Title resolved at scan time (before the score lands), so the header shows the
    /// real book instead of a placeholder while the backend works.
    let pendingTitle: String?
    let error: String?
    /// True when `error` is the free-scan-quota 403 — shows a dedicated exhausted
    /// layout (no game, no retry) instead of the generic error view.
    var exhausted: Bool = false
    let onReveal: () -> Void
    let onRetry: () -> Void
    var onBack: () -> Void = {}
    let onClose: () -> Void

    @State private var gameOpen = false
    @State private var popupDismissed = false
    @State private var liveIdx = 0

    private var done: Bool { book != nil }
    private var showPopup: Bool { done && !popupDismissed }

    private let reading = [
        "pulling r/books + r/suggestmeabook",
        "weighting reviews by reader similarity",
        "cross-referencing your rated books",
        "checking friends who shelved this",
        "scoring genre / pacing / depth for you",
    ]
    private let tick = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    /// Real source cells once the score lands; "—" placeholders while still scoring.
    private var sources: [(value: Int?, label: String)] {
        guard let book else {
            return [(nil, "READERS"), (nil, "RATINGS"), (nil, "YOUR SHELF")]
        }
        return [(book.readersCount, "READERS"),
                (book.communityRatings, "RATINGS"),
                (book.shelfCount, "YOUR SHELF")]
    }

    var body: some View {
        ZStack {
            SK.bg.ignoresSafeArea()

            if let error, exhausted {
                exhaustedView(error)
            } else if let error {
                errorView(error)
            } else {
                analysis
                if gameOpen {
                    ScanGameHost(onClose: { withAnimation { gameOpen = false } })
                        .transition(.move(edge: .bottom))
                        .zIndex(2)
                }
                if showPopup {
                    resultPopup.zIndex(3)
                }
            }
        }
        .onReceive(tick) { _ in
            if !done { withAnimation(.easeInOut(duration: 0.2)) { liveIdx = (liveIdx + 1) % reading.count } }
        }
    }

    // MARK: - Analysis page

    private var analysis: some View {
        VStack(spacing: 0) {
            statusBar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    bookRow.padding(.horizontal, 16).padding(.top, 14)
                    orbFrame.padding(.horizontal, 16).padding(.top, 16)
                    liveLine.padding(.horizontal, 16).padding(.top, 12)
                    sourceCells.padding(.horizontal, 16).padding(.top, 4)
                    terminalLog.padding(.horizontal, 16).padding(.top, 16)
                }
            }
            bottomAction
        }
    }

    private var statusBar: some View {
        HStack {
            HStack(spacing: 8) {
                BlinkDot(color: SK.accent, size: 8)
                MonoLabel(text: done ? "Analysis · Complete" : "Analyzing", size: 11, tracking: 1.6,
                          color: SK.ink, weight: .semibold)
            }
            Spacer()
            MonoLabel(text: done ? "08.4s" : "For you", size: 9.5, tracking: 1.2, color: SK.sub)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(SK.sub)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(SK.line).frame(height: 2) }
    }

    private var bookRow: some View {
        HStack(spacing: 12) {
            if let book {
                ScanCover(result: book, width: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(book.title).font(PB.serif(18, .bold)).foregroundStyle(SK.ink).lineLimit(2)
                    MonoLabel(text: book.author, size: 10, tracking: 1.2, color: SK.sub)
                }
            } else {
                Rectangle().fill(SK.faint.opacity(0.4)).frame(width: 40, height: 60)
                    .overlay(Rectangle().strokeBorder(SK.line, lineWidth: 2))
                VStack(alignment: .leading, spacing: 4) {
                    Text(pendingTitle ?? "Scoring your scan")
                        .font(PB.serif(18, .bold)).foregroundStyle(SK.ink).lineLimit(2)
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6).tint(SK.sub)
                        MonoLabel(text: "scoring for you", size: 10, tracking: 1.2, color: SK.sub)
                    }
                }
            }
            Spacer()
        }
    }

    private var orbFrame: some View {
        VStack {
            ScanOrbView(done: done, size: 192)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(SK.panel)
        .overlay(Rectangle().strokeBorder(SK.line, lineWidth: 2))
        .overlay(CropCorners(color: SK.accent, length: 16, weight: 3))
        .overlay(alignment: .topLeading) { cornerLabel("NODES·132").padding(7) }
        .overlay(alignment: .topTrailing) { cornerLabel("GRAPH·3D").padding(7) }
        .overlay(alignment: .bottomTrailing) {
            cornerLabel(done ? "DONE" : "LIVE", color: done ? SK.accent : SK.faint).padding(7)
        }
    }

    private func cornerLabel(_ t: String, color: Color = SK.faint) -> some View {
        Text(t).font(PB.mono(8.5)).tracking(1.0).foregroundStyle(color)
    }

    private var liveLine: some View {
        HStack(spacing: 0) {
            Text("> ").font(PB.mono(11)).foregroundStyle(SK.accent)
            Text(done ? "cross-referenced — building your match" : reading[liveIdx])
                .font(PB.mono(11)).foregroundStyle(SK.ink)
            Text("_").font(PB.mono(11)).foregroundStyle(SK.accent)
            Spacer()
        }
        .frame(minHeight: 26, alignment: .leading)
    }

    private var sourceCells: some View {
        HStack(spacing: 10) {
            ForEach(sources.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    if let value = sources[i].value {
                        CountUpText(target: value, font: PB.mono(21, .semibold), color: SK.ink)
                    } else {
                        // Still scoring: roll digits so the number feels like it's
                        // being tallied, then CountUpText settles on the real value.
                        RollingNumber(font: PB.mono(21, .semibold), color: SK.faint)
                    }
                    MonoLabel(text: sources[i].label, size: 8.5, tracking: 1.4, color: SK.sub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12).padding(.horizontal, 8)
                .background(SK.panel)
                .overlay(Rectangle().strokeBorder(SK.line, lineWidth: 1.875))
                .background(SK.ink.opacity(0.5).offset(x: 3, y: 3))
            }
        }
    }

    private var terminalLog: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(reading.indices, id: \.self) { i in
                let isLive = !done && i == liveIdx
                let passed = done || i < liveIdx
                HStack(spacing: 9) {
                    Text(passed ? "✓" : isLive ? "▸" : "·")
                        .font(PB.mono(11)).foregroundStyle(passed ? SK.accent : SK.sub).frame(width: 14)
                    Text(reading[i])
                        .font(PB.mono(11, isLive ? .semibold : .regular))
                        .foregroundStyle(isLive ? SK.ink : SK.sub)
                    Spacer()
                }
                .opacity(passed || isLive ? 1 : 0.35)
            }
        }
        .padding(.bottom, 8)
    }

    private var bottomAction: some View {
        VStack(spacing: 10) {
            if done {
                BruButton(title: "See your match score", trailing: "arrow.right", action: onReveal)
            } else {
                BruButton(title: "Play a game while you wait", glyph: "▶") { withAnimation { gameOpen = true } }
            }
            MonoLabel(text: done ? "Ready · tap to reveal" : "Est ~15s · no need to wait",
                      size: 9.5, tracking: 1.2, color: SK.faint)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 26)
        .background(SK.bg)
    }

    // MARK: - Result popup

    private var resultPopup: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { withAnimation { popupDismissed = true } }
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    BlinkDot(color: SK.accent, size: 7)
                    MonoLabel(text: "Results Ready", size: 10, tracking: 1.8, color: SK.panel, weight: .semibold)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(SK.ink)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your match score is in.")
                        .font(PB.serif(25, .bold)).foregroundStyle(SK.ink).fixedSize(horizontal: false, vertical: true)
                    Text("\(book?.title ?? "Your book") read against your shelf. Your game keeps going — pick it up whenever.")
                        .font(PB.mono(11)).foregroundStyle(SK.sub).lineSpacing(2)
                    BruButton(title: "See your score", trailing: "arrow.right", action: onReveal)
                        .padding(.top, 10)
                    Button { withAnimation { popupDismissed = true } } label: {
                        MonoLabel(text: "Keep playing", size: 10.5, tracking: 1.6, color: SK.faint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .padding(18)
                .background(SK.bg)
            }
            .overlay(Rectangle().strokeBorder(SK.line, lineWidth: 2))
            .background(SK.accent.offset(x: 7, y: 7))
            .padding(.horizontal, 14)
            .padding(.bottom, 22)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Exhausted (free-scan quota used up)

    private func exhaustedView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "hourglass")
                .font(.system(size: 28)).foregroundStyle(SK.ink)
            Text(message).font(PB.serif(18)).foregroundStyle(SK.ink)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Text("You've used your free scans. More scans coming soon.")
                .font(.system(size: 13)).foregroundStyle(SK.sub)
                .multilineTextAlignment(.center)
            BruButton(title: "Back", action: onBack).padding(.horizontal, 40).padding(.top, 6)
            Button(action: onClose) {
                MonoLabel(text: "Close", size: 11, tracking: 1.4, color: SK.sub)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28)).foregroundStyle(SK.ink)
            Text(message).font(PB.serif(18)).foregroundStyle(SK.ink)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            BruButton(title: "Try again", action: onRetry).padding(.horizontal, 40)
            Button(action: onClose) {
                MonoLabel(text: "Close", size: 11, tracking: 1.4, color: SK.sub)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }
}
