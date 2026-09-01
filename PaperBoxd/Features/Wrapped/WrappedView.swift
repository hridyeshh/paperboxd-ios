import Combine
import SwiftUI

/// Monthly Wrapped — a fourteen-chapter story player. Port of the design
/// prototype's Monthly Wrapped.html; the prototype previewed the story inside
/// phone mockups, here the story *is* the screen.
struct WrappedView: View {
    @StateObject private var viewModel: WrappedViewModel
    @Environment(\.dismiss) private var dismiss

    init(month: String? = nil) {
        _viewModel = StateObject(wrappedValue: WrappedViewModel(month: month))
    }

    var body: some View {
        ZStack {
            PBW.ink.ignoresSafeArea()

            if let wrapped = viewModel.wrapped, wrapped.hasData {
                WrappedStoryPlayer(wrapped: wrapped, onClose: { dismiss() })
            } else if viewModel.isLoading {
                PBSpinner()
            } else {
                WrappedEmptyState(
                    message: viewModel.errorMessage
                        ?? "Nothing logged\(monthName). Read a few pages and your Wrapped writes itself.",
                    onClose: { dismiss() }
                )
            }
        }
        .task { await viewModel.load() }
        .statusBarHidden()
    }

    private var monthName: String {
        guard let month = viewModel.wrapped?.month else { return " this month" }
        return " in \(month)"
    }
}

// MARK: - Player

private struct WrappedStoryPlayer: View {
    let wrapped: Wrapped
    let onClose: () -> Void

    @State private var index = 0
    @State private var progress: Double = 0
    @State private var isPaused = false
    @State private var didHold = false
    @State private var holdTask: Task<Void, Never>?
    @State private var isFinished = false
    @State private var showShare = false

    /// Seconds a chapter holds before it turns itself.
    private let chapterDuration: Double = 6
    private let tick: Double = 0.06

    private var chapters: [WrappedChapter] { WrappedChapter.all(for: wrapped) }
    private var chapter: WrappedChapter { chapters[min(index, chapters.count - 1)] }
    private var foreground: Color { chapter.isLight ? PBW.ink : PBW.cream }

    private let timer = Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            // Chapters are drawn on the 402pt design grid and scaled up or down
            // to the device; the chrome around them stays at true size so tap
            // targets and safe-area insets are not scaled with it.
            let scale = geo.size.width / PBW.designWidth

            ZStack(alignment: .top) {
                chapter.content(wrapped)
                    .frame(width: PBW.designWidth, height: geo.size.height / scale)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    .id(chapter.id)   // a new chapter re-runs its own typesetting
                    .clipped()

                chrome(width: geo.size.width)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in beginHold() }
                    .onEnded { value in endHold(at: value.location.x, width: geo.size.width) }
            )
        }
        .ignoresSafeArea()
        .onReceive(timer) { _ in advanceProgress() }
        .sheet(isPresented: $showShare) {
            WrappedShareSheet(wrapped: wrapped)
                .presentationDetents([.large])
                .presentationBackground(PBW.inkDeep)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Next chapter") { go(1) }
        .accessibilityAction(named: "Previous chapter") { go(-1) }
        .accessibilityAction(named: isPaused ? "Resume" : "Pause") { isPaused.toggle() }
        .accessibilityAction(named: "Close") { onClose() }
    }

    // MARK: Chrome

    private func chrome(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { i, _ in
                    GeometryReader { bar in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(foreground.opacity(0.26))
                            Rectangle()
                                .fill(foreground)
                                .frame(width: bar.size.width * fill(for: i))
                        }
                    }
                    .frame(height: 2.5)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            HStack {
                Text("\(wrapped.monthShort) \(wrapped.year) WRAPPED")
                    .font(PBW.mono(9)).tracking(1.4)
                Spacer()
                Text("\(String(format: "%02d", index + 1))/\(chapters.count)")
                    .font(PBW.mono(9)).tracking(1.4).opacity(0.7)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.leading, 12)
                }
                .accessibilityLabel("Close Wrapped")
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 30)
            .padding(.top, 16)

            Spacer()

            if isPaused && !showShare {
                HStack(spacing: 5) {
                    Rectangle().frame(width: 5, height: 26)
                    Rectangle().frame(width: 5, height: 26)
                }
                .foregroundStyle(foreground.opacity(0.9))
                Spacer()
            }

            Button {
                showShare = true
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 12, weight: .semibold))
                    Text("SHARE THIS").font(PBW.mono(10)).tracking(1.4)
                }
                .foregroundStyle(foreground)
                .padding(.horizontal, 20).padding(.vertical, 11)
                .background(
                    Capsule().fill(chapter.isLight ? PBW.ink.opacity(0.07) : PBW.cream.opacity(0.1))
                )
                .overlay(
                    Capsule().stroke(chapter.isLight ? PBW.ink.opacity(0.4) : PBW.cream.opacity(0.34), lineWidth: 1)
                )
            }
            .padding(.bottom, 22)
        }
        .padding(.top, safeTop)
        .padding(.bottom, safeBottom)
    }

    private var safeTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
            .first ?? 20
    }

    private var safeBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom }
            .first ?? 0
    }

    private func fill(for i: Int) -> Double {
        if i < index { return 1 }
        if i == index { return progress }
        return 0
    }

    // MARK: Playback

    private func advanceProgress() {
        guard !isPaused, !showShare, !isFinished else { return }
        progress += tick / chapterDuration
        if progress >= 1 { go(1) }
    }

    private func go(_ direction: Int) {
        let next = index + direction
        if next < 0 {
            progress = 0
            return
        }
        if next >= chapters.count {
            // The story holds on its last page rather than snapping back.
            isFinished = true
            progress = 1
            return
        }
        index = next
        progress = 0
    }

    private func beginHold() {
        guard holdTask == nil else { return }
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.22))
            guard !Task.isCancelled else { return }
            didHold = true
            isPaused = true
        }
    }

    private func endHold(at x: CGFloat, width: CGFloat) {
        holdTask?.cancel()
        holdTask = nil

        if didHold {
            didHold = false
            isPaused = false
            return
        }
        if isFinished {
            isFinished = false
            index = 0
            progress = 0
            return
        }
        go(x < width * 0.32 ? -1 : 1)
    }
}

// MARK: - Share sheet

private struct WrappedShareSheet: View {
    let wrapped: Wrapped
    @Environment(\.dismiss) private var dismiss

    /// 9:16 at 1080×1920 — the size every story surface wants.
    private static let exportWidth: CGFloat = 360

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(PBW.cream.opacity(0.3))
                .frame(width: 40, height: 3.5)
                .padding(.top, 14)

            WrappedRecapCard(w: wrapped, width: 230)
                .environment(\.wrappedStill, true)
                .shadow(color: .black.opacity(0.55), radius: 22, y: 18)

            Text("9:16 STORY")
                .font(PBW.mono(9)).tracking(1)
                .foregroundStyle(PBW.cream)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(Rectangle().stroke(PBW.cream, lineWidth: 1))

            if let image = renderedCard {
                ShareLink(
                    item: image,
                    preview: SharePreview("My \(wrapped.month) \(wrapped.year) on PaperBoxd", image: image)
                ) {
                    HStack(spacing: 9) {
                        Image(systemName: "square.and.arrow.up")
                        Text("SHARE CARD").font(PBW.mono(10)).tracking(1.4)
                    }
                    .foregroundStyle(PBW.terra)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(Rectangle().stroke(PBW.terra, lineWidth: 1))
                }
                .padding(.horizontal, 22)
            } else {
                Text("Could not draw the card.")
                    .font(PBW.mono(10)).tracking(1)
                    .foregroundStyle(PBW.muted)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PBW.inkDeep)
    }

    /// Rendered once per presentation. `wrappedStill` makes every primitive
    /// draw its finished state — ImageRenderer never runs an animation, so
    /// without it the card would export blank.
    private var renderedCard: Image? {
        let renderer = ImageRenderer(
            content: WrappedRecapCard(w: wrapped, width: Self.exportWidth)
                .environment(\.wrappedStill, true)
        )
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}

// MARK: - Empty / error state

private struct WrappedEmptyState: View {
    let message: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("PaperBoxd").font(PBW.script(34)).foregroundStyle(PBW.cream)
            Text("MONTHLY WRAPPED").font(PBW.mono(10)).tracking(1.8).foregroundStyle(PBW.muted)
            Text(message)
                .font(PBW.displayItalic(21))
                .foregroundStyle(PBW.cream)
                .padding(.top, 8)
            Button("Close", action: onClose)
                .font(PBW.mono(10))
                .tracking(1.4)
                .foregroundStyle(PBW.terra)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(30)
    }
}

#if DEBUG
#Preview("Wrapped — player") {
    WrappedStoryPlayer(wrapped: PreviewData.wrapped, onClose: {})
}

#Preview("Wrapped — empty month") {
    ZStack {
        PBW.ink.ignoresSafeArea()
        WrappedEmptyState(
            message: "Nothing logged in August. Read a few pages and your Wrapped writes itself.",
            onClose: {}
        )
    }
}
#endif
