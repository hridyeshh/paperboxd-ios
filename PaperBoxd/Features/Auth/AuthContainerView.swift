import Combine
import SwiftUI

/// The paper front door: Welcome, Register, Login and the one-time code all
/// share the onboarding ground, and every page change runs `PageDissolve`.
struct AuthContainerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        ZStack {
            BK.paper.ignoresSafeArea()

            content
                .animation(.easeInOut(duration: 0.25), value: viewModel.mode)
        }
        .preferredColorScheme(.light)
        // `$mode` publishes before the new value lands, so the old page is
        // still on screen: burn it away, or un-burn the page we're going back to.
        .onReceive(viewModel.$mode.removeDuplicates().dropFirst()) { next in
            PageDissolve.cover(reverse: next.depth < viewModel.mode.depth)
        }
        .onAppear {
            viewModel.onAuthSuccess = { [weak appState] token, user, refreshToken in
                appState?.signedIn(token: token, user: user, refreshToken: refreshToken)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.mode {
        case .welcome:
            WelcomeView(viewModel: viewModel).transition(pageTransition)
        case .login:
            LoginView(viewModel: viewModel).transition(pageTransition)
        case .loginOTP:
            OTPView(viewModel: viewModel).transition(pageTransition)
        case .register:
            RegisterView(viewModel: viewModel).transition(pageTransition)
        }
    }

    /// The swap underneath the dissolve is instant so the effect only ever
    /// shows whole pages. Reduce Motion skips the dissolve, so fade instead.
    private var pageTransition: AnyTransition { reduceMotion ? .opacity : .identity }
}

private extension AuthMode {
    /// How deep into the front door a page sits; heading back up plays the
    /// dissolve in reverse.
    var depth: Int {
        switch self {
        case .welcome: 0
        case .login, .register: 1
        case .loginOTP: 2
        }
    }
}
