import Foundation

struct ReadingList: Codable, Identifiable {
    let id: String
    let userID: String
    let username: String
    let title: String
    let description: String?
    let isPrivate: Bool
    let bookCount: Int64
    let saveCount: Int64
    let isSaved: Bool
    let canEdit: Bool
    let canView: Bool
    let coverURLs: [String]
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, username, title, description
        case userID = "user_id"
        case isPrivate = "is_private"
        case bookCount = "book_count"
        case saveCount = "save_count"
        case isSaved = "is_saved"
        case canEdit = "can_edit"
        case canView = "can_view"
        case coverURLs = "cover_urls"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserListsResponse: Decodable {
    let ownLists: [ReadingList]
    let savedLists: [ReadingList]

    enum CodingKeys: String, CodingKey {
        case ownLists = "own_lists"
        case savedLists = "saved_lists"
    }
}

struct BookWithStatus: Codable, Identifiable {
    let id: String
    let volumeInfo: Book.VolumeInfo
    let paperboxdStats: Book.PaperboxdStats?
    let googleBooksId: String?
    let slug: String?
    let status: String
    let rating: Int?
    let finishedAt: String?
    let addedAt: String

    enum CodingKeys: String, CodingKey {
        case id, slug, status, rating
        case volumeInfo
        case paperboxdStats
        case googleBooksId
        case finishedAt = "finished_at"
        case addedAt = "added_at"
    }

    var title: String { volumeInfo.title }
    var authors: [String] { volumeInfo.authors ?? [] }
    var coverURL: String? {
        let links = volumeInfo.imageLinks
        let raw = links?.large ?? links?.medium ?? links?.thumbnail ?? links?.smallThumbnail
        return raw?.replacingOccurrences(of: "http://", with: "https://")
    }
}

struct BookshelfResponse: Decodable {
    let books: [BookWithStatus]
    let totalCount: Int64
    let page: Int
    let pageSize: Int
    let pagination: PaginationMeta?

    enum CodingKeys: String, CodingKey {
        case books
        case totalCount = "total_count"
        case page
        case pageSize = "page_size"
        case pagination
    }
}

struct BookWithLikedAt: Codable, Identifiable {
    let id: String
    let volumeInfo: Book.VolumeInfo
    let paperboxdStats: Book.PaperboxdStats?
    let googleBooksId: String?
    let slug: String?
    let likedAt: String

    enum CodingKeys: String, CodingKey {
        case id, slug, volumeInfo, paperboxdStats, googleBooksId
        case likedAt = "liked_at"
    }

    var title: String { volumeInfo.title }
    var authors: [String] { volumeInfo.authors ?? [] }
    var coverURL: String? {
        let links = volumeInfo.imageLinks
        let raw = links?.large ?? links?.medium ?? links?.thumbnail ?? links?.smallThumbnail
        return raw?.replacingOccurrences(of: "http://", with: "https://")
    }
}

struct LikesResponse: Decodable {
    let books: [BookWithLikedAt]
    let totalCount: Int64
    let page: Int
    let pageSize: Int
    let pagination: PaginationMeta?

    enum CodingKeys: String, CodingKey {
        case books
        case totalCount = "total_count"
        case page
        case pageSize = "page_size"
        case pagination
    }
}

/// One author the user has read, from GET /api/v1/users/{username}/authors.
struct AuthorSummary: Codable, Identifiable {
    let name: String
    let bookCount: Int
    let cover: String?

    enum CodingKeys: String, CodingKey {
        case name, cover
        case bookCount = "book_count"
    }

    var id: String { name }
    var coverURL: String? { (cover?.isEmpty ?? true) ? nil : cover }
}

struct TBRItem: Codable, Identifiable {
    let id: String
    let bookID: String
    let book: Book
    let status: String
    let tbrNotes: String?
    let tbrPriority: String?
    let tbrAddedAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, book, status
        case bookID = "book_id"
        case tbrNotes = "tbr_notes"
        case tbrPriority = "tbr_priority"
        case tbrAddedAt = "tbr_added_at"
        case createdAt = "created_at"
    }
}
