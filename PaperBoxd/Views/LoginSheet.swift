import SwiftUI
import UIKit

struct LoginSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Welcome back")
                    .font(.title2.bold())
                    .padding(.top, 50)
                    .foregroundColor(.white)
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
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(Color.white)
                    .cornerRadius(30)
                }
                
                // Divider with "or"
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.5))
                    Text("or")
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding(.vertical, 5)

                // 2. Email & Password Fields (Black boxes with dark gray borders, gray text)
                VStack(spacing: 15) {
                    TextField("", text: $email, prompt: Text("Email address").foregroundColor(.gray))
                        .padding()
                        .foregroundColor(.gray)
                        .background(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                        .cornerRadius(15)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .tint(.white) // Cursor color
                    
                    SecureField("", text: $password, prompt: Text("Password").foregroundColor(.gray))
                        .padding()
                        .foregroundColor(.gray)
                        .background(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                        .cornerRadius(15)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .tint(.white) // Cursor color
                }
                
                // 3. Main Action Button (Black background, white text)
                Button(action: {
                    // Handle Email Login
                    print("Email login tapped")
                }) {
                    Text("Log in")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                        .cornerRadius(30)
                }
                
                // 4. Forgot Password (Underlined, white text)
                Button(action: {
                    // Handle Forgot Password
                    print("Forgot password tapped")
                }) {
                    Text("Forgot your password?")
                        .font(.subheadline)
                        .underline()
                        .foregroundColor(.white)
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

