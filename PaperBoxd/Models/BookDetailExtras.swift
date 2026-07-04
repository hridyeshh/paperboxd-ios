import Foundation

/// One friend who has the current book on their shelf.
/// Source: GET /api/v1/books/{id}/friends-reading
struct FriendOnBook: Codable, Identifiable {
    let userID: String
    let username: String
    let name: String
    let avatarURL: String?
    let status: String
    let currentPage: Int?
    let startedAt: String?

    var id: String { userID }
    var displayName: String { name.isEmpty ? username : name }
    var isReadingNow: Bool { status == "reading" }

    enum CodingKeys: String, CodingKey {
        case username, name, status
        case userID = "user_id"
        case avatarURL = "avatar_url"
        case currentPage = "current_page"
        case startedAt = "started_at"
    }
}

struct FriendsReadingResponse: Decodable {
    let friends: [FriendOnBook]
    let readingCount: Int

    enum CodingKeys: String, CodingKey {
        case friends
        case readingCount = "reading_count"
    }
}

/// One review from a friend on the current book.
/// Source: GET /api/v1/books/{id}/reviews/friends
struct FriendBookReview: Codable, Identifiable {
    let userID: String
    let username: String
    let name: String
    let avatarURL: String?
    let rating: Int?
    let review: String?
    let reviewedAt: String?
    let edited: Bool

    var id: String { userID }
    var displayName: String { name.isEmpty ? username : name }

    enum CodingKeys: String, CodingKey {
        case username, name, rating, review, edited
        case userID = "user_id"
        case avatarURL = "avatar_url"
        case reviewedAt = "reviewed_at"
    }
}

struct FriendReviewsResponse: Decodable {
    let reviews: [FriendBookReview]
}

/// One public review on the current book, from any reader.
/// Source: GET /api/v1/books/{id}/reviews
struct BookReview: Codable, Identifiable {
    let userID: String
    let username: String
    let avatarURL: String?
    let rating: Int?
    let review: String?
    let reviewedAt: String?
    let edited: Bool

    var id: String { userID }

    enum CodingKeys: String, CodingKey {
        case username, rating, review, edited
        case userID = "user_id"
        case avatarURL = "avatar_url"
        case reviewedAt = "reviewed_at"
    }
}

struct BookReviewsResponse: Decodable {
    let reviews: [BookReview]
}

/// Reading progress on a specific book for the authenticated user.
/// Source: GET /api/v1/users/{username}/bookshelf/{bookId}/progress
struct ReadingProgress: Decodable {
    let onShelf: Bool
    let status: String
    let currentPage: Int?
    let totalPages: Int?
    let percent: Double?
    let estimatedFinishDate: String?
    let startedAt: String?
    let finishedAt: String?

    var isReading: Bool { status == "reading" || (currentPage ?? 0) > 0 && status != "read" }

    enum CodingKeys: String, CodingKey {
        case status
        case onShelf = "on_shelf"
        case currentPage = "current_page"
        case totalPages = "total_pages"
        case percent
        case estimatedFinishDate = "estimated_finish_date"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
    }
}
