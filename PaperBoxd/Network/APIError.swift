import Foundation

/// Typed errors surfaced by APIClient. Wraps backend codes per MOBILE_API.md
/// + a few transport-level cases the UI layer needs to distinguish.
enum APIError: LocalizedError, Equatable {
    case transport(String)              // network / DNS / timeout
    case decoding(String)
    case invalidResponse                // not HTTP, or status read failure
    case unauthorized(message: String)  // 401 UNAUTHORIZED / INVALID_TOKEN / EXPIRED_TOKEN
    case forbidden(message: String)
    case notFound(message: String)
    case validation(message: String)
    case rateLimited(message: String)
    case server(message: String)
    case unknown(code: String, message: String)

    /// Initialiser from the backend error envelope.
    static func fromBackend(status: Int, code: String?, message: String?) -> APIError {
        let msg = message ?? "Something went wrong"
        switch code {
        case "UNAUTHORIZED", "INVALID_TOKEN", "EXPIRED_TOKEN":
            return .unauthorized(message: msg)
        case "FORBIDDEN":
            return .forbidden(message: msg)
        case "NOT_FOUND":
            return .notFound(message: msg)
        case "VALIDATION_ERROR":
            return .validation(message: msg)
        case "RATE_LIMITED":
            return .rateLimited(message: msg)
        case "INTERNAL_ERROR":
            return .server(message: msg)
        default:
            // Some routes still emit nested {error:{code,message}} or no code
            // at all. Fall through to a generic unknown with the status.
            if status == 401 { return .unauthorized(message: msg) }
            if status == 403 { return .forbidden(message: msg) }
            if status == 404 { return .notFound(message: msg) }
            if status == 429 { return .rateLimited(message: msg) }
            if (500...599).contains(status) { return .server(message: msg) }
            if (400...499).contains(status) { return .validation(message: msg) }
            return .unknown(code: code ?? "UNKNOWN", message: msg)
        }
    }

    var errorDescription: String? {
        switch self {
        case .transport(let m), .decoding(let m): return m
        case .invalidResponse: return "Server returned an invalid response."
        case .unauthorized(let m), .forbidden(let m), .notFound(let m),
             .validation(let m), .rateLimited(let m), .server(let m):
            return m
        case .unknown(_, let m): return m
        }
    }
}

/// Wire format for backend error envelopes. Handles both the current flat
/// shape `{error: string, code: string}` and the older nested
/// `{error: {code, message}}` shape because Phase 1 will see both during
/// rollout.
struct BackendErrorEnvelope: Decodable {
    let error: String?
    let code: String?

    struct NestedError: Decodable {
        let code: String?
        let message: String?
    }

    enum CodingKeys: String, CodingKey {
        case error, code
    }

    init(error: String?, code: String?) {
        self.error = error
        self.code = code
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        var messageOut: String? = nil
        var codeOut: String? = nil

        if let str = try? c.decode(String.self, forKey: .error) {
            messageOut = str
        } else if let obj = try? c.decode(NestedError.self, forKey: .error) {
            messageOut = obj.message
            codeOut = obj.code
        }

        if let flat = try? c.decode(String.self, forKey: .code) {
            codeOut = flat
        }

        self.error = messageOut
        self.code = codeOut
    }

    static let empty = BackendErrorEnvelope(error: nil, code: nil)
}
