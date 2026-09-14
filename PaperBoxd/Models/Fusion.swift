import Foundation

// Fusion — two readers' shelves side by side, made from a one-time link.
// Shapes mirror internal/service/fusion.go and fusion_view.go in the backend.

struct FusionPerson: Codable, Hashable {
    let userID: String
    let username: String
    let name: String
    let first: String
    let avatarURL: String?

    var initial: String { String((first.first ?? username.first ?? "?")).uppercased() }

    enum CodingKeys: String, CodingKey {
        case username, name, first
        case userID = "user_id"
        case avatarURL = "avatar_url"
    }
}

struct FusionInvite: Codable, Equatable {
    let token: String
    let url: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case token, url
        case expiresAt = "expires_at"
    }

    /// Whole days left, for "6 days left". Never below 1 while the link is live.
    var daysLeft: Int {
        guard let date = ISO8601.parse(expiresAt) else { return 7 }
        return max(1, Int((date.timeIntervalSinceNow / 86_400).rounded(.up)))
    }
}

struct FusionInvitePreview: Codable {
    enum Status: String, Codable {
        case valid, expired, used, own, joined, unavailable
    }

    let status: Status
    let inviter: FusionPerson?
    let fusionID: String?

    enum CodingKeys: String, CodingKey {
        case status, inviter
        case fusionID = "fusion_id"
    }
}

struct FusionAcceptResponse: Codable {
    let fusionID: String
    enum CodingKeys: String, CodingKey { case fusionID = "fusion_id" }
}

struct FusionSummary: Codable, Identifiable {
    let id: String
    let them: FusionPerson
    let score: Int?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, them, score
        case createdAt = "created_at"
    }
}

struct FusionList: Codable {
    let invite: FusionInvite?
    let fusions: [FusionSummary]
}

struct FusionBook: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let slug: String?
    let authors: [String]
    let coverURL: String?
    let you: Int?
    let them: Int?
    let reason: String?
    let match: String?

    var author: String { authors.first ?? "" }

    enum CodingKeys: String, CodingKey {
        case id, title, slug, authors, you, them, reason, match
        case coverURL = "cover_url"
    }
}

struct FusionAgree: Codable, Hashable {
    /// "axis" (a taste axis) or "genre" (shelf-share fallback).
    let kind: String
    let key: String
    let phrase: String
    let you: Int
    let them: Int
}

struct FusionSplit: Codable, Hashable {
    let label: String
    let you: String
    let them: String
}

struct FusionReason: Codable, Hashable {
    /// "both", "you" or "them".
    let who: String
    let text: String
}

struct FusionPick: Codable, Hashable {
    let book: FusionBook
    let label: String
    let reasons: [FusionReason]
}

/// The whole story from the viewer's side. Empty arrays and nil picks mean
/// "no honest content" — the player skips those pages.
struct FusionStory: Codable {
    let id: String
    let me: FusionPerson
    let them: FusionPerson
    let score: Int
    let scoreLine: String

    let sharedCount: Int
    let agreement: Int
    let lovedCount: Int
    let sharedAuthors: [String]
    let sharedGenres: [String]

    let sharedLoved: [FusionBook]
    let agree: [FusionAgree]
    let splits: [FusionSplit]
    let disagreement: FusionBook?
    let forYou: [FusionBook]
    let forThem: [FusionBook]
    let pick: FusionPick?
    let also: [FusionBook]
    let wildcard: FusionPick?
    let both: [FusionBook]

    let waitingCount: Int
    let verdict: String
    let verdictSub: String
    let lowData: Bool

    enum CodingKeys: String, CodingKey {
        case id, me, them, score, agreement, agree, splits, disagreement, pick, also, wildcard, both, verdict
        case scoreLine = "score_line"
        case sharedCount = "shared_count"
        case lovedCount = "loved_count"
        case sharedAuthors = "shared_authors"
        case sharedGenres = "shared_genres"
        case sharedLoved = "shared_loved"
        case forYou = "for_you"
        case forThem = "for_them"
        case waitingCount = "waiting_count"
        case verdictSub = "verdict_sub"
        case lowData = "low_data"
    }
}
