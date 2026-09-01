import Foundation

/// Monthly Wrapped, as returned by GET /api/v1/users/me/wrapped.
///
/// The story is fourteen chapters cut from one month of reading. Anything the
/// backend cannot know for certain is either absent (`topRated`, `abandoned`
/// are optional) or named as an estimate (`estimatedHours` is derived from
/// pages, not from a timer).
struct Wrapped: Decodable, Equatable {
    /// False when nothing was logged that month — show the empty state, not a
    /// story about zero.
    let hasData: Bool
    let month: String
    let monthShort: String
    let year: String
    let nextMonth: String
    let reader: Reader
    let totals: Totals
    let books: [Book]
    let authors: [Author]
    let genres: [Genre]
    let rhythm: Rhythm
    let streak: Streak
    let topRated: TopRated?
    let abandoned: Abandoned?
    let rank: Rank
    let archetype: Archetype
    let dare: Dare

    enum CodingKeys: String, CodingKey {
        case hasData = "has_data"
        case month
        case monthShort = "month_short"
        case year
        case nextMonth = "next_month"
        case reader, totals, books, authors, genres, rhythm, streak
        case topRated = "top_rated"
        case abandoned, rank, archetype, dare
    }

    struct Reader: Decodable, Equatable {
        let name: String
        let handle: String
        let first: String
    }

    struct Totals: Decodable, Equatable {
        let books: Int
        let pages: Int
        let estimatedHours: Int
        let estimatedMinutes: Int
        let sessions: Int
        let activeDays: Int
        let biggestDayPages: Int
        let biggestDay: String

        enum CodingKeys: String, CodingKey {
            case books, pages, sessions
            case estimatedHours = "estimated_hours"
            case estimatedMinutes = "estimated_minutes"
            case activeDays = "active_days"
            case biggestDayPages = "biggest_day_pages"
            case biggestDay = "biggest_day"
        }
    }

    struct Book: Decodable, Equatable, Identifiable {
        let title: String
        let author: String
        let cover: String
        let pages: Int
        let days: Int
        let rating: Double

        var id: String { title + author }
    }

    struct Author: Decodable, Equatable, Identifiable {
        let name: String
        let books: Int
        let pages: Int
        let note: String?

        var id: String { name }
    }

    struct Genre: Decodable, Equatable, Identifiable {
        let name: String
        let pct: Int

        var id: String { name }
    }

    struct Rhythm: Decodable, Equatable {
        let label: String
        let peak: String
        let pctAfterMidnight: Int
        let line: String
        /// 24 slots, 0–100, normalised against the busiest hour.
        let hours: [Int]

        enum CodingKeys: String, CodingKey {
            case label, peak, line, hours
            case pctAfterMidnight = "pct_after_midnight"
        }
    }

    struct Streak: Decodable, Equatable {
        let days: Int
        let start: String
        let end: String
        let broke: String
        let longestEver: Int
        /// One entry per day of the month, in pages.
        let calendar: [Int]
        /// Indices into `calendar`; -1 when there was no streak.
        let streakStart: Int
        let streakEnd: Int
        let brokeIndex: Int

        enum CodingKeys: String, CodingKey {
            case days, start, end, broke, calendar
            case longestEver = "longest_ever"
            case streakStart = "streak_start"
            case streakEnd = "streak_end"
            case brokeIndex = "broke_index"
        }

        func isInStreak(_ index: Int) -> Bool {
            streakStart >= 0 && index >= streakStart && index <= streakEnd
        }
    }

    struct TopRated: Decodable, Equatable {
        let title: String
        let author: String
        let cover: String
        let rating: Double
        let date: String
        let review: String
    }

    struct Abandoned: Decodable, Equatable {
        let title: String
        let author: String
        let page: Int
        let of: Int
        let started: String
        let lastOpened: String
        let roast: String

        enum CodingKeys: String, CodingKey {
            case title, author, page, of, started, roast
            case lastOpened = "last_opened"
        }

        var pctRead: Int {
            guard of > 0 else { return 0 }
            return Int((Double(page) / Double(of) * 100).rounded())
        }
    }

    struct Rank: Decodable, Equatable {
        let percentile: Int
        let label: String
        let readers: Int
        let beat: Int
        let line: String
    }

    struct Archetype: Decodable, Equatable {
        let name: String
        let kicker: String
        let definition: String
        let traits: [String]
        let statLabel: String
        let statValue: String
        let pairs: String

        enum CodingKeys: String, CodingKey {
            case name, kicker, definition, traits, pairs
            case statLabel = "stat_label"
            case statValue = "stat_value"
        }
    }

    struct Dare: Decodable, Equatable {
        let title: String
        let body: String
        let target: String
        let tag: String
    }
}
