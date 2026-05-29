import Foundation

/// A selectable genre. `id` is the slug the backend stores in
/// users.favorite_genres; `label` is the chip text. Mirrors the web
/// onboarding-flow GENRES list so web and mobile collect identical slugs.
struct Genre: Identifiable, Hashable {
    let id: String
    let label: String

    static let all: [Genre] = [
        Genre(id: "fiction", label: "Fiction"),
        Genre(id: "mystery", label: "Mystery"),
        Genre(id: "thriller", label: "Thriller"),
        Genre(id: "romance", label: "Romance"),
        Genre(id: "science-fiction", label: "Sci-Fi"),
        Genre(id: "fantasy", label: "Fantasy"),
        Genre(id: "horror", label: "Horror"),
        Genre(id: "historical", label: "Historical"),
        Genre(id: "biography", label: "Biography"),
        Genre(id: "self-help", label: "Self-Help"),
        Genre(id: "business", label: "Business"),
        Genre(id: "non-fiction", label: "Non-Fiction"),
        Genre(id: "young-adult", label: "Young Adult"),
        Genre(id: "classics", label: "Classics"),
        Genre(id: "poetry", label: "Poetry"),
    ]
}

/// Reading tempo option. Cosmetic for now — the backend has no tempo column, so
/// like the web flow we collect it but don't persist it yet.
struct ReadingTempo: Identifiable, Hashable {
    let id: String
    let label: String
    let sub: String

    static let all: [ReadingTempo] = [
        ReadingTempo(id: "casual", label: "Casual", sub: "1–3 books / month"),
        ReadingTempo(id: "regular", label: "Regular", sub: "About 1 / week"),
        ReadingTempo(id: "voracious", label: "Voracious", sub: "Multiple per week"),
    ]
}

/// One recommended book from GET /api/v1/recommendations/home. Mirrors the Go
/// service.BookCandidate JSON shape.
struct RecBook: Decodable, Identifiable, Equatable {
    let id: String
    let title: String
    let authors: [String]
    let coverURL: String?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case id, title, authors, reason
        case coverURL = "cover_url"
    }

    var authorLine: String {
        authors.isEmpty ? "Unknown author" : authors.joined(separator: ", ")
    }
}

struct RecommendationsResponse: Decodable {
    let recommendations: [RecBook]
    let source: String?
}

/// Response from POST /api/v1/users/me/avatar/upload — the backend returns the
/// full user response; we only need the new avatar URL.
struct AvatarUploadResponse: Decodable {
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case avatarURL = "avatar_url"
    }
}

/// Response from PATCH /api/mobile/users/me — { user: <mobileUser> }.
struct MobileUserResponse: Decodable {
    let user: User
}
