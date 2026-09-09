import Foundation

/// A reader's XP standing, as shown by the profile avatar ring and level sheet.
///
/// `level` and `name` come from the server (`GET /api/v1/users/me/leaderboard-stats`)
/// and are never computed here — the backend owns the naming. The thresholds
/// below mirror `CalculateLevel` in `internal/service/xp_service.go` and exist
/// only to draw the ring and say how far the next level is; if they ever drift,
/// the server's `level` still wins and only the arc is slightly off.
struct ReaderProgress: Equatable {
    let level: Int
    let name: String
    let totalXP: Int

    /// XP at which `level` began.
    var levelStart: Int { Self.xpAtStart(of: level) }
    /// XP at which the next level begins.
    var levelEnd: Int { Self.xpAtStart(of: level + 1) }
    var xpIntoLevel: Int { max(0, totalXP - levelStart) }
    var xpToNext: Int { max(0, levelEnd - totalXP) }

    /// 0…1 through the current level. Floored at 6% — a true zero-length arc
    /// reads as a rendering failure rather than a fresh start.
    var ringFill: Double {
        let span = levelEnd - levelStart
        guard span > 0 else { return 1 }
        return max(0.06, min(1, Double(xpIntoLevel) / Double(span)))
    }

    var nextLevelName: String { Self.name(for: level + 1) }

    init(level: Int, name: String, totalXP: Int) {
        self.level = level
        self.name = name
        self.totalXP = totalXP
    }

    init(entry: LeaderboardEntry) {
        self.init(level: entry.level, name: entry.levelName, totalXP: entry.totalXP)
    }

    // MARK: - Progression (mirrors xp_service.go)

    static func xpAtStart(of level: Int) -> Int {
        switch level {
        case 31...: return 12000 + (level - 31) * 500
        case 26...: return 8000  + (level - 26) * 800
        case 21...: return 5000  + (level - 21) * 600
        case 16...: return 3000  + (level - 16) * 400
        case 11...: return 1500  + (level - 11) * 300
        case 6...:  return 500   + (level - 6)  * 200
        default:    return max(0, (level - 1) * 100)
        }
    }

    /// Only for levels the user has not reached — the server supplies the name
    /// of the level they're actually on.
    static func name(for level: Int) -> String {
        switch level {
        case 31...: return "Living Library"
        case 26...: return "Legendary Curator"
        case 21...: return "Grand Archivist"
        case 16...: return "Literary Scholar"
        case 11...: return "Bibliophile"
        case 6...:  return "Avid Reader"
        default:    return "Beginner Reader"
        }
    }

    /// The seven named tiers and the level each begins at.
    static let tiers: [(level: Int, name: String)] = [
        (1, "Beginner Reader"), (6, "Avid Reader"), (11, "Bibliophile"),
        (16, "Literary Scholar"), (21, "Grand Archivist"),
        (26, "Legendary Curator"), (31, "Living Library"),
    ]
}

/// What each action is worth, straight from `xp_service.go`. Shown in the level
/// sheet so "why did my XP stop" is answerable without leaving the app.
enum XPAction {
    static let all: [(label: String, xp: Int)] = [
        ("Finish a book", 25),
        ("7-day streak", 50),
        ("Thought on a book", 20),
        ("30-day streak", 200),
        ("Write a thought", 15),
        ("100-day streak", 1000),
        ("Your first list", 15),
        ("Another list", 5),
        ("Log progress", 5),
        ("Gain a follower", 5),
        ("Open the app", 3),
        ("Add to TBR", 2),
    ]
    /// `MaxDailyXP` — streak and referral bonuses are exempt.
    static let dailyCap = 150
}
