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

    enum CodingKeys: String, CodingKey {
        case id, title, authors, categories, reason
        case coverURL = "cover_url"
        case similarityScore = "similarity_score"
        case reasonType = "reasonType"
    }

    var authorLine: String {
        authors.isEmpty ? "" : authors.joined(separator: ", ")
    }
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
