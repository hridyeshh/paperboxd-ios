import Foundation

struct UserProfile: Codable, Identifiable, Equatable {
    let id: String
    let username: String
    let name: String
    let avatarURL: String?
    let bannerURL: String?
    let bio: String?
    let pronouns: [String]
    let birthday: String?
    let gender: String?
    let links: [String]
    let isPublic: Bool
    let booksReadCount: Int
    let totalPagesRead: Int
    let favoritesCount: Int
    let listsCount: Int
    let diaryEntriesCount: Int
    let followersCount: Int
    let followingCount: Int
    let favoriteGenres: [String]
    let createdAt: String
    var isFollowing: Bool?
    /// Private accounts: the backend redacts the payload and sets can_view=false
    /// for anyone who is neither the owner nor an approved follower.
    var canView: Bool?
    var hasRequested: Bool?

    enum CodingKeys: String, CodingKey {
        case id, username, name, bio, pronouns, birthday, gender, links
        case avatarURL = "avatar_url"
        case bannerURL = "banner_url"
        case isPublic = "is_public"
        case booksReadCount = "books_read_count"
        case totalPagesRead = "total_pages_read"
        case favoritesCount = "favorites_count"
        case listsCount = "lists_count"
        case diaryEntriesCount = "diary_entries_count"
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case favoriteGenres = "favorite_genres"
        case createdAt = "created_at"
        case isFollowing = "is_following"
        case canView = "can_view"
        case hasRequested = "has_requested"
    }

    var displayName: String { name.isEmpty ? username : name }
}

/// One of the "Four books I love" favourites.
/// Maps types.FavoriteResponse from GET /api/v1/users/{username}/favorites (top-level array).
struct FavoriteBook: Codable, Identifiable {
    let id: String
    let bookID: String
    let displayOrder: Int
    let note: String?
    let book: Book
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, note, book
        case bookID = "book_id"
        case displayOrder = "display_order"
        case createdAt = "created_at"
    }

    var coverURL: String? { book.coverURL }
    var title: String { book.title }
}

/// Server-computed reading streak from GET /api/v1/users/{username}/streak.
struct StreakResponse: Decodable {
    let streak: Int
}

struct FollowResponse: Decodable {
    let message: String
    let isFollowing: Bool
    /// True when the target is private and the follow was queued as a request.
    let hasRequested: Bool?
    let followersCount: Int
    let followingCount: Int
}

/// One pending follow request in the owner's inbox.
struct FollowRequestUser: Decodable, Identifiable {
    let requestID: String
    let requestedAt: String?
    let id: String
    let username: String
    let name: String
    let avatarURL: String?
    let bio: String?

    enum CodingKeys: String, CodingKey {
        case id, username, name, bio
        case requestID = "request_id"
        case requestedAt = "requested_at"
        case avatarURL = "avatar_url"
    }
}

struct FollowRequestsResponse: Decodable {
    let requests: [FollowRequestUser]
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case requests
        case totalCount = "total_count"
    }
}

struct UserListResponse: Decodable {
    let users: [UserProfile]
    let totalCount: Int64
    let page: Int
    let pageSize: Int
    let pagination: PaginationMeta?

    enum CodingKeys: String, CodingKey {
        case users
        case totalCount = "total_count"
        case page
        case pageSize = "page_size"
        case pagination
    }
}

struct PaginationMeta: Decodable {
    let page: Int
    let perPage: Int
    let total: Int64
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page
        case perPage = "per_page"
        case total
        case totalPages = "total_pages"
    }
}
