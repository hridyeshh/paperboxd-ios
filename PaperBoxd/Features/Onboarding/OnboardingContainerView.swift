import Combine
import SwiftUI

/// Entry point for the post-registration onboarding flow. Replaces the old
/// single-screen ChooseUsernameView. Hosts the step machine, the stage header,
/// and the cross-step transitions.
struct OnboardingContainerView: View {
    let user: User
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: OnboardingViewModel
    @State private var contentIn = false

    init(user: User) {
        self.user = user
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(user: user))
    }

    var body: some View {
        ZStack {
            BK.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.step != .ahaLoading {
                    OnboardingStageHeader(step: viewModel.step)
                    .padding(.horizontal, 26)
                    .padding(.top, 18)
                    .transition(.opacity)
                }

                stepContent
            }
            .opacity(contentIn ? 1 : 0)
            .offset(y: contentIn ? 0 : 28)
        }
        // `$step` publishes before the new value lands, so the screen still
        // shows the old page here: freeze it and burn it away over the new one.
        .onReceive(viewModel.$step.dropFirst()) { _ in PageDissolve.cover() }
        .onAppear {
            viewModel.onUsernameSet = { [weak appState] uname in
                appState?.setOnboardingUsername(uname)
            }
            viewModel.onFinished = { [weak appState] in
                appState?.finishOnboarding()
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.08)) {
                contentIn = true
            }
            Analytics.track("onboarding_started", metadata: ["entry_step": "username"])
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .username:
            UsernameStepView(viewModel: viewModel)
                .transition(stepTransition)
        case .genres:
            SwipeGenresStepView(viewModel: viewModel)
                .transition(stepTransition)
        case .ahaLoading:
            AhaLoadingView(genres: Genre.all.filter { viewModel.selectedGenres.contains($0.id) }.map(\.label))
                .transition(stepTransition)
        case .ahaReveal:
            AhaRevealView(viewModel: viewModel)
                .transition(stepTransition)
        }
    }

    /// The swap underneath the dissolve is instant so the burnt hole only ever
    /// shows the new page. Reduce Motion skips the dissolve, so fade instead.
    private var stepTransition: AnyTransition { reduceMotion ? .opacity : .identity }
}

// MARK: - Stage header

struct OnboardingStageHeader: View {
    let step: OnboardingViewModel.Step

    /// Signup is step 1 of the shared 3-step run; onboarding picks up at 2.
    private var subStep: Int? {
        switch step {
        case .username: return 2
        case .genres:   return 3
        default:        return nil
        }
    }

    var body: some View {
        if let subStep {
            PBStepHeader(step: subStep)
        }
    }
}

// MARK: - Shared light-theme components

/// Crimson CTA plate on the paper onboarding ground.
struct OnboardingPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(BK.cream)
                } else {
                    HStack(spacing: 8) {
                        Text(title)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .font(.system(size: 14.5, weight: .semibold))
                }
            }
            .foregroundStyle(BK.cream)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(BrutalButtonStyle(fill: BK.ink, borderWidth: 2))
        .disabled(!isEnabled || isLoading)
        .animation(.easeInOut(duration: 0.18), value: isEnabled)
        .animation(.easeInOut(duration: 0.18), value: isLoading)
    }
}

func onboardingFieldLabel(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .textCase(.uppercase)
        .kerning(1.2)
        .foregroundStyle(BK.muted)
}
