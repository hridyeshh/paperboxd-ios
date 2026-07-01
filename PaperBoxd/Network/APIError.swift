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
    ///
    /// `errorCode` is the flat `error` string (e.g. "book_not_found"), `message`
    /// the human-readable `message` field when the backend supplies one, and
    /// `code` the structured code ("NOT_FOUND", …) used by older routes.
    static func fromBackend(status: Int, code: String?, errorCode: String?, message: String?) -> APIError {
        let msg = displayString(code: code, errorCode: errorCode, message: message)
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

    /// Builds the user-facing string. Prefers an explicit `message`, then a
    /// friendly mapping for known machine codes, then any human string the
    /// backend put in the flat `error` field.
    private static func displayString(code: String?, errorCode: String?, message: String?) -> String {
        if let message, !message.isEmpty {
            return message
        }
        if let mapped = friendlyForCode(errorCode ?? code) {
            return mapped
        }
        if let errorCode, !errorCode.isEmpty {
            return errorCode
        }
        return "Something went wrong — please try again"
    }

    /// Maps known machine error codes to friendly copy. Returns nil for codes
    /// that aren't recognised (e.g. human messages from older routes).
    private static func friendlyForCode(_ code: String?) -> String? {
        switch code {
        case "book_not_found":  return "Couldn't find this book — try searching by title"
        case "scans_exhausted": return "You've used all your free scans"
        case "scoring_failed":  return "Something took too long — your scan hasn't been used"
        default:                return nil
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
    /// Explicit human-readable message (e.g. scan routes: `{error, message}`).
    let message: String?

    struct NestedError: Decodable {
        let code: String?
        let message: String?
    }

    enum CodingKeys: String, CodingKey {
        case error, code, message
    }

    init(error: String?, code: String?, message: String? = nil) {
        self.error = error
        self.code = code
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        var errorOut: String? = nil
        var codeOut: String? = nil
        var messageOut: String? = nil

        if let str = try? c.decode(String.self, forKey: .error) {
            errorOut = str
        } else if let obj = try? c.decode(NestedError.self, forKey: .error) {
            messageOut = obj.message
            codeOut = obj.code
        }

        if let flat = try? c.decode(String.self, forKey: .code) {
            codeOut = flat
        }

        if let m = try? c.decode(String.self, forKey: .message), !m.isEmpty {
            messageOut = m
        }

        self.error = errorOut
        self.code = codeOut
        self.message = messageOut
    }

    static let empty = BackendErrorEnvelope(error: nil, code: nil, message: nil)
}
