import Foundation

struct FriendActivity: Codable, Identifiable {
    let id: String
    let userID: String
    let username: String
    let name: String
    let avatarURL: String?
    let activityType: String
    let bookID: String?
    let bookTitle: String?
    let bookSlug: String?
    let listID: String?
    let listTitle: String?
    let createdAt: String
    /// Per-type extras from the Go row; `rating` on "rated" / "finished_reading".
    var metadata: ActivityMetadata? = nil
    /// Only the community feed sends a cover inline.
    var bookCover: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, username, name, metadata
        case userID = "user_id"
        case avatarURL = "avatar_url"
        case activityType = "activity_type"
        case bookID = "book_id"
        case bookTitle = "book_title"
        case bookSlug = "book_slug"
        case bookCover = "book_cover"
        case listID = "list_id"
        case listTitle = "list_title"
        case createdAt = "created_at"
    }

    /// Verb for "<name> <verb> <title>". Types are the ones the Go backend
    /// writes (handler/bookshelf.go shelfActivityType, thoughts.go, lists.go);
    /// the fallback turns any newer type into readable words.
    var verbPhrase: String {
        let stars = metadata?.rating.map { " " + String(repeating: "★", count: min(5, max(0, $0))) } ?? ""
        switch activityType {
        case "finished_reading":     return "finished" + stars
        case "started_reading":      return "started reading"
        case "wants_to_read":        return "wants to read"
        case "rated":                return "rated" + stars
        case "added_book":           return "shelved"
        case "created_thought":      return "wrote about"
        case "liked_thought":        return "liked a thought on"
        case "reposted_thought":     return "reposted a thought on"
        case "created_list":         return "made a list"
        case "shared_list":          return "shared a list"
        case "shared_book":          return "shared"
        case "fusion_joined":        return "fused with you. Tap to play your Fusion"
        default:                     return activityType.replacingOccurrences(of: "_", with: " ")
        }
    }

    var objectTitle: String? {
        bookTitle ?? listTitle
    }

    var displayName: String {
        name.isEmpty ? username : name.split(separator: " ").first.map(String.init) ?? name
    }

    /// Parses the backend's RFC3339 timestamp (with or without fractional seconds).
    var createdDate: Date? { ISO8601.parse(createdAt) }

    var relativeTime: String {
        guard let date = createdDate else { return "" }
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "now" }
        if diff < 3600 { return "\(Int(diff / 60))m" }
        if diff < 86400 { return "\(Int(diff / 3600))h" }
        return "\(Int(diff / 86400))d"
    }
}

struct ActivityMetadata: Codable {
    let rating: Int?
    /// Set on "fusion_joined": the Fusion the tap should open.
    var fusionID: String? = nil

    enum CodingKeys: String, CodingKey {
        case rating
        case fusionID = "fusion_id"
    }
}

/// Shared ISO8601 parser that tolerates fractional seconds, which Go's
/// encoding/json emits for time.Time values.
enum ISO8601 {
    private static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ string: String) -> Date? {
        withFractional.date(from: string) ?? plain.date(from: string)
    }
}

struct FollowingActivitiesResponse: Decodable {
    let activities: [FriendActivity]
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case activities
        case page
        case pageSize = "page_size"
    }
}

struct TodayProgress: Decodable {
    let todayPages: Int
    let todayBooks: Int
    let lastBook: TodayLastBook?
    let weekBars: [WeekBar]

    enum CodingKeys: String, CodingKey {
        case todayPages = "today_pages"
        case todayBooks = "today_books"
        case lastBook = "last_book"
        case weekBars = "week_bars"
    }
}

struct TodayLastBook: Decodable {
    let bookID: String
    let title: String
    let slug: String
    let author: String
    let cover: String
    let currentPage: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case bookID = "book_id"
        case title, slug, author, cover
        case currentPage = "current_page"
        case totalPages = "total_pages"
    }

    var progressPercent: Int {
        guard totalPages > 0 else { return 0 }
        return Int((Double(currentPage) / Double(totalPages) * 100).rounded())
    }
}

struct WeekBar: Decodable {
    let date: String
    let pages: Int
    let books: Int
}
