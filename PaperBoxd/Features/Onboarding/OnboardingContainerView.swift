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
            (isDark ? Color(white: 0.06) : Color.white)
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
        case .tempo:
            TempoStepView(viewModel: viewModel)
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
        case .username, .genres, .tempo: return 1
        case .ahaLoading, .ahaReveal:    return 2
        }
    }

    private var subStep: Int? {
        switch step {
        case .username: return 1
        case .genres:   return 2
        case .tempo:    return 3
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
                            .fill(Color(white: 0.85))
                            .frame(width: 14, height: 1)
                    }
                }
                Spacer(minLength: 0)
            }
            if let subStep {
                Text("Step \(subStep) of 3")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .textCase(.uppercase)
                    .kerning(1.4)
                    .foregroundStyle(Color(white: 0.6))
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
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(isCurrent ? .white : Color(white: isDone ? 0.45 : 0.65))
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(
                isCurrent ? Color(white: 0.07)
                    : isDone ? Color(white: 0.92)
                    : Color(white: 0.96)
            )
        )
    }
}

// MARK: - Shared light-theme components

/// Dark pill CTA on the light onboarding background.
struct OnboardingPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Text(title)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .font(.system(size: 14.5, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(white: 0.07), in: Capsule())
            .opacity(isEnabled ? 1 : 0.38)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!isEnabled || isLoading)
        .animation(.easeInOut(duration: 0.18), value: isEnabled)
        .animation(.easeInOut(duration: 0.18), value: isLoading)
    }
}

/// Selectable chip used for genres.
struct OnboardingChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 13.5, weight: .medium))
            }
            .foregroundStyle(isOn ? .white : Color(white: 0.25))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(isOn ? Color(white: 0.07) : Color(white: 0.96))
            )
            .overlay(
                Capsule().stroke(Color(white: isOn ? 0.07 : 0.88), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

func onboardingFieldLabel(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .textCase(.uppercase)
        .kerning(1.2)
        .foregroundStyle(Color(white: 0.6))
}
