import Foundation

/// User payload mobile auth endpoints return. Mirrors MOBILE_API.md §2 user
/// shape. `username` is optional because the mobile register endpoint may not
/// include one yet (we then route to ChooseUsername).
struct User: Codable, Equatable, Identifiable {
    let id: String
    let username: String?
    let email: String
    let avatarURL: String?
    let level: Int?
    let xp: Int?
    let onboardingCompleted: Bool?

    enum CodingKeys: String, CodingKey {
        case id, username, email, level, xp
        case avatarURL = "avatar_url"
        case onboardingCompleted = "onboarding_completed"
    }
}

/// Response shape for login / OTP verify / Google success.
struct AuthResponse: Codable {
    let token: String
    let refreshToken: String?
    let user: User

    enum CodingKeys: String, CodingKey {
        case token, user
        case refreshToken = "refresh_token"
    }
}

/// Response shape for register — same as AuthResponse plus optional flag the
/// backend sets when it had to auto-create the account.
struct RegisterResponse: Codable {
    let token: String
    let refreshToken: String?
    let user: User

    enum CodingKeys: String, CodingKey {
        case token, user
        case refreshToken = "refresh_token"
    }
}

struct GoogleAuthResponse: Codable {
    let token: String
    let refreshToken: String?
    let user: User
    let isNewUser: Bool

    enum CodingKeys: String, CodingKey {
        case token, user
        case refreshToken = "refresh_token"
        case isNewUser = "is_new_user"
    }
}

/// Response shape for POST /api/mobile/auth/otp/send.
struct OTPSendResponse: Codable {
    let message: String
    let expiresInSeconds: Int

    enum CodingKeys: String, CodingKey {
        case message
        case expiresInSeconds = "expires_in_seconds"
    }
}

/// Response shape for POST /api/mobile/auth/refresh.
struct RefreshResponse: Codable {
    let token: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case token
        case refreshToken = "refresh_token"
    }
}

/// Response shape for GET /api/health.
struct HealthResponse: Codable {
    let status: String
    let version: String
    let timestamp: String
}

/// Response shape for the web check-username endpoint.
/// GET /api/v1/auth/check-username?username=X → { available, username, reason? }
struct CheckUsernameResponse: Codable {
    let available: Bool
    let username: String
    let reason: String?
}
