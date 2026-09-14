import Combine
import SwiftUI

// The Fusion story player, the Explore page it ends on, and the share card.
// Playback mirrors WrappedStoryPlayer: tap right/left, hold to pause.

struct FusionStoryPlayer: View {
    let story: FusionStory
    let actions: FusionActions
    let onClose: () -> Void

    @State private var index = 0
    @State private var progress: Double = 0
    @State private var isPaused = false
    @State private var didHold = false
    @State private var holdTask: Task<Void, Never>?
    @State private var isFinished = false
    @State private var showShare = false

    private let chapterDuration: Double = 6.2
    private let tick: Double = 0.06
    private let timer = Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()

    private var chapters: [FusionChapter] { FusionChapter.all(for: story) }
    private var chapter: FusionChapter { chapters[min(index, chapters.count - 1)] }
    private var fg: Color { chapter.isDark ? FZ.bg : FZ.ink }

    /// Pages share and skip through the player; the rest comes from the root.
    private var pageActions: FusionActions {
        var a = actions
        a.share = { showShare = true }
        a.next = { go(1) }
        return a
    }

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / FZ.designWidth

            ZStack(alignment: .top) {
                chapter.content(story, index + 1, chapters.count, pageActions)
                    .frame(width: FZ.designWidth, height: geo.size.height / scale)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    .id(chapter.id)
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in beginHold() }
                            .onEnded { v in endHold(at: v.location.x, width: geo.size.width) }
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        // Chrome sits in the safe area by layout. Reading the window's insets
        // during body instead caused an AttributeGraph cycle that froze the
        // player on its first page.
        .overlay { chrome }
        .onReceive(timer) { _ in
            guard !isPaused, !showShare, !isFinished else { return }
            progress += tick / chapterDuration
            if progress >= 1 { go(1) }
        }
        .sheet(isPresented: $showShare) {
            FusionShareSheet(story: story)
                .presentationDetents([.large])
                .presentationBackground(FZ.ink)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Next page") { go(1) }
        .accessibilityAction(named: "Previous page") { go(-1) }
        .accessibilityAction(named: isPaused ? "Resume" : "Pause") { isPaused.toggle() }
        .accessibilityAction(named: "Close") { onClose() }
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { i, _ in
                    GeometryReader { bar in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(fg.opacity(chapter.isDark ? 0.24 : 0.16))
                            Rectangle().fill(fg).frame(width: bar.size.width * (i < index ? 1 : i == index ? progress : 0))
                        }
                    }
                    .frame(height: 2)
                }
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(fg)
                        .padding(.leading, 10)
                        .frame(height: 28)
                }
                .accessibilityLabel("Close Fusion")
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            Spacer()

            if isPaused && !showShare {
                HStack(spacing: 5) {
                    Rectangle().frame(width: 5, height: 22)
                    Rectangle().frame(width: 5, height: 22)
                }
                .foregroundStyle(fg.opacity(0.85))
                .allowsHitTesting(false)
                Spacer()
            }

            Button { showShare = true } label: {
                Text("SHARE THIS")
                    .font(FZ.medium(10)).tracking(1.4)
                    .foregroundStyle(fg)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(chapter.isDark ? FZ.bg.opacity(0.1) : FZ.ink.opacity(0.05))
                    .overlay(Rectangle().stroke(chapter.isDark ? FZ.bg.opacity(0.4) : FZ.ink.opacity(0.34), lineWidth: 1))
            }
            .padding(.bottom, 14)
        }
    }

    private func go(_ d: Int) {
        let next = index + d
        if next < 0 { progress = 0; return }
        if next >= chapters.count { isFinished = true; progress = 1; return }
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
        if didHold { didHold = false; isPaused = false; return }
        go(x < width * 0.32 ? -1 : 1)
    }
}

// MARK: - Explore

struct FusionExploreView: View {
    let story: FusionStory
    let actions: FusionActions
    let onClose: () -> Void

    @State private var tab = 0
    @State private var showShare = false

    private var tabs: [String] { ["For both", "For you", "For \(story.them.first)"] }
    private var rows: [FusionBook] { [story.both, story.forYou, story.forThem][tab] }

    var body: some View {
        ZStack {
            FZ.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        FZMonogram(initial: story.me.initial, size: 28, accent: true)
                        FZMonogram(initial: story.them.initial, size: 28)
                        Spacer()
                        FZNum(text: "\(story.score)%", size: 26, color: FZ.accent)
                        Button(action: onClose) {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(FZ.ink)
                        }
                        .padding(.leading, 12)
                        .accessibilityLabel("Close Fusion")
                    }
                    PBRise(delay: 0.14) { FZHeading(text: "Your Fusion", size: 32) }.padding(.top, 14)
                    HStack(spacing: 6) {
                        ForEach(Array(tabs.enumerated()), id: \.offset) { i, t in
                            Button { tab = i } label: {
                                Text(t.uppercased())
                                    .font(FZ.medium(9.5)).tracking(0.95)
                                    .foregroundStyle(i == tab ? FZ.bg : FZ.ink)
                                    .padding(.horizontal, 12).padding(.vertical, 9)
                                    .background(i == tab ? FZ.ink : .clear)
                                    .overlay(Rectangle().stroke(FZ.ink, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 18)
                }
                .padding(.horizontal, 30)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if rows.isEmpty {
                            FZBody(text: "Nothing here yet. Rate a few more books and this fills in.", size: 13.5)
                                .padding(.top, 14)
                        }
                        ForEach(Array(rows.enumerated()), id: \.element.id) { i, b in
                            Rectangle().fill(FZ.line).frame(height: 1)
                            HStack(alignment: .center, spacing: 13) {
                                FZNum(text: .fzIndex(i + 1), size: 11, color: FZ.grey).frame(width: 20, alignment: .leading)
                                VStack(alignment: .leading, spacing: 6) {
                                    FZHeading(text: b.title, size: 19)
                                    FZLabel(text: b.author, size: 9)
                                }
                                Spacer(minLength: 8)
                                VStack(alignment: .trailing, spacing: 8) {
                                    if let m = b.match { FZLabel(text: m, size: 8.5, color: m == "Wildcard" ? FZ.ink : FZ.accent) }
                                    FZPill(title: "+ TBR", compact: true, fullWidth: false) { actions.addToTBR([b]) }
                                }
                            }
                            .padding(.vertical, 14)
                        }
                        Rectangle().fill(FZ.line).frame(height: 1)
                        FZBody(text: "Rebuilt when either of you rates something new.", size: 12.5).padding(.top, 14)
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.top, 22)

                VStack(spacing: 0) {
                    Rectangle().fill(FZ.line).frame(height: 1)
                    FZPill(title: "Share this Fusion", solid: true) { showShare = true }
                        .padding(.horizontal, 30)
                        .padding(.top, 16)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showShare) {
            FusionShareSheet(story: story)
                .presentationDetents([.large])
                .presentationBackground(FZ.ink)
        }
    }
}

// MARK: - Share card

/// The artifact: ink ground, the two names overprinted, the number at full
/// width. Designed at 300×534 and scaled. Only counts and first names — no
/// ratings or titles leave the app on it.
struct FusionShareCard: View {
    let story: FusionStory
    var width: CGFloat = 300

    var body: some View {
        let k = width / 300
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("PaperBoxd").font(FZ.script(21 * k)).foregroundStyle(FZ.bg)
                Spacer()
                Text("FUSION").font(FZ.medium(9 * k)).tracking(2 * k).foregroundStyle(FZ.bg.opacity(0.6))
            }
            Rectangle().fill(FZ.bg.opacity(0.24)).frame(height: 1).padding(.top, 12 * k)
            VStack(alignment: .leading, spacing: -6 * k) {
                Text(story.me.first.uppercased()).font(FZ.heading(30 * k)).tracking(-1 * k).foregroundStyle(FZ.accent)
                Text(story.them.first.uppercased()).font(FZ.heading(30 * k)).tracking(-1 * k).foregroundStyle(FZ.bg)
                    .padding(.leading, 13 * k)
            }
            .padding(.top, 26 * k)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(story.score)").font(FZ.heading(128 * k)).tracking(-7 * k).foregroundStyle(FZ.bg)
                Text("%").font(FZ.heading(42 * k)).foregroundStyle(FZ.accent)
            }
            Text("TASTE FUSION").font(FZ.medium(11 * k)).tracking(2.8 * k).foregroundStyle(FZ.bg.opacity(0.72)).padding(.top, 4 * k)
            Rectangle().fill(FZ.bg.opacity(0.24)).frame(height: 1).padding(.top, 18 * k)
            ForEach([(story.lovedCount, "shared favourites"), (story.sharedAuthors.count, "shared authors"), (story.waitingCount, "books discovered")], id: \.1) { n, l in
                HStack(alignment: .firstTextBaseline, spacing: 12 * k) {
                    Text("\(n)").font(FZ.heading(20 * k)).monospacedDigit().foregroundStyle(FZ.bg).frame(width: 30 * k, alignment: .leading)
                    Text(l).font(FZ.body(12.5 * k)).foregroundStyle(FZ.bg.opacity(0.74))
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 9 * k)
                .overlay(alignment: .bottom) { Rectangle().fill(FZ.bg.opacity(0.12)).frame(height: 1) }
            }
            HStack(alignment: .bottom) {
                Text("Two tastes.\nOne discovery.").font(FZ.heading(17 * k)).foregroundStyle(FZ.bg)
                    .fixedSize(horizontal: true, vertical: true)
                Spacer()
                Text("CREATE YOUR\nFUSION ON\nPAPERBOXD").font(FZ.medium(8 * k)).tracking(1.1 * k)
                    .multilineTextAlignment(.trailing).foregroundStyle(FZ.bg.opacity(0.56))
                    .fixedSize(horizontal: true, vertical: true)
            }
            .padding(.top, 22 * k)
        }
        .padding(.horizontal, 26 * k)
        .padding(.vertical, 28 * k)
        .frame(width: width, height: 534 * k)
        .background(FZ.ink)
    }
}

struct FusionShareSheet: View {
    let story: FusionStory

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(FZ.bg.opacity(0.3)).frame(width: 40, height: 3.5).padding(.top, 14)
            FusionShareCard(story: story, width: 250)
                .environment(\.wrappedStill, true)
                .shadow(color: .black.opacity(0.5), radius: 22, y: 18)
            FZLabel(text: "No ratings, titles or notes are on the card", size: 9, color: FZ.bg.opacity(0.5))
            if let image = renderedCard {
                ShareLink(item: image, preview: SharePreview("Our PaperBoxd Fusion", image: image)) {
                    Text("SHARE CARD")
                        .font(FZ.medium(11)).tracking(1.1)
                        .foregroundStyle(FZ.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(FZ.bg)
                }
                .padding(.horizontal, 26)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FZ.ink)
    }

    private var renderedCard: Image? {
        let renderer = ImageRenderer(content: FusionShareCard(story: story, width: 360).environment(\.wrappedStill, true))
        renderer.scale = 3
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }
}

#if DEBUG
#Preview("Fusion — story") {
    FusionStoryPlayer(story: PreviewData.fusionStory, actions: FusionActions(), onClose: {})
}

#Preview("Fusion — explore") {
    FusionExploreView(story: PreviewData.fusionStory, actions: FusionActions(), onClose: {})
}

#Preview("Fusion — share card") {
    FusionShareCard(story: PreviewData.fusionStory).environment(\.wrappedStill, true)
}
#endif
