import SwiftUI

/// First screen a new install sees. Paper ground, brutal borders — same
/// language as onboarding, so "Get Started" doesn't jump the reader into a
/// different app halfway through signup.
struct WelcomeView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            illustration
                .padding(.bottom, 28)

            VStack(spacing: 6) {
                Text("Welcome to")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BK.muted)
                Text("PaperBoxd")
                    .font(.custom("SnellRoundhand-Black", size: 44))
                    .foregroundStyle(BK.ink)
            }

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                OnboardingPrimaryButton(title: "Get Started") {
                    viewModel.switchTo(.register)
                }
                Button {
                    viewModel.switchTo(.login)
                } label: {
                    Text("Already have an account? Sign in")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(BK.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 36)
        }
        .padding(.horizontal, 28)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { appear = true }
        }
    }

    private var illustration: some View {
        Image("WelcomeIllustration")
            .resizable()
            .scaledToFit()
            .frame(width: 200)
    }
}
