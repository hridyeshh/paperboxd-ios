import SwiftUI
import UIKit

struct LandingView: View {
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showLoginSheet = false
    @State private var showSignUpSheet = false
    @State private var signUpSheetExpanded = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 0. Fallback background color
                Color(red: 0.18, green: 0.18, blue: 0.18)
                    .ignoresSafeArea()
                
                // 1. THE BEAUTIFUL BACKGROUND
                MasonryBackground()
                    .opacity(0.8) // Dim slightly so it doesn't fight the text
                
                // 2. THE GRADIENT FADE (Crucial for the "Pinterest" look)
                // This ensures your white text is readable against colorful photos
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .black.opacity(0.1), // Top is clear
                                .black.opacity(0.3),
                                .black.opacity(0.8),
                                .black               // Bottom is solid black
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .edgesIgnoringSafeArea(.all)
                
                // 3. THE CONTENT
                VStack(spacing: 25) {
                    Spacer()
                    
                    // Logo or Icon
                    Image("icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        )
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                        .padding(.bottom, 10)
                    
                    Text("Share the stories\nthat shape you")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    // Buttons
                    VStack(spacing: 16) {
                        // Sign Up Button (Triggers Sheet)
                        Button(action: {
                            showSignUpSheet = true
                        }) {
                            Text("Sign up")
                                .font(.headline)
                                .foregroundColor(.black) // Ink color
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(Color(red: 0.96, green: 0.93, blue: 0.88)) // "Paper" Cream
                                .cornerRadius(30)
                        }

                        // Log In Button (Triggers Sheet)
                        Button(action: {
                            showLoginSheet = true
                        }) {
                            Text("Log in")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(.ultraThinMaterial) // Frosted glass effect
                                .cornerRadius(30)
                                .overlay( // Optional: subtle border for definition
                                    RoundedRectangle(cornerRadius: 30)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // Terms and Privacy Policy Text
                    termsAndPrivacyText
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                // Animate icon zoom-in when view appears
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    iconScale = 1.0
                    iconOpacity = 1.0
                }
            }
            .sheet(isPresented: $showTerms) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showLoginSheet) {
                LoginSheet()
                    .presentationDetents([.fraction(0.65), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSignUpSheet) {
                SignUpSheet(isExpanded: $signUpSheetExpanded)
                    .presentationDetents(signUpSheetExpanded ? [.large] : [.fraction(0.65), .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    // Terms and Privacy Policy Text with tappable links
    private var termsAndPrivacyText: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("By continuing, you agree to PaperBoxd's ")
                    .font(.caption)
                    .foregroundColor(.gray)
                
//                Text("Terms of Service")
//                    .font(.caption)
//                    .foregroundColor(.white)
//                    .underline()
//                    .onTapGesture {
//                        showTerms = true
//                    }
                
            }
            HStack(spacing: 0) {
        
                Text("Terms of Service")
                    .font(.caption)
                    .foregroundColor(.white)
                    .underline()
                    .onTapGesture {
                        showTerms = true
                    }
                
                Text("and acknowledge that ")
                    .font(.caption)
                    .foregroundColor(.gray)
                
            }
            
            HStack(spacing: 0) {
            
                Text("you've read our ")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.white)
                    .underline()
                    .onTapGesture {
                        showPrivacy = true
                    }
                
                Text(".")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - THE "NO LAG" BACKGROUND COMPONENTS

struct MasonryBackground: View {
    // HARDCODED IMAGES: Ensure these names match your Assets.xcassets exactly
    // Note: Don't include file extensions (.jpg, .png) when referencing assets
    let images = ["image_1", "image_2", "image_3", "image_4", "image_5", "image_6", "image_7", "image_8", "image_9", "image_10", "image_11"]
    
    var body: some View {
        HStack(spacing: 15) {
            // Column 1: Moves medium speed
            MarqueeColumn(images: images.reversed().shuffled(), speed: 50)
            
            // Column 2: Moves slow (creates depth/parallax)
            MarqueeColumn(images: images, speed: 70)
                .padding(.top, -100) // Offset so images aren't aligned horizontally
            
            // Column 3: Moves fast
            MarqueeColumn(images: images.reversed(), speed: 40)
        }
        .rotationEffect(.degrees(-6)) // The "Pinterest Tilt"
        .scaleEffect(1.15) // Zoom in slightly to cover edges caused by rotation
        .drawingGroup() // OPTIMIZATION: Flattens view for GPU rendering (Zero Lag)
    }
}

struct MarqueeColumn: View {
    let images: [String]
    let speed: Double
    
    @State private var offset: CGFloat = 0
    
    // Total height calculation:
    // We assume roughly 250pt height per image + 15pt spacing.
    // 6 images * 265 = ~1590. 
    // We animate by this amount to create a perfect loop.
    private let scrollHeight: CGFloat = 1590
    
    // Colors for fallback placeholders (so we can see if structure is working)
    private let placeholderColors: [Color] = [
        .blue.opacity(0.6),
        .green.opacity(0.6),
        .orange.opacity(0.6),
        .purple.opacity(0.6),
        .pink.opacity(0.6),
        .cyan.opacity(0.6)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 15) {
                // We repeat the stack 3 times to ensure the screen is always full
                // while the animation resets.
                ForEach(0..<3, id: \.self) { _ in
                    ForEach(Array(images.enumerated()), id: \.element) { index, img in
                        ZStack {
                            // Try to load the image
                            Image(img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width)
                                .frame(height: 250)
                                .cornerRadius(15)
                                .clipped()
                            
                            // Fallback: Show colored placeholder if image doesn't exist
                            // This helps debug - if you see colors, the structure works but images aren't loading
                            if UIImage(named: img) == nil {
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(placeholderColors[index % placeholderColors.count])
                                    .frame(width: geometry.size.width)
                                    .frame(height: 250)
                                    .overlay(
                                        Text("\(img)")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    )
                            }
                        }
                    }
                }
            }
            .offset(y: offset)
            .onAppear {
                // The Infinite Loop Logic
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                    offset = -scrollHeight
                }
            }
        }
    }
}

struct LandingView_Previews: PreviewProvider {
    static var previews: some View {
        LandingView()
    }
}
