import Foundation

/// Service for handling JWT token refresh
@MainActor
class TokenRefreshService {
    static let shared = TokenRefreshService()
    
    private init() {}
    
    /// Check if token is expired or will expire soon
    /// - Parameter token: The JWT token string
    /// - Returns: True if token is expired or expires within 7 days
    func isTokenExpiredOrExpiringSoon(_ token: String) -> Bool {
        guard let payload = decodeJWTPayload(token) else {
            return true // If we can't decode, assume expired
        }
        
        guard let exp = payload["exp"] as? TimeInterval else {
            return true // No expiration claim, assume expired
        }
        
        let expirationDate = Date(timeIntervalSince1970: exp)
        let sevenDaysFromNow = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days buffer
        
        return expirationDate <= sevenDaysFromNow
    }
    
    /// Refresh the authentication token
    /// - Returns: New AuthResponse with fresh token
    /// - Throws: APIError if refresh fails
    func refreshToken() async throws -> AuthResponse {
        // Check if we have a current token
        guard let currentToken = KeychainHelper.shared.readToken() else {
            throw TokenRefreshError.noToken
        }
        
        // Try to refresh using the current token
        // Note: You'll need to create a /api/auth/refresh endpoint in your backend
        // For now, if the endpoint doesn't exist, we'll throw an error
        do {
            let refreshRequest = TokenRefreshRequest(token: currentToken)
            let response: AuthResponse = try await APIClient.shared.post(
                endpoint: "/auth/refresh",
                body: refreshRequest
            )
            
            // Save new token
            KeychainHelper.shared.saveToken(response.token)
            print("✅ TokenRefreshService: Successfully refreshed token")
            
            return response
        } catch let error as APIError {
            // If refresh endpoint doesn't exist (404) or fails, user needs to re-authenticate
            if case .httpError(let statusCode) = error, statusCode == 404 {
                print("⚠️ TokenRefreshService: Refresh endpoint not found. User will need to re-authenticate when token expires.")
                throw TokenRefreshError.refreshFailed(error)
            }
            throw TokenRefreshError.refreshFailed(error)
        } catch {
            print("⚠️ TokenRefreshService: Refresh failed: \(error.localizedDescription)")
            throw TokenRefreshError.refreshFailed(error)
        }
    }
    
    /// Decode JWT payload (without verification)
    /// - Parameter token: The JWT token string
    /// - Returns: Dictionary containing the payload claims
    private func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let segments = token.components(separatedBy: ".")
        guard segments.count == 3 else {
            return nil
        }
        
        // JWT has 3 parts: header.payload.signature
        // We need to decode the payload (second segment)
        var base64String = segments[1]
        
        // Add padding if needed
        let remainder = base64String.count % 4
        if remainder > 0 {
            base64String = base64String.padding(toLength: base64String.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        
        guard let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) else {
            return nil
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json
        } catch {
            print("❌ TokenRefreshService: Failed to decode JWT payload: \(error)")
            return nil
        }
    }
    
    /// Validate and refresh token if needed before making API calls
    /// This should be called before making authenticated API requests
    /// - Note: Silently fails if refresh is not available (endpoint doesn't exist)
    func ensureValidToken() async throws {
        guard let token = KeychainHelper.shared.readToken() else {
            throw TokenRefreshError.noToken
        }
        
        if isTokenExpiredOrExpiringSoon(token) {
            print("🔄 TokenRefreshService: Token expired or expiring soon, attempting refresh...")
            do {
                _ = try await refreshToken()
            } catch {
                // If refresh fails (e.g., endpoint doesn't exist), log but don't throw
                // The API call will proceed and fail with 401 if token is truly expired
                print("⚠️ TokenRefreshService: Could not refresh token: \(error.localizedDescription)")
                print("   API call will proceed - backend will return 401 if token is expired")
            }
        }
    }
}

/// Token refresh request payload
struct TokenRefreshRequest: Codable {
    let token: String
}

/// Token refresh errors
enum TokenRefreshError: LocalizedError {
    case noToken
    case refreshFailed(Error)
    case invalidToken
    
    var errorDescription: String? {
        switch self {
        case .noToken:
            return "No authentication token found"
        case .refreshFailed(let error):
            return "Token refresh failed: \(error.localizedDescription)"
        case .invalidToken:
            return "Invalid authentication token"
        }
    }
}

