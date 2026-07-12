import SwiftUI

// MARK: - Favourite Four (standalone section above tabs)

struct FavouriteFourView: View {
    let books: [FavoriteBook]
    let title: String

    private var filledCount: Int { min(books.count, 4) }
    private var emptyCount: Int { max(0, 4 - filledCount) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(eyebrow: "Favourites", title: title)
                .padding(.horizontal, 20)

            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(books.prefix(4))) { fav in
                    NavigationLink(value: fav.bookID) {
                        VStack(spacing: 5) {
                            GridCoverCell(url: fav.coverURL)
                            if let note = fav.note?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !note.isEmpty {
                                Text(note)
                                    .font(PB.mono(8.5))
                                    .tracking(0.5)
                                    .foregroundStyle(Color("TextSecondary"))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                ForEach(0..<emptyCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color("Surface"))
                        .aspectRatio(2/3, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Shelf tab (3-col grid)

struct ShelfGridView: View {
    let books: [BookWithStatus]
    let isLoading: Bool
    /// When set, caps the grid (the profile tab shows 3×3) and swaps infinite
    /// pagination for a Show More button. `nil` = full paginated grid.
    var limit: Int? = nil
    var onShowMore: (() -> Void)? = nil
    var onAppearItem: (BookWithStatus) async -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        if books.isEmpty && !isLoading {
            EmptyTabState(icon: "books.vertical", message: "No books read yet")
        } else {
            VStack(spacing: 0) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(limit.map { Array(books.prefix($0)) } ?? books) { item in
                        NavigationLink(value: item.id) {
                            GridCoverCell(url: item.coverURL)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if limit == nil { Task { await onAppearItem(item) } }
                        }
                    }
                    if isLoading {
                        ForEach(0..<6, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color("Surface"))
                                .aspectRatio(2/3, contentMode: .fit)
                                .pbShimmer()
                        }
                    }
                }
                if let limit, let onShowMore, books.count > limit {
                    ShowMoreButton(action: onShowMore)
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }
}

// MARK: - Diary tab (editorial rows)

struct DiaryListView: View {
    let entries: [DiaryEntry]
    let isLoading: Bool
    var onAppearItem: (DiaryEntry) async -> Void
    var onOpen: (DiaryEntry) -> Void

    var body: some View {
        if entries.isEmpty && !isLoading {
            EmptyTabState(icon: "book.closed", message: "No diary entries yet")
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                    Button { onOpen(entry) } label: {
                        DiaryEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) {
                        if idx > 0 { Rectangle().fill(Color("Border")).frame(height: 1) }
                    }
                    .onAppear { Task { await onAppearItem(entry) } }
                }
                if isLoading { PBSpinner().padding(.vertical, 16) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
}

struct DiaryEntryRow: View {
    let entry: DiaryEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let book = entry.book {
                BookCoverView(url: book.coverURL, width: 44, cornerRadius: 4)
            } else {
                RoundedRectangle(cornerRadius: 4).fill(Color("Surface")).frame(width: 44, height: 66)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.book?.title ?? entry.title ?? "Untitled")
                        .font(PB.serif(14.5))
                        .foregroundStyle(Color("TextPrimary"))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(relativeDate(entry.createdAt))
                        .font(PB.mono(9.5))
                        .tracking(1)
                        .foregroundStyle(Color("TextSecondary"))
                }

                if !entry.plainTextPreview.isEmpty {
                    Text("“\(entry.plainTextPreview)”")
                        .font(PB.serifItalic(13.5))
                        .foregroundStyle(Color("TextPrimary").opacity(0.72))
                        .lineSpacing(2)
                        .lineLimit(3)
                }

                HStack(spacing: 8) {
                    if let rating = entry.rating { stars(rating) }
                    if let cat = entry.book?.categories.first {
                        moodPill(cat)
                    }
                }
            }
        }
        .padding(.vertical, 14)
    }

    private func stars(_ r: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= r ? "star.fill" : "star")
                    .font(.system(size: 9))
                    .foregroundStyle(i <= r ? Color("Accent") : Color("TextSecondary").opacity(0.5))
            }
        }
    }

    private func moodPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(Color("Accent"))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color("Accent").opacity(0.12))
            .clipShape(Capsule())
            .lineLimit(1)
    }

    private func relativeDate(_ s: String) -> String {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = df.date(from: s) ?? {
            df.formatOptions = [.withInternetDateTime]
            return df.date(from: s)
        }()
        guard let d = date else { return "" }
        let out = DateFormatter()
        out.dateFormat = "MMM d"
        return out.string(from: d).uppercased()
    }
}

// MARK: - Lists tab (horizontal rail of cover-mosaic cards)

struct ListsTabView: View {
    let ownLists: [ReadingList]
    let savedLists: [ReadingList]

    var body: some View {
        if ownLists.isEmpty && savedLists.isEmpty {
            EmptyTabState(icon: "list.bullet", message: "No lists yet")
        } else {
            VStack(alignment: .leading, spacing: 18) {
                if !ownLists.isEmpty { listSection("Made", ownLists) }
                if !savedLists.isEmpty { listSection("Saved", savedLists) }
            }
            .padding(.top, 16)
        }
    }

    private func listSection(_ eyebrow: String, _ lists: [ReadingList]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: eyebrow).padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(lists) { ReadingListCard(list: $0) }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct ReadingListCard: View {
    let list: ReadingList

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    if i < list.coverURLs.count {
                        BookCoverView(url: list.coverURLs[i], width: 41, cornerRadius: 3)
                    } else {
                        RoundedRectangle(cornerRadius: 3).fill(Color("Background"))
                            .frame(width: 41, height: 61)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(list.title)
                    .font(PB.serif(13))
                    .foregroundStyle(Color("TextPrimary"))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if list.isPrivate {
                        Image(systemName: "lock.fill").font(.system(size: 8))
                            .foregroundStyle(Color("TextSecondary"))
                    }
                    Text("\(list.bookCount) books")
                        .font(PB.mono(9.5))
                        .foregroundStyle(Color("TextSecondary"))
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .frame(width: 140)
        .padding(6)
        .background(Color("Surface"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - TBR tab (3-col grid, same format as the bookshelf)

struct TBRGridView: View {
    let items: [TBRItem]
    var isLoading: Bool = false
    var emptyMessage: String = "Nothing on the TBR list"
    /// Same semantics as `ShelfGridView.limit` — 3×3 cap on the profile tab.
    var limit: Int? = nil
    var onShowMore: (() -> Void)? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        if items.isEmpty && !isLoading {
            EmptyTabState(icon: "bookmark", message: emptyMessage)
        } else {
            VStack(spacing: 0) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(limit.map { Array(items.prefix($0)) } ?? items) { item in
                        NavigationLink(value: item.bookID) {
                            GridCoverCell(url: item.book.coverURL)
                        }
                        .buttonStyle(.plain)
                    }
                    if isLoading {
                        ForEach(0..<6, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color("Surface"))
                                .aspectRatio(2/3, contentMode: .fit)
                                .pbShimmer()
                        }
                    }
                }
                if let limit, let onShowMore, items.count > limit {
                    ShowMoreButton(action: onShowMore)
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }
}

/// Full-width brutalist "show more" — mono caps with a hard ink border.
struct ShowMoreButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("SHOW MORE")
                .font(PB.mono(11, .medium))
                .tracking(1.5)
                .foregroundStyle(Color("TextPrimary"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .overlay(Rectangle().strokeBorder(Color("TextPrimary"), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Authors tab (3-col grid, same format as the bookshelf)

struct AuthorsGridView: View {
    let authors: [AuthorSummary]
    let isLoading: Bool
    /// Same semantics as `ShelfGridView.limit` — 3×3 cap on the profile tab.
    var limit: Int? = nil
    var onShowMore: (() -> Void)? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        if authors.isEmpty && !isLoading {
            EmptyTabState(icon: "person.2", message: "No authors yet")
        } else {
            VStack(spacing: 0) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(limit.map { Array(authors.prefix($0)) } ?? authors) { author in
                        AuthorGridCell(author: author)
                    }
                    if isLoading {
                        ForEach(0..<6, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color("Surface"))
                                .aspectRatio(2/3, contentMode: .fit)
                                .pbShimmer()
                        }
                    }
                }
                if let limit, let onShowMore, authors.count > limit {
                    ShowMoreButton(action: onShowMore)
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }
}

/// One author: a representative book cover with the author's name and book
/// count beneath — matches the bookshelf cover cells' footprint.
struct AuthorGridCell: View {
    let author: AuthorSummary

    var body: some View {
        VStack(spacing: 6) {
            GridCoverCell(url: author.coverURL)
            VStack(spacing: 1) {
                Text(author.name)
                    .font(PB.serif(12.5))
                    .foregroundStyle(Color("TextPrimary"))
                    .lineLimit(1)
                Text("\(author.bookCount) book\(author.bookCount == 1 ? "" : "s")")
                    .font(PB.mono(8.5))
                    .foregroundStyle(Color("TextSecondary"))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Likes tab (3-col grid)

struct LikesGridView: View {
    let books: [BookWithLikedAt]
    let isLoading: Bool
    var onAppearItem: (BookWithLikedAt) async -> Void
    var onTapBook: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        if books.isEmpty && !isLoading {
            EmptyTabState(icon: "heart", message: "No liked books yet")
        } else {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(books) { item in
                    GridCoverCell(url: item.coverURL)
                        .onTapGesture { onTapBook(item.id) }
                        .onAppear { Task { await onAppearItem(item) } }
                }
                if isLoading {
                    ForEach(0..<6, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color("Surface"))
                            .aspectRatio(2/3, contentMode: .fit)
                            .pbShimmer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }
}

// MARK: - Editorial signature footer

struct EditorialSignatureView: View {
    let profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "This year")
            Text(headline)
                .font(PB.serif(16))
                .foregroundStyle(Color("TextPrimary"))
                .lineSpacing(2)
            if !profile.favoriteGenres.isEmpty {
                Text(profile.favoriteGenres.prefix(3).joined(separator: " · "))
                    .font(PB.serifItalic(13))
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color("Surface"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var headline: String {
        let pages = profile.totalPagesRead
        let pagesStr = pages >= 1000 ? String(format: "%.1fk", Double(pages)/1000) : "\(pages)"
        return "\(profile.booksReadCount) books · \(pagesStr) pages · \(profile.diaryEntriesCount) reviews."
    }
}

// MARK: - Shared helpers

struct GridCoverCell: View {
    let url: String?
    var body: some View {
        GeometryReader { geo in
            BookCoverView(url: url, width: geo.size.width, cornerRadius: 6)
        }
        .aspectRatio(2/3, contentMode: .fit)
    }
}

struct EmptyTabState: View {
    let icon: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color("TextSecondary").opacity(0.7))
            Text(message)
                .font(PB.serifItalic(14))
                .foregroundStyle(Color("TextSecondary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 56)
    }
}
