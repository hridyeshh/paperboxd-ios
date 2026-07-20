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
                    JazyMatchCard(match: match,
                                  onSkip: skip,
                                  onOpen: { openMatch = match })
                        .scaleEffect(1 - CGFloat(depth) * 0.045)
                        .offset(x: depth == 0 && leaving ? -520 : 0,
                                y: CGFloat(depth) * 14)
                        .rotationEffect(.degrees(depth == 0 && leaving ? -9 : 0))
                        .opacity(depth == 0 && leaving ? 0 : (depth == 2 ? 0.55 : 1))
                        .zIndex(Double(10 - depth))
                        .allowsHitTesting(depth == 0)
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

    private func skip() {
        guard !leaving, !done else { return }
        withAnimation(.easeIn(duration: 0.4)) { leaving = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            index += 1
            leaving = false
        }
    }
}

// MARK: - The card

private struct JazyMatchCard: View {
    let match: VibeMatch
    let onSkip: () -> Void
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

            // Why Jazy picked it. The backend sends one reason string per match.
            if !match.matchReason.isEmpty {
                Divider().overlay(JZ.line).padding(.top, 20)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(JZ.accent)
                        .padding(.top, 3)
                    Text(match.matchReason)
                        .font(.system(size: 13))
                        .foregroundStyle(JZ.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 16)
            }

            Spacer(minLength: 16)

            HStack(spacing: 10) {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 14))
                        .foregroundStyle(JZ.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(JZ.line))
                }
                .buttonStyle(.plain)

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
                .layoutPriority(1)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(JZ.card)
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(JZ.line))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.13), radius: 22, y: 18)
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
