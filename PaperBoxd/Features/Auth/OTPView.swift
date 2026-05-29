import SwiftUI

struct OTPView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var fieldFocused: Bool

    private let length = 6

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
        }
        .padding(.horizontal, 26)
        .padding(.top, 20)
    }

    // MARK: - Glass card

    private var glassCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            otpBoxes.padding(.top, 24)
            errorRow
            resendRow.padding(.top, 20)
            backLink.padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 26)
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
            Text("Enter your code.")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(.white)
            Group {
                Text("Sent to ")
                    .foregroundStyle(.white.opacity(0.55))
                + Text(viewModel.otpEmail)
                    .foregroundStyle(.white.opacity(0.88))
            }
            .font(.system(size: 14, design: .serif).italic())
            .lineSpacing(2)
        }
        .padding(.bottom, 4)
    }

    private var otpBoxes: some View {
        ZStack {
            // Hidden capture field
            TextField("", text: $viewModel.otpCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($fieldFocused)
                .opacity(0.001)
                .frame(height: 0)
                .onChange(of: viewModel.otpCode) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(length))
                    if digits != newValue { viewModel.otpCode = digits }
                    if digits.count == length { Task { await viewModel.verifyOTP() } }
                }

            HStack(spacing: 10) {
                ForEach(0..<length, id: \.self) { idx in
                    OTPBox(
                        digit: digit(at: idx),
                        isActive: viewModel.otpCode.count == idx && fieldFocused
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { fieldFocused = true }
        }
        .onAppear { fieldFocused = true }
    }

    @ViewBuilder
    private var errorRow: some View {
        if let msg = viewModel.errorMessage {
            Text(msg)
                .font(.footnote)
                .foregroundStyle(Color("Error"))
                .padding(.top, 12)
        }
    }

    @ViewBuilder
    private var resendRow: some View {
        HStack {
            if viewModel.otpCountdown > 0 {
                Text("Expires in \(formatCountdown(viewModel.otpCountdown))")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("Resend")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.25))
            } else {
                Text("Code expired")
                    .font(.footnote)
                    .foregroundStyle(Color("Error"))
                Spacer()
                Button("Resend code") {
                    Task { await viewModel.sendOTP() }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color("Accent"))
            }
        }
    }

    private var backLink: some View {
        Button {
            viewModel.switchTo(.login)
        } label: {
            Text("Use a different email")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .underline(color: .white.opacity(0.3))
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    private func digit(at idx: Int) -> String {
        let arr = Array(viewModel.otpCode)
        return idx < arr.count ? String(arr[idx]) : ""
    }

    private func formatCountdown(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct OTPBox: View {
    let digit: String
    let isActive: Bool

    var body: some View {
        Text(digit)
            .font(.system(size: 26, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: 46, height: 56)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isActive ? Color("Accent") : .white.opacity(0.14),
                        lineWidth: 1.5
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}
