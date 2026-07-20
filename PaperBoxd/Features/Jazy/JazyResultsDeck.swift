import SwiftUI

/// Jazy's vibe results — one match card at a time, skip or open.
/// The top card flicks off to the left; the two behind it sit stacked and scaled.
struct JazyResultsDeck: View {
    let query: String
    let matches: [VibeMatch]
    let user: User
    let onClose: () -> Void

    @State private var index = 0
    @State private var leaving = false
    @State private var openMatch: VibeMatch?
    /// Live finger position on the top card. Released short of `flickDistance`
    /// it springs back; past it the card leaves the way it was thrown.
    @State private var drag: CGSize = .zero
    @State private var leavingDirection: CGFloat = -1

    private static let flickDistance: CGFloat = 110

    private var done: Bool { index >= matches.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            deck
            dots
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .background(JZ.bg.ignoresSafeArea())
        .fullScreenCover(item: $openMatch) { match in
            NavigationStack {
                BookDetailView(bookId: match.book.id, user: user)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(JZ.ink)
                    .frame(width: 34, height: 34)
                    .background(JZ.card)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(JZ.line))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Ask Jazy")

            VStack(alignment: .leading, spacing: 1) {
                Text("Jazy found \(matches.count) book\(matches.count == 1 ? "" : "s") for")
                    .font(.system(size: 12))
                    .foregroundStyle(JZ.sub)
                Text("“\(query)”")
                    .font(PB.serifItalic(16))
                    .foregroundStyle(JZ.ink)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            PipFace(thinking: done)
                .frame(width: 40, height: 44)
        }
        .padding(.top, 10)
    }

    private var deck: some View {
        ZStack {
            if done {
                VStack(spacing: 14) {
                    Text("That was all \(matches.count). Another vibe?")
                        .font(PB.serif(22, .semibold))
                        .foregroundStyle(JZ.ink)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                    Button(action: onClose) {
                        Text("Search again")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 13)
                            .background(JZ.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ForEach(Array(matches[index..<min(index + 3, matches.count)].enumerated()), id: \.element.id) { depth, match in
                    let top = depth == 0
                    JazyMatchCard(match: match,
                                  onNext: { skip() },
                                  onOpen: { openMatch = match })
                        .scaleEffect(1 - CGFloat(depth) * 0.045)
                        .offset(x: top ? (leaving ? 520 * leavingDirection : drag.width) : 0,
                                y: CGFloat(depth) * 14 + (top ? drag.height * 0.12 : 0))
                        // Tilt follows the throw, so the card pivots off the
                        // wrist rather than sliding flat.
                        .rotationEffect(.degrees(top ? (leaving ? 9 * leavingDirection : drag.width / 22) : 0))
                        .opacity(top && leaving ? 0 : (depth == 2 ? 0.55 : 1))
                        .zIndex(Double(10 - depth))
                        .allowsHitTesting(top)
                        .gesture(top ? swipe : nil)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(matches.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? JZ.accent : JZ.ink.opacity(0.16))
                    .frame(width: i == index ? 18 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: index)
        .padding(.bottom, 26)
    }

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

    /// Advance to the next match. `direction` is which way the card flies out —
    /// the way it was thrown, or left by default when the button was tapped.
    private func skip(direction: CGFloat = -1) {
        guard !leaving, !done else { return }
        leavingDirection = direction
        withAnimation(.easeIn(duration: 0.4)) {
            leaving = true
            drag = .zero
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            index += 1
            leaving = false
        }
    }
}

// MARK: - The card

private struct JazyMatchCard: View {
    let match: VibeMatch
    let onNext: () -> Void
    let onOpen: () -> Void

    private var book: Book { match.book }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 18) {
                cover
                VStack(alignment: .leading, spacing: 7) {
                    Text("\(match.matchPercent)% match")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(JZ.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(JZ.accent.opacity(0.1))
                        .clipShape(Capsule())

                    Text(book.title)
                        .font(PB.serif(21, .semibold))
                        .foregroundStyle(JZ.ink)
                        .lineLimit(3)

                    if !book.authorLine.isEmpty {
                        Text(book.authorLine)
                            .font(.system(size: 13))
                            .foregroundStyle(JZ.sub)
                            .lineLimit(1)
                    }
                    if !book.categories.isEmpty {
                        Text(book.categories.prefix(3).joined(separator: " · ").lowercased())
                            .font(.system(size: 11.5))
                            .foregroundStyle(JZ.faint)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Why Jazy picked it, and what it's honest about. Both come from
            // Claude alongside the match percent above.
            if !match.matchReason.isEmpty {
                Divider().overlay(JZ.line).padding(.top, 20)
                VStack(alignment: .leading, spacing: 10) {
                    reasonLine("checkmark", match.matchReason, tint: JZ.accent, ink: JZ.ink)
                    if !match.matchCaveat.isEmpty {
                        reasonLine("exclamationmark", match.matchCaveat, tint: JZ.faint, ink: JZ.sub)
                    }
                }
                .padding(.top, 16)
            }

            Spacer(minLength: 16)

            // Open is the primary action and takes the full width; Next sits
            // under it, so skipping never competes with opening.
            VStack(spacing: 10) {
                Button(action: onOpen) {
                    HStack(spacing: 7) {
                        Text("Open this book")
                        Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(JZ.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button(action: onNext) {
                    HStack(spacing: 6) {
                        Text("Next")
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(JZ.sub)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(JZ.line))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Or swipe the card aside")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(JZ.card)
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(JZ.line))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.13), radius: 22, y: 18)
    }

    private func reasonLine(_ symbol: String, _ text: String, tint: Color, ink: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 12)
                .padding(.top, 3)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cover: some View {
        Group {
            if let raw = book.coverURL, let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { coverFallback }
                }
            } else {
                coverFallback
            }
        }
        .frame(width: 92, height: 138)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 10)
    }

    private var coverFallback: some View {
        SK.coverGradient.overlay(alignment: .bottomLeading) {
            Text(book.title)
                .font(PB.serif(13, .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(3)
                .padding(12)
        }
    }
}
