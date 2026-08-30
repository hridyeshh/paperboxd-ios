import SwiftUI

struct AuthContainerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.09, blue: 0.09).ignoresSafeArea()
            BookCoverColumns().ignoresSafeArea()
            darkWash

            content
                .animation(.easeInOut(duration: 0.25), value: viewModel.mode)
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
        case .login:
            LoginView(viewModel: viewModel).transition(.opacity)
        case .loginOTP:
            OTPView(viewModel: viewModel).transition(.opacity)
        case .register:
            RegisterView(viewModel: viewModel).transition(.opacity)
        }
    }

    private var darkWash: some View {
        ZStack {
            RadialGradient(
                colors: [.black.opacity(0.48), .black.opacity(0.74), .black.opacity(0.90)],
                center: .center, startRadius: 0, endRadius: 440
            )
            LinearGradient(
                colors: [.black.opacity(0.40), .black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
