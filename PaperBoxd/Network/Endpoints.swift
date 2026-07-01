import Foundation

/// Path constants for every endpoint the Phase 1 client touches. Keeping these
/// stringly-typed in one file makes future MOBILE_API.md churn easy to track.
enum Endpoints {
    // Connectivity
    static let health = "/api/health"

    // Mobile auth (long-lived tokens, no cookies)
    static let mobileLogin     = "/api/mobile/auth/login"
    static let mobileRegister  = "/api/mobile/auth/register"
    static let mobileOTPSend   = "/api/mobile/auth/otp/send"
    static let mobileOTPVerify = "/api/mobile/auth/otp/verify"
    static let mobileGoogle    = "/api/mobile/auth/google"
    static let mobileRefresh   = "/api/mobile/auth/refresh"

    // Authenticated mobile user endpoints
    static let mobileUpdateMe  = "/api/mobile/users/me"
    static let deleteMe        = "/api/v1/users/me"   // DELETE — soft-deletes account

    // Onboarding (web v1 routes — accept the mobile bearer token)
    static let saveOnboarding     = "/api/v1/users/me/onboarding"
    static let avatarUpload       = "/api/v1/users/me/avatar/upload"
    static let bannerUpload       = "/api/v1/users/me/banner/upload"
    static let recommendationsHome = "/api/v1/recommendations/home"
    static let scanAnalyze        = "/api/v1/scan/analyze"

    static func addToBookshelf(username: String) -> String {
        "/api/v1/users/\(username)/bookshelf"
    }

    static func removeFromBookshelf(username: String, bookId: String) -> String {
        "/api/v1/users/\(username)/bookshelf/\(bookId)"
    }

    static func bookStatus(username: String, bookId: String) -> String {
        "/api/v1/users/\(username)/bookshelf/\(bookId)/status"
    }

    // Books
    static func book(_ id: String) -> String { "/api/v1/books/\(id)" }
    static func likeBook(_ id: String) -> String { "/api/v1/books/\(id)/like" }
    static func similarBooks(_ id: String) -> String { "/api/v1/recommendations/similar/\(id)" }
    static func bookFriendsReading(_ id: String) -> String { "/api/v1/books/\(id)/friends-reading" }
    static func bookReviews(_ id: String) -> String { "/api/v1/books/\(id)/reviews" }
    static func bookReviewsByFriends(_ id: String) -> String { "/api/v1/books/\(id)/reviews/friends" }
    static func readingProgress(username: String, bookId: String) -> String {
        "/api/v1/users/\(username)/bookshelf/\(bookId)/progress"
    }

    // Profile
    static func profile(username: String) -> String { "/api/v1/users/\(username)" }
    static func followers(username: String) -> String { "/api/v1/users/\(username)/followers" }
    static func following(username: String) -> String { "/api/v1/users/\(username)/following" }
    static func follow(username: String) -> String { "/api/v1/users/\(username)/follow" }
    static func userBookshelf(username: String) -> String { "/api/v1/users/\(username)/bookshelf" }
    static func userFavorites(username: String) -> String { "/api/v1/users/\(username)/favorites" }
    static func userLikes(username: String) -> String { "/api/v1/users/\(username)/likes" }
    static func userTBR(username: String) -> String { "/api/v1/users/\(username)/tbr" }
    static func userDNF(username: String) -> String { "/api/v1/users/\(username)/dnf" }
    static func userAuthors(username: String) -> String { "/api/v1/users/\(username)/authors" }
    static func userStreak(username: String) -> String { "/api/v1/users/\(username)/streak" }
    static func userLists(username: String) -> String { "/api/v1/users/\(username)/lists" }
    static func userDiary(username: String) -> String { "/api/v1/users/\(username)/diary" }
    static func userReading(username: String) -> String { "/api/v1/users/\(username)/reading" }
    static func readingToday(username: String) -> String { "/api/v1/users/\(username)/reading/today" }
    static func lastLoggedBook(username: String) -> String { "/api/v1/users/\(username)/reading/last" }

    // Books — trending wall feed (already exists; surfacing in iOS)
    static let publicBooks = "/api/v1/books/public"
    static let latestBooks = "/api/v1/books/latest"
    static let randomBooks = "/api/v1/books/random"

    // Activities
    static let followingActivities = "/api/v1/activities/following"

    // Search
    static let searchBooks = "/api/v1/books/search"
    static let searchUsers = "/api/v1/users/search"

    // Leaderboard
    static let globalLeaderboard = "/api/v1/leaderboard/global"
    static let friendsLeaderboard = "/api/v1/leaderboard/friends"
    static let myLeaderboardStats = "/api/v1/users/me/leaderboard-stats"
    static func leaderboardDimension(_ dimension: String) -> String {
        "/api/v1/leaderboard/dimension/\(dimension)"
    }

    // Events
    static let events = "/api/v1/events"

    // Diary mutations
    static func diaryEntry(username: String, entryId: String) -> String {
        "/api/v1/users/\(username)/diary/\(entryId)"
    }
    static func diaryEntryLike(username: String, entryId: String) -> String {
        "/api/v1/users/\(username)/diary/\(entryId)/like"
    }

    // Password reset (web v1 route — works for mobile too)
    static let forgotPassword  = "/api/v1/auth/forgot-password"

    // Username availability (uses existing web v1 route — no mobile twin yet)
    static func checkUsername(_ username: String) -> String {
        var c = URLComponents(string: "/api/v1/auth/check-username")!
        c.queryItems = [URLQueryItem(name: "username", value: username)]
        return c.string ?? "/api/v1/auth/check-username"
    }
}
