import SwiftUI

struct AppCoordinator: View {
    // 🎨 MOTION STATE
    @State private var showSplash = true
    @State private var splashAnimationFinished = false
    
    // App state management (from PaperBoxdApp)
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    
    var body: some View {
        ZStack {
            // 1. The Main App (Pre-loaded in background)
            if splashAnimationFinished {
                if isLoggedIn {
                    HomeView()
                        .transition(.opacity.animation(.easeIn(duration: 0.5)))
                } else {
                    LandingView()
                        .transition(.opacity.animation(.easeIn(duration: 0.5)))
                }
            }
            
            // 2. The Splash Overlay
            if showSplash {
                SplashScreen(isActive: $splashAnimationFinished)
                    // Ensure it stays on top
                    .zIndex(1)
            }
        }
        .onAppear {
            // Check for existing authentication token on app launch
            checkAuthenticationStatus()
        }
        .onChange(of: isLoggedIn) { oldValue, newValue in
            // React to authentication state changes
            // This ensures smooth transition when user signs up or logs in
            if newValue {
                print("✅ AppCoordinator: User logged in, transitioning to HomeView")
            } else {
                print("ℹ️ AppCoordinator: User logged out, showing LandingView")
            }
        }
    }
    
    /// Check if user has a valid authentication token stored in Keychain
    /// This runs on app launch to determine initial state
    private func checkAuthenticationStatus() {
        if KeychainHelper.shared.readToken() != nil {
            // Token exists - user is authenticated
            print("✅ AppCoordinator: Found existing auth token, user is logged in")
            isLoggedIn = true
        } else {
            // No token found - new user or logged out
            // Show LandingView with Sign Up / Log In options
            print("ℹ️ AppCoordinator: No auth token found, showing landing page for new user")
            isLoggedIn = false
        }
    }
}

// MARK: - The Animated Splash Screen
struct SplashScreen: View {
    @Binding var isActive: Bool
    
    // Animation States
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var backgroundOpacity: Double = 1.0
    
    var body: some View {
        ZStack {
            // 1. Background (Matches LandingView exactly)
            Color(red: 0.18, green: 0.18, blue: 0.18)
                .ignoresSafeArea()
                .opacity(backgroundOpacity)
            
            VStack(spacing: 16) {
                // 2. Logo Icon
                ZStack {
                    Circle()
                        .fill(Color(red: 0.205, green: 0.985, blue: 0.985).opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image("icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                .shadow(color: .cyan.opacity(0.5), radius: 20, x: 0, y: 0)
                
                // 3. Brand Text
                Text("PaperBoxd")
                    .font(.system(size: 48, weight: .bold, design: .rounded)) // Fallback if custom font not available
                    .foregroundColor(.white)
                    .tracking(2) // Cinematic letter spacing
                    .opacity(textOpacity)
                    .offset(y: textOffset)
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Step 1: Spring the Icon in (0.0s - 0.5s)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        
        // Step 2: Slide up the text (0.5s - 1.8s)
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            textOpacity = 1.0
            textOffset = 0
        }
        
        // Step 3: Exit Sequence (1.8s - 2.0s)
        // We wait for 2 seconds total, then fade out smoothly
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                // Scale up slightly as we fade out (Zoom effect)
                iconScale = 1.5
                backgroundOpacity = 0
                textOpacity = 0
                iconOpacity = 0
            }
            
            // Remove from view hierarchy after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation {
                    self.isActive = true
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AppCoordinator()
}

