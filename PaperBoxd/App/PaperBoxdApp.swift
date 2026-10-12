import SwiftUI

@main
struct PaperBoxdApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Free-scan quota: 3 a month before the backend writes a real count.
        UserDefaults.standard.register(defaults: ["pb_scans_remaining": 3, "pb_scans_unlimited": false])

        // Every AsyncImage cover goes through URLSession.shared, whose default
        // cache (~512KB in memory) held a handful of covers — scrolling back up
        // a grid re-downloaded them. APIClient has its own uncached session.
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)

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
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { appState.recordDailyOpen() }
                }
                .onChange(of: appState.currentScreen) { _, _ in
                    appState.recordDailyOpen()
                }
                .onOpenURL { appState.handleIncomingURL($0) }
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
                .sheet(isPresented: $appState.showTempoPrompt) {
                    TempoPromptView(onDismiss: { appState.showTempoPrompt = false })
                        .presentationDetents([.medium])
                }
        }
    }
}
