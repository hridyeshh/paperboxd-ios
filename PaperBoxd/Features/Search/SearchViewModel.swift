import Combine
import Foundation

/// Vibe search moved out of here — it lives in Ask Jazy now (`Features/Jazy`).
enum SearchType: String, CaseIterable {
    case books = "Books"
    case readers = "Readers"
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var searchType: SearchType = .books
    @Published var books: [Book] = []
    @Published var users: [UserProfile] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    @Published var wallBooks: [Book] = []
    @Published var isLoadingWall = false
    @Published var isLoadingMoreWall = false
    private var wallPage = 1
    private var wallHasMore = true

    @Published var suggestedReaders: [UserProfile] = []
    private var suggestedReadersLoaded = false

    // "Picked for you" rail above the wall — same payload the home feed uses.
    @Published var recommendations: [RecommendationItem] = []
    private var recommendationsLoaded = false

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
        case .readers: return []
        }
    }

    func onQueryChanged() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            books = []; users = []; errorMessage = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await search(query: q)
        }
    }

    func onTypeChanged() {
        searchTask?.cancel()
        books = []; users = []; errorMessage = nil
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

    func loadWallIfNeeded() async {
        guard wallBooks.isEmpty, !isLoadingWall else { return }
        isLoadingWall = true
        defer { isLoadingWall = false }
        let items = await fetchRandomWall()
        wallBooks = items
        wallHasMore = !items.isEmpty
    }

    func loadMoreWall() async {
        guard wallHasMore, !isLoadingMoreWall, !isLoadingWall else { return }
        isLoadingMoreWall = true
        defer { isLoadingMoreWall = false }
        let items = await fetchRandomWall()
        // Random slices can repeat books, so append only ones we don't have yet.
        var seen = Set(wallBooks.map { $0.id })
        let fresh = items.filter { seen.insert($0.id).inserted }
        wallBooks.append(contentsOf: fresh)
        // Keep the feed unlimited as long as the endpoint keeps returning books.
        wallHasMore = !items.isEmpty
    }

    func shuffleWall() async {
        guard !isLoadingWall else { return }
        isLoadingWall = true
        defer { isLoadingWall = false }
        let items = await fetchRandomWall()
        if !items.isEmpty {
            wallBooks = items
            wallHasMore = true
        }
    }

    /// `/books/random` returns a fresh `ORDER BY RANDOM()` slice server-side.
    /// The `_` cache-buster stops URLSession from replaying a cached response,
    /// so every refresh / page actually varies.
    private func fetchRandomWall() async -> [Book] {
        let bust = Int(Date().timeIntervalSince1970 * 1000)
        let resp: BookListResponse? = try? await APIClient.shared.request(
            path: Endpoints.randomBooks + "?page_size=24&_=\(bust)",
            method: .get,
            requiresAuth: false
        )
        return resp?.items ?? []
    }

    func loadRecommendationsIfNeeded() async {
        guard !recommendationsLoaded else { return }
        recommendationsLoaded = true
        let resp: HomeRecommendationsResponse? = try? await APIClient.shared.request(
            path: Endpoints.recommendationsHome,
            method: .get,
            requiresAuth: true
        )
        recommendations = resp?.recommendations ?? []
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
