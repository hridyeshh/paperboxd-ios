import Foundation

struct DiaryEntry: Codable, Identifiable {
    let id: String
    let userID: String
    let username: String
    let name: String
    let avatarURL: String?
    let bookID: String?
    let book: Book?
    let title: String?
    let content: String
    let isPrivate: Bool
    let rating: Int?
    let likesCount: Int64
    let isLiked: Bool
    let canEdit: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, username, name, title, content, rating, book
        case userID = "user_id"
        case avatarURL = "avatar_url"
        case bookID = "book_id"
        case isPrivate = "is_private"
        case likesCount = "likes_count"
        case isLiked = "is_liked"
        case canEdit = "can_edit"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var plainTextPreview: String {
        let stripped = content
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(stripped.prefix(200))
    }
}

struct DiaryEntriesResponse: Decodable {
    let entries: [DiaryEntry]
    let totalCount: Int64
    let page: Int
    let pageSize: Int
    let pagination: PaginationMeta?

    enum CodingKeys: String, CodingKey {
        case entries
        case totalCount = "total_count"
        case page
        case pageSize = "page_size"
        case pagination
    }
}
