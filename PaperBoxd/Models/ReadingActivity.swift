import Foundation

/// GitHub-contributions equivalent for reading. Mirrors the JSON from
/// GET /api/v1/users/{username}/reading/activity?year=YYYY — one dense entry per
/// UTC calendar day of the year (gaps already zero-filled server-side) plus the
/// roll-up stats shown in the heatmap header and legend.
struct ReadingActivity: Decodable {
    let year: Int
    let start: String            // yyyy-MM-dd (UTC)
    let end: String              // yyyy-MM-dd (UTC)
    let days: [Day]
    let totalPages: Int
    let daysRead: Int
    let bestDay: Int
    let longestStreak: Int
    let currentStreak: Int

    struct Day: Decodable {
        let date: String         // yyyy-MM-dd
        let pages: Int
        let books: Int
    }

    enum CodingKeys: String, CodingKey {
        case year, start, end, days
        case totalPages = "total_pages"
        case daysRead = "days_read"
        case bestDay = "best_day"
        case longestStreak = "longest_streak"
        case currentStreak = "current_streak"
    }
}
