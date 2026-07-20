import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Actor-isolated HTTP client. One shared instance. URLSession only — no
/// third-party libs in Phase 1.
///
/// Responsibilities:
/// - Inject `Authorization: Bearer <token>` from KeychainManager when
///   `requiresAuth` is true.
/// - Decode the backend error envelope on non-2xx and throw a typed APIError.
/// - On 401, clear the keychain and post `.paperboxdSessionExpired` so AppState
///   routes the user back to auth.
actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL: URL

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.waitsForConnectivity = true
        // API responses must never be served from URLCache: pull-to-refresh and
        // post-delete refetches were returning stale cached JSON until relaunch.
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.urlCache = nil
        cfg.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": Config.userAgent,
        ]
        self.session = URLSession(configuration: cfg)
        self.baseURL = Config.backendURL
    }

    /// Generic request. Pass `Empty` for void responses.
    func request<Response: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        requiresAuth: Bool = false
    ) async throws -> Response {
        let data = try await rawRequest(path: path, method: method, body: body, requiresAuth: requiresAuth)
        if Response.self == Empty.self {
            // Caller wanted void; produce a synthesized Empty.
            return Empty() as! Response
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding("Failed to decode \(Response.self): \(error.localizedDescription)")
        }
    }

    /// Uploads a single file as `multipart/form-data`. Used for avatar upload,
    /// which the backend forwards to Cloudinary (signed, server-side).
    func upload<Response: Decodable>(
        path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fieldName: String = "file",
        requiresAuth: Bool = true
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.transport("Invalid URL: \(path)")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: url)
        req.httpMethod = HTTPMethod.post.rawValue
        // Override the actor's default JSON Content-Type for this request only.
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        if requiresAuth, let token = KeychainManager.shared.getToken(), !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data = try await send(req)
        if Response.self == Empty.self {
            return Empty() as! Response
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding("Failed to decode \(Response.self): \(error.localizedDescription)")
        }
    }

    /// Returns raw `Data` for endpoints with bespoke decoding.
    func rawRequest(
        path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        requiresAuth: Bool = false
    ) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.transport("Invalid URL: \(path)")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue

        if let body {
            do {
                req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
            } catch {
                throw APIError.transport("Failed to encode body: \(error.localizedDescription)")
            }
        }

        if requiresAuth {
            // Keychain reads are sync and cheap; safe in actor context.
            if let token = KeychainManager.shared.getToken(), !token.isEmpty {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        return try await send(req)
    }

    /// Performs the request, maps status codes, and surfaces typed errors. Shared
    /// by `rawRequest` and `upload` so the 401 / error-envelope handling stays in
    /// one place.
    private func send(_ req: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch is CancellationError {
            throw CancellationError()
        } catch let e as URLError where e.code == .cancelled {
            // Task was cancelled (e.g. pull-to-refresh gesture ended). Surface as
            // CancellationError, not a transport failure, so callers can ignore it.
            throw CancellationError()
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if (200...299).contains(http.statusCode) {
            return data
        }

        // Non-2xx: parse envelope, surface typed error. Fall back to .empty
        // if the body isn't JSON (e.g. raw 502 from a proxy).
        let envelope = (try? JSONDecoder().decode(BackendErrorEnvelope.self, from: data)) ?? .empty

        let typed = APIError.fromBackend(
            status: http.statusCode,
            code: envelope.code,
            errorCode: envelope.error,
            message: envelope.message
        )

        if http.statusCode == 401 {
            // Don't loop if the request itself was the refresh attempt
            // (caller can still handle via APIError.unauthorized).
            KeychainManager.shared.clearAll()
            NotificationCenter.default.post(name: .paperboxdSessionExpired, object: nil)
        }

        throw typed
    }
}

/// Sentinel response type for endpoints that return no body we care about.
struct Empty: Decodable {}

/// Tiny eraser so the generic body parameter can be any Encodable.
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        self._encode = wrapped.encode
    }
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

