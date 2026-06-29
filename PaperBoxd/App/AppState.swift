import Combine
import Foundation
import SwiftUI

/// Root navigation states. Splash is the bootstrap holding state. The
/// PaperBoxdApp root view switches on this enum.
enum AppScreen: Equatable {
    case splash
    case auth
    case onboarding(User)   // post-register, no username yet — pass user so we know the id
    case main(User)         // fully authenticated session
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .splash

    /// Backing user reference — exposed so views that need full identity can
    /// read it without unwrapping the enum each time.
    @Published private(set) var currentUser: User?

    init() {
        // Listen for any layer that calls API and hits 401 — APIClient posts
        // this notification after clearing the keychain. We then reset state.
        NotificationCenter.default.addObserver(
            forName: .paperboxdSessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.currentUser = nil
                self?.currentScreen = .auth
            }
        }
    }

    /// Boots the app: keychain → health → refresh. Sets currentScreen.
    /// Per spec: keychain present + token valid → .main; otherwise .auth.
    func bootstrap() async {
        // Track wall-clock so we can guarantee a minimum splash duration
        // without an extra async-let dance.
        let start = Date()

        guard let token = KeychainManager.shared.getToken(), !token.isEmpty else {
            await holdSplash(since: start)
            transition(to: .auth)
            return
        }

        // Verify the backend is reachable before bothering the user with a
        // 401 from a half-loaded refresh call. Health endpoint is unauthed.
        do {
            let _: HealthResponse = try await APIClient.shared.request(
                path: Endpoints.health,
                method: .get,
                requiresAuth: false
            )
        } catch {
            // Backend unreachable. Keep the token (might be flaky network) and
            // assume cached user is still valid. Route based on stored user.
            await holdSplash(since: start)
            if let cached = KeychainManager.shared.getUser() {
                self.currentUser = cached
                transition(to: needsOnboarding(cached) ? .onboarding(cached) : .main(cached))
            } else {
                transition(to: .auth)
            }
            return
        }

        // Refresh re-mints the token. If it fails, keychain is cleared
        // inside APIClient on 401; treat the error as logout.
        do {
            let resp: RefreshResponse = try await APIClient.shared.request(
                path: Endpoints.mobileRefresh,
                method: .post,
                requiresAuth: true
            )
            KeychainManager.shared.saveToken(resp.token)
            let user = KeychainManager.shared.getUser()
            await holdSplash(since: start)
            if let user {
                self.currentUser = user
                transition(to: needsOnboarding(user) ? .onboarding(user) : .main(user))
            } else {
                // Token valid but no user cached — happens after a reinstall
                // where the keychain survived but UserDefaults did not. Push
                // back to auth so the next login repopulates user.
                KeychainManager.shared.clearAll()
                transition(to: .auth)
            }
        } catch {
            await holdSplash(since: start)
            KeychainManager.shared.clearAll()
            transition(to: .auth)
        }
    }

    /// Keep the splash on screen at least `minimum` seconds so transitions
    /// don't flicker on hot starts with a warm cache.
    private func holdSplash(since start: Date, minimum: TimeInterval = 2.5) async {
        let elapsed = Date().timeIntervalSince(start)
        if elapsed < minimum {
            let remaining = UInt64((minimum - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: remaining)
        }
    }

    /// Called by views after a successful sign-in. Persists user and routes.
    func signedIn(token: String, user: User) {
        KeychainManager.shared.saveToken(token)
        KeychainManager.shared.saveUser(user)
        self.currentUser = user
        transition(to: needsOnboarding(user) ? .onboarding(user) : .main(user))
    }

    /// True when the user hasn't completed mobile onboarding.
    /// nil means the flag wasn't in the cached payload (legacy client) — fall
    /// back to username presence so existing users never hit onboarding again.
    private func needsOnboarding(_ user: User) -> Bool {
        if let completed = user.onboardingCompleted {
            return !completed
        }
        return user.username == nil || user.username?.isEmpty == true
    }

    /// Called mid-onboarding once the username is claimed. Updates the cached
    /// user without routing — the flow continues to the next step.
    func setOnboardingUsername(_ username: String) {
        guard let user = currentUser else { return }
        let updated = User(
            id: user.id,
            username: username,
            email: user.email,
            avatarURL: user.avatarURL,
            level: user.level,
            xp: user.xp,
            onboardingCompleted: user.onboardingCompleted
        )
        currentUser = updated
        KeychainManager.shared.saveUser(updated)
    }

    /// Called when the onboarding flow completes (or is skipped). Marks the user
    /// onboarded and routes to the main app.
    func finishOnboarding() {
        guard let user = currentUser else { return }
        let updated = User(
            id: user.id,
            username: user.username,
            email: user.email,
            avatarURL: user.avatarURL,
            level: user.level,
            xp: user.xp,
            onboardingCompleted: true
        )
        currentUser = updated
        KeychainManager.shared.saveUser(updated)
        transition(to: .main(updated))
    }

    /// Called by manual logout.
    func signOut() {
        KeychainManager.shared.clearAll()
        currentUser = nil
        transition(to: .auth)
    }

    private func transition(to screen: AppScreen) {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.currentScreen = screen
        }
    }
}

extension Notification.Name {
    static let paperboxdSessionExpired = Notification.Name("paperboxd.sessionExpired")
    static let diaryEntryCreated = Notification.Name("paperboxd.diaryEntryCreated")
    static let diaryEntryDeleted = Notification.Name("paperboxd.diaryEntryDeleted")
}
