import Foundation

/// Full book detail. Maps to types.BookResponse from the Go backend.
/// The backend wraps metadata in a nested `volumeInfo` to mirror Google Books API shape.
struct Book: Codable, Identifiable, Hashable {
    let id: String
    let slug: String?
    let volumeInfo: VolumeInfo
    let paperboxdStats: PaperboxdStats?
    let googleBooksId: String?
    let apiSource: String?

    enum CodingKeys: String, CodingKey {
        case id, slug
        case volumeInfo = "volumeInfo"
        case paperboxdStats = "paperboxdStats"
        case googleBooksId = "googleBooksId"
        case apiSource = "apiSource"
    }

    // MARK: - Convenience

    var title: String { volumeInfo.title }
    var authors: [String] { volumeInfo.authors ?? [] }
    var authorLine: String { authors.isEmpty ? "" : authors.joined(separator: ", ") }
    var description: String? {
        guard let d = volumeInfo.description, !d.isEmpty else { return nil }
        return d
    }
    var pageCount: Int? {
        guard let p = volumeInfo.pageCount, p > 0 else { return nil }
        return p
    }
    var publishedYear: String? {
        guard let d = volumeInfo.publishedDate, d.count >= 4 else { return nil }
        return String(d.prefix(4))
    }
    var categories: [String] { volumeInfo.categories ?? [] }
    var averageRating: Double? { volumeInfo.averageRating }

    /// Best available cover URL, largest to smallest. Forces HTTPS (Google Books returns http://).
    var coverURL: String? {
        let links = volumeInfo.imageLinks
        let raw = links?.large ?? links?.medium ?? links?.thumbnail ?? links?.small ?? links?.smallThumbnail
        return raw?.replacingOccurrences(of: "http://", with: "https://")
    }
}

// MARK: - VolumeInfo

extension Book {
    struct VolumeInfo: Codable, Hashable {
        let title: String
        let authors: [String]?
        let publishedDate: String?
        let description: String?
        let pageCount: Int?
        let categories: [String]?
        let imageLinks: ImageLinks?
        let averageRating: Double?
        let publisher: String?
        let language: String?

        enum CodingKeys: String, CodingKey {
            case title, authors, description, categories, publisher, language
            case publishedDate = "publishedDate"
            case pageCount = "pageCount"
            case imageLinks = "imageLinks"
            case averageRating = "averageRating"
        }
    }

    struct ImageLinks: Codable, Hashable {
        let smallThumbnail: String?
        let thumbnail: String?
        let small: String?
        let medium: String?
        let large: String?
        let extraLarge: String?
    }

    struct PaperboxdStats: Codable, Hashable {
        let rating: Double?
        let ratingsCount: Int?
        let totalReads: Int?
        let totalLikes: Int?
        let totalTBR: Int?
    }
}
