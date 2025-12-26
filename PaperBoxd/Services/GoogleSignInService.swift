import Foundation
import GoogleSignIn

/// Service for handling Google Sign-In authentication
@MainActor
class GoogleSignInService {
    static let shared = GoogleSignInService()
    
    private var clientID: String?
    
    private init() {}
    
    /// Configure Google Sign-In with client ID
    /// Call this in your App's initialization (e.g., PaperBoxdApp.swift)
    func configure(clientID: String) {
        var finalClientID: String?
        
        // Try to get from GoogleService-Info.plist first
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let plistClientID = plist["CLIENT_ID"] as? String {
            finalClientID = plistClientID
        } else if !clientID.isEmpty {
            // Use provided clientID
            finalClientID = clientID
        } else if let envClientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"], !envClientID.isEmpty {
            // Use environment variable
            finalClientID = envClientID
        }
        
        guard let validClientID = finalClientID, !validClientID.isEmpty else {
            print("⚠️ GoogleSignInService: No Google Client ID found. Google Sign-In will not work.")
            return
        }
        
        // Configure Google Sign-In with the client ID
        let configuration = GIDConfiguration(clientID: validClientID)
        GIDSignIn.sharedInstance.configuration = configuration
        self.clientID = validClientID
        
        print("✅ GoogleSignInService: Configured with client ID")
    }
    
    /// Sign in with Google
    /// - Parameter presentingViewController: The view controller to present the sign-in UI
    /// - Returns: The Google ID token string
    /// - Throws: GoogleSignInError if sign-in fails
    func signIn(presentingViewController: UIViewController) async throws -> String {
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInError.noIDToken
        }
        
        print("✅ GoogleSignInService: Successfully obtained Google ID token")
        return idToken
    }
    
    /// Sign out from Google
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        print("✅ GoogleSignInService: Signed out from Google")
    }
}

/// Errors for Google Sign-In
enum GoogleSignInError: LocalizedError {
    case noPresentingViewController
    case noIDToken
    case signInCancelled
    case signInFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noPresentingViewController:
            return "Unable to present Google Sign-In view"
        case .noIDToken:
            return "Failed to obtain Google ID token"
        case .signInCancelled:
            return "Google Sign-In was cancelled"
        case .signInFailed(let error):
            return "Google Sign-In failed: \(error.localizedDescription)"
        }
    }
}

