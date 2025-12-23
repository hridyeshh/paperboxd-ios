import Foundation

/// Singleton API client for making requests to the PaperBoxd API
class APIClient {
    static let shared = APIClient()
    
    private let baseURL = "https://paperboxd.in/api"
    
    private init() {}
    
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
        // Construct URL
        guard let baseURLInstance = URL(string: baseURL) else {
            throw APIError.invalidURL
        }
        
        var urlComponents = URLComponents(url: baseURLInstance.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false)
        
        if let queryItems = queryItems {
            urlComponents?.queryItems = queryItems
        }
        
        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }
        
        print("🌐 APIClient: Making request to \(url.absoluteString)")
        
        // Perform request
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
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
    
    /// Fetch books for the sphere visualization
    /// - Returns: SphereResponse containing an array of books
    /// - Throws: Network errors or decoding errors
    func fetchSphereBooks() async throws -> SphereResponse {
        let queryItems = [URLQueryItem(name: "limit", value: "80")]
        return try await request(endpoint: "/books/sphere", queryItems: queryItems)
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

