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

    enum CodingKeys: String, CodingKey {
        case id, username, name
        case userID = "user_id"
        case avatarURL = "avatar_url"
        case activityType = "activity_type"
        case bookID = "book_id"
        case bookTitle = "book_title"
        case bookSlug = "book_slug"
        case listID = "list_id"
        case listTitle = "list_title"
        case createdAt = "created_at"
    }

    var verbPhrase: String {
        switch activityType {
        case "book_read":        return "finished"
        case "book_shelved":     return "shelved"
        case "book_reading":     return "started reading"
        case "book_tbr":         return "wants to read"
        case "diary_entry":      return "wrote about"
        case "book_liked":       return "liked"
        case "list_created":     return "made a list"
        case "list_saved":       return "saved a list"
        case "follow":           return "followed"
        default:                 return activityType.replacingOccurrences(of: "_", with: " ")
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
