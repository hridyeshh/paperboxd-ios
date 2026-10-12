import Foundation

/// Where a reader can get the text of a book. Maps to `read_links` on the
/// single-book detail response (backend docs/API.md); never on list items.
/// A store that doesn't carry the book is nil. Amazon and WorldCat are always set.
struct BookReadLinks: Codable, Hashable {
    let googlePlayBuyLink: String?
    let appleBooksUrl: String?
    let amazonSearchUrl: String
    let worldcatUrl: String
    let isPublicDomain: Bool
    let gutenbergId: Int?
    let gutenbergHtmlUrl: String?
    let gutenbergEpubUrl: String?

    enum CodingKeys: String, CodingKey {
        case googlePlayBuyLink = "google_play_buy_link"
        case appleBooksUrl = "apple_books_url"
        case amazonSearchUrl = "amazon_search_url"
        case worldcatUrl = "worldcat_url"
        case isPublicDomain = "is_public_domain"
        case gutenbergId = "gutenberg_id"
        case gutenbergHtmlUrl = "gutenberg_html_url"
        case gutenbergEpubUrl = "gutenberg_epub_url"
    }

    /// Store buttons in display order, nil links dropped.
    var stores: [(label: String, url: URL)] {
        [
            ("Amazon Kindle", amazonSearchUrl),
            ("Google Play Books", googlePlayBuyLink),
            ("Apple Books", appleBooksUrl),
            ("Find at your library", worldcatUrl),
        ].compactMap { label, raw in
            guard let raw, let url = URL(string: raw) else { return nil }
            return (label, url)
        }
    }
}
