import Foundation

/// A thought (types.ThoughtResponse). Swift still calls it DiaryEntry; the API
/// and backend call it a thought.
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
    var repostsCount: Int64 = 0
    var isReposted: Bool = false
    /// Set on a follow-up: the thought that started its thread.
    var threadRootID: String? = nil
    /// Follow-ups under a thread-starting thought; 0 on follow-ups.
    var threadCount: Int64 = 0
    /// Set when the row is on a profile because that reader reposted it.
    var repostedBy: Reposter? = nil

    struct Reposter: Codable, Hashable {
        let username: String
        let name: String
    }

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
        case repostsCount = "reposts_count"
        case isReposted = "is_reposted"
        case threadRootID = "thread_root_id"
        case threadCount = "thread_count"
        case repostedBy = "reposted_by"
    }

    var displayName: String { name.isEmpty ? username : name }

    /// List identity: a repost and the original can share a page, so `id` alone collides.
    var rowKey: String { repostedBy.map { "\(id)-repost-\($0.username)" } ?? id }

    var plainTextPreview: String {
        String(plainText.prefix(280))
    }

    /// Stored content is rich-text HTML from the web editor or plain text from
    /// the apps; both read as paragraphs here.
    var plainText: String {
        content
            .replacingOccurrences(of: "</p>|<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct DiaryEntriesResponse: Decodable {
    let thoughts: [DiaryEntry]
    let totalCount: Int64
    let page: Int
    let pageSize: Int
    let pagination: PaginationMeta?

    enum CodingKeys: String, CodingKey {
        case thoughts
        case totalCount = "total_count"
        case page
        case pageSize = "page_size"
        case pagination
    }
}

/// GET /api/v1/users/{username}/thoughts/{id}/thread
struct ThoughtThreadResponse: Decodable {
    let thoughts: [DiaryEntry]
}

/// Like/unlike and repost/unrepost answer with the fresh count.
struct ThoughtCountResponse: Decodable {
    let likesCount: Int64?
    let repostsCount: Int64?

    enum CodingKeys: String, CodingKey {
        case likesCount = "likes_count"
        case repostsCount = "reposts_count"
    }
}
