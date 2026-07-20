import Foundation

/// One vibe-search match: the book plus why Jazy picked it.
/// Mirrors `types.VibeBookResult` — the same JSON object carries the book
/// fields *and* the score, so it decodes as a flat object, not a nested one.
struct VibeMatch: Decodable, Identifiable {
    let book: Book
    let similarityScore: Double
    /// The "% match" pill. Claude sets it server-side so the number and
    /// `matchReason` make the same claim; raw cosine similarity is the fallback
    /// for a backend running without an Anthropic key.
    let matchPercent: Int
    let matchReason: String
    /// One honest note on what might not land. Empty when Claude is unavailable.
    let matchCaveat: String

    var id: String { book.id }

    private enum Keys: String, CodingKey {
        case similarityScore, matchPercent, matchReason, matchCaveat
    }

    init(from decoder: Decoder) throws {
        book = try Book(from: decoder)
        let c = try decoder.container(keyedBy: Keys.self)
        similarityScore = try c.decodeIfPresent(Double.self, forKey: .similarityScore) ?? 0
        matchReason = try c.decodeIfPresent(String.self, forKey: .matchReason) ?? ""
        matchCaveat = try c.decodeIfPresent(String.self, forKey: .matchCaveat) ?? ""
        let percent = try c.decodeIfPresent(Int.self, forKey: .matchPercent)
            ?? Int((similarityScore * 100).rounded())
        matchPercent = max(0, min(100, percent))
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
