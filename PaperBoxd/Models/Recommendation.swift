import Foundation

/// Flat recommendation from GET /api/v1/recommendations/home or
/// GET /api/v1/recommendations/similar/{id}. Maps to service.BookCandidate.
struct RecommendationItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let authors: [String]
    let coverURL: String?
    let categories: [String]
    let similarityScore: Double?
    let reason: String?
    let reasonType: String?
    /// Confidence tier as a sentence ("Wild card"); the number is never sent.
    /// `var` with a default so the memberwise initialisers stay unchanged.
    var confidence: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, title, authors, categories, reason, confidence
        case coverURL = "cover_url"
        case similarityScore = "similarity_score"
        case reasonType = "reasonType"
    }

    var authorLine: String {
        authors.isEmpty ? "" : authors.joined(separator: ", ")
    }
}

/// One section of the modular home. Mirrors `service.FeedModule`: the
/// server writes the title and the reason on every book, so all three
/// clients say the same thing and copy changes without a release.
struct FeedModule: Decodable, Identifiable {
    let kind: String
    let title: String
    let subtitle: String?
    let books: [RecommendationItem]

    var id: String { kind }
}

/// Response for GET /api/v1/recommendations/feed
struct FeedResponse: Decodable {
    let greeting: String?
    let modules: [FeedModule]
}

/// Response for GET /api/v1/recommendations/home
struct HomeRecommendationsResponse: Decodable {
    let recommendations: [RecommendationItem]
    let source: String?
}

/// Response for GET /api/v1/recommendations/similar/{bookId}
struct SimilarBooksResponse: Decodable {
    let similar: [RecommendationItem]
}
