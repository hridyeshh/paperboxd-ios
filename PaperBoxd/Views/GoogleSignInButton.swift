import SwiftUI

/// A SwiftUI button for Google Sign-In
struct GoogleSignInButton: View {
    let action: () -> Void
    
    // Cache whether the Google logo asset exists to avoid repeated lookups
    private static var hasGoogleLogo: Bool? = nil
    
    private var googleLogoExists: Bool {
        if let cached = Self.hasGoogleLogo {
            return cached
        }
        // Check once and cache the result
        let exists = UIImage(named: "google-log-in") != nil
        Self.hasGoogleLogo = exists
        return exists
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Google logo or fallback icon
                if googleLogoExists {
                    Image("google-log-in")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else {
                    // Fallback: Use SF Symbol with Google colors
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.26, green: 0.52, blue: 0.96), // Google Blue
                                        Color(red: 0.13, green: 0.59, blue: 0.95)  // Lighter Blue
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 20, height: 20)
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Text("Continue with Google")
                    .font(.headline)
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 55)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(30)
        }
    }
}

