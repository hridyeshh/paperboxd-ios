import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Google OAuth 2.0 Authorization Code + PKCE for native iOS.
/// No GoogleSignIn SDK required — uses ASWebAuthenticationSession.
///
/// Setup (one-time):
///   1. https://console.cloud.google.com → Credentials → Create → OAuth 2.0 Client → iOS
///   2. Enter your app's Bundle ID (in.paperboxd.app)
///   3. Copy the generated Client ID (looks like: 123456789-abc...xyz.apps.googleusercontent.com)
///   4. Paste it into Config.swift as `googleClientID`
///
/// No Info.plist URL scheme needed — ASWebAuthenticationSession handles the redirect internally.
@MainActor
enum GoogleOAuth {

    private static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    private static let scope         = "openid email profile"

    // Derived from client ID: reversed, e.g. com.googleusercontent.apps.123...abc
    private static var redirectScheme: String {
        let parts = Config.googleClientID
            .replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
            .split(separator: "-")
        return "com.googleusercontent.apps." + parts.joined(separator: "-")
    }
    private static var redirectURI: String { "\(redirectScheme):/oauth2redirect" }

    /// Full sign-in flow → returns Google id_token string.
    /// Throws `GoogleOAuthError` or `URLError` on failure.
    static func signIn() async throws -> String {
        let verifier  = makeVerifier()
        let challenge = try sha256Base64URL(verifier)
        let state     = UUID().uuidString

        var comps     = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id",             value: Config.googleClientID),
            .init(name: "redirect_uri",          value: redirectURI),
            .init(name: "response_type",         value: "code"),
            .init(name: "scope",                 value: scope),
            .init(name: "code_challenge",        value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state",                 value: state),
        ]
        guard let authURL = comps.url else { throw GoogleOAuthError.badURL }

        // 1 — Open browser, receive redirect
        let callbackURL = try await presentBrowser(url: authURL)

        // 2 — Extract auth code
        guard
            let cbComps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            cbComps.queryItems?.first(where: { $0.name == "state" })?.value == state,
            let code = cbComps.queryItems?.first(where: { $0.name == "code" })?.value
        else { throw GoogleOAuthError.missingCode }

        // 3 — Exchange code for id_token (PKCE, no client_secret needed for native clients)
        return try await exchangeForIDToken(code: code, verifier: verifier)
    }

    // MARK: - Browser

    private static func presentBrowser(url: URL) async throws -> URL {
        guard let window = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: { $0.isKeyWindow })
        else { throw GoogleOAuthError.noWindow }

        return try await withCheckedThrowingContinuation { continuation in
            // session must stay alive until the callback fires — capture it in the closure
            var session: ASWebAuthenticationSession?
            session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: redirectScheme
            ) { callbackURL, error in
                _ = session  // keep alive
                session = nil
                if let error {
                    let nsErr = error as NSError
                    if nsErr.domain == ASWebAuthenticationSessionErrorDomain,
                       nsErr.code  == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: GoogleOAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: GoogleOAuthError.cancelled)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session?.presentationContextProvider = window
            session?.prefersEphemeralWebBrowserSession = false
            session?.start()
        }
    }

    // MARK: - Token exchange

    private static func exchangeForIDToken(code: String, verifier: String) async throws -> String {
        var req = URLRequest(url: tokenEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params: [(String, String)] = [
            ("grant_type",    "authorization_code"),
            ("code",          code),
            ("redirect_uri",  redirectURI),
            ("client_id",     Config.googleClientID),
            ("code_verifier", verifier),
        ]
        req.httpBody = params
            .map { "\($0)=\($1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GoogleOAuthError.tokenExchangeFailed(body)
        }

        struct TokenResponse: Decodable { let id_token: String }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        return decoded.id_token
    }

    // MARK: - PKCE

    private static func makeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func sha256Base64URL(_ input: String) throws -> String {
        guard let data = input.data(using: .utf8) else { throw GoogleOAuthError.badURL }
        return Data(SHA256.hash(data: data)).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// UIWindow presents the OAuth browser sheet.
extension UIWindow: @retroactive ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { self }
}

enum GoogleOAuthError: LocalizedError {
    case badURL, missingCode, cancelled, noWindow, tokenExchangeFailed(String)
    var errorDescription: String? {
        switch self {
        case .badURL:                        return "Invalid OAuth configuration."
        case .missingCode:                   return "Google sign-in failed — no auth code returned."
        case .cancelled:                     return "Sign-in was cancelled."
        case .noWindow:                      return "No window available to present sign-in."
        case .tokenExchangeFailed(let msg):  return "Google token exchange failed: \(msg)"
        }
    }
}
