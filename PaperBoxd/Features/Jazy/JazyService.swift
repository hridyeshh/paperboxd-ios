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

/// One turn with Jazy: either a deck, or one clarifying question.
///
/// Mirrors `service.ConciergeResponse`. `question` is set when Jazy wants one
/// thing settled before answering; the client re-sends the same query with the
/// tapped option as `answer`.
struct JazyTurn: Decodable {
    let kind: String
    let sessionId: String
    let query: String
    let question: String?
    let options: [String]?
    let intro: String?
    let personalised: Bool
    let items: [VibeMatch]
    /// The accumulated ask ("like Murakami · under 300 pages") and whether
    /// this turn refined the previous one rather than starting over.
    var understood: String? = nil
    var refined: Bool = false

    var isQuestion: Bool { kind == "jazy#question" && question != nil }
}

enum JazyService {
    /// POST /api/v1/search/vibe — auth is optional, results are personalised when signed in.
    /// Kept for the deck's "more like this" path; new asks go through `ask`.
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

    /// POST /api/v1/jazy — the concierge. Plus-only: 402 SUBSCRIPTION_REQUIRED
    /// without an active subscription.
    ///
    /// `sessionId` carries the conversation so "shorter" after "like Murakami"
    /// is read as a refinement. `answer` is the reply to a previous question.
    static func ask(
        _ query: String,
        sessionId: String? = nil,
        answer: String? = nil,
        limit: Int = 5
    ) async throws -> JazyTurn {
        struct Body: Encodable {
            let query: String
            let limit: Int
            let sessionId: String?
            let answer: String?
            let anonId: String?

            enum CodingKeys: String, CodingKey {
                case query, limit, answer
                case sessionId = "session_id"
                case anonId = "anon_id"
            }
        }
        return try await APIClient.shared.request(
            path: "/api/v1/jazy",
            method: .post,
            body: Body(query: query, limit: limit, sessionId: sessionId, answer: answer, anonId: AnonID.current),
            requiresAuth: true
        )
    }
}

/// A stable per-install id so a logged-out reader can still hold a search
/// conversation. Same contract as the web's `pb_anon_id`.
enum AnonID {
    private static let key = "pb_anon_id"
    static var current: String {
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let fresh = UUID().uuidString.lowercased()
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }
}
