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

    // Onboarding (web v1 routes — accept the mobile bearer token)
    static let saveOnboarding     = "/api/v1/users/me/onboarding"
    static let avatarUpload       = "/api/v1/users/me/avatar/upload"
    static let recommendationsHome = "/api/v1/recommendations/home"

    static func addToBookshelf(username: String) -> String {
        "/api/v1/users/\(username)/bookshelf"
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
