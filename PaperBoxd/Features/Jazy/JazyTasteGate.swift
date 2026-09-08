import SwiftUI

/// Scan & Know is gated on knowing the reader.
///
/// The scan's whole claim is "how well does this book fit *you*" — against an
/// empty shelf it has nothing to score with, so it reads as a random number.
/// Under `minimumShelf` books (bookshelf + TBR) the camera asks for a few books
/// first instead of producing a confident-looking guess.
enum JazyTaste {
    static let minimumShelf = 5

    /// Bookshelf total + TBR count. Nil when it could not be determined —
    /// callers must fail OPEN on nil: a network hiccup is not a reason to take
    /// a feature away.
    static func shelfSize(username: String?) async -> Int? {
        guard let username, !username.isEmpty else { return nil }

        // ponytail: a book on both the shelf and the TBR counts twice. The two
        // are near-disjoint in practice (TBR means not read yet) and this only
        // decides a soft nudge — union the ids if that ever proves wrong.
        async let shelf: BookshelfResponse? = try? await APIClient.shared.request(
            path: Endpoints.userBookshelf(username: username) + "?page=1&page_size=1",
            method: .get, requiresAuth: true
        )
        async let tbr: [TBRItem]? = try? await APIClient.shared.request(
            path: Endpoints.userTBR(username: username),
            method: .get, requiresAuth: true
        )

        let shelfCount = await shelf.map { Int($0.totalCount) }
        let tbrCount = await tbr?.count
        guard shelfCount != nil || tbrCount != nil else { return nil }
        return (shelfCount ?? 0) + (tbrCount ?? 0)
    }
}

/// The gate itself — same kit as everything else in the feature: hard ink
/// frame, hard offset shadow, mono labels, one serif line that Jazy says.
struct JazyTasteGateSheet: View {
    let shelfSize: Int
    let onDismiss: () -> Void

    private var remaining: Int { max(0, JazyTaste.minimumShelf - shelfSize) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    MonoLabel(text: "Scan locked", size: 9.5, tracking: 2.2, color: SK.faint)
                    Spacer()
                    PipFace()
                        .frame(width: 30, height: 32)
                        .offset(x: 2, y: -4)
                }

                Text("Jazy works best when it knows your taste.")
                    .font(PB.serif(23, .semibold))
                    .foregroundStyle(SK.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                Text("Scanning a cover scores it against what you already read. With \(shelfSize) book\(shelfSize == 1 ? "" : "s") on your shelf there is nothing to score against yet.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(SK.sub)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                Rectangle().fill(SK.ink.opacity(0.14)).frame(height: 1).padding(.vertical, 16)

                HStack {
                    MonoLabel(text: "Add \(remaining) more book\(remaining == 1 ? "" : "s")",
                              size: 10, tracking: 1.6, color: SK.ink)
                    Spacer()
                    MonoLabel(text: "\(shelfSize) / \(JazyTaste.minimumShelf)",
                              size: 10, tracking: 1.6, color: SK.faint)
                }

                // Shelf-progress as spines, in the feature's own vocabulary.
                HStack(spacing: 4) {
                    ForEach(0..<JazyTaste.minimumShelf, id: \.self) { i in
                        Rectangle()
                            .fill(i < shelfSize ? SK.spines[i % SK.spines.count] : Color.clear)
                            .frame(height: 26)
                            .overlay(Rectangle().strokeBorder(
                                i < shelfSize ? SK.ink : SK.ink.opacity(0.22),
                                lineWidth: i < shelfSize ? 2 : 1.5))
                    }
                }
                .padding(.top, 10)

                Button(action: onDismiss) {
                    MonoLabel(text: "Ask Jazy instead", size: 12, tracking: 1.4,
                              color: SK.panel, weight: .semibold)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(BrutalButtonStyle(fill: SK.ink, shadowColor: SK.ink.opacity(0.78),
                                               border: SK.ink, borderWidth: 2, offset: 4))
                .padding(.top, 20)
                .padding(.trailing, 4)
                .padding(.bottom, 4)

                MonoLabel(text: "Vibe search needs no shelf — that one is open",
                          size: 9, tracking: 1.4, color: SK.faint)
                    .padding(.top, 4)
            }
            .padding(20)
            .background(SK.panel)
            .overlay(Rectangle().strokeBorder(SK.ink, lineWidth: 2))
            .background(Rectangle().fill(SK.ink).offset(x: 5, y: 5))
            .padding(.horizontal, 28)
            .padding(.trailing, 5)
            .padding(.bottom, 5)
        }
    }
}
