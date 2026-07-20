import Foundation

/// One row of the leaderboard. Maps the backend's statToMap shape from
/// GET /api/v1/leaderboard/* and GET /api/v1/users/me/leaderboard-stats.
struct LeaderboardEntry: Decodable, Identifiable, Equatable {
    let userID: String
    let username: String
    let booksRead: Int
    let pagesRead: Int
    let diaryEntries: Int
    let genresExplored: Int
    let totalXP: Int
    let level: Int
    let currentStreak: Int
    let booksRank: Int?
    let pagesRank: Int?
    let diaryRank: Int?
    let genresRank: Int?
    let xpRank: Int?
    let streakRank: Int?
    let levelName: String
    let levelBadge: String

    var id: String { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case booksRead = "books_read"
        case pagesRead = "pages_read"
        case diaryEntries = "diary_entries"
        case genresExplored = "genres_explored"
        case totalXP = "total_xp"
        case level
        case currentStreak = "current_streak"
        case booksRank = "books_rank"
        case pagesRank = "pages_rank"
        case diaryRank = "diary_rank"
        case genresRank = "genres_rank"
        case xpRank = "xp_rank"
        case streakRank = "streak_rank"
        case levelName = "level_name"
        case levelBadge = "level_badge"
    }
}

/// Wrapper for the list endpoints: { "leaderboard": [...], "count": N }.
struct LeaderboardResponse: Decodable {
    let leaderboard: [LeaderboardEntry]
    let count: Int
}
