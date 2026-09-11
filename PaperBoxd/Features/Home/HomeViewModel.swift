import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recommendations: [RecommendationItem] = []
    /// Server-assembled modules, each with its own title and reason. Rendered
    /// above the legacy rails; books in them are removed from those rails so
    /// nothing appears twice.
    @Published var feedModules: [FeedModule] = []
    /// "Good evening." — written server-side in the reader's time zone.
    @Published var greeting: String?
    @Published var lastLoggedBook: LastLoggedBook?
    @Published var latestBooks: [Book] = []
    @Published var friendsActivities: [FriendActivity] = []
    @Published var trendingBooks: [Book] = []
    @Published var risingBooks: [CommunityShelfBook] = []
    @Published var mostTBRBooks: [CommunityShelfBook] = []
    @Published var communityActivities: [FriendActivity] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var hasNewActivities = false
    @Published var followRequests: [FollowRequestUser] = []

    let user: User

    private var lastViewedKey: String { "activity_last_viewed_\(user.username ?? user.id)" }

    init(user: User, loadOnInit: Bool = true) {
        self.user = user
        if loadOnInit {
            Task { await load() }
        }
    }

    /// Ids already shown inside a feed module.
    private var usedIDs: Set<String> { Set(feedModules.flatMap { $0.books.map(\.id) }) }
    private func unused(_ items: [RecommendationItem]) -> [RecommendationItem] {
        let used = usedIDs
        return items.filter { !used.contains($0.id) }
    }

    var pickedForYou: [RecommendationItem] { Array(unused(recommendations).prefix(6)) }
    var freshShelves: [RecommendationItem] { unused(latestBooks.prefix(8).map(Self.item)) }
    /// Needs a few titles to read as a trend rather than one person's week.
    var trending: [RecommendationItem] {
        trendingBooks.count >= 4 ? unused(trendingBooks.prefix(10).map(Self.item)) : []
    }
    /// Same threshold for the discovery shelves; the label rides along as the
    /// card's reason line so the claim stays the server's.
    var rising: [RecommendationItem] { unused(Self.shelf(risingBooks)) }
    var mostTBR: [RecommendationItem] { unused(Self.shelf(mostTBRBooks)) }

    private static func shelf(_ books: [CommunityShelfBook]) -> [RecommendationItem] {
        guard books.count >= 4 else { return [] }
        return books.prefix(10).map { entry in
            RecommendationItem(id: entry.book.id, title: entry.book.title, authors: entry.book.authors,
                               coverURL: entry.book.coverURL, categories: entry.book.categories,
                               similarityScore: nil, reason: entry.label, reasonType: nil)
        }
    }
    /// Public activity fills the rail while the follow graph is empty.
    var showsCommunityRail: Bool { friendsActivities.isEmpty && !communityActivities.isEmpty }

    private static func item(_ b: Book) -> RecommendationItem {
        RecommendationItem(id: b.id, title: b.title, authors: b.authors,
                           coverURL: b.coverURL, categories: b.categories,
                           similarityScore: nil, reason: nil, reasonType: nil)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        async let recsTask: HomeRecommendationsResponse = APIClient.shared.request(
            path: Endpoints.recommendationsHome,
            method: .get,
            requiresAuth: true
        )
        async let feedTask: FeedResponse? = fetchFeed()
        async let lastBookTask: LastLoggedBook? = fetchLastLoggedBook()
        async let latestTask: [Book] = fetchLatestBooks()
        async let activitiesTask: [FriendActivity] = fetchFriendActivities()
        async let communityTask: CommunityResponse? = fetchCommunity()
        // Pending follow requests belong in the bell beside the feed — they are
        // the only thing there that needs an answer.
        async let followRequestsTask: [FollowRequestUser] = fetchFollowRequests()

        do {
            let resp = try await recsTask
            recommendations = resp.recommendations
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        if let feed = await feedTask {
            feedModules = feed.modules.filter { !$0.books.isEmpty }
            greeting = feed.greeting
        }
        lastLoggedBook = await lastBookTask
        latestBooks = await latestTask
        friendsActivities = await activitiesTask
        if let community = await communityTask {
            trendingBooks = community.trendingBooks.filter { $0.coverURL != nil }
            risingBooks = community.rising.filter { $0.book.coverURL != nil }
            mostTBRBooks = community.mostTBR.filter { $0.book.coverURL != nil }
            communityActivities = community.activity.filter { $0.userID != user.id && $0.bookTitle != nil }
        }
        followRequests = await followRequestsTask
        recomputeUnread()
        isLoading = false
    }

    /// Best-effort: a missing feed leaves the legacy rails, never a blank home.
    private func fetchFeed() async -> FeedResponse? {
        try? await APIClient.shared.request(
            path: Endpoints.recommendationsFeed(timeZone: TimeZone.current.identifier),
            method: .get,
            requiresAuth: true
        )
    }

    private func fetchFollowRequests() async -> [FollowRequestUser] {
        let response: FollowRequestsResponse? = try? await APIClient.shared.request(
            path: Endpoints.followRequests,
            method: .get,
            requiresAuth: true
        )
        return response?.requests ?? []
    }

    func respondToFollowRequest(_ username: String, accept: Bool) {
        Task {
            let path = Endpoints.followRequest(username: username)
            do {
                if accept {
                    let _: FollowResponse = try await APIClient.shared.request(
                        path: path, method: .post, requiresAuth: true
                    )
                } else {
                    let _: Empty = try await APIClient.shared.request(
                        path: path, method: .delete, requiresAuth: true
                    )
                }
                followRequests.removeAll { $0.username == username }
            } catch {
                // Leave the row; the next load re-fetches the truth.
            }
        }
    }

    /// Mirrors the web's localStorage "activity_last_viewed" dot: the bell shows an
    /// unread marker when the newest friend activity is more recent than the last
    /// time the user opened the notifications sheet.
    private func recomputeUnread() {
        // A pending follow request keeps the dot lit until it is answered —
        // unlike feed items, it is a decision, not news.
        if !followRequests.isEmpty {
            hasNewActivities = true
            return
        }
        guard let newest = friendsActivities.compactMap(\.createdDate).max() else {
            hasNewActivities = false
            return
        }
        let lastViewed = UserDefaults.standard.object(forKey: lastViewedKey) as? Date ?? .distantPast
        hasNewActivities = newest > lastViewed
    }

    func markActivitiesViewed() {
        UserDefaults.standard.set(Date(), forKey: lastViewedKey)
        hasNewActivities = !followRequests.isEmpty
    }

    private func fetchLastLoggedBook() async -> LastLoggedBook? {
        guard let uname = user.username else { return nil }
        let resp: LastLoggedBookResponse? = try? await APIClient.shared.request(
            path: Endpoints.lastLoggedBook(username: uname),
            method: .get,
            requiresAuth: true
        )
        return resp?.lastBook
    }

    private func fetchLatestBooks() async -> [Book] {
        let resp: BookListResponse? = try? await APIClient.shared.request(
            path: Endpoints.latestBooks + "?page_size=12",
            method: .get,
            requiresAuth: false
        )
        return resp?.items ?? []
    }

    private func fetchCommunity() async -> CommunityResponse? {
        try? await APIClient.shared.request(
            path: Endpoints.community,
            method: .get,
            requiresAuth: false
        )
    }

    private func fetchFriendActivities() async -> [FriendActivity] {
        let resp: FollowingActivitiesResponse? = try? await APIClient.shared.request(
            path: Endpoints.followingActivities + "?page_size=10",
            method: .get,
            requiresAuth: true
        )
        // Between covers shows friends' activity, not your own.
        return (resp?.activities ?? []).filter { $0.userID != user.id }
    }

    func refresh() async { await load() }

    /// The five verdicts a reader can give a card without opening it. Mirrors
    /// service.Verdict* on the backend.
    enum Verdict: String, CaseIterable {
        case loved, maybe, notForMe = "not_for_me", alreadyRead = "already_read", notNow = "not_now"

        var label: String {
            switch self {
            case .loved: return "Love it"
            case .maybe: return "Maybe"
            case .notForMe: return "Not for me"
            case .alreadyRead: return "Already read"
            case .notNow: return "Not now"
            }
        }
        var symbol: String {
            switch self {
            case .loved: return "heart"
            case .maybe: return "clock"
            case .notForMe: return "hand.thumbsdown"
            case .alreadyRead: return "checkmark"
            case .notNow: return "xmark"
            }
        }
    }

    /// Records a verdict and removes the card from every rail. Removal is
    /// the confirmation: a card that stays put after "not for me" reads as
    /// the button doing nothing. "Love it" keeps it — that is a reason to
    /// leave the book in front of them, not to take it away.
    func giveVerdict(_ verdict: Verdict, on item: RecommendationItem) {
        struct Body: Encodable {
            let bookId: String
            let verdict: String
            let reasonType: String?
            enum CodingKeys: String, CodingKey {
                case bookId = "book_id", verdict, reasonType = "reason_type"
            }
        }
        if verdict != .loved {
            recommendations.removeAll { $0.id == item.id }
        }
        let body = Body(bookId: item.id, verdict: verdict.rawValue, reasonType: item.reasonType)
        Task.detached {
            _ = try? await APIClient.shared.request(
                path: "/api/v1/recommendations/feedback",
                method: .post,
                body: body,
                requiresAuth: true
            ) as Empty
        }
    }

    /// reasonType is the recommendation's reason bucket. It defaults to nil ->
    /// "unknown" so existing call sites keep compiling; thread the real value
    /// through wherever the card already knows it, or the discovery funnel
    /// cannot split this client's impressions by reason.
    func trackImpression(bookId: String, reasonType: String? = nil) {
        let body = ImpressionEvent(bookId: bookId, reasonType: reasonType)
        Task.detached {
            _ = try? await APIClient.shared.request(
                path: Endpoints.events,
                method: .post,
                body: body,
                requiresAuth: true
            ) as Empty
        }
    }
}

private struct ImpressionEvent: Encodable {
    /// Canonical name from the backend taxonomy (service.EventRecImpression).
    /// The old "book_impression" is still accepted as an alias for builds
    /// already in the field, but nothing new should emit it.
    let eventType = "rec_impression"
    let bookId: String
    let metadata: ImpressionMeta

    init(bookId: String, reasonType: String?) {
        self.bookId = bookId
        self.metadata = ImpressionMeta(reasonType: reasonType ?? "unknown")
    }

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case bookId = "book_id"
        case metadata
    }

    /// reason_type is what /analytics/discovery groups the funnel by. Without
    /// it every impression from this client lands in the 'unknown' bucket and
    /// cannot be compared against any other reason.
    struct ImpressionMeta: Encodable {
        let source = "home_feed"
        let reasonType: String

        enum CodingKeys: String, CodingKey {
            case source
            case reasonType = "reason_type"
        }
    }
}
