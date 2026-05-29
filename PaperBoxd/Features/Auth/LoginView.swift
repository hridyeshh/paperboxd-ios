import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var showPassword = false
    @State private var showForgotOptions = false
    @State private var cardIn = false
    @FocusState private var focused: Field?

    enum Field { case email, password }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            glassCard
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .offset(y: cardIn ? 0 : 420)
                .opacity(cardIn ? 1 : 0)
                .animation(.spring(response: 0.62, dampingFraction: 0.84), value: cardIn)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                cardIn = true
            }
        }
        .confirmationDialog(
            "How would you like to continue?",
            isPresented: $showForgotOptions,
            titleVisibility: .visible
        ) {
            Button("Send a one-time code") {
                Task { await viewModel.sendOTP() }
            }
            Button("Reset password via email") {
                Task { await viewModel.forgotPassword() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text("PaperBoxd")
                .font(.custom("SnellRoundhand-Black", size: 30))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.white)
            Spacer()
            Text("sign in")
                .font(.system(size: 9.5, design: .monospaced))
                .textCase(.uppercase)
                .kerning(1.6)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        }
        .padding(.horizontal, 26)
        .padding(.top, 20)
    }

    // MARK: - Glass card

    private var glassCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            emailField
            passwordField
            feedbackRow
            signInButton
            orDivider.padding(.vertical, 14)
            googleButton
            registerLink
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 26)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 0.055, green: 0.055, blue: 0.065).opacity(0.54))
                // Top-edge shimmer — glass catches ambient light
                LinearGradient(
                    colors: [.white.opacity(0.07), .clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.14)
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.62), radius: 58, x: 0, y: 34)
        .contentShape(Rectangle())
        .onTapGesture { focused = nil }
    }

    // MARK: - Card header

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back,\nreader.")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.8)
                .lineSpacing(1)
                .foregroundStyle(.white)
            Text("Your shelves are right where you left them.")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.62))
                .lineSpacing(2)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Fields

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldLabel("Email")
            DarkTextField(
                title: "you@paperboxd.com",
                text: $viewModel.email,
                keyboard: .emailAddress,
                contentType: .username
            )
            .focused($focused, equals: .email)
            .submitLabel(.next)
            .onSubmit { focused = .password }
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                fieldLabel("Password")
                Spacer()
                Button {
                    if viewModel.email.isEmpty {
                        viewModel.errorMessage = "Enter your email first."
                    } else {
                        showForgotOptions = true
                    }
                } label: {
                    Text("Forgot?")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.bottom, 6)
            }
            .padding(.top, 12)
            ZStack(alignment: .trailing) {
                DarkSecureField(
                    title: "••••••••",
                    text: $viewModel.password,
                    showText: showPassword
                )
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .onSubmit { Task { await viewModel.login() } }
                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.trailing, 14)
                }
            }
        }
    }

    // MARK: - Feedback

    @ViewBuilder
    private var feedbackRow: some View {
        if let msg = viewModel.errorMessage {
            Text(msg)
                .font(.footnote)
                .foregroundStyle(Color("Error"))
                .padding(.top, 10)
        } else if let msg = viewModel.successMessage {
            Text(msg)
                .font(.footnote)
                .foregroundStyle(Color(red: 0.3, green: 0.85, blue: 0.5))
                .padding(.top, 10)
        }
    }

    // MARK: - Buttons

    private var signInButton: some View {
        let enabled = !viewModel.email.isEmpty && !viewModel.password.isEmpty
        return Button {
            Task { await viewModel.login() }
        } label: {
            ZStack {
                if viewModel.isLoading {
                    ProgressView().tint(.black)
                } else {
                    HStack(spacing: 8) {
                        Text("Sign in")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .font(.system(size: 14.5, weight: .semibold))
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(.white, in: Capsule())
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled || viewModel.isLoading)
        .padding(.top, 18)
        .animation(.easeInOut(duration: 0.18), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.18), value: enabled)
    }

    private var orDivider: some View {
        HStack(spacing: 10) {
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
            Text("or")
                .font(.system(size: 11, design: .monospaced))
                .textCase(.uppercase)
                .kerning(2.2)
                .foregroundStyle(.white.opacity(0.3))
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
        }
    }

    private var googleButton: some View {
        Button {
            Task { await viewModel.loginWithGoogle() }
        } label: {
            HStack(spacing: 10) {
                googleLogo
                Text("Continue with Google")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.13), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(viewModel.isLoading)
    }

    private var googleLogo: some View {
        ZStack {
            Circle().fill(.white).frame(width: 18, height: 18)
            Text("G")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
        }
    }

    private var registerLink: some View {
        HStack(spacing: 5) {
            Text("New here?")
                .foregroundStyle(.white.opacity(0.48))
            Button("Create an account") {
                viewModel.switchTo(.register)
            }
            .foregroundStyle(.white.opacity(0.90))
            .fontWeight(.semibold)
            .underline(color: .white.opacity(0.30))
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(.white.opacity(0.48))
            .padding(.bottom, 6)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.11), value: configuration.isPressed)
    }
}
