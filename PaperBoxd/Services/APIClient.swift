import Foundation

/// Singleton API client for making requests to the PaperBoxd API
class APIClient {
    static let shared = APIClient()
    
    // CRITICAL: Use www.paperboxd.in to avoid redirect that strips Authorization header
    // URLSession strips headers when following redirects to different subdomains
    private let baseURL = "https://www.paperboxd.in/api"
    
    private init() {}
    
    /// Get the stored authentication token from Keychain
    private func getAuthToken() -> String? {
        return KeychainHelper.shared.readToken()
    }
    
    /// Generic GET request function
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
        // Construct URL using string concatenation to avoid encoding slashes
        // CRITICAL: Remove leading slash, ADD trailing slash to prevent redirects that strip Authorization header
        let normalizedEndpoint = endpoint.hasPrefix("/") ? String(endpoint.dropFirst()) : endpoint
        
        // IMPORTANT: Vercel logs show trailing slashes are expected for most routes.
        // Only true dynamic routes (like /users/[username]) should NOT have trailing slashes.
        // Static routes like /books/personalized, /books/latest, /auth/token/verify should have trailing slashes.
        // Heuristic: Only routes starting with /users/ and having a variable segment are dynamic
        let isDynamicUserRoute = normalizedEndpoint.hasPrefix("users/") && 
                                 normalizedEndpoint.split(separator: "/").count > 2 &&
                                 !normalizedEndpoint.contains("/users/register") &&
                                 !normalizedEndpoint.contains("/users/search")
        
        // Add trailing slash for all routes except dynamic user routes
        let finalPath: String
        if isDynamicUserRoute {
            // Dynamic user routes: don't add trailing slash (e.g., /users/username)
            finalPath = normalizedEndpoint
        } else {
            // All other routes: add trailing slash to prevent redirects (e.g., /books/personalized/, /auth/token/verify/)
            finalPath = normalizedEndpoint.hasSuffix("/") ? normalizedEndpoint : "\(normalizedEndpoint)/"
        }
        
        // Build URL string (baseURL already ends with /api, so we need / before finalPath)
        let urlString = "\(baseURL)/\(finalPath)"
        
        guard var url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        // Add query items if provided (URLComponents will handle the URL correctly)
        if let queryItems = queryItems, !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            guard let finalURL = components?.url else {
                throw APIError.invalidURL
            }
            url = finalURL
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
            let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleanToken.isEmpty {
                request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
                // Log the length to verify it's not a tiny/empty string
                print("🔐 APIClient: Successfully added valid Bearer token (length: \(cleanToken.count), prefix: \(cleanToken.prefix(10))...)")
                
                // Verify the header was actually set
                if let authHeader = request.value(forHTTPHeaderField: "Authorization") {
                    print("✅ APIClient: Verified Authorization header is set (length: \(authHeader.count))")
                } else {
                    print("❌ APIClient: ERROR - Authorization header was NOT set despite token being valid!")
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
        // Construct URL
        guard let baseURLInstance = URL(string: baseURL) else {
            throw APIError.invalidURL
        }
        
        // Construct URL using string concatenation to avoid encoding slashes
        // CRITICAL: Remove leading slash, ADD trailing slash to prevent redirects that strip Authorization header
        let normalizedEndpoint = endpoint.hasPrefix("/") ? String(endpoint.dropFirst()) : endpoint
        
        // IMPORTANT: Vercel logs show trailing slashes are expected for most routes.
        // Only true dynamic routes (like /users/[username]) should NOT have trailing slashes.
        // Static routes like /books/personalized, /books/latest, /auth/token/verify should have trailing slashes.
        // Heuristic: Only routes starting with /users/ and having a variable segment are dynamic
        let isDynamicUserRoute = normalizedEndpoint.hasPrefix("users/") && 
                                 normalizedEndpoint.split(separator: "/").count > 2 &&
                                 !normalizedEndpoint.contains("/users/register") &&
                                 !normalizedEndpoint.contains("/users/search")
        
        // Add trailing slash for all routes except dynamic user routes
        let finalPath: String
        if isDynamicUserRoute {
            // Dynamic user routes: don't add trailing slash (e.g., /users/username)
            finalPath = normalizedEndpoint
        } else {
            // All other routes: add trailing slash to prevent redirects (e.g., /books/personalized/, /auth/token/verify/)
            finalPath = normalizedEndpoint.hasSuffix("/") ? normalizedEndpoint : "\(normalizedEndpoint)/"
        }
        
        // Build URL string (baseURL already ends with /api, so we need / before finalPath)
        let urlString = "\(baseURL)/\(finalPath)"
        
        guard let url = URL(string: urlString) else {
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
            let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleanToken.isEmpty {
                request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
                // Log the length to verify it's not a tiny/empty string
                print("🔐 APIClient: Successfully added valid Bearer token (length: \(cleanToken.count), prefix: \(cleanToken.prefix(10))...)")
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
    
    /// Fetch latest books
    /// - Parameters:
    ///   - page: Page number (default: 1)
    ///   - pageSize: Number of results per page (default: 200)
    /// - Returns: LatestBooksResponse containing books and pagination info
    /// - Throws: Network errors or decoding errors
    func fetchLatestBooks(page: Int = 1, pageSize: Int = 200) async throws -> LatestBooksResponse {
        let queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]
        return try await request(endpoint: "/books/latest", queryItems: queryItems)
    }
    
    /// Fetch personalized book recommendations
    /// - Parameters:
    ///   - type: Type of personalized content (recommended, favorites, authors, genres, continue-reading, onboarding)
    ///   - limit: Number of results (default: 20)
    /// - Returns: PersonalizedBooksResponse containing books
    /// - Throws: Network errors or decoding errors
    func fetchPersonalizedBooks(type: String, limit: Int = 20) async throws -> PersonalizedBooksResponse {
        let queryItems = [
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await request(endpoint: "/books/personalized", queryItems: queryItems)
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
    /// - Returns: UserProfileResponse containing current user data
    /// - Throws: Network errors or decoding errors
    func fetchCurrentUserProfile() async throws -> UserProfileResponse {
        // First get the username from token verification
        let user = try await verifyToken()
        guard let username = user.username, !username.isEmpty else {
            print("⚠️ APIClient: Username is missing from token verification response")
            throw APIError.invalidResponse
        }
        print("✅ APIClient: Got username from token: \(username)")
        return try await fetchUserProfile(username: username)
    }
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

