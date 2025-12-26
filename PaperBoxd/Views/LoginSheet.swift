import SwiftUI
import UIKit

struct LoginSheet: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isGoogleSigningIn = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // System background
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Welcome back")
                    .font(.title2.bold())
                    .padding(.top, 50)
                    .foregroundColor(.primary)
                    .padding(.top, 20)
                
                // 1. Official Google Sign-In Button
                if isGoogleSigningIn {
                    // Show loading state
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Signing in...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(Color.black)
                    .cornerRadius(30)
                } else {
                    // Official Google Sign-In Button
                    GoogleSignInButton(action: handleGoogleSignIn)
                        .frame(height: 55)
                        .disabled(isLoading)
                }
                
                // Divider with "or"
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.5))
                    Text("or")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding(.vertical, 5)

                // 2. Email & Password Fields (Black boxes with dark gray borders, gray text)
                VStack(spacing: 15) {
                    TextField("", text: $email, prompt: Text("Email address").foregroundColor(.secondary))
                        .padding()
                        .foregroundColor(.primary)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                        )
                        .cornerRadius(15)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .tint(.primary) // Cursor color
                    
                    SecureField("", text: $password, prompt: Text("Password").foregroundColor(.secondary))
                        .padding()
                        .foregroundColor(.primary)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                        )
                        .cornerRadius(15)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .tint(.primary) // Cursor color
                }
                
                // 3. Main Action Button (Black background, white text)
                Button(action: {
                    handleLogin()
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Text("Log in")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                    )
                    .cornerRadius(30)
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                
                // Error message display
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }
                
                // 4. Forgot Password (Underlined)
                Button(action: {
                    // Handle Forgot Password
                    print("Forgot password tapped")
                }) {
                    Text("Forgot your password?")
                        .font(.subheadline)
                        .underline()
                        .foregroundColor(.primary)
                }
                .padding(.top, 5)
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.top, 20)
        }
    }
    
    /// Handle login with email and password
    private func handleLogin() {
        // Validate input
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password"
            return
        }
        
        // Clear previous error
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                // Call the API
                let response: AuthResponse = try await APIClient.shared.login(email: email, password: password)
                
                // Save token securely to Keychain
                KeychainHelper.shared.saveToken(response.token)
                
                print("✅ LoginSheet: Successfully logged in user: \(response.user.email)")
                
                // Update UI on main thread
                await MainActor.run {
                    isLoggedIn = true
                    isLoading = false
                    dismiss()
                }
            } catch let error as APIError {
                await MainActor.run {
                    isLoading = false
                    switch error {
                    case .httpError(let statusCode):
                        if statusCode == 401 {
                            errorMessage = "Invalid email or password"
                        } else {
                            errorMessage = "Login failed. Please try again."
                        }
                    case .networkError:
                        errorMessage = "Network error. Please check your connection."
                    default:
                        errorMessage = "Login failed. Please try again."
                    }
                    print("❌ LoginSheet: Login failed - \(error.localizedDescription)")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "An unexpected error occurred"
                    print("❌ LoginSheet: Unexpected error - \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Handle Google Sign-In
    /// This method gets the root view controller and initiates the Google Sign-In flow
    /// The official GoogleSignInButton calls this action when tapped
    private func handleGoogleSignIn() {
        isGoogleSigningIn = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                // Get the root view controller for presenting Google Sign-In
                // This is required for the Google Sign-In SDK to present the authentication UI
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    isGoogleSigningIn = false
                    errorMessage = "Unable to present sign-in. Please try again."
                    return
                }
                
                // Get Google ID token using our service
                let idToken = try await GoogleSignInService.shared.signIn(presentingViewController: rootViewController)
                
                // Call backend to verify and get JWT
                let response: AuthResponse = try await APIClient.shared.signInWithGoogle(idToken: idToken)
                
                // Validate token before saving
                let token = response.token.trimmingCharacters(in: .whitespaces)
                guard !token.isEmpty else {
                    print("❌ LoginSheet: Received empty token from backend")
                    isGoogleSigningIn = false
                    errorMessage = "Authentication failed: Invalid token received"
                    return
                }
                
                print("✅ LoginSheet: Received token from backend (length: \(token.count), prefix: \(token.prefix(20))...)")
                
                // Save token securely to Keychain
                KeychainHelper.shared.saveToken(token)
                
                // Verify token was saved correctly
                if let savedToken = KeychainHelper.shared.readToken(), savedToken == token {
                    print("✅ LoginSheet: Token successfully saved to Keychain")
                } else {
                    print("⚠️ LoginSheet: Token may not have been saved correctly")
                }
                
                print("✅ LoginSheet: Successfully signed in with Google: \(response.user.email)")
                
                // Update UI - we're already on MainActor
                isLoggedIn = true
                isGoogleSigningIn = false
                dismiss()
            } catch let error as GoogleSignInError {
                isGoogleSigningIn = false
                switch error {
                case .signInCancelled:
                    // User cancelled - don't show error
                    print("ℹ️ LoginSheet: Google Sign-In cancelled by user")
                default:
                    errorMessage = "Google Sign-In failed. Please try again."
                    print("❌ LoginSheet: Google Sign-In failed - \(error.localizedDescription)")
                }
            } catch let error as APIError {
                isGoogleSigningIn = false
                switch error {
                case .httpError(let statusCode):
                    if statusCode == 401 {
                        errorMessage = "Google Sign-In failed. Please try again."
                    } else {
                        errorMessage = "Authentication failed. Please try again."
                    }
                case .networkError:
                    errorMessage = "Network error. Please check your connection."
                default:
                    errorMessage = "Google Sign-In failed. Please try again."
                }
                print("❌ LoginSheet: Google Sign-In API error - \(error.localizedDescription)")
            } catch {
                isGoogleSigningIn = false
                errorMessage = "An unexpected error occurred"
                print("❌ LoginSheet: Unexpected error - \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    LoginSheet()
}

