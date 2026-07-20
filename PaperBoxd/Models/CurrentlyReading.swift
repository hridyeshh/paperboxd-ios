import Foundation

/// Maps backend types.CurrentlyReadingResponse from GET /api/v1/users/{username}/reading.
struct CurrentlyReading: Codable, Identifiable {
    let id: String
    let bookID: String
    let book: Book
    let status: String
    let currentPage: Int?
    let progressPercentage: Double
    let pagesRemaining: Int
    let startedAt: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, book, status
        case bookID = "book_id"
        case currentPage = "current_page"
        case progressPercentage = "progress_percentage"
        case pagesRemaining = "pages_remaining"
        case startedAt = "started_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var totalPages: Int? { book.pageCount }
    var displayPercent: Int { Int(progressPercentage.rounded()) }
}

/// The user's most-recently logged book, from GET /api/v1/users/{username}/reading/last.
/// Maps the backend's TodayLastBook shape. Unlike /reading, this is the real last
/// book the user logged progress on regardless of date.
struct LastLoggedBook: Codable, Identifiable {
    let bookID: String
    let title: String
    let slug: String
    let author: String
    let cover: String
    let currentPage: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case title, slug, author, cover
        case bookID = "book_id"
        case currentPage = "current_page"
        case totalPages = "total_pages"
    }

    var id: String { bookID }
    var coverURL: String? { cover.isEmpty ? nil : cover }
    var displayPercent: Int {
        guard totalPages > 0 else { return 0 }
        return min(100, Int((Double(currentPage) / Double(totalPages) * 100).rounded()))
    }
}

struct LastLoggedBookResponse: Decodable {
    let lastBook: LastLoggedBook?

    enum CodingKeys: String, CodingKey {
        case lastBook = "last_book"
    }
}
