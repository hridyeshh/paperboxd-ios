import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recommendations: [RecommendationItem] = []
    @Published var lastLoggedBook: LastLoggedBook?
    @Published var latestBooks: [Book] = []
    @Published var friendsActivities: [FriendActivity] = []
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

    var pickedForYou: [RecommendationItem] { Array(recommendations.prefix(6)) }
    var freshShelves: [RecommendationItem] {
        latestBooks.prefix(8).map { b in
            RecommendationItem(id: b.id, title: b.title, authors: b.authors,
                               coverURL: b.coverURL, categories: b.categories,
                               similarityScore: nil, reason: nil, reasonType: nil)
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        async let recsTask: HomeRecommendationsResponse = APIClient.shared.request(
            path: Endpoints.recommendationsHome,
            method: .get,
            requiresAuth: true
        )
        async let lastBookTask: LastLoggedBook? = fetchLastLoggedBook()
        async let latestTask: [Book] = fetchLatestBooks()
        async let activitiesTask: [FriendActivity] = fetchFriendActivities()
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
        lastLoggedBook = await lastBookTask
        latestBooks = await latestTask
        friendsActivities = await activitiesTask
        followRequests = await followRequestsTask
        recomputeUnread()
        isLoading = false
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

    func trackImpression(bookId: String) {
        let body = ImpressionEvent(bookId: bookId)
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
    let eventType = "book_impression"
    let bookId: String
    let metadata = ImpressionMeta()

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case bookId = "book_id"
        case metadata
    }

    struct ImpressionMeta: Encodable {
        let source = "home_feed"
    }
}
