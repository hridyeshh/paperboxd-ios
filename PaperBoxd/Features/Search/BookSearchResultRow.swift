import SwiftUI

struct BookSearchResultRow: View {
    let book: Book
    var onAdd: () -> Void = { }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            BookCoverView(url: book.coverURL, width: 40, cornerRadius: 4)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(PB.serif(14.5))
                    .foregroundStyle(BK.ink)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(authorYearLine)
                        .font(.system(size: 12))
                        .foregroundStyle(BK.muted)
                        .lineLimit(1)
                    if let rating = book.averageRating {
                        Text(String(format: "★ %.1f", rating))
                            .font(PB.mono(11))
                            .foregroundStyle(BK.ink)
                    }
                }

                if !book.categories.isEmpty {
                    Text(book.categories.prefix(2).joined(separator: " · "))
                        .font(PB.mono(9.5))
                        .tracking(1)
                        .foregroundStyle(BK.accent.opacity(0.85))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BK.ink)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().strokeBorder(BK.paper2, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    private var authorYearLine: String {
        var parts: [String] = []
        if !book.authors.isEmpty { parts.append(book.authorLine) }
        if let year = book.publishedYear { parts.append(year) }
        return parts.joined(separator: " · ")
    }
}
