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
            Rectangle().fill(BK.ink.opacity(0.18)).frame(height: 1)
            Text("or")
                .font(.system(size: 11, design: .monospaced))
                .textCase(.uppercase)
                .kerning(2.2)
                .foregroundStyle(BK.muted.opacity(0.7))
            Rectangle().fill(BK.ink.opacity(0.18)).frame(height: 1)
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
            .padding(.vertical, 13)
            .background(BK.card)
            .overlay(Rectangle().stroke(BK.ink, lineWidth: 2))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(viewModel.isLoading || !acceptedTerms)
        .opacity(acceptedTerms ? 1 : 0.45)
    }


    var body: some View {
        VStack(spacing: 0) {
            topBar
            BookShelfHero(
                spines: ShelfSpine.register,
                height: 196,
                rowHeight: 158,
                leadingPad: 26,
                duration: 96,
                titleSize: 10,
                maxTitleRun: 92,
                spinePadding: 8
            )
            glassCard
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
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
                .foregroundStyle(BK.ink)
            Spacer()
            Text("register")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .textCase(.uppercase)
                .kerning(1.6)
                .foregroundStyle(BK.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(BK.ochre)
                .overlay(Rectangle().stroke(BK.ink, lineWidth: 2))
        }
        .padding(.horizontal, 26)
        .padding(.top, 20)
        .padding(.bottom, 12)
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
        .background(BrutalCard(echo: BK.forest))
    }

    // MARK: - Card sections

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start your\nreading life.")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.8)
                .lineSpacing(1)
                .foregroundStyle(BK.ink)
            Text("Track every book worth remembering.")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundStyle(BK.sepia)
                .lineSpacing(2)
        }
        .padding(.bottom, 24)
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldLabel("Email")
            PaperTextField(
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
                PaperSecureField(
                    title: "Min 8 characters",
                    text: $viewModel.password,
                    showText: showPassword
                )
                .focused($focused, equals: .password)
                .submitLabel(.next)
                .onSubmit { focused = .confirm }
                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(BK.muted)
                        .padding(.trailing, 14)
                }
            }

            if !viewModel.password.isEmpty {
                strengthBar.padding(.top, 8)
            }

            fieldLabel("Confirm password").padding(.top, 12)
            ZStack(alignment: .trailing) {
                PaperSecureField(
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
                        .foregroundStyle(BK.muted)
                        .padding(.trailing, 14)
                }
            }
        }
    }

    private var strengthBar: some View {
        let strength = PasswordStrength.from(viewModel.password)
        return HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { idx in
                Rectangle()
                    .fill(idx <= strength.rawValue ? strength.color : BK.ink.opacity(0.18))
                    .frame(height: 3)
            }
            Text(strength.label)
                .font(.caption2)
                .foregroundStyle(BK.muted)
        }
    }

    @ViewBuilder
    private var errorRow: some View {
        if let msg = viewModel.errorMessage {
            Text(msg)
                .font(.footnote)
                .foregroundStyle(BK.accent)
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
                        .fill(acceptedTerms ? BK.crimson : BK.card)
                        .frame(width: 20, height: 20)
                        .overlay(Rectangle().stroke(BK.ink, lineWidth: 2))
                    if acceptedTerms {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(BK.cream)
                    }
                }
            }
            .buttonStyle(.plain)

            Text("I agree to the [Terms of Service](paperboxd://terms) and [Privacy Policy](paperboxd://privacy).")
                .font(.system(size: 12.5))
                .foregroundStyle(BK.muted)
                .tint(BK.crimson)
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
                    ProgressView().tint(BK.cream)
                } else {
                    HStack(spacing: 8) {
                        Text("Create Account")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .font(.system(size: 14.5, weight: .semibold))
                }
            }
            .foregroundStyle(BK.cream)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .opacity(canSubmit ? 1 : 0.45)
        }
        .buttonStyle(BrutalButtonStyle(fill: BK.crimson, borderWidth: 2))
        .disabled(!canSubmit || viewModel.isLoading)
        .padding(.top, 18)
        .animation(.easeInOut(duration: 0.18), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.18), value: canSubmit)
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
            .underline(color: BK.muted.opacity(0.7))
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
            .foregroundStyle(BK.muted)
            .padding(.bottom, 6)
    }
}
