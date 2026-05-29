import SwiftUI

struct RegisterView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var showPassword = false
    @State private var showConfirm  = false
    @FocusState private var focused: Field?

    enum Field { case email, password, confirm }

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
                ZStack {
                    Circle().fill(.white).frame(width: 18, height: 18)
                    Text("G")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                }
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

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            glassCard
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text("PaperBoxd")
                .font(.custom("SnellRoundhand-Black", size: 30))
                .foregroundStyle(.white)
            Spacer()
            Text("register")
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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader
                emailField
                passwordFields
                errorRow
                createButton
                orDivider.padding(.vertical, 14)
                googleButton
                signInLink
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 0.055, green: 0.055, blue: 0.065).opacity(0.54))
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
    }

    // MARK: - Card sections

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start your\nreading life.")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.8)
                .lineSpacing(1)
                .foregroundStyle(.white)
            Text("Track every book worth remembering.")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.62))
                .lineSpacing(2)
        }
        .padding(.bottom, 24)
    }

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

    private var passwordFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldLabel("Password").padding(.top, 12)
            ZStack(alignment: .trailing) {
                DarkSecureField(
                    title: "Min 8 characters",
                    text: $viewModel.password,
                    showText: showPassword
                )
                .focused($focused, equals: .password)
                .submitLabel(.next)
                .onSubmit { focused = .confirm }
                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.trailing, 14)
                }
            }

            if !viewModel.password.isEmpty {
                strengthBar.padding(.top, 8)
            }

            fieldLabel("Confirm password").padding(.top, 12)
            ZStack(alignment: .trailing) {
                DarkSecureField(
                    title: "Repeat password",
                    text: $viewModel.confirmPassword,
                    showText: showConfirm
                )
                .focused($focused, equals: .confirm)
                .submitLabel(.go)
                .onSubmit {
                    if canSubmit { Task { await viewModel.register() } }
                }
                Button { showConfirm.toggle() } label: {
                    Image(systemName: showConfirm ? "eye.slash" : "eye")
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.trailing, 14)
                }
            }
        }
    }

    private var strengthBar: some View {
        let strength = PasswordStrength.from(viewModel.password)
        return HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { idx in
                Capsule()
                    .fill(idx <= strength.rawValue ? strength.color : Color("Border"))
                    .frame(height: 3)
            }
            Text(strength.label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    @ViewBuilder
    private var errorRow: some View {
        if let msg = viewModel.errorMessage {
            Text(msg)
                .font(.footnote)
                .foregroundStyle(Color("Error"))
                .padding(.top, 10)
        }
    }

    private var createButton: some View {
        PrimaryButton(
            "Create Account",
            isLoading: viewModel.isLoading,
            isEnabled: canSubmit
        ) {
            Task { await viewModel.register() }
        }
        .padding(.top, 18)
    }

    private var signInLink: some View {
        HStack(spacing: 4) {
            Text("Already reading?")
                .foregroundStyle(.white.opacity(0.52))
            Button("Sign in") {
                viewModel.switchTo(.login)
            }
            .foregroundStyle(.white)
            .fontWeight(.semibold)
            .underline(color: .white.opacity(0.35))
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    private var canSubmit: Bool {
        !viewModel.email.isEmpty
            && !viewModel.password.isEmpty
            && viewModel.password == viewModel.confirmPassword
            && PasswordStrength.from(viewModel.password) != .weak
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.bottom, 6)
    }
}
