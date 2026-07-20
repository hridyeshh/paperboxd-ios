import Foundation

/// Centralised configuration. Build-time switch picks the backend URL; no
/// production URLs leak into a debug binary and vice versa.
///
/// To add staging later: introduce a third compilation flag (e.g.
/// `-DSTAGING`) and branch here.
enum Config {
    nonisolated static let backendURL: URL = {
        #if DEBUG
        // Current decision: debug + release both hit Railway prod. When local
        // backend dev is desired, flip this to:
        //   URL(string: "http://localhost:8080")!
        return URL(string: "https://paperboxd-backend-production-d9e0.up.railway.app")!
        #else
        return URL(string: "https://paperboxd-backend-production-d9e0.up.railway.app")!
        #endif
    }()

    /// User-Agent the backend sees. Helps backend logs distinguish surfaces.
    nonisolated static let userAgent: String = "PaperBoxd-iOS/\(Bundle.shortVersion) (iOS)"

    /// Keychain service identifier. Stays stable across builds so tokens
    /// survive reinstall-from-Xcode during development.
    nonisolated static let keychainService: String = "in.paperboxd.app"

    /// Google OAuth 2.0 iOS client ID.
    /// Get from: console.cloud.google.com → Credentials → Create → OAuth 2.0 Client → iOS
    /// Enter bundle ID: in.paperboxd.app — copy the generated client ID here.
    nonisolated static let googleClientID: String = "893085484645-68k40avfeifi14qdpah7cqtuu7e0qntj.apps.googleusercontent.com"
}

private extension Bundle {
    nonisolated static var shortVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }
}
