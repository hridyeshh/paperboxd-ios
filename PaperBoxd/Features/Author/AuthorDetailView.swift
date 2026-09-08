import SwiftUI

// MARK: - Navigation

/// Value pushed onto a NavigationStack to open an author. A distinct type so it
/// doesn't collide with the `String` bookId destination every stack registers.
struct AuthorNav: Hashable {
    let name: String
}

// MARK: - Responses

/// GET /api/v1/authors/info — Wikipedia-backed, cached 24h server-side.
struct AuthorInfoResponse: Decodable {
    let found: Bool
    let name: String
    let description: String?
    let extract: String
    let photoURL: String
    let wikipediaURL: String

    enum CodingKeys: String, CodingKey {
        case found, name, description, extract
        case photoURL = "photo_url"
        case wikipediaURL = "wikipedia_url"
    }
}

// MARK: - Detail view

/// Author page: portrait, Wikipedia blurb, and the books PaperBoxd holds by
/// them. Mirrors the web `/authors/[authorName]` page and ListDetailView's
/// header-plus-3-column-grid shape.
struct AuthorDetailView: View {
    let nav: AuthorNav

    @State private var info: AuthorInfoResponse?
    @State private var books: [Book] = []
    @State private var isLoading = true
    @State private var extractExpanded = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private let extractLimit = 420

    var body: some View {
        ScrollView {
            if isLoading {
                PBSpinner().padding(.top, 80)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if books.isEmpty {
                        EmptyTabState(icon: "books.vertical", message: "No books by \(displayName) yet")
                    } else {
                        Text("Books".uppercased())
                            .font(PB.mono(10)).tracking(1.5)
                            .foregroundStyle(Color("TextSecondary"))
                            .padding(.horizontal, 20)
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(books) { book in
                                NavigationLink(value: book.id) {
                                    GridCoverCell(url: book.coverURL)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .background(Color("Background").ignoresSafeArea())
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var displayName: String {
        (info?.found ?? false) && !(info?.name.isEmpty ?? true) ? info!.name : nav.name
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                portrait
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(PB.serif(22))
                        .foregroundStyle(Color("TextPrimary"))
                    if let d = info?.description, !d.isEmpty {
                        Text(d)
                            .font(PB.serifItalic(13))
                            .foregroundStyle(Color("TextSecondary"))
                    }
                    Text("\(books.count) book\(books.count == 1 ? "" : "s") on PaperBoxd")
                        .font(PB.mono(10))
                        .foregroundStyle(Color("TextSecondary"))
                }
                Spacer(minLength: 0)
            }

            if let extract = info?.extract, !extract.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(extractShown(extract))
                        .font(PB.serif(14))
                        .foregroundStyle(Color("TextPrimary").opacity(0.85))
                    if extract.count > extractLimit {
                        Button(extractExpanded ? "Show less" : "Read more") {
                            withAnimation(.snappy(duration: 0.22)) { extractExpanded.toggle() }
                        }
                        .font(PB.mono(10))
                        .foregroundStyle(Color("TextSecondary"))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var portrait: some View {
        if let url = info?.photoURL, !url.isEmpty {
            BookCoverView(url: url, width: 92, cornerRadius: 8)
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color("Surface"))
                .frame(width: 92, height: 138)
                .overlay(
                    Text(initials)
                        .font(PB.serif(28))
                        .foregroundStyle(Color("TextSecondary"))
                )
        }
    }

    private var initials: String {
        displayName.split(separator: " ").prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }

    private func extractShown(_ extract: String) -> String {
        guard !extractExpanded, extract.count > extractLimit else { return extract }
        return String(extract.prefix(extractLimit)).trimmingCharacters(in: .whitespaces) + "…"
    }

    private func load() async {
        async let infoTask: AuthorInfoResponse? = try? await APIClient.shared.request(
            path: Endpoints.authorInfo(name: nav.name),
            method: .get,
            requiresAuth: false
        )
        async let booksTask: BookListResponse? = try? await APIClient.shared.request(
            path: Endpoints.booksByAuthor(name: nav.name),
            method: .get,
            requiresAuth: false
        )
        let loaded = await infoTask
        info = (loaded?.found ?? false) ? loaded : nil
        books = (await booksTask)?.items ?? []
        isLoading = false
    }
}
