import SwiftUI
import UIKit

struct LoginSheet: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @State private var email = ""
    @State private var password = ""
    
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
                
                // 1. Google Button (White background, black text)
                Button(action: {
                    // Handle Google Login
                    print("Google login tapped")
                }) {
                    HStack(spacing: 12) {
                        // Try to load Google logo from assets
                        // Note: iOS Assets.xcassets doesn't support .webp directly - convert to PNG first
                        Group {
                            if let googleImage = UIImage(named: "google-log-in") {
                                Image(uiImage: googleImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else if let googleImage = UIImage(named: "google_logo") {
                                Image(uiImage: googleImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                // Fallback: Use a G letter if image not found
                                // This means the asset isn't loading - check:
                                // 1. Asset name matches exactly "google-log-in" (no extension)
                                // 2. Image is PNG/JPEG format (not .webp)
                                // 3. Image is properly added to the image set in Assets.xcassets
                                Text("G")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.blue)
                                    .frame(width: 20, height: 20)
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                        }
                        .frame(width: 20, height: 20)
                        
                        Text("Continue with Google")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(Color.black)
                    .cornerRadius(30)
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
                    // TEMP: Bypass auth and mark user as logged in for testing
                    isLoggedIn = true
                    dismiss()
                }) {
                    Text("Log in")
                        .font(.headline)
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
}

#Preview {
    LoginSheet()
}

