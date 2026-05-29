import SwiftUI

/// Accent-on-dark primary CTA used across auth + onboarding.
struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    init(_ title: String, isLoading: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color("Background"))
                } else {
                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color("Background"))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color("Accent"))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isEnabled ? 1.0 : 0.4)
        }
        .disabled(!isEnabled || isLoading)
        .animation(.easeInOut(duration: 0.18), value: isLoading)
        .animation(.easeInOut(duration: 0.18), value: isEnabled)
    }
}

/// Secondary borderless button used for "Forgot password", toggle links etc.
struct LinkButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Color("TextSecondary"))
        }
    }
}
