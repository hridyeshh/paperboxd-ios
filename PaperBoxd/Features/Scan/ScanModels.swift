import SwiftUI

// MARK: - Backend wire models (POST /api/v1/scan/analyze)

struct ScanAnalyzeResponse: Decodable {
    let book: ScanBook
    let score: ScanScore
    let sources: ScanSources?
    let scansRemaining: Int?

    enum CodingKeys: String, CodingKey {
        case book, score, sources
        case scansRemaining = "scans_remaining"
    }
}

/// Real source counts for the analyzing screen. readers/ratings/rating come from
/// Hardcover (Goodreads-style community); shelf = books the reader has read;
/// friends = followed users who own it.
struct ScanSources: Decodable {
    let readers: Int
    let ratings: Int
    let rating: Double?   // community average, 0–5
    let shelf: Int
    let friends: Int
}

struct ScanBook: Decodable {
    let isbn: String
    let title: String
    let authors: [String]
    let genres: [String]
    let pages: Int
    let description: String?
    let coverURL: String?

    enum CodingKeys: String, CodingKey {
        case isbn, title, authors, genres, pages, description
        case coverURL = "cover_url"
    }
}

struct ScanScore: Decodable {
    let overallScore: Int
    let dimensions: ScanDimensions
    let verdict: String
    let forYou: [String]
    let againstYou: [String]
    let oneLine: String

    enum CodingKeys: String, CodingKey {
        case overallScore = "overall_score"
        case dimensions, verdict
        case forYou = "for_you"
        case againstYou = "against_you"
        case oneLine = "one_line"
    }
}

struct ScanDimensions: Decodable {
    let genreFit: Int
    let writingStyle: Int
    let lengthComplexity: Int
    let communityLove: Int
    let personalFit: Int

    enum CodingKeys: String, CodingKey {
        case genreFit = "genre_fit"
        case writingStyle = "writing_style"
        case lengthComplexity = "length_complexity"
        case communityLove = "community_love"
        case personalFit = "personal_fit"
    }
}

// MARK: - View model

/// Everything the reveal + breakdown screens render. Built from the backend response
/// — no hardcoded book or score.
struct ScanResult {
    let isbn: String
    let title: String
    let author: String
    let pages: Int
    let genres: [String]
    let coverURL: String?
    let matchScore: Int          // 0...100
    let verdict: String
    let oneLine: String
    let dimensions: [Dimension]  // five radar axes
    let forYou: [String]
    let againstYou: [String]
    let coverColor: Color
    /// "The internet" rating (e.g. Goodreads avg). Not always supplied by the backend.
    let internetRating: Double?
    /// Human ratings count, e.g. "23.4k". Optional.
    let ratingsCount: String?
    /// Real source counts shown on the analyzing screen (from the backend).
    let readersCount: Int
    let communityRatings: Int
    let shelfCount: Int
    let friendsCount: Int

    struct Dimension: Identifiable {
        let id = UUID()
        let name: String
        let value: Double         // 0...1
    }

    /// Reveal sub-line: anchors the personal score against the crowd's average.
    var verdictSub: String {
        if let r = internetRating {
            return "Goodreads says \(String(format: "%.2f", r))★ — but this is read against your shelf."
        }
        return oneLine
    }

    /// "Why this score, for you" — positives first (✓), then caveats (✗).
    var reasons: [(ok: Bool, text: String)] {
        forYou.map { (true, $0) } + againstYou.map { (false, $0) }
    }

    init(isbn: String = "", title: String, author: String, pages: Int, genres: [String], coverURL: String?,
         matchScore: Int, verdict: String, oneLine: String, dimensions: [Dimension],
         forYou: [String], againstYou: [String], coverColor: Color,
         internetRating: Double? = nil, ratingsCount: String? = nil,
         readersCount: Int = 0, communityRatings: Int = 0, shelfCount: Int = 0, friendsCount: Int = 0) {
        self.isbn = isbn
        self.title = title
        self.author = author
        self.pages = pages
        self.genres = genres
        self.coverURL = coverURL
        self.matchScore = matchScore
        self.verdict = verdict
        self.oneLine = oneLine
        self.dimensions = dimensions
        self.forYou = forYou
        self.againstYou = againstYou
        self.coverColor = coverColor
        self.internetRating = internetRating
        self.ratingsCount = ratingsCount
        self.readersCount = readersCount
        self.communityRatings = communityRatings
        self.shelfCount = shelfCount
        self.friendsCount = friendsCount
    }

    init(response: ScanAnalyzeResponse) {
        let d = response.score.dimensions
        self.init(
            isbn: response.book.isbn,
            title: response.book.title,
            author: response.book.authors.first ?? "Unknown",
            pages: response.book.pages,
            genres: response.book.genres,
            coverURL: response.book.coverURL,
            matchScore: response.score.overallScore,
            verdict: response.score.verdict,
            oneLine: response.score.oneLine,
            // Each Claude dimension is scored out of 20, so normalize by 20 to fill
            // the radar (0...1). Dividing by 100 kept every axis under 0.2 → tiny blob.
            dimensions: [
                .init(name: "Genre fit", value: Double(d.genreFit) / 20),
                .init(name: "Writing", value: Double(d.writingStyle) / 20),
                .init(name: "Depth", value: Double(d.lengthComplexity) / 20),
                .init(name: "Community", value: Double(d.communityLove) / 20),
                .init(name: "For you", value: Double(d.personalFit) / 20),
            ],
            forYou: response.score.forYou,
            againstYou: response.score.againstYou,
            coverColor: ScanResult.fallbackColor(for: response.book.title),
            internetRating: (response.sources?.rating).flatMap { $0 > 0 ? $0 : nil },
            ratingsCount: ScanResult.compactCount(response.sources?.ratings ?? 0),
            readersCount: response.sources?.readers ?? 0,
            communityRatings: response.sources?.ratings ?? 0,
            shelfCount: response.sources?.shelf ?? 0,
            friendsCount: response.sources?.friends ?? 0
        )
    }

    /// Deterministic muted spine color when no cover art is available.
    static func fallbackColor(for title: String) -> Color {
        let hue = Double(abs(title.hashValue) % 1000) / 1000
        return Color(hue: hue, saturation: 0.28, brightness: 0.34)
    }

    /// Compact human count, e.g. 1896 → "1.9k", 662 → "662". Returns nil for 0.
    static func compactCount(_ n: Int) -> String? {
        guard n > 0 else { return nil }
        if n < 1000 { return "\(n)" }
        let k = Double(n) / 1000
        return String(format: k < 10 ? "%.1fk" : "%.0fk", k)
    }

    static let mock = ScanResult(
        title: "The Inner Game of Tennis",
        author: "W. Timothy Gallwey",
        pages: 134,
        genres: ["Self-help", "Sports"],
        coverURL: nil,
        matchScore: 81,
        verdict: "Strong match for you",
        oneLine: "Read against your shelf, not the crowd's.",
        dimensions: [
            .init(name: "Genre fit", value: 0.86),
            .init(name: "Writing", value: 0.72),
            .init(name: "Depth", value: 0.68),
            .init(name: "Community", value: 0.60),
            .init(name: "For you", value: 0.80),
        ],
        forYou: ["You finish short, idea-dense books — this one's only 134 pages",
                 "Matches the focus & mindfulness reads you rate 4–5★",
                 "3 friends shelved this in the last month"],
        againstYou: ["Light on narrative — you lean toward story-driven nonfiction",
                     "Sport framing sits outside your usual shelves"],
        coverColor: Color(red: 0.18, green: 0.30, blue: 0.22),
        internetRating: 4.08, ratingsCount: "23.4k",
        readersCount: 61321, communityRatings: 1386, shelfCount: 84, friendsCount: 3
    )
}

// MARK: - Service

/// One title-search result usable by the scan flow.
struct ScanSearchHit: Identifiable {
    let id: String
    let title: String
    let author: String
    let isbn: String?
    let coverURL: String?
}

enum ScanService {
    static func analyze(isbn: String) async throws -> ScanResult {
        let response: ScanAnalyzeResponse = try await APIClient.shared.request(
            path: Endpoints.scanAnalyze,
            method: .post,
            body: ["isbn": isbn],
            requiresAuth: true
        )
        return ScanResult(response: response)
    }

    /// Title (or ISBN) search via `/api/v1/books/search`.
    static func search(query: String) async throws -> [ScanSearchHit] {
        var comps = URLComponents(string: Endpoints.searchBooks)!
        comps.queryItems = [URLQueryItem(name: "q", value: query),
                            URLQueryItem(name: "page_size", value: "15")]
        let resp: BookListResponse = try await APIClient.shared.request(
            path: comps.string ?? Endpoints.searchBooks,
            method: .get,
            requiresAuth: false
        )
        return resp.items.map {
            ScanSearchHit(id: $0.id, title: $0.title, author: $0.authorLine,
                          isbn: $0.isbn, coverURL: $0.coverURL)
        }
    }

    /// Best-effort title for a scanned ISBN, to show on the confirmation card.
    static func lookupTitle(isbn: String) async -> String? {
        (try? await search(query: isbn))?.first?.title
    }
}

// MARK: - Cover swatch

/// Book cover — real artwork via the backend `cover_url` when present, otherwise a
/// tinted spine with the title set in serif.
struct BookCoverSwatch: View {
    let result: ScanResult
    var width: CGFloat = 38

    var body: some View {
        Group {
            if let raw = result.coverURL,
               let url = URL(string: raw.replacingOccurrences(of: "http://", with: "https://")) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        swatch
                    }
                }
            } else {
                swatch
            }
        }
        .frame(width: width, height: width * 1.46)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    private var swatch: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(result.coverColor)
            .overlay(
                Text(result.title)
                    .font(.system(size: width * 0.17, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .padding(width * 0.12)
            )
    }
}
