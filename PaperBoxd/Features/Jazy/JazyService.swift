import Foundation

/// One vibe-search match: the book plus why Jazy picked it.
/// Mirrors `types.VibeBookResult` — the same JSON object carries the book
/// fields *and* the score, so it decodes as a flat object, not a nested one.
struct VibeMatch: Decodable, Identifiable {
    let book: Book
    let similarityScore: Double
    let matchReason: String

    var id: String { book.id }
    /// 0…1 similarity rendered as the card's "% match" pill.
    var matchPercent: Int { max(0, min(100, Int((similarityScore * 100).rounded()))) }

    private enum Keys: String, CodingKey {
        case similarityScore, matchReason
    }

    init(from decoder: Decoder) throws {
        book = try Book(from: decoder)
        let c = try decoder.container(keyedBy: Keys.self)
        similarityScore = try c.decodeIfPresent(Double.self, forKey: .similarityScore) ?? 0
        matchReason = try c.decodeIfPresent(String.self, forKey: .matchReason) ?? ""
    }
}

struct VibeSearchResponse: Decodable {
    let query: String
    let personalised: Bool
    let items: [VibeMatch]
}

enum JazyService {
    /// POST /api/v1/search/vibe — auth is optional, results are personalised when signed in.
    static func vibeSearch(_ query: String, limit: Int = 5) async throws -> [VibeMatch] {
        struct Body: Encodable { let query: String; let limit: Int }
        let resp: VibeSearchResponse = try await APIClient.shared.request(
            path: "/api/v1/search/vibe",
            method: .post,
            body: Body(query: query, limit: limit),
            requiresAuth: false
        )
        return resp.items
    }
}
