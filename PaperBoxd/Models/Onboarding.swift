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

/// Backend cap on favourites (Top 4). The "books you love" step reuses it so a
/// pick never fails on the favourites write.
let onboardingMaxPicks = 4

/// One row of GET /api/v1/users/suggested. `reason` is authored by the server
/// so web, iOS and Android show the same explanation.
struct SuggestedReader: Decodable, Identifiable, Equatable {
    let id: String
    let username: String
    let name: String?
    let avatarURL: String?
    let bio: String?
    let booksReadCount: Int
    let followersCount: Int
    let sharedGenres: [String]
    let reason: String

    enum CodingKeys: String, CodingKey {
        case id, username, name, bio, reason
        case avatarURL = "avatar_url"
        case booksReadCount = "books_read_count"
        case followersCount = "followers_count"
        case sharedGenres = "shared_genres"
    }

    var displayName: String { (name?.isEmpty == false ? name : nil) ?? username }
}

struct SuggestedReadersResponse: Decodable {
    let users: [SuggestedReader]
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

    /// A search hit (Google-volumes shape) as a pick candidate.
    init(searchResult book: Book) {
        self.id = book.id
        self.title = book.volumeInfo.title
        self.authors = book.volumeInfo.authors ?? []
        self.coverURL = book.coverURL
        self.reason = nil
    }

    init(id: String, title: String, authors: [String], coverURL: String?, reason: String?) {
        self.id = id
        self.title = title
        self.authors = authors
        self.coverURL = coverURL
        self.reason = reason
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
