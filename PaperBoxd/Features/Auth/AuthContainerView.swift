import SwiftUI

struct AuthContainerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        ZStack {
            // Paper ground, continuous with the splash before it and the home
            // screen after it — the cover wall and its dark wash belonged to the
            // old dark auth design and would break that run of colour.
            BK.paper.ignoresSafeArea()
            DotGrid().ignoresSafeArea()

            content
                .animation(.easeInOut(duration: 0.25), value: viewModel.mode)
        }
        // The app forces dark appearance window-wide; auth is a paper surface,
        // so it opts back into light or the keyboard and other system chrome
        // come up dark against it.
        .preferredColorScheme(.light)
        .onAppear {
            viewModel.onAuthSuccess = { [weak appState] token, user, refreshToken in
                appState?.signedIn(token: token, user: user, refreshToken: refreshToken)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.mode {
        case .login:
            LoginView(viewModel: viewModel).transition(.opacity)
        case .loginOTP:
            OTPView(viewModel: viewModel).transition(.opacity)
        case .register:
            RegisterView(viewModel: viewModel).transition(.opacity)
        }
    }

}

/// The same faint ink dot grid the home screen lays over its paper, so auth and
/// home read as one surface.
private struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 26
            let radius: CGFloat = 0.75
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                               width: radius * 2, height: radius * 2)),
                        with: .color(BK.ink.opacity(0.05))
                    )
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}
