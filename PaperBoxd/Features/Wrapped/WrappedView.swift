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
    /// Where the safe-area chrome starts, measured from layout — feeds the
    /// chapters' top inset so their headers clear the rails and label row.
    @State private var safeTop: CGFloat = 0

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

            chapter.content(wrapped)
                // Chapters keep their design-grid 76pt top margin, measured
                // from below the notch rather than the screen edge, so the
                // rails + label row never overlap the chapter's own header.
                .environment(\.wrappedTopInset, safeTop / scale)
                .frame(width: PBW.designWidth, height: geo.size.height / scale)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .id(chapter.id)   // a new chapter re-runs its own typesetting
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in beginHold() }
                        .onEnded { value in endHold(at: value.location.x, width: geo.size.width) }
                )
        }
        .ignoresSafeArea()
        // Chrome sits in the safe area by layout (same as the Fusion player).
        // Reading the window's insets during body caused an AttributeGraph
        // cycle there, and the rails ended up under the notch here.
        .overlay {
            chrome
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { safeTop = $0 }
        }
        .onReceive(timer) { _ in advanceProgress() }
        .sheet(isPresented: $showShare) {
            WrappedShareSheet(wrapped: wrapped, chapter: chapter)
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

    private var chrome: some View {
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
    /// The chapter on screen when "Share this" was tapped — that is what gets
    /// exported. The card chapter exports the recap card itself.
    let chapter: WrappedChapter
    @Environment(\.dismiss) private var dismiss
    @State private var toast: String?
    @State private var rendered: UIImage?

    /// 9:16 at 1080×1920 — the size every story surface wants.
    private static let exportPixels: CGFloat = 1080

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(PBW.cream.opacity(0.3))
                .frame(width: 40, height: 3.5)
                .padding(.top, 14)

            Group {
                if let rendered {
                    Image(uiImage: rendered).resizable().scaledToFit()
                } else {
                    Rectangle().fill(PBW.ink)
                }
            }
            .frame(width: 230, height: 230 * 16 / 9)
            .shadow(color: .black.opacity(0.55), radius: 22, y: 18)

            Text("9:16 STORY")
                .font(PBW.mono(9)).tracking(1)
                .foregroundStyle(PBW.cream)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(Rectangle().stroke(PBW.cream, lineWidth: 1))

            // Two destinations the card was drawn for, not the system sheet:
            // straight into an Instagram story, or into Photos to post anywhere.
            if let image = rendered {
                VStack(spacing: 10) {
                    if ShareService.canShareToInstagramStories {
                        shareButton("INSTAGRAM STORY", icon: { InstagramGlyph(size: 14, color: PBW.terra) }) {
                            ShareService.shareToInstagramStories(image: image, sourceAppID: "com.paperboxd.PaperBoxd")
                            dismiss()
                        }
                    }
                    shareButton("SAVE IMAGE", icon: { Image(systemName: "arrow.down.to.line") }) {
                        ShareService.saveToPhotos(image) { ok in
                            toast = ok ? "Saved to Photos" : "Couldn’t save image"
                        }
                    }
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
        .task { rendered = await renderChapter() }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast.uppercased())
                    .font(PBW.mono(10)).tracking(1.4)
                    .foregroundStyle(PBW.ink)
                    .padding(.horizontal, 15).padding(.vertical, 9)
                    .background(PBW.cream)
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: toast) {
                        try? await Task.sleep(for: .seconds(2.2))
                        withAnimation { self.toast = nil }
                    }
            }
        }
    }

    private func shareButton<I: View>(_ label: String, @ViewBuilder icon: () -> I, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                icon()
                Text(label).font(PBW.mono(10)).tracking(1.4)
            }
            .foregroundStyle(PBW.terra)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(Rectangle().stroke(PBW.terra, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Rendered once per presentation. `wrappedStill` makes every primitive
    /// draw its finished state — ImageRenderer never runs an animation, so
    /// without it the export would be blank. Covers are fetched first for the
    /// same reason: AsyncImage never resolves inside a renderer.
    @MainActor
    private func renderChapter() async -> UIImage? {
        let covers = await preloadCovers()
        let width: CGFloat = chapter.id == "card" ? 360 : PBW.designWidth
        let content: AnyView = chapter.id == "card"
            ? AnyView(WrappedRecapCard(w: wrapped, width: width))
            : AnyView(chapter.content(wrapped).frame(width: width, height: width * 16 / 9))
        let renderer = ImageRenderer(
            content: content
                .environment(\.wrappedStill, true)
                .environment(\.wrappedCovers, covers)
        )
        renderer.scale = Self.exportPixels / width
        return renderer.uiImage
    }

    /// URLSession's cache already holds whatever the chapter showed, so this is
    /// usually instant; a miss just leaves that book on its drawn board.
    private func preloadCovers() async -> [String: UIImage] {
        var urls = wrapped.books.map(\.cover)
        if let t = wrapped.topRated { urls.append(t.cover) }
        if let a = wrapped.abandoned?.cover { urls.append(a) }
        var out: [String: UIImage] = [:]
        for raw in Set(urls) where !raw.isEmpty {
            guard let url = URL(string: raw.replacingOccurrences(of: "http://", with: "https://")),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { continue }
            out[raw] = image
        }
        return out
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
