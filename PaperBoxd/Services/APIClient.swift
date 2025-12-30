import Foundation
import UIKit

/// Singleton API client for making requests to the PaperBoxd API
class APIClient {
    static let shared = APIClient()
    
    // BFF Pattern: Dedicated mobile API namespace
    // Always use www.paperboxd.in to avoid redirect that strips Authorization header
    // URLSession strips headers when following redirects to different subdomains
    private let baseURL = "https://www.paperboxd.in/api/mobile/v1"
    
    private init() {}
    
    /// Get the authentication token from Keychain
    /// - Returns: The stored JWT token, or nil if not found
    private func getAuthToken() -> String? {
        return KeychainHelper.shared.readToken()
    }
    
    /// Generic request function that performs a GET request and decodes the response
    /// - Parameters:
    ///   - endpoint: The API endpoint path (e.g., "/books/sphere")
    ///   - queryItems: Optional query parameters
    /// - Returns: Decoded response of type T
    /// - Throws: Network errors or decoding errors
    func request<T: Codable>(
        endpoint: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        // Ensure token is valid before making authenticated requests
        // Skip for public endpoints (like /books/sphere)
        if endpoint.contains("/auth/") == false && getAuthToken() != nil {
            try? await TokenRefreshService.shared.ensureValidToken()
        }
        // Construct URL using URLComponents for robust URL building
        // BFF Pattern: Mobile API routes always get trailing slashes to prevent redirects
        let normalizedEndpoint = endpoint.hasPrefix("/") ? String(endpoint.dropFirst()) : endpoint
        
        // Force a trailing slash so Vercel doesn't redirect /profile to /profile/
        let finalPath = normalizedEndpoint.hasSuffix("/") ? normalizedEndpoint : "\(normalizedEndpoint)/"
        
        // Use URLComponents from the start for proper URL construction
        guard var components = URLComponents(string: baseURL) else {
            throw APIError.invalidURL
        }
        
        // Append the path component (URLComponents handles slashes correctly)
        let currentPath = components.path.isEmpty ? "" : components.path
        components.path = "\(currentPath)/\(finalPath)"
        
        // Add query items if provided
        if let queryItems = queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        print("🌐 APIClient: Making GET request to \(url.absoluteString)")
        
        // Create URLRequest with auth header
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication header if token exists and is valid (strict validation)
        // CRITICAL: Trim whitespaces AND newlines - hidden characters break headers
        let rawToken = getAuthToken()
        print("🔍 APIClient: Token check for \(endpoint) - rawToken is \(rawToken != nil ? "present (length: \(rawToken!.count))" : "nil")")
        
        if let token = rawToken {
            let cleanToken = token.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            if !cleanToken.isEmpty {
                // Set standard Authorization header
                request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
                
                // CRITICAL: Also set custom header as fallback
                // Vercel sometimes strips/replaces the Authorization header, so we send it in a custom header too
                // The backend will check both Authorization and X-User-Authorization
                request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "X-User-Authorization")
                
                // Log the length to verify it's not a tiny/empty string
                print("🔐 APIClient: Successfully added valid Bearer token (length: \(cleanToken.count), prefix: \(cleanToken.prefix(10))...)")
                print("🔐 APIClient: Set both 'Authorization' and 'X-User-Authorization' headers (fallback for Vercel)")
                
                // Verify both headers were actually set
                if let authHeader = request.value(forHTTPHeaderField: "Authorization") {
                    print("✅ APIClient: Verified Authorization header is set (length: \(authHeader.count))")
                } else {
                    print("❌ APIClient: ERROR - Authorization header was NOT set despite token being valid!")
                }
                
                if let customAuthHeader = request.value(forHTTPHeaderField: "X-User-Authorization") {
                    print("✅ APIClient: Verified X-User-Authorization header is set (length: \(customAuthHeader.count))")
                } else {
                    print("❌ APIClient: ERROR - X-User-Authorization header was NOT set!")
                }
            } else {
                print("⚠️ APIClient: Token was found but resolved to an empty string after trimming (raw length: \(token.count))")
            }
        } else {
            print("⚠️ APIClient: Attempted authenticated request but token was empty or missing")
            print("⚠️ APIClient: Endpoint: \(endpoint) - This request will fail without authentication")
        }
        
        // Perform request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ APIClient: Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("📊 APIClient: Status code: \(httpResponse.statusCode)")
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ APIClient: Request failed with status code \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("📄 APIClient: Error response body: \(errorString)")
                }
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }
            
            // Decode response
            do {
                let decoder = JSONDecoder()
                // Configure date decoding strategy if needed
                decoder.dateDecodingStrategy = .iso8601
                
                let decoded = try decoder.decode(T.self, from: data)
                print("✅ APIClient: Successfully decoded response")
                return decoded
            } catch let decodingError as DecodingError {
                // Enhanced error handling with specific key information
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ APIClient: Key '\(key.stringValue)' not found at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("   Available keys in JSON might be different. Check the raw response below.")
                case .dataCorrupted(let context):
                    print("❌ APIClient: Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    if let underlyingError = context.underlyingError {
                        print("   Underlying error: \(underlyingError.localizedDescription)")
                    }
                case .typeMismatch(let type, let context):
                    print("❌ APIClient: Type mismatch for \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .valueNotFound(let value, let context):
                    print("❌ APIClient: Value '\(value)' not found at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                @unknown default:
                    print("❌ APIClient: Unknown decoding error")
                }
                // Print raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 APIClient: Raw response (first 500 chars): \(String(responseString.prefix(500)))")
                }
                throw APIError.decodingError(decodingError)
            } catch {
                print("❌ APIClient: Decoding error: \(error.localizedDescription)")
                // Print raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 APIClient: Raw response (first 500 chars): \(String(responseString.prefix(500)))")
                }
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ APIClient: Network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }
    
    /// Generic POST request function
    /// - Parameters:
    ///   - endpoint: The API endpoint path (e.g., "/auth/token/login")
    ///   - body: The request body to encode as JSON
    /// - Returns: Decoded response of type T
    /// - Throws: Network errors or decoding errors
    func post<T: Codable, B: Codable>(
        endpoint: String,
        body: B
    ) async throws -> T {
        // Ensure token is valid before making authenticated requests
        // Skip for auth endpoints (login, register, google-mobile)
        if !endpoint.contains("/auth/") && getAuthToken() != nil {
            try? await TokenRefreshService.shared.ensureValidToken()
        }
        // Construct URL using URLComponents for robust URL building
        // BFF Pattern: Mobile API routes get trailing slashes to prevent redirects
        // BUT: Auth endpoints should NOT have trailing slashes to avoid 405 errors
        let normalizedEndpoint = endpoint.hasPrefix("/") ? String(endpoint.dropFirst()) : endpoint
        
        // Force a trailing slash for most endpoints, but NOT for auth endpoints
        // Auth endpoints can have issues with trailing slashes causing 405 errors
        let finalPath: String
        if normalizedEndpoint.contains("/auth/") {
            // Don't add trailing slash for auth endpoints
            finalPath = normalizedEndpoint
        } else {
            // Add trailing slash for other endpoints
            finalPath = normalizedEndpoint.hasSuffix("/") ? normalizedEndpoint : "\(normalizedEndpoint)/"
        }
        
        // Use URLComponents from the start for proper URL construction
        guard var components = URLComponents(string: baseURL) else {
            throw APIError.invalidURL
        }
        
        // Append the path component (URLComponents handles slashes correctly)
        let currentPath = components.path.isEmpty ? "" : components.path
        components.path = "\(currentPath)/\(finalPath)"
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        print("🌐 APIClient: Making POST request to \(url.absoluteString)")
        
        // Create URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add authentication header if token exists and is valid (strict validation)
        // CRITICAL: Trim whitespaces AND newlines - hidden characters break headers
        if let token = getAuthToken() {
            let cleanToken = token.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            if !cleanToken.isEmpty {
                // Set standard Authorization header
                request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
                
                // CRITICAL: Also set custom header as fallback
                // Vercel sometimes strips/replaces the Authorization header, so we send it in a custom header too
                request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "X-User-Authorization")
                
                // Log the length to verify it's not a tiny/empty string
                print("🔐 APIClient: Successfully added valid Bearer token (length: \(cleanToken.count), prefix: \(cleanToken.prefix(10))...)")
                print("🔐 APIClient: Set both 'Authorization' and 'X-User-Authorization' headers (fallback for Vercel)")
            } else {
                print("⚠️ APIClient: Token was found but resolved to an empty string after trimming")
            }
        } else {
            print("⚠️ APIClient: Attempted authenticated request but token was empty or missing")
        }
        
        // Encode body
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        } catch {
            print("❌ APIClient: Failed to encode request body: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
        
        // Perform request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ APIClient: Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("📊 APIClient: Status code: \(httpResponse.statusCode)")
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ APIClient: Request failed with status code \(httpResponse.statusCode)")
                if let errorString = String(data: data, encoding: .utf8) {
                    print("📄 APIClient: Error response body: \(errorString)")
                }
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }
            
            // Decode response
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let decoded = try decoder.decode(T.self, from: data)
                print("✅ APIClient: Successfully decoded POST response")
                return decoded
            } catch let decodingError as DecodingError {
                // Enhanced error handling
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ APIClient: Key '\(key.stringValue)' not found at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("❌ APIClient: Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .typeMismatch(let type, let context):
                    print("❌ APIClient: Type mismatch for \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .valueNotFound(let value, let context):
                    print("❌ APIClient: Value '\(value)' not found at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                @unknown default:
                    print("❌ APIClient: Unknown decoding error")
                }
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 APIClient: Raw response (first 500 chars): \(String(responseString.prefix(500)))")
                }
                throw APIError.decodingError(decodingError)
            } catch {
                print("❌ APIClient: Decoding error: \(error.localizedDescription)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 APIClient: Raw response (first 500 chars): \(String(responseString.prefix(500)))")
                }
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ APIClient: Network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }
    
    /// Login with email and password
    /// - Parameters:
    ///   - email: User email
    ///   - password: User password
    /// - Returns: AuthResponse with token and user data
    /// - Throws: Network errors or authentication errors
    func login(email: String, password: String) async throws -> AuthResponse {
        let loginRequest = LoginRequest(email: email, password: password)
        return try await post(endpoint: "/auth/token/login", body: loginRequest)
    }
    
    /// Register a new user
    /// - Parameters:
    ///   - name: User's name
    ///   - email: User email
    ///   - password: User password
    /// - Returns: AuthResponse with token and user data
    /// - Throws: Network errors or registration errors
    func register(name: String, email: String, password: String) async throws -> AuthResponse {
        let registerRequest = RegisterRequest(name: name, email: email, password: password)
        return try await post(endpoint: "/users/register", body: registerRequest)
    }
    
    /// Sign in with Google ID token
    /// - Parameter idToken: Google ID token from Google Sign-In SDK
    /// - Returns: AuthResponse with token and user data
    /// - Throws: Network errors or authentication errors
    func signInWithGoogle(idToken: String) async throws -> AuthResponse {
        // Note: We don't call ensureValidToken() here because this is the initial sign-in
        // There's no existing token to refresh - we're creating a new one
        let googleRequest = GoogleSignInRequest(idToken: idToken)
        return try await post(endpoint: "/auth/google-mobile", body: googleRequest)
    }
    
    /// Logout - clears the stored token
    func logout() {
        KeychainHelper.shared.deleteToken()
        print("✅ APIClient: User logged out, token cleared")
    }
    
    /// Delete user account
    /// - Parameter reasons: Array of reasons for account deletion
    /// - Throws: Network errors
    func deleteAccount(reasons: [String]) async throws {
        // Use web API endpoint (not mobile API) for account deletion
        let webBaseURL = baseURL.replacingOccurrences(of: "/mobile/v1", with: "")
        guard let url = URL(string: "\(webBaseURL)/users/delete-account") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication header
        if let token = getAuthToken() {
            let cleanToken = token.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !cleanToken.isEmpty {
                request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
                request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "X-User-Authorization")
            }
        }
        
        let body = ["reasons": reasons]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// Check if user is authenticated
    var isAuthenticated: Bool {
        return getAuthToken() != nil
    }
    
    /// Fetch books for the sphere visualization
    /// - Returns: SphereResponse containing an array of books
    /// - Throws: Network errors or decoding errors
    func fetchSphereBooks() async throws -> SphereResponse {
        let queryItems = [URLQueryItem(name: "limit", value: "80")]
        return try await request(endpoint: "/books/sphere", queryItems: queryItems)
    }
    
    
    /// Fetch latest books (Mobile API - BFF Pattern)
    /// - Parameters:
    ///   - page: Page number (default: 1)
    ///   - pageSize: Number of results per page (default: 50)
    /// - Returns: LatestBooksResponse containing books and pagination info
    /// - Throws: Network errors or decoding errors
    func fetchLatestBooks(page: Int = 1, pageSize: Int = 50) async throws -> LatestBooksResponse {
        let queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]
        // Uses /api/mobile/v1/books/latest (via baseURL)
        return try await request(endpoint: "books/latest", queryItems: queryItems)
    }
    
    /// Fetch personalized book recommendations (Mobile API - BFF Pattern)
    /// - Parameters:
    ///   - type: Type of personalized content (recommended, onboarding, friends)
    ///   - limit: Number of results (default: 20)
    /// - Returns: PersonalizedBooksResponse containing books
    /// - Throws: Network errors or decoding errors
    func fetchPersonalizedBooks(type: String, limit: Int = 20) async throws -> PersonalizedBooksResponse {
        let queryItems = [
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        // Uses /api/mobile/v1/books/personalized (via baseURL)
        return try await request(endpoint: "books/personalized", queryItems: queryItems)
    }
    
    /// Fetch user profile by username
    /// - Parameter username: The username to fetch
    /// - Returns: UserProfileResponse containing user data
    /// - Throws: Network errors or decoding errors
    func fetchUserProfile(username: String) async throws -> UserProfileResponse {
        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        return try await request(endpoint: "/users/\(encodedUsername)", queryItems: nil)
    }
    
    /// Verify token and get current user info
    /// - Returns: User info including username
    /// - Throws: Network errors or decoding errors
    func verifyToken() async throws -> User {
        let response: TokenVerifyResponse = try await request(endpoint: "/auth/token/verify", queryItems: nil)
        return response.user
    }
    
    /// Get current user's profile (requires authentication)
    /// Uses the dedicated mobile API endpoint (BFF Pattern)
    /// - Returns: UserProfileResponse containing current user data
    /// - Throws: Network errors or decoding errors
    func fetchCurrentUserProfile() async throws -> UserProfileResponse {
        // Use the dedicated mobile API endpoint - bypasses web session logic
        return try await request(endpoint: "profile", queryItems: nil)
    }
    
    /// Fetch book details by ID (Mobile API - BFF Pattern)
    /// Supports: MongoDB ObjectId, ISBNdb ID, Open Library ID, ISBN-10, ISBN-13
    /// - Parameter bookId: The book identifier (any supported format)
    /// - Returns: Book object with full details
    /// - Throws: Network errors or decoding errors
    func fetchBookDetails(bookId: String) async throws -> Book {
        // URL encode the bookId to handle special characters
        let encodedBookId = bookId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bookId
        // Uses /api/mobile/v1/books/[id] (via baseURL)
        return try await request(endpoint: "books/\(encodedBookId)", queryItems: nil)
    }
    
    /// Log book to user's collection (Save to Bookshelf)
    /// - Parameters:
    ///   - bookId: The book identifier
    ///   - status: "Want to Read", "Reading", "Read", or "DNF"
    ///   - rating: Optional rating (1-5)
    ///   - thoughts: Optional thoughts/review
    ///   - format: Optional format ("Print", "Digital", "Audio")
    ///   - cover: Optional cover image URL (to ensure correct cover is saved)
    /// - Returns: Success response
    /// - Throws: Network errors or decoding errors
    func logBook(bookId: String, status: String, rating: Int? = nil, thoughts: String? = nil, format: String? = nil, cover: String? = nil) async throws -> LogBookResponse {
        let encodedBookId = bookId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bookId
        
        let body = LogBookRequest(
            status: status,
            rating: rating,
            thoughts: thoughts,
            format: format,
            cover: cover
        )
        
        return try await post(endpoint: "books/\(encodedBookId)/log", body: body)
    }
    
    /// Update user profile
    /// - Parameters:
    ///   - username: The username (required for API endpoint)
    ///   - name: Optional name
    ///   - bio: Optional bio
    ///   - pronouns: Optional pronouns array
    ///   - birthday: Optional birthday (yyyy-MM-dd format)
    ///   - gender: Optional gender
    ///   - links: Optional links array
    ///   - avatar: Optional avatar URL
    /// - Returns: Update response
    /// - Throws: Network errors or decoding errors
    func updateProfile(
        username: String,
        name: String? = nil,
        bio: String? = nil,
        pronouns: [String]? = nil,
        birthday: String? = nil,
        gender: String? = nil,
        links: [String]? = nil,
        avatar: String? = nil
    ) async throws -> ProfileUpdateResponse {
        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        
        // Use web API endpoint (not mobile API) for profile updates
        let webBaseURL = baseURL.replacingOccurrences(of: "/mobile/v1", with: "")
        let urlString = "\(webBaseURL)/users/\(encodedUsername)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let bio = bio { body["bio"] = bio }
        if let pronouns = pronouns { body["pronouns"] = pronouns }
        if let birthday = birthday { body["birthday"] = birthday }
        if let gender = gender { body["gender"] = gender }
        if let links = links { body["links"] = links }
        if let avatar = avatar { body["avatar"] = avatar }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(ProfileUpdateResponse.self, from: data)
    }
    
    /// Upload avatar image
    /// - Parameter image: The UIImage to upload
    /// - Returns: Avatar URL
    /// - Throws: Network errors
    func uploadAvatar(image: UIImage) async throws -> String {
        print("📤 APIClient: Starting avatar upload...")
        
        // Ensure token is valid before making authenticated request
        if getAuthToken() != nil {
            try? await TokenRefreshService.shared.ensureValidToken()
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ APIClient: Failed to convert image to JPEG data")
            throw APIError.invalidResponse
        }
        
        print("📤 APIClient: Image data size: \(imageData.count) bytes")
        
        // Use web API endpoint (not mobile API) for avatar upload
        let webBaseURL = baseURL.replacingOccurrences(of: "/mobile/v1", with: "")
        guard let url = URL(string: "\(webBaseURL)/upload/avatar") else {
            print("❌ APIClient: Invalid URL: \(webBaseURL)/upload/avatar")
            throw APIError.invalidURL
        }
        
        print("📤 APIClient: Upload URL: \(url.absoluteString)")
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Add authentication header with same pattern as request() function
        // CRITICAL: Trim whitespaces AND newlines - hidden characters break headers
        let rawToken = getAuthToken()
        print("🔍 APIClient: Token check for upload - rawToken is \(rawToken != nil ? "present (length: \(rawToken!.count))" : "nil")")
        
        if let token = rawToken {
            let cleanToken = token.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            if !cleanToken.isEmpty {
                // Set standard Authorization header
                request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
                
                // CRITICAL: Also set custom header as fallback
                // Vercel sometimes strips/replaces the Authorization header, so we send it in a custom header too
                // The backend will check both Authorization and X-User-Authorization
                request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "X-User-Authorization")
                
                print("🔐 APIClient: Successfully added valid Bearer token (length: \(cleanToken.count), prefix: \(cleanToken.prefix(10))...)")
                print("🔐 APIClient: Set both 'Authorization' and 'X-User-Authorization' headers (fallback for Vercel)")
                
                // Verify both headers were actually set
                if let authHeader = request.value(forHTTPHeaderField: "Authorization") {
                    print("✅ APIClient: Verified Authorization header is set (length: \(authHeader.count))")
                } else {
                    print("❌ APIClient: ERROR - Authorization header was NOT set despite token being valid!")
                }
                
                if let customAuthHeader = request.value(forHTTPHeaderField: "X-User-Authorization") {
                    print("✅ APIClient: Verified X-User-Authorization header is set (length: \(customAuthHeader.count))")
                } else {
                    print("❌ APIClient: ERROR - X-User-Authorization header was NOT set!")
                }
            } else {
                print("⚠️ APIClient: Token is empty after trimming")
            }
        } else {
            print("⚠️ APIClient: No auth token available")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        print("📤 APIClient: Request body size: \(body.count) bytes")
        
        print("📤 APIClient: Sending upload request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("📤 APIClient: Received response")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ APIClient: Invalid response type")
            throw APIError.invalidResponse
        }
        
        print("📤 APIClient: Response status code: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ APIClient: HTTP error with status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ APIClient: Response body: \(responseString)")
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        struct AvatarResponse: Codable {
            let avatar: String
        }
        
        do {
            let avatarResponse = try JSONDecoder().decode(AvatarResponse.self, from: data)
            print("✅ APIClient: Avatar uploaded successfully, URL: \(avatarResponse.avatar)")
            return avatarResponse.avatar
        } catch {
            print("❌ APIClient: Failed to decode response: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ APIClient: Response body: \(responseString)")
            }
            throw error
        }
    }
    
    /// Check if username is available
    /// - Parameter username: The username to check
    /// - Returns: true if available, false if taken
    /// - Throws: Network errors
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        // Use web API endpoint (not mobile API) for username check
        let webBaseURL = baseURL.replacingOccurrences(of: "/mobile/v1", with: "")
        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let urlString = "\(webBaseURL)/users/check-username?username=\(encodedUsername)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Username check doesn't require authentication
        // But we can include token if available for rate limiting purposes
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        struct UsernameCheckResponse: Codable {
            let available: Bool
            let username: String?
        }
        
        let checkResponse = try JSONDecoder().decode(UsernameCheckResponse.self, from: data)
        return checkResponse.available
    }
    
    /// Delete a diary entry
    /// - Parameters:
    ///   - username: The username of the diary entry owner
    ///   - entryId: The ID of the diary entry (for general entries)
    ///   - bookId: The book ID (for book entries, optional)
    /// - Throws: Network errors
    func deleteDiaryEntry(username: String, entryId: String? = nil, bookId: String? = nil) async throws {
        // Use web API endpoint (not mobile API) for diary deletion
        let webBaseURL = baseURL.replacingOccurrences(of: "/mobile/v1", with: "")
        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        guard let url = URL(string: "\(webBaseURL)/users/\(encodedUsername)/diary") else {
            throw APIError.invalidURL
        }
        
        // Ensure token is valid before making authenticated requests
        if getAuthToken() != nil {
            try? await TokenRefreshService.shared.ensureValidToken()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication header
        if let token = getAuthToken() {
            let cleanToken = token.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !cleanToken.isEmpty {
                request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
                request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "X-User-Authorization")
            }
        }
        
        // Build request body
        var body: [String: String] = [:]
        if let entryId = entryId {
            body["entryId"] = entryId
        } else if let bookId = bookId {
            body["bookId"] = bookId
        } else {
            throw APIError.invalidResponse // Need either entryId or bookId
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                throw NSError(domain: "APIClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    /// Like or unlike a diary entry
    /// - Parameters:
    ///   - username: The username of the diary entry owner
    ///   - entryId: The ID of the diary entry
    /// - Returns: LikeResponse with liked status and likesCount
    /// - Throws: Network errors
    func toggleDiaryEntryLike(username: String, entryId: String) async throws -> DiaryLikeResponse {
        // Use web API endpoint (not mobile API) for diary likes
        let webBaseURL = baseURL.replacingOccurrences(of: "/mobile/v1", with: "")
        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let encodedEntryId = entryId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? entryId
        guard let url = URL(string: "\(webBaseURL)/users/\(encodedUsername)/diary/\(encodedEntryId)/like") else {
            throw APIError.invalidURL
        }
        
        // Ensure token is valid before making authenticated requests
        // CRITICAL: This is an authenticated endpoint, so we need a valid token
        guard let rawToken = getAuthToken() else {
            print("❌ APIClient: No auth token available for diary like request")
            throw APIError.httpError(statusCode: 401)
        }
        
        // Try to refresh token if needed
        do {
            try await TokenRefreshService.shared.ensureValidToken()
        } catch {
            print("⚠️ APIClient: Token refresh failed, proceeding with current token: \(error.localizedDescription)")
        }
        
        // Get the token again (might have been refreshed)
        guard let token = getAuthToken() else {
            print("❌ APIClient: Token is missing after refresh attempt")
            throw APIError.httpError(statusCode: 401)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add authentication header with proper trimming
        let cleanToken = token.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !cleanToken.isEmpty {
            // Set standard Authorization header
            request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
            
            // CRITICAL: Also set custom header as fallback
            // Vercel sometimes strips/replaces the Authorization header, so we send it in a custom header too
            request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "X-User-Authorization")
            
            print("🔐 APIClient: Successfully added Bearer token for diary like (length: \(cleanToken.count))")
        } else {
            print("❌ APIClient: Token is empty after trimming")
            throw APIError.httpError(statusCode: 401)
        }
        
        print("🌐 APIClient: Making POST request to \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("📊 APIClient: Diary like response status code: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message from response
            if let errorString = String(data: data, encoding: .utf8) {
                print("📄 APIClient: Error response body: \(errorString)")
            }
            
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                throw NSError(domain: "APIClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let likeResponse = try JSONDecoder().decode(DiaryLikeResponse.self, from: data)
        print("✅ APIClient: Successfully toggled diary entry like")
        return likeResponse
    }
}

// MARK: - Diary Like Response
struct DiaryLikeResponse: Codable {
    let liked: Bool
    let likesCount: Int
}

// MARK: - Request Models

struct LogBookRequest: Codable {
    let status: String
    let rating: Int?
    let thoughts: String?
    let format: String?
    let cover: String? // Cover image URL to ensure correct cover is saved
}

// MARK: - Response Models

struct LatestBooksResponse: Codable {
    let books: [Book]
    let pagination: Pagination?
}

struct Pagination: Codable {
    let page: Int
    let pageSize: Int
    let total: Int
    let totalPages: Int
}

struct PersonalizedBooksResponse: Codable {
    let books: [Book]
    let count: Int?
}

struct LogBookResponse: Codable {
    let success: Bool
    let status: String
    let message: String
    let removed: Bool?
}

/// API error types
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let statusCode):
            return "HTTP error with status code: \(statusCode)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Response Models
struct ProfileUpdateResponse: Codable {
    let message: String
    let user: UpdatedUser?
}

struct UpdatedUser: Codable {
    let id: String?
    let username: String?
    let name: String?
    let bio: String?
    let avatar: String?
    let pronouns: [String]?
}


