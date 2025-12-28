import SwiftUI

struct EmailChangeView: View {
    @Environment(\.dismiss) var dismiss
    let currentEmail: String
    let onEmailChanged: (String) -> Void
    let onCancel: () -> Void
    
    @State private var newEmail: String = ""
    @State private var isSendingOTP = false
    @State private var showOTPVerification = false
    @State private var otpCode: String = ""
    @State private var isVerifyingOTP = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    var body: some View {
        NavigationView {
            Form {
                if !showOTPVerification {
                    // Step 1: Enter new email
                    Section {
                        Text("Current Email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(currentEmail)
                            .foregroundColor(.primary)
                    }
                    
                    Section {
                        TextField("New Email", text: $newEmail)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                    } header: {
                        Text("Enter New Email Address")
                    } footer: {
                        Text("We'll send a verification code to your new email address.")
                    }
                    
                    if let errorMessage = errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    Section {
                        Button(action: {
                            Task {
                                await sendOTP()
                            }
                        }) {
                            HStack {
                                if isSendingOTP {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text(isSendingOTP ? "Sending..." : "Send Verification Code")
                            }
                        }
                        .disabled(isSendingOTP || newEmail.isEmpty || newEmail.lowercased() == currentEmail.lowercased())
                    }
                } else {
                    // Step 2: Verify OTP
                    Section {
                        Text("Verification Code")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter 6-digit code", text: $otpCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .onChange(of: otpCode) { _, newValue in
                                // Limit to 6 digits
                                if newValue.count > 6 {
                                    otpCode = String(newValue.prefix(6))
                                }
                            }
                    } header: {
                        Text("Enter Verification Code")
                    } footer: {
                        Text("We sent a 6-digit code to \(newEmail). Enter it below to verify your new email address.")
                    }
                    
                    if let errorMessage = errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    if let successMessage = successMessage {
                        Section {
                            Text(successMessage)
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    
                    Section {
                        Button(action: {
                            Task {
                                await verifyOTP()
                            }
                        }) {
                            HStack {
                                if isVerifyingOTP {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text(isVerifyingOTP ? "Verifying..." : "Verify & Update Email")
                            }
                        }
                        .disabled(isVerifyingOTP || otpCode.count != 6)
                        
                        Button(action: {
                            // Resend OTP
                            showOTPVerification = false
                            otpCode = ""
                            errorMessage = nil
                        }) {
                            Text("Resend Code")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Change Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
    
    private func sendOTP() async {
        await MainActor.run {
            isSendingOTP = true
            errorMessage = nil
        }
        
        do {
            let response = try await APIClient.shared.sendEmailChangeOTP(newEmail: newEmail)
            await MainActor.run {
                isSendingOTP = false
                showOTPVerification = true
                successMessage = response.message
            }
        } catch {
            await MainActor.run {
                isSendingOTP = false
                // Check if it's an NSError with a localized description
                if let nsError = error as NSError? {
                    let errorDesc = nsError.localizedDescription
                    // If the error message is not the generic one, use it
                    if !errorDesc.contains("HTTP error") && !errorDesc.isEmpty {
                        errorMessage = errorDesc
                    } else {
                        // Fall back to status code based messages
                        if nsError.code == 409 {
                            errorMessage = "This email is already registered"
                        } else if nsError.code == 429 {
                            errorMessage = "Too many requests. Please try again later."
                        } else if nsError.code == 400 {
                            errorMessage = "Invalid email address"
                        } else {
                            errorMessage = "Failed to send verification code. Please try again."
                        }
                    }
                } else if let apiError = error as? APIError {
                    switch apiError {
                    case .httpError(let statusCode):
                        if statusCode == 409 {
                            errorMessage = "This email is already registered"
                        } else if statusCode == 429 {
                            errorMessage = "Too many requests. Please try again later."
                        } else {
                            errorMessage = "Failed to send verification code. Please try again."
                        }
                    default:
                        errorMessage = "Failed to send verification code. Please try again."
                    }
                } else {
                    errorMessage = "Failed to send verification code. Please try again."
                }
            }
        }
    }
    
    private func verifyOTP() async {
        await MainActor.run {
            isVerifyingOTP = true
            errorMessage = nil
        }
        
        do {
            let response = try await APIClient.shared.verifyEmailChangeOTP(code: otpCode)
            await MainActor.run {
                isVerifyingOTP = false
                successMessage = response.message
                // Wait a moment to show success message, then dismiss
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    await MainActor.run {
                        onEmailChanged(response.email)
                        dismiss()
                    }
                }
            }
        } catch {
            await MainActor.run {
                isVerifyingOTP = false
                if let apiError = error as? APIError {
                    switch apiError {
                    case .httpError(let statusCode):
                        if statusCode == 400 {
                            errorMessage = "Invalid or expired code. Please request a new code."
                        } else {
                            errorMessage = "Failed to verify code. Please try again."
                        }
                    default:
                        errorMessage = "Failed to verify code. Please try again."
                    }
                } else {
                    errorMessage = "Failed to verify code. Please try again."
                }
            }
        }
    }
}

