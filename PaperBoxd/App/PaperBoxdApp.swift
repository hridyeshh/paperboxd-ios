import SwiftUI

@main
struct PaperBoxdApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Force dark appearance project-wide. Belt-and-braces in case Info.plist
        // is missed in a build variant.
        UIWindow.appearance().overrideUserInterfaceStyle = .dark
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .background(Color("Background").ignoresSafeArea())
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch appState.currentScreen {
        case .splash:
            SplashView()
                .transition(.opacity)
        case .auth:
            AuthContainerView()
                .transition(.opacity)
        case .onboarding(let user):
            OnboardingContainerView(user: user)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
        case .main(let user):
            MainTabView(user: user)
                .transition(.opacity)
        }
    }
}

/// Phase 1 placeholder. Real tab bar lands in Phase 2.
struct MainPlaceholderView: View {
    let user: User
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()
            VStack(spacing: 24) {
                Text("PaperBoxd")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(Color("Accent"))
                Text("Welcome, \(user.username ?? user.email).")
                    .font(.body)
                    .foregroundStyle(Color("TextSecondary"))
                Button("Sign out") {
                    appState.signOut()
                }
                .foregroundStyle(Color("TextPrimary"))
                .padding(.top, 32)
            }
            .padding()
        }
    }
}
