import SwiftUI

/// Sign-in on the paper ground, built from the same kit as `RegisterView`.
struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var showPassword = false
    @State private var showForgotOptions = false
    @State private var appear = false
    @State private var errorTrigger = 0
    @FocusState private var focused: Field?

    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaperBackHeader(title: "Sign in") { viewModel.switchTo(.welcome) }
                    .padding(.bottom, 22)
                header
                emailField.reveal(appear, delay: 0.1)
                passwordField.reveal(appear, delay: 0.14)
                feedbackRow
                signInButton.reveal(appear, delay: 0.18)
                orDivider.padding(.vertical, 16).reveal(appear, delay: 0.21)
                googleButton.reveal(appear, delay: 0.21)
                registerLink.reveal(appear, delay: 0.24)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .background(BK.paper)
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .shake(trigger: errorTrigger)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appear = true }
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            guard newValue != nil else { return }
            errorTrigger += 1
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Read anything new?")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(BK.ink)
                .reveal(appear, delay: 0)
            Text("Sign in to your account & save it.")
                .font(.system(size: 13.5))
                .foregroundStyle(BK.muted)
                .reveal(appear, delay: 0.05)
        }
        .padding(.bottom, 26)
    }

    // MARK: - Fields

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            onboardingFieldLabel("Email")
            TextField("you@example.com", text: $viewModel.email)
                .font(.system(size: 14))
                .foregroundStyle(BK.ink)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($focused, equals: .email)
                .submitLabel(.next)
                .onSubmit { focused = .password }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(BK.field)
                .overlay(Rectangle().stroke(BK.ink.opacity(0.30), lineWidth: 2))
        }
        .padding(.bottom, 16)
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                onboardingFieldLabel("Password")
                Spacer()
                Button {
                    if viewModel.email.isEmpty {
                        viewModel.errorMessage = "Enter your email first."
                    } else {
                        showForgotOptions = true
                    }
                } label: {
                    Text("Forgot?")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BK.muted)
                }
            }
            ZStack(alignment: .trailing) {
                Group {
                    if showPassword {
                        TextField("••••••••", text: $viewModel.password)
                    } else {
                        SecureField("••••••••", text: $viewModel.password)
                    }
                }
                .font(.system(size: 14))
                .foregroundStyle(BK.ink)
                .textContentType(.password)
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .onSubmit { if canSubmit { Task { await viewModel.login() } } }
                .padding(.horizontal, 14)
                .padding(.trailing, 34)
                .frame(height: 48)
                .background(BK.field)
                .overlay(Rectangle().stroke(BK.ink.opacity(0.30), lineWidth: 2))

                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(BK.muted)
                        .padding(.trailing, 14)
                }
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Feedback

    @ViewBuilder
    private var feedbackRow: some View {
        if let msg = viewModel.errorMessage {
            Text(msg)
                .font(.footnote)
                .foregroundStyle(BK.crimson)
                .padding(.top, 4)
                .padding(.bottom, 10)
        } else if let msg = viewModel.successMessage {
            Text(msg)
                .font(.footnote)
                .foregroundStyle(BK.sage)
                .padding(.top, 4)
                .padding(.bottom, 10)
        }
    }

    // MARK: - Buttons

    private var signInButton: some View {
        OnboardingPrimaryButton(title: "Sign in", isLoading: viewModel.isLoading, isEnabled: canSubmit) {
            Task { await viewModel.login() }
        }
        .padding(.top, 4)
    }

    private var orDivider: some View {
        HStack(spacing: 10) {
            Rectangle().fill(BK.ink.opacity(0.15)).frame(height: 1)
            Text("or")
                .font(.system(size: 11, design: .monospaced))
                .textCase(.uppercase)
                .kerning(2.2)
                .foregroundStyle(BK.muted)
            Rectangle().fill(BK.ink.opacity(0.15)).frame(height: 1)
        }
    }

    private var googleButton: some View {
        Button {
            Task { await viewModel.loginWithGoogle() }
        } label: {
            HStack(spacing: 10) {
                Image("GoogleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text("Continue with Google")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(BK.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(BrutalButtonStyle(fill: BK.card, borderWidth: 2))
        .disabled(viewModel.isLoading)
    }

    private var registerLink: some View {
        HStack(spacing: 4) {
            Text("New here?")
                .foregroundStyle(BK.muted)
            Button("Create an account") {
                viewModel.switchTo(.register)
            }
            .foregroundStyle(BK.ink)
            .fontWeight(.semibold)
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    private var canSubmit: Bool {
        !viewModel.email.isEmpty && !viewModel.password.isEmpty
    }
}
