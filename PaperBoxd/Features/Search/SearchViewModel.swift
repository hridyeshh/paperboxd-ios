import Combine
import Foundation

enum SearchType: String, CaseIterable {
    case books = "Books"
    case readers = "Readers"
    case vibe = "Vibe"
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var searchType: SearchType = .books
    @Published var books: [Book] = []
    @Published var users: [UserProfile] = []
    @Published var vibeBooks: [Book] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    @Published var wallBooks: [Book] = []
    @Published var isLoadingWall = false
    @Published var isLoadingMoreWall = false
    private var wallPage = 1
    private var wallHasMore = true

    @Published var suggestedReaders: [UserProfile] = []
    private var suggestedReadersLoaded = false

    @Published var recentSearches: [String] = []
    private let historyKey = "pb_search_history"

    private var searchTask: Task<Void, Never>?

    init() {
        recentSearches = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }

    func addToHistory(_ term: String) {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        recentSearches.removeAll { $0 == t }
        recentSearches.insert(t, at: 0)
        if recentSearches.count > 10 { recentSearches = Array(recentSearches.prefix(10)) }
        UserDefaults.standard.set(recentSearches, forKey: historyKey)
    }

    func removeFromHistory(_ term: String) {
        recentSearches.removeAll { $0 == term }
        UserDefaults.standard.set(recentSearches, forKey: historyKey)
    }

    func clearHistory() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    var currentResults: [Book] {
        switch searchType {
        case .books: return books
        case .vibe: return vibeBooks
        case .readers: return []
        }
    }

    func onQueryChanged() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            books = []; users = []; vibeBooks = []; errorMessage = nil
            return
        }
        let debounce: UInt64 = searchType == .vibe ? 600_000_000 : 400_000_000
        searchTask = Task {
            try? await Task.sleep(nanoseconds: debounce)
            guard !Task.isCancelled else { return }
            await search(query: q)
        }
    }

    func onTypeChanged() {
        searchTask?.cancel()
        books = []; users = []; vibeBooks = []; errorMessage = nil
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        searchTask = Task {
            guard !Task.isCancelled else { return }
            await search(query: q)
        }
    }

    private func search(query: String) async {
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        switch searchType {
        case .books:
            let result = (try? await searchBooks(query)) ?? []
            books = result
            if !result.isEmpty { addToHistory(query) }
        case .readers:
            let result = (try? await searchUsers(query)) ?? []
            users = result
            if !result.isEmpty { addToHistory(query) }
        case .vibe:
            let result = (try? await searchVibe(query)) ?? []
            vibeBooks = result
            if !result.isEmpty { addToHistory(query) }
        }
    }

    private func searchBooks(_ q: String) async throws -> [Book] {
        var comps = URLComponents(string: Endpoints.searchBooks)!
        comps.queryItems = [URLQueryItem(name: "q", value: q), URLQueryItem(name: "page_size", value: "20")]
        let resp: BookListResponse = try await APIClient.shared.request(
            path: comps.string ?? Endpoints.searchBooks,
            method: .get,
            requiresAuth: false
        )
        return resp.items
    }

    private func searchUsers(_ q: String) async throws -> [UserProfile] {
        var comps = URLComponents(string: Endpoints.searchUsers)!
        comps.queryItems = [URLQueryItem(name: "query", value: q), URLQueryItem(name: "page_size", value: "20")]
        let resp: UserListResponse = try await APIClient.shared.request(
            path: comps.string ?? Endpoints.searchUsers,
            method: .get,
            requiresAuth: true
        )
        return resp.users
    }

    private func searchVibe(_ q: String) async throws -> [Book] {
        struct VibeRequest: Encodable { let query: String; let limit: Int }
        let resp: BookListResponse = try await APIClient.shared.request(
            path: "/api/v1/search/vibe",
            method: .post,
            body: VibeRequest(query: q, limit: 10),
            requiresAuth: false
        )
        return resp.items
    }

    func loadWallIfNeeded() async {
        guard wallBooks.isEmpty, !isLoadingWall else { return }
        isLoadingWall = true
        defer { isLoadingWall = false }
        let resp: BookListResponse? = try? await APIClient.shared.request(
            path: Endpoints.latestBooks + "?page=1&page_size=24",
            method: .get,
            requiresAuth: false
        )
        let items = resp?.items ?? []
        wallBooks = items
        wallPage = 1
        wallHasMore = items.count == 24
    }

    func loadMoreWall() async {
        guard wallHasMore, !isLoadingMoreWall, !isLoadingWall else { return }
        isLoadingMoreWall = true
        defer { isLoadingMoreWall = false }
        let nextPage = wallPage + 1
        let resp: BookListResponse? = try? await APIClient.shared.request(
            path: Endpoints.latestBooks + "?page=\(nextPage)&page_size=24",
            method: .get,
            requiresAuth: false
        )
        let items = resp?.items ?? []
        wallBooks.append(contentsOf: items)
        wallPage = nextPage
        wallHasMore = items.count == 24
    }

    func shuffleWall() async {
        guard !isLoadingWall else { return }
        isLoadingWall = true
        defer { isLoadingWall = false }

        // `/books/random` returns a fresh `ORDER BY RANDOM()` slice server-side,
        // so every pull-to-refresh yields a genuinely different wall.
        let resp: BookListResponse? = try? await APIClient.shared.request(
            path: Endpoints.randomBooks + "?page_size=24",
            method: .get,
            requiresAuth: false
        )
        let items = resp?.items ?? []
        if !items.isEmpty {
            wallBooks = items
            wallPage = 1
            // Random feed isn't paginated; stop infinite-scroll from re-fetching `latest`.
            wallHasMore = false
        }
    }

    func loadSuggestedReaders() async {
        guard !suggestedReadersLoaded else { return }
        suggestedReadersLoaded = true
        let resp: UserListResponse? = try? await APIClient.shared.request(
            path: Endpoints.searchUsers + "?query=reader&page_size=8",
            method: .get,
            requiresAuth: true
        )
        suggestedReaders = resp?.users ?? []
    }
}

struct BookListResponse: Decodable {
    let items: [Book]
    let totalItems: Int
    let page: Int?
    let pageSize: Int?
    let pagination: PaginationMeta?

    enum CodingKeys: String, CodingKey {
        case items
        case totalItems
        case page
        case pageSize
        case pagination
    }
}
