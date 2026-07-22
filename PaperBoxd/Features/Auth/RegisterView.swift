import AuthenticationServices
import SwiftUI

struct RegisterView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var showPassword = false
    @State private var showConfirm  = false
    @State private var acceptedTerms = false
    @State private var legalSheet: LegalDocKind?
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
                Image("GoogleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text("Continue with Google")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.white.opacity(0.05))
            .overlay(Rectangle().stroke(.white.opacity(0.85), lineWidth: 1.5))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(viewModel.isLoading || !acceptedTerms)
        .opacity(acceptedTerms ? 1 : 0.45)
    }


    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            glassCard
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
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
                .overlay(Rectangle().stroke(.white.opacity(0.30), lineWidth: 1))
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
                termsCheckbox
                createButton
                orDivider.padding(.vertical, 14)
                googleButton
                signInLink
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .clipShape(Rectangle())
        .background(BrutalCard())
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

    private var termsCheckbox: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                acceptedTerms.toggle()
            } label: {
                ZStack {
                    Rectangle()
                        .stroke(.white.opacity(0.85), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if acceptedTerms {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Text("I agree to the [Terms of Service](paperboxd://terms) and [Privacy Policy](paperboxd://privacy).")
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.6))
                .tint(Color("Accent"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 16)
    }

    private var createButton: some View {
        Button {
            Task { await viewModel.register() }
        } label: {
            ZStack {
                if viewModel.isLoading {
                    ProgressView().tint(.black)
                } else {
                    HStack(spacing: 8) {
                        Text("Create Account")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .font(.system(size: 14.5, weight: .semibold))
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(red: 0.96, green: 0.95, blue: 0.93))
            .overlay(Rectangle().stroke(.black.opacity(0.9), lineWidth: 2))
            .shadow(color: .white.opacity(0.22), radius: 0, x: 4, y: 4)
            .opacity(canSubmit ? 1 : 0.45)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canSubmit || viewModel.isLoading)
        .padding(.top, 18)
        .animation(.easeInOut(duration: 0.18), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.18), value: canSubmit)
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
            && acceptedTerms
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
