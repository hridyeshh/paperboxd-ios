import Foundation

/// Authentication response from the API
struct AuthResponse: Codable {
    let token: String
    let user: User
}

/// Token verify response from the API
struct TokenVerifyResponse: Codable {
    let user: User
}

/// User model matching the web version
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let username: String?
    let name: String?
    let image: String? // Avatar URL
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case name
        case image
    }
}

/// Login request payload
struct LoginRequest: Codable {
    let email: String
    let password: String
}

/// Registration request payload
struct RegisterRequest: Codable {
    let name: String
    let email: String
    let password: String
}

/// Error response from API
struct AuthErrorResponse: Codable {
    let error: String
}

/// Google Sign-In request payload
struct GoogleSignInRequest: Codable {
    let idToken: String
}

