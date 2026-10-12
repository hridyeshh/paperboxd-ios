import SwiftUI

/// Story/square card for a thought — the book card's quote layout: the reader's
/// words set large on the chosen ground, the book (real cover board) underneath,
/// the handle at the foot.
struct ThoughtShareCardView: View {
    let text: String
    let handle: String
    let bookTitle: String?
    let bookAuthor: String?
    let coverImage: UIImage?
    /// "2/3" when shared from a thread.
    let threadLabel: String?
    var ground: BookShareCardView.Ground = .ink
    let format: BookShareCardView.Format

    var body: some View {
        BookShareCardView(
            title: bookTitle ?? "",
            author: bookAuthor ?? "",
            year: nil,
            coverImage: coverImage,
            handle: handle,
            rating: nil,
            note: text,
            statusLabel: threadLabel.map { "Thread \($0)" } ?? "A thought",
            ground: ground,
            layout: .quote,
            format: format
        )
    }
}

/// Share sheet for one thought — the same chrome and destinations as a book.
struct ThoughtShareSheet: View {
    let entry: DiaryEntry
    var threadLabel: String? = nil

    @State private var coverImage: UIImage?
    @State private var ground: BookShareCardView.Ground = .ink

    var body: some View {
        ShareCardSheet(
            link: URL(string: "https://paperboxd.in/u/\(entry.username)"),
            prepare: { coverImage = await ShareService.loadImage(entry.book?.coverURL) },
            renderKey: "\(ground)",
            // Private thoughts can't be sent; the server refuses them too.
            send: entry.isPrivate ? nil : AttachmentRef(kind: AttachKind.thought, refID: entry.id),
            render: { format in
                let canvas = BookShareCardView.canvas(format)
                return ShareService.render(
                    ThoughtShareCardView(
                        text: entry.plainText,
                        handle: "@\(entry.username)",
                        bookTitle: entry.book?.title,
                        bookAuthor: entry.book?.authorLine,
                        coverImage: coverImage,
                        threadLabel: threadLabel,
                        ground: ground,
                        format: format
                    ),
                    baseSize: canvas,
                    scale: 1080 / canvas.width
                )
            },
            controls: { _ in
                HStack(spacing: 12) {
                    ShareChip(label: "INK", on: ground == .ink, swatch: PBW.inkDeep) { ground = .ink }
                    ShareChip(label: "PAPER", on: ground == .paper, swatch: PBW.cream) { ground = .paper }
                    ShareChip(label: "TERRA", on: ground == .terra, swatch: PBW.terraDeep) { ground = .terra }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
            }
        )
    }
}
