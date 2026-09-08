import SwiftUI

/// Book preview shown when a "Between covers." card is tapped.
///
/// The activity payload carries only the book's id and title (see
/// `FriendActivity`), so the cover, author line and rating are fetched on open.
/// The title already in the activity fills the gap while that request is in
/// flight, which keeps the popup useful even if the fetch fails.
///
/// Brutalist plate + hard offset shadow, matching the card it opens from.
struct FriendActivityPopup: View {
    let activity: FriendActivity
    var onOpenBook: (String) -> Void
    var onDismiss: () -> Void

    @State private var book: Book?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            card
                .padding(.horizontal, 34)
        }
        .task {
            guard let id = activity.bookID else { isLoading = false; return }
            book = try? await APIClient.shared.request(
                path: Endpoints.book(id),
                method: .get,
                requiresAuth: true
            )
            isLoading = false
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 13) {
                BookCoverView(url: book?.coverURL, width: 72, cornerRadius: 0)
                    .overlay(Rectangle().strokeBorder(BK.ink, lineWidth: 2))

                VStack(alignment: .leading, spacing: 5) {
                    Text(book?.title ?? activity.objectTitle ?? "This book")
                        .font(PB.serif(17))
                        .foregroundStyle(BK.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let authors = book?.authorLine, !authors.isEmpty {
                        Text(authors)
                            .font(.system(size: 12.5))
                            .foregroundStyle(BK.muted)
                            .lineLimit(2)
                    } else if isLoading {
                        Rectangle()
                            .fill(BK.paper2)
                            .frame(width: 92, height: 11)
                    }

                    if let rating = book?.averageRating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                            Text(String(format: "%.1f", rating))
                                .font(PB.mono(11, .medium))
                        }
                        .foregroundStyle(BK.ink)
                        .padding(.top, 1)
                    }
                }

                Spacer(minLength: 0)
            }

            Rectangle().fill(BK.ink.opacity(0.16)).frame(height: 1)

            HStack(spacing: 9) {
                ZStack {
                    if let urlStr = activity.avatarURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            PB.avatarGradient
                        }
                    } else {
                        PB.avatarGradient
                    }
                }
                .frame(width: 22, height: 22)
                .clipShape(Rectangle())
                .overlay(Rectangle().strokeBorder(BK.ink, lineWidth: 1))

                Text("\(activity.displayName) \(activity.verbPhrase)")
                    .font(.system(size: 12.5))
                    .foregroundStyle(BK.muted)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(activity.relativeTime.uppercased())
                    .font(PB.mono(9.5))
                    .tracking(0.8)
                    .foregroundStyle(BK.muted)
            }

            if let bookID = activity.bookID {
                Button { onOpenBook(bookID) } label: {
                    Text("OPEN BOOK  →")
                        .font(PB.mono(12, .medium))
                        .tracking(1.2)
                        .foregroundStyle(BK.paper)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(BrutalButtonStyle(fill: BK.ink, borderWidth: 2, offset: 4))
                .padding(.top, 2)
            }
        }
        .padding(16)
        .brutalPlate(fill: BK.card)
    }
}
