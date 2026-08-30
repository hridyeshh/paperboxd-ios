import Combine
import Foundation
import SwiftUI

/// Sub-screen the AuthContainerView routes between.
enum AuthMode: Equatable {
    case login
    case loginOTP            // came from "Login with OTP instead"
    case register
}

@MainActor
final class AuthViewModel: ObservableObject {
    // Form fields
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var otpCode: String = ""

    // Sub-screen
    @Published var mode: AuthMode = .login

    // Async UX
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // OTP
    @Published var otpCountdown: Int = 0
    @Published var otpEmail: String = ""

    /// Called by sub-flows on a successful auth. Container wires this to
    /// AppState.signedIn so the VM never imports AppState directly.
    var onAuthSuccess: (String, User, String?) -> Void = { _, _, _ in }

    private var countdownTask: Task<Void, Never>?

    deinit {
        countdownTask?.cancel()
    }

    // MARK: - Mode transitions

    func switchTo(_ next: AuthMode) {
        errorMessage = nil
        successMessage = nil
        if next == .register || next == .login {
            password = ""
            confirmPassword = ""
            otpCode = ""
        }
        mode = next
    }

    // MARK: - Email + password login

    func login() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."
            return
        }
        await withLoading {
            let body = ["email": trimmed, "password": self.password]
            let resp: AuthResponse = try await APIClient.shared.request(
                path: Endpoints.mobileLogin,
                method: .post,
                body: body
            )
            self.onAuthSuccess(resp.token, resp.user, resp.refreshToken)
        }
    }

    // MARK: - Register

    func register() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        guard PasswordStrength.from(password) != .weak else {
            errorMessage = "Password must be at least 8 characters with upper, lower, and a digit."
            return
        }
        await withLoading {
            let body = ["email": trimmed, "password": self.password]
            let resp: RegisterResponse = try await APIClient.shared.request(
                path: Endpoints.mobileRegister,
                method: .post,
                body: body
            )
            // onboarding_completed is false for all new registrations — AppState
            // routes to .onboarding based on that flag.
            self.onAuthSuccess(resp.token, resp.user, resp.refreshToken)
        }
    }

    // MARK: - OTP

    func sendOTP() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            errorMessage = "Enter your email to receive a code."
            return
        }
        await withLoading {
            let body = ["email": trimmed]
            let resp: OTPSendResponse = try await APIClient.shared.request(
                path: Endpoints.mobileOTPSend,
                method: .post,
                body: body
            )
            self.otpEmail = trimmed
            self.otpCode = ""
            self.startCountdown(seconds: resp.expiresInSeconds)
            self.switchTo(.loginOTP)
        }
    }

    func verifyOTP() async {
        let trimmed = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 6 else {
            errorMessage = "Enter the 6-digit code."
            return
        }
        await withLoading {
            let body = ["email": self.otpEmail, "code": trimmed]
            let resp: AuthResponse = try await APIClient.shared.request(
                path: Endpoints.mobileOTPVerify,
                method: .post,
                body: body
            )
            self.stopCountdown()
            self.onAuthSuccess(resp.token, resp.user, resp.refreshToken)
        }
    }

    // MARK: - Forgot password

    func forgotPassword() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            errorMessage = "Enter your email first."
            return
        }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }
        do {
            struct FPResponse: Decodable {}
            let _: FPResponse = try await APIClient.shared.request(
                path: Endpoints.forgotPassword,
                method: .post,
                body: ["email": trimmed]
            )
            successMessage = "Reset link sent — check your inbox."
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Google

    func loginWithGoogle() async {
        guard !Config.googleClientID.hasPrefix("YOUR_") else {
            errorMessage = "Google sign-in not configured — add Client ID to Config.swift."
            return
        }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }
        do {
            let idToken = try await GoogleOAuth.signIn()
            let resp: GoogleAuthResponse = try await APIClient.shared.request(
                path: Endpoints.mobileGoogle,
                method: .post,
                body: ["id_token": idToken]
            )
            onAuthSuccess(resp.token, resp.user, resp.refreshToken)
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Apple

    func loginWithApple(identityToken: String, name: String?) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }
        do {
            var body: [String: String] = ["identity_token": identityToken]
            if let name, !name.isEmpty { body["name"] = name }
            let resp: GoogleAuthResponse = try await APIClient.shared.request(
                path: Endpoints.mobileApple,
                method: .post,
                body: body
            )
            onAuthSuccess(resp.token, resp.user, resp.refreshToken)
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Countdown

    private func startCountdown(seconds: Int) {
        stopCountdown()
        otpCountdown = max(seconds, 0)
        countdownTask = Task { [weak self] in
            while !(Task.isCancelled) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                await MainActor.run {
                    guard let self else { return }
                    if self.otpCountdown > 0 {
                        self.otpCountdown -= 1
                    }
                }
                let stop = await MainActor.run { self?.otpCountdown ?? 0 == 0 }
                if stop { return }
            }
        }
    }

    private func stopCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    // MARK: - Helper

    private func withLoading(_ work: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await work()
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Password strength

enum PasswordStrength: Int {
    case weak = 0
    case fair = 1
    case strong = 2

    var label: String {
        switch self {
        case .weak: return "Weak"
        case .fair: return "Fair"
        case .strong: return "Strong"
        }
    }

    var color: Color {
        switch self {
        case .weak: return Color("Error")
        case .fair: return Color("Accent")
        case .strong: return Color("Accent")
        }
    }

    static func from(_ password: String) -> PasswordStrength {
        let hasUpper = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLower = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
        let long = password.count >= 12

        if password.count < 8 || !(hasUpper && hasLower && hasDigit) {
            return .weak
        }
        if long && password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil {
            return .strong
        }
        return .fair
    }
}
