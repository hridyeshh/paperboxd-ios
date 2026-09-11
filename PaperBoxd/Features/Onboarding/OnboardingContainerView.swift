import SwiftUI

/// Entry point for the post-registration onboarding flow. Replaces the old
/// single-screen ChooseUsernameView. Hosts the step machine, the stage header,
/// and the cross-step transitions.
struct OnboardingContainerView: View {
    let user: User
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: OnboardingViewModel
    @State private var contentIn = false

    init(user: User) {
        self.user = user
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(user: user))
    }

    private var isDark: Bool { viewModel.step == .ahaLoading }

    var body: some View {
        ZStack {
            (isDark ? Color(white: 0.06) : BK.paper)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: isDark)

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
            GenresStepView(viewModel: viewModel)
                .transition(stepTransition)
        case .books:
            BooksStepView(viewModel: viewModel)
                .transition(stepTransition)
        case .readers:
            ReadersStepView(viewModel: viewModel)
                .transition(stepTransition)
        case .ahaLoading:
            AhaLoadingView()
                .transition(.opacity)
        case .ahaReveal:
            AhaRevealView(viewModel: viewModel)
                .transition(stepTransition)
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

// MARK: - Stage header

struct OnboardingStageHeader: View {
    let step: OnboardingViewModel.Step

    private let stages = ["Sign up", "Set up", "Aha"]

    private var activeStage: Int {
        switch step {
        case .username, .genres, .books, .readers: return 1
        case .ahaLoading, .ahaReveal:    return 2
        }
    }

    private var subStep: Int? {
        switch step {
        case .username: return 1
        case .genres:   return 2
        case .books:    return 3
        case .readers:  return 4
        default:        return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Array(stages.enumerated()), id: \.offset) { idx, label in
                    pill(label: label, index: idx)
                    if idx < stages.count - 1 {
                        Rectangle()
                            .fill(idx < activeStage ? BK.ink : BK.ink.opacity(0.2))
                            .frame(width: 12, height: 2)
                    }
                }
                Spacer(minLength: 0)
            }
            if let subStep {
                Text("Step \(subStep) of 4")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .textCase(.uppercase)
                    .kerning(1.4)
                    .foregroundStyle(BK.muted)
            }
        }
    }

    @ViewBuilder
    private func pill(label: String, index: Int) -> some View {
        let isDone = index < activeStage
        let isCurrent = index == activeStage
        HStack(spacing: 4) {
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
            }
            Text(label)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(isCurrent ? BK.cream : isDone ? BK.ink : Color(hex: "A6A092"))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(isCurrent ? BK.ink : isDone ? BK.ochre : BK.card)
        .overlay(
            Rectangle().stroke(isDone || isCurrent ? BK.ink : BK.ink.opacity(0.25), lineWidth: 2)
        )
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
        .buttonStyle(BrutalButtonStyle(fill: BK.crimson, borderWidth: 2))
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
