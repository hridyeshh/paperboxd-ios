import SwiftUI

/// One-time-code sign-in on the paper ground.
struct OTPView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var fieldFocused: Bool
    @State private var appear = false
    @State private var errorTrigger = 0

    private let length = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaperBackHeader(title: "Sign in") { viewModel.switchTo(.login) }
                .padding(.bottom, 22)
            header
            otpBoxes.padding(.top, 28)
                .reveal(appear, delay: 0.15)
            errorRow
            resendRow.padding(.top, 20)
                .reveal(appear, delay: 0.2)
            backLink.padding(.top, 14)
                .reveal(appear, delay: 0.24)
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BK.paper)
        .shake(trigger: errorTrigger)
        .onAppear {
            fieldFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appear = true }
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            guard newValue != nil else { return }
            errorTrigger += 1
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter your code.")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(BK.ink)
                .reveal(appear, delay: 0)
            Group {
                Text("Sent to ").foregroundStyle(BK.muted)
                + Text(viewModel.otpEmail).foregroundStyle(BK.ink)
            }
            .font(.system(size: 13.5))
            .reveal(appear, delay: 0.05)
        }
    }

    private var otpBoxes: some View {
        ZStack {
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
                    PaperOTPBox(
                        digit: digit(at: idx),
                        isActive: viewModel.otpCode.count == idx && fieldFocused
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { fieldFocused = true }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var errorRow: some View {
        if let msg = viewModel.errorMessage {
            Text(msg)
                .font(.footnote)
                .foregroundStyle(BK.crimson)
                .padding(.top, 12)
        }
    }

    @ViewBuilder
    private var resendRow: some View {
        HStack {
            if viewModel.otpCountdown > 0 {
                Text("Expires in \(formatCountdown(viewModel.otpCountdown))")
                    .font(.footnote)
                    .foregroundStyle(BK.muted)
                Spacer()
                Text("Resend")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(BK.muted.opacity(0.6))
            } else {
                Text("Code expired")
                    .font(.footnote)
                    .foregroundStyle(BK.crimson)
                Spacer()
                Button("Resend code") {
                    Task { await viewModel.sendOTP() }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BK.ink)
            }
        }
    }

    private var backLink: some View {
        Button {
            viewModel.switchTo(.login)
        } label: {
            Text("Use a different email")
                .font(.system(size: 13))
                .foregroundStyle(BK.muted)
                .underline(color: BK.muted.opacity(0.5))
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
