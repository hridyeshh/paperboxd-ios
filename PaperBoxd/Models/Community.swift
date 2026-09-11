import Foundation

/// GET /api/v1/community — the public "what is happening" snapshot. Only the
/// parts the home screen renders are decoded; lists and readers ship on the
/// web first (Phase 2) and land here with the discovery tab.
struct CommunityResponse: Decodable {
    let trendingBooks: [Book]
    let activity: [FriendActivity]
    /// Phase 6 discovery shelves. Each entry carries a server-authored `label`
    /// stating the number that earned its place ("shelved by 7 readers this
    /// week"), so no client has to invent the claim.
    let rising: [CommunityShelfBook]
    let mostTBR: [CommunityShelfBook]
    let hiddenGems: [CommunityShelfBook]

    enum CodingKeys: String, CodingKey {
        case trendingBooks = "trending_books"
        case activity, rising
        case mostTBR = "most_tbr"
        case hiddenGems = "hidden_gems"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        trendingBooks = try c.decodeIfPresent([Book].self, forKey: .trendingBooks) ?? []
        activity = try c.decodeIfPresent([FriendActivity].self, forKey: .activity) ?? []
        rising = try c.decodeIfPresent([CommunityShelfBook].self, forKey: .rising) ?? []
        mostTBR = try c.decodeIfPresent([CommunityShelfBook].self, forKey: .mostTBR) ?? []
        hiddenGems = try c.decodeIfPresent([CommunityShelfBook].self, forKey: .hiddenGems) ?? []
    }
}

/// A book on a discovery shelf: the book itself plus the reason it is there.
struct CommunityShelfBook: Decodable {
    let book: Book
    let label: String

    private enum CodingKeys: String, CodingKey { case label }

    init(from decoder: Decoder) throws {
        book = try Book(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
    }
}

/// GET /api/v1/books/{id}/social — what Paperboxd readers did with a book.
/// `books.average_rating` is the publisher's number; this one is ours.
struct BookSocialResponse: Decodable {
    struct Readers: Decodable {
        let rating: Double?
        let ratingsCount: Int
        let reads: Int
        let reading: Int
        let tbr: Int
        let tbr30d: Int

        enum CodingKeys: String, CodingKey {
            case rating, reads, reading, tbr
            case ratingsCount = "ratings_count"
            case tbr30d = "tbr_30d"
        }
    }
    let readers: Readers
}
