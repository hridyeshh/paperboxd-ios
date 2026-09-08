import SwiftUI

/// Beats 03 and 04 of the Ask Jazy arc — the hinge and the resolution.
///
///   03 · The pull   one spine turns face-out; hard frames start thinning,
///                   the hard shadow becomes a faint accent offset, the score
///                   counts up in mono. Swipe left slots it back, right pulls
///                   the next one out of the wall.
///   04 · The match  everything exhales: no frames, no shadows, hairlines,
///                   whitespace and serif — the same shape as `BreakdownScreen`.
///
/// The old rounded card with the "92% match" capsule and the blurred drop
/// shadow is gone; so is `JZ`.
struct JazyResultsDeck: View {
    let query: String
    let matches: [VibeMatch]
    let user: User
    let onClose: () -> Void

    @State private var index = 0
    /// false = 03 (the pull), true = 04 (the match). One book, two beats.
    @State private var expanded = false
    @State private var leaving = false
    @State private var drag: CGSize = .zero
    @State private var leavingDirection: CGFloat = -1
    @State private var openMatch: VibeMatch?

    private static let flickDistance: CGFloat = 110

    private var done: Bool { index >= matches.count }
    private var current: VibeMatch? { done ? nil : matches[index] }

    var body: some View {
        ZStack {
            SK.bgSofter.ignoresSafeArea()

            if done {
                exhausted
            } else if let current {
                if expanded {
                    JazyMatchSheet(query: query, match: current,
                                   onBack: { withAnimation(.easeInOut(duration: 0.35)) { expanded = false } },
                                   onOpen: { openMatch = current },
                                   onNext: { withAnimation(.easeInOut(duration: 0.35)) { expanded = false }; skip() })
                        .transition(.opacity)
                } else {
                    pullBeat(current)
                        .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.light)
        .fullScreenCover(item: $openMatch) { match in
            NavigationStack {
                BookDetailView(bookId: match.book.id, user: user)
                    .navigationDestination(for: String.self) { bookId in
                        BookDetailView(bookId: bookId, user: user)
                    }
                    .navigationDestination(for: AuthorNav.self) { AuthorDetailView(nav: $0) }
            }
        }
    }

    // MARK: - 03 · The pull

    private func pullBeat(_ match: VibeMatch) -> some View {
        VStack(spacing: 0) {
            // The 2pt rule thins to a hairline here: the arc turning.
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    MonoLabel(text: "The pull", size: 10, tracking: 2.4, color: SK.ink, weight: .semibold)
                    Spacer()
                    MonoLabel(text: "03 / hinge", size: 9.5, tracking: 1.8, color: SK.faint)
                }
                Rectangle().fill(SK.ink.opacity(0.22)).frame(height: 1).padding(.top, 14)
                Text("“\(query)”")
                    .font(PB.serifItalic(14))
                    .foregroundStyle(SK.sub)
                    .lineLimit(1)
                    .padding(.top, 11)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer(minLength: 0)

            pulledSpine(match)
                .offset(x: leaving ? 520 * leavingDirection : drag.width,
                        y: drag.height * 0.12)
                // Tilt follows the throw, so it pivots off the wrist.
                .rotationEffect(.degrees(leaving ? 9 * leavingDirection : drag.width / 22))
                .opacity(leaving ? 0 : 1)
                .gesture(swipe)

            VStack(spacing: 0) {
                CountUpText(target: match.matchPercent, duration: 1.1,
                            font: PB.mono(54, .medium), color: SK.ink, grouping: false)
                MonoLabel(text: "match", size: 10, tracking: 3, color: SK.faint)
                    .padding(.top, 7)
            }
            .padding(.top, 30)
            .id(match.id)   // re-runs the count-up for each pulled book

            VStack(spacing: 0) {
                Text(match.book.title)
                    .font(PB.serif(27, .semibold))
                    .foregroundStyle(SK.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if !match.book.authorLine.isEmpty {
                    Text(match.book.authorLine)
                        .font(.system(size: 13))
                        .foregroundStyle(SK.sub)
                        .lineLimit(1)
                        .padding(.top, 7)
                }
                if !match.book.categories.isEmpty {
                    MonoLabel(text: match.book.categories.prefix(3).joined(separator: " · "),
                              size: 9.5, tracking: 1.8, color: SK.faint)
                        .padding(.top, 9)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 22)

            Spacer(minLength: 0)

            pullActions
        }
    }

    /// The spine, rotated out of the wall to cover-face. Its neighbours stay
    /// edge-on — that is what makes swiping read as physical.
    private func pulledSpine(_ match: VibeMatch) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            Rectangle().fill(SK.spines[1])
                .frame(width: 22, height: 226)
                .overlay(Rectangle().strokeBorder(SK.ink, lineWidth: 1.5))
                .rotationEffect(.degrees(-7), anchor: .bottomLeading)
                .opacity(0.8)

            ZStack {
                // The last trace of the hard shadow: a faint accent offset, no blur.
                Rectangle().fill(SK.accent.opacity(0.22))
                    .frame(width: 154, height: 231)
                    .offset(x: 7, y: 7)
                cover(match)
                    .frame(width: 154, height: 231)
                    .overlay(Rectangle().strokeBorder(SK.ink, lineWidth: 2))
            }

            Rectangle().fill(SK.spines[4])
                .frame(width: 28, height: 200)
                .overlay(Rectangle().strokeBorder(SK.ink, lineWidth: 1.5))
                .opacity(0.8)
        }
    }

    private var pullActions: some View {
        VStack(spacing: 0) {
            Rectangle().fill(SK.ink.opacity(0.14)).frame(height: 1).padding(.horizontal, 26)

            HStack {
                MonoLabel(text: "← slot back", size: 9.5, tracking: 1.6, color: SK.faint)
                Spacer()
                HStack(spacing: 5) {
                    ForEach(matches.indices, id: \.self) { i in
                        Rectangle()
                            .fill(i == index ? SK.accent : SK.ink.opacity(0.18))
                            .frame(width: i == index ? 18 : 4, height: 4)
                    }
                }
                Spacer()
                MonoLabel(text: "pull next →", size: 9.5, tracking: 1.6, color: SK.faint)
            }
            .animation(.easeInOut(duration: 0.3), value: index)
            .padding(.horizontal, 26)
            .padding(.top, 15)

            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.35)) { expanded = true }
                } label: {
                    HStack(spacing: 8) {
                        MonoLabel(text: "Why it fits", size: 12, tracking: 1.4,
                                  color: SK.panel, weight: .semibold)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(SK.panel)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(SK.ink)
                }
                .buttonStyle(.plain)

                Button { onClose() } label: {
                    Image(systemName: "arrow.uturn.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(SK.ink)
                        .frame(width: 52, height: 52)
                        .overlay(Rectangle().strokeBorder(SK.ink.opacity(0.30), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to Ask Jazy")
            }
            .padding(.horizontal, 26)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - The end of the shelf

    private var exhausted: some View {
        VStack(spacing: 16) {
            MonoLabel(text: "end of shelf", size: 10, tracking: 2.4, color: SK.faint)
            Text("That was all \(matches.count). Another shelf?")
                .font(PB.serif(24, .semibold))
                .foregroundStyle(SK.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 270)
            Button(action: onClose) {
                MonoLabel(text: "New label", size: 12, tracking: 1.4, color: SK.panel, weight: .semibold)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 52)
            }
            .buttonStyle(BrutalButtonStyle(fill: SK.ink, shadowColor: SK.ink.opacity(0.78),
                                           border: SK.ink, borderWidth: 2, offset: 4))
        }
    }

    // MARK: - Swipe

    private var swipe: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !leaving else { return }
                drag = value.translation
            }
            .onEnded { value in
                guard !leaving else { return }
                if abs(value.translation.width) > Self.flickDistance {
                    skip(direction: value.translation.width < 0 ? -1 : 1)
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { drag = .zero }
                }
            }
    }

    /// Slot this one back and pull the next. `direction` is the way it was
    /// thrown; the button throws left.
    private func skip(direction: CGFloat = -1) {
        guard !leaving, !done else { return }
        leavingDirection = direction
        withAnimation(.easeIn(duration: 0.35)) {
            leaving = true
            drag = .zero
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            index += 1
            leaving = false
        }
    }

    @ViewBuilder private func cover(_ match: VibeMatch) -> some View {
        if let raw = match.book.coverURL, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { coverFallback(match) }
            }
            .clipped()
        } else {
            coverFallback(match)
        }
    }

    private func coverFallback(_ match: VibeMatch) -> some View {
        SK.coverGradient.overlay(alignment: .bottomLeading) {
            Text(match.book.title)
                .font(PB.serif(21, .semibold))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(4)
                .padding(.leading, 34)
                .padding([.trailing, .bottom], 14)
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(.white.opacity(0.28)).frame(width: 1).offset(x: 24)
        }
    }
}

// MARK: - 04 · The match

/// The calm resolution. Deliberately built like `BreakdownScreen`: no boxes, no
/// shadows, hairline splits, a mono score, a serif verdict, whitespace.
private struct JazyMatchSheet: View {
    let query: String
    let match: VibeMatch
    let onBack: () -> Void
    let onOpen: () -> Void
    let onNext: () -> Void

    private var book: Book { match.book }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoLabel(text: "04 / the match", size: 10, tracking: 2.2, color: SK.faint)

                    header.padding(.top, 20)

                    hairline.padding(.top, 30)
                    askedVsIs
                    hairline

                    section("Why it fits", body: match.matchReason.isEmpty
                            ? "Jazy matched this on the shelf's own signals."
                            : match.matchReason)
                        .padding(.top, 30)

                    if !match.matchCaveat.isEmpty {
                        section("What it isn't", body: match.matchCaveat, muted: true)
                            .padding(.top, 26)
                    }

                    hairline.padding(.top, 28)
                    MonoLabel(text: "Pulled from your vibe · not a bestseller list",
                              size: 10, tracking: 1.4, color: SK.faint)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 26)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }

            bottomBar
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onBack) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SK.sub)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .accessibilityLabel("Back to the pull")
        }
    }

    private var hairline: some View {
        Rectangle().fill(SK.ink.opacity(0.10)).frame(height: 1)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            cover
                .frame(width: 62, height: 93)
                // The one radius left in the feature — the same one BookCoverView uses.
                .clipShape(RoundedRectangle(cornerRadius: 3))
            VStack(alignment: .leading, spacing: 5) {
                Text(book.title)
                    .font(PB.serif(21, .medium))
                    .foregroundStyle(SK.ink)
                    .lineLimit(3)
                if !book.authorLine.isEmpty {
                    Text(book.authorLine)
                        .font(.system(size: 12.5))
                        .foregroundStyle(SK.sub)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(match.matchPercent)")
                    .font(PB.mono(34))
                    .foregroundStyle(SK.ink)
                MonoLabel(text: "match", size: 10.5, tracking: 1, color: SK.faint)
            }
        }
    }

    /// What you asked, against what the book actually is. Both sides are real:
    /// the left is the query, the right is the book's own categories.
    private var askedVsIs: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(text: "You asked", size: 11, tracking: 0.8, color: SK.faint)
                Text(query)
                    .font(PB.serifItalic(15))
                    .foregroundStyle(SK.ink)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)

            Rectangle().fill(SK.ink.opacity(0.10)).frame(width: 1)

            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(text: "What it is", size: 11, tracking: 0.8, color: SK.faint)
                Text(book.categories.isEmpty ? "—" : book.categories.prefix(3).joined(separator: ", ").lowercased())
                    .font(PB.serifItalic(15))
                    .foregroundStyle(SK.ink)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)
            .padding(.leading, 22)
        }
    }

    private func section(_ eyebrow: String, body: String, muted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            MonoLabel(text: eyebrow, size: 10, tracking: 2.2, color: SK.faint)
            Text(body)
                .font(PB.serif(17, .regular))
                .foregroundStyle(muted ? SK.sub : SK.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            hairline
            HStack(spacing: 10) {
                Button(action: onOpen) {
                    HStack(spacing: 8) {
                        MonoLabel(text: "Open book", size: 12, tracking: 1.4,
                                  color: SK.panel, weight: .semibold)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(SK.panel)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(SK.ink)
                }
                .buttonStyle(.plain)

                Button(action: onNext) {
                    Image(systemName: "arrow.right.to.line")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(SK.ink)
                        .frame(width: 52, height: 52)
                        .overlay(Rectangle().strokeBorder(SK.ink.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pull the next book")
            }
            .padding(.horizontal, 26)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder private var cover: some View {
        if let raw = book.coverURL, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { fallback }
            }
            .clipped()
        } else {
            fallback
        }
    }

    private var fallback: some View {
        SK.coverGradient.overlay(alignment: .bottomLeading) {
            Text(book.title)
                .font(PB.serif(9.5, .semibold))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(3)
                .padding(.leading, 14)
                .padding([.trailing, .bottom], 6)
        }
    }
}
