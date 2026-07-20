import SwiftUI

@main
struct PaperBoxdApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Free-scan quota defaults to 7 before the first scan writes a real count.
        UserDefaults.standard.register(defaults: ["pb_scans_remaining": 7])

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
