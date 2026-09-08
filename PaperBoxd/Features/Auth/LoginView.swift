import AuthenticationServices
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
            BookShelfHero()
            glassCard
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .offset(y: cardIn ? 0 : 420)
                .opacity(cardIn ? 1 : 0)
                .animation(.spring(response: 0.62, dampingFraction: 0.84), value: cardIn)
                // Sized before the shelf, so the headline keeps both its lines
                // and the shelf takes whatever band is left.
                .layoutPriority(1)
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
                .foregroundStyle(BK.ink)
            Spacer()
            Text("sign in")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .textCase(.uppercase)
                .kerning(1.6)
                .foregroundStyle(BK.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(BK.ochre)
                .overlay(Rectangle().stroke(BK.ink, lineWidth: 2))
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 14)
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
        .background(BrutalCard())
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
                .foregroundStyle(BK.ink)
            Text("Your shelves are right where you left them.")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundStyle(BK.sepia)
                .lineSpacing(2)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Fields

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
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(BK.crimson)
                }
                .padding(.bottom, 6)
            }
            .padding(.top, 12)
            ZStack(alignment: .trailing) {
                PaperSecureField(
                    title: "••••••••",
                    text: $viewModel.password,
                    showText: showPassword
                )
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .onSubmit { Task { await viewModel.login() } }
                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(BK.muted)
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
                .foregroundStyle(BK.accent)
                .padding(.top, 10)
        } else if let msg = viewModel.successMessage {
            Text(msg)
                .font(.footnote)
                .foregroundStyle(Color(red: 0.13, green: 0.55, blue: 0.30))
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
                    ProgressView().tint(BK.cream)
                } else {
                    HStack(spacing: 8) {
                        Text("Sign in")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundStyle(BK.cream)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(BrutalButtonStyle(fill: BK.crimson, borderWidth: 2))
        .disabled(!enabled || viewModel.isLoading)
        .padding(.top, 18)
        .animation(.easeInOut(duration: 0.18), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.18), value: enabled)
    }

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
                googleLogo
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
        .disabled(viewModel.isLoading)
    }

    private var googleLogo: some View {
        Image("GoogleLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
    }

    private var registerLink: some View {
        HStack(spacing: 5) {
            Text("New here?")
                .foregroundStyle(BK.muted)
            Button("Create an account") {
                viewModel.switchTo(.register)
            }
            .foregroundStyle(BK.crimson)
            .fontWeight(.bold)
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(BK.muted)
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

/// The official four-colour Google "G", drawn as a stroked ring split into
/// red / yellow / green / blue arcs plus the blue horizontal bar. Full-colour
/// on any background (Google permits the colour mark on dark surfaces), so no
/// white chip is needed. Trim fractions start at 3 o'clock and run clockwise.
struct GoogleGLogo: View {
    var size: CGFloat = 18

    private let blue   = Color(red: 0.259, green: 0.522, blue: 0.957)
    private let red    = Color(red: 0.918, green: 0.263, blue: 0.208)
    private let yellow = Color(red: 0.984, green: 0.737, blue: 0.020)
    private let green  = Color(red: 0.204, green: 0.659, blue: 0.325)

    var body: some View {
        let lw = size * 0.26
        ZStack {
            // Ring: blue wraps the 3 o'clock seam (where the bar exits),
            // green bottom, yellow left, red over the top.
            segment(0.833, 1.0, blue, lw)
            segment(0.0, 0.166, blue, lw)
            segment(0.166, 0.333, green, lw)
            segment(0.333, 0.583, yellow, lw)
            segment(0.583, 0.833, red, lw)

            // Blue crossbar: from centre out to the right edge, on the midline.
            Rectangle()
                .fill(blue)
                .frame(width: size * 0.40, height: lw)
                .offset(x: size * 0.15)
        }
        .frame(width: size, height: size)
    }

    private func segment(_ from: CGFloat, _ to: CGFloat, _ color: Color, _ lw: CGFloat) -> some View {
        Circle()
            .trim(from: from, to: to)
            .stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .butt))
            .padding(lw / 2)
    }
}
