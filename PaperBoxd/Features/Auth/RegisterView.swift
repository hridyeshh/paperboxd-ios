import SwiftUI

/// Step 1 of the paper-themed signup run. Email + a single password field —
/// confirmation and the terms checkbox are dropped from the UI; register()
/// still wants a confirmPassword, so we mirror it in on submit.
struct RegisterView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var showPassword = false
    @State private var legalSheet: LegalDocKind?
    @State private var appear = false
    @State private var errorTrigger = 0
    @FocusState private var focused: Field?

    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PBStepHeader(step: 1, onBack: { viewModel.switchTo(.welcome) })
                    .padding(.bottom, 22)
                header
                emailField.reveal(appear, delay: 0.1)
                passwordField.reveal(appear, delay: 0.14)
                errorRow
                createButton.reveal(appear, delay: 0.18)
                orDivider.padding(.vertical, 16).reveal(appear, delay: 0.21)
                googleButton.reveal(appear, delay: 0.21)
                continueWithEmailButton.reveal(appear, delay: 0.24)
                legalFooter.reveal(appear, delay: 0.27)
                signInLink.reveal(appear, delay: 0.27)
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
        .environment(\.openURL, OpenURLAction { url in
            switch url.absoluteString {
            case "paperboxd://terms":   legalSheet = .terms;   return .handled
            case "paperboxd://privacy": legalSheet = .privacy; return .handled
            default:                    return .systemAction
            }
        })
        .sheet(item: $legalSheet) { kind in
            LegalSheetView(kind: kind)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start your\nreading life.")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .lineSpacing(2)
                .foregroundStyle(BK.ink)
                .reveal(appear, delay: 0)
            Text("Track books, follow friends, get smarter recs the more you read.")
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
            onboardingFieldLabel("Password")
            ZStack(alignment: .trailing) {
                Group {
                    if showPassword {
                        TextField("Min 8 characters", text: $viewModel.password)
                    } else {
                        SecureField("Min 8 characters", text: $viewModel.password)
                    }
                }
                .font(.system(size: 14))
                .foregroundStyle(BK.ink)
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .onSubmit { if canSubmit { submit() } }
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

    @ViewBuilder
    private var errorRow: some View {
        if let msg = viewModel.errorMessage {
            Text(msg)
                .font(.footnote)
                .foregroundStyle(BK.crimson)
                .padding(.top, 4)
                .padding(.bottom, 10)
        }
    }

    private var createButton: some View {
        OnboardingPrimaryButton(title: "Create account", isLoading: viewModel.isLoading, isEnabled: canSubmit) {
            submit()
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
        .padding(.bottom, 10)
    }

    /// Same submit path as "Create account" — a second, lower-emphasis entry
    /// point for readers who land here wanting to type an email and go.
    private var continueWithEmailButton: some View {
        Button {
            if canSubmit { submit() } else { focused = .email }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "envelope")
                    .font(.system(size: 14, weight: .semibold))
                Text("Continue with email")
                    .font(.system(size: 14.5, weight: .semibold))
            }
            .foregroundStyle(BK.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(BrutalButtonStyle(fill: BK.card, borderWidth: 2))
        .disabled(viewModel.isLoading)
    }

    private var legalFooter: some View {
        Text("By continuing you agree to our [terms](paperboxd://terms) and [privacy policy](paperboxd://privacy).")
            .font(.system(size: 11.5))
            .foregroundStyle(BK.muted)
            .tint(BK.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
    }

    private var signInLink: some View {
        HStack(spacing: 4) {
            Text("Already reading?")
                .foregroundStyle(BK.muted)
            Button("Sign in") {
                viewModel.switchTo(.login)
            }
            .foregroundStyle(BK.ink)
            .fontWeight(.semibold)
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var canSubmit: Bool {
        looksLikeEmail(viewModel.email) && viewModel.password.count >= 8
    }

    private func submit() {
        viewModel.confirmPassword = viewModel.password
        Task { await viewModel.register() }
    }
}
