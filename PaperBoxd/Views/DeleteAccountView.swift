import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) var dismiss
    @State private var step: DeleteStep = .reason
    @State private var selectedReasons: Set<String> = []
    @State private var otherReason: String = ""
    @State private var isDeleting: Bool = false
    
    private let deleteReasons = [
        "I'm not using this account anymore",
        "I have privacy concerns",
        "I found a better alternative",
        "The service doesn't meet my needs",
        "I'm receiving too many notifications",
        "I want to start fresh with a new account",
        "Other"
    ]
    
    enum DeleteStep {
        case reason
        case confirm
        case goodbye
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                if step != .goodbye {
                    HStack {
                        Button(action: {
                            if step == .reason {
                                dismiss()
                            } else {
                                step = .reason
                            }
                        }) {
                            Image(systemName: step == .reason ? "xmark" : "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Text(step == .reason ? "Delete Account" : "Confirm Deletion")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Invisible button to center the title
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.clear)
                        }
                        .disabled(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .systemBackground))
                    
                    Divider()
                }
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        if step == .reason {
                            reasonStepView
                        } else if step == .confirm {
                            confirmStepView
                        } else {
                            goodbyeStepView
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var reasonStepView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("We're sorry to see you go. Please let us know why you're deleting your account.")
                .font(.system(size: 16))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(deleteReasons, id: \.self) { reason in
                    ReasonCheckbox(
                        reason: reason,
                        isSelected: selectedReasons.contains(reason),
                        onToggle: { isSelected in
                            if isSelected {
                                selectedReasons.insert(reason)
                            } else {
                                selectedReasons.remove(reason)
                                if reason == "Other" {
                                    otherReason = ""
                                }
                            }
                        }
                    )
                    
                    if reason == "Other" && selectedReasons.contains("Other") {
                        TextField("Please specify", text: $otherReason)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.leading, 40)
                            .padding(.top, 8)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                if isFormValid {
                    step = .confirm
                }
            }) {
                Text("Continue")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isFormValid ? Color.red : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(!isFormValid)
        }
    }
    
    private var confirmStepView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Are you sure?")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            Text("This action cannot be undone. All your data will be permanently deleted.")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Button(action: {
                    deleteAccount()
                }) {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red)
                            .cornerRadius(10)
                    } else {
                        Text("Delete my account")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
                .disabled(isDeleting)
                
                Button(action: {
                    step = .reason
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(10)
                }
                .disabled(isDeleting)
            }
        }
    }
    
    private var goodbyeStepView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("Account Deleted")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Your account has been successfully deleted. We're sorry to see you go.")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button(action: {
                handleGoodbyeOk()
            }) {
                Text("OK")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private var isFormValid: Bool {
        if selectedReasons.isEmpty {
            return false
        }
        if selectedReasons.contains("Other") && otherReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return true
    }
    
    private func deleteAccount() {
        isDeleting = true
        
        Task {
            do {
                let reasons = selectedReasons.map { reason in
                    reason == "Other" ? "Other: \(otherReason.trimmingCharacters(in: .whitespacesAndNewlines))" : reason
                }
                
                try await APIClient.shared.deleteAccount(reasons: reasons)
                
                await MainActor.run {
                    step = .goodbye
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    // Show error alert
                    print("❌ DeleteAccountView: Failed to delete account: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleGoodbyeOk() {
        // Clear token
        APIClient.shared.logout()
        
        // Clear profile data
        ProfileViewModel.shared.clearProfile()
        
        // Sign out from Google
        GoogleSignInService.shared.signOut()
        
        // Update app state
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        
        // Dismiss - this will trigger the app to show LandingView
        dismiss()
    }
}

struct ReasonCheckbox: View {
    let reason: String
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: {
            onToggle(!isSelected)
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                Text(reason)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

