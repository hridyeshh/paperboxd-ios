import SwiftUI

/// Three-step delete-account bottom sheet, mirroring the web dialog
/// (delete-account-dialog.tsx): pick exit reasons → confirm → goodbye.
/// Reasons are sent as `{reasons: string[]}` to DELETE /api/v1/users/me and
/// persisted server-side in the account_deletions audit table.
struct DeleteAccountSheet: View {
    /// Called after the goodbye step is acknowledged; wired to sign-out.
    var onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss

    private enum Step { case reason, confirm, goodbye }
    @State private var step: Step = .reason
    @State private var selectedReasons: Set<String> = []
    @State private var otherReason = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    // Same options as the web dialog, order included.
    private static let reasons = [
        "I'm not using this account anymore",
        "I have privacy concerns",
        "I found a better alternative",
        "The service doesn't meet my needs",
        "I'm receiving too many notifications",
        "I want to start fresh with a new account",
        "Other",
    ]

    private var isFormValid: Bool {
        if selectedReasons.isEmpty { return false }
        if selectedReasons.contains("Other")
            && otherReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch step {
            case .reason:  reasonStep
            case .confirm: confirmStep
            case .goodbye: goodbyeStep
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color("Background").ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: step)
        .interactiveDismissDisabled(step == .goodbye || isDeleting)
        .alert("Couldn't delete account",
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Step 1: Reasons

    private var reasonStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            sheetHeader(title: "Delete Account",
                        subtitle: "We're sorry to see you go. Please let us know why you're deleting your account.")

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Self.reasons, id: \.self) { reason in
                        reasonRow(reason)
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.top, 18)

            HStack(spacing: 12) {
                secondaryButton("Cancel") { dismiss() }
                destructiveButton("Continue", disabled: !isFormValid) {
                    step = .confirm
                }
            }
            .padding(.top, 18)
        }
    }

    private func reasonRow(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if selectedReasons.contains(reason) {
                    selectedReasons.remove(reason)
                    if reason == "Other" { otherReason = "" }
                } else {
                    selectedReasons.insert(reason)
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: selectedReasons.contains(reason) ? "checkmark.square.fill" : "square")
                        .font(.system(size: 19))
                        .foregroundStyle(selectedReasons.contains(reason) ? Color("Accent") : Color("TextSecondary"))
                    Text(reason)
                        .font(.system(size: 15))
                        .foregroundStyle(Color("TextPrimary"))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            if reason == "Other", selectedReasons.contains("Other") {
                TextField("Please specify…", text: $otherReason)
                    .font(.system(size: 15))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color("Surface"))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.leading, 31)
            }
        }
    }

    // MARK: - Step 2: Confirm

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color("Error").opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color("Error"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Are you sure?")
                        .font(PB.serif(22))
                        .foregroundStyle(Color("TextPrimary"))
                    Text("This action cannot be undone")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("TextSecondary"))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Deleting your account will permanently remove:")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("TextPrimary"))
                VStack(alignment: .leading, spacing: 5) {
                    bulletLine("Your profile and all personal information")
                    bulletLine("All your books, lists, and reading data")
                    bulletLine("Your followers and following relationships")
                    bulletLine("All your activities and reviews")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("Error").opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color("Error").opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.top, 18)

            HStack(spacing: 12) {
                secondaryButton("Go back", disabled: isDeleting) { step = .reason }
                destructiveButton(isDeleting ? "Deleting…" : "Delete my account",
                                  disabled: isDeleting,
                                  showsProgress: isDeleting) {
                    Task { await deleteAccount() }
                }
            }
            .padding(.top, 22)
        }
    }

    private func bulletLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundStyle(Color("TextSecondary"))
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    // MARK: - Step 3: Goodbye

    private var goodbyeStep: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Color("Surface")).frame(width: 64, height: 64)
                Image(systemName: "trash")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Color("TextSecondary"))
            }
            .padding(.top, 8)

            Text("We're sorry to see you go")
                .font(PB.serif(22))
                .foregroundStyle(Color("TextPrimary"))
                .padding(.top, 16)

            Text("Your account has been successfully deleted. Thank you for being part of our community.")
                .font(.system(size: 14))
                .foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Button {
                onDeleted()
            } label: {
                Text("Okay")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color("Accent"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Shared chrome

    private func sheetHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(PB.serif(24))
                    .foregroundStyle(Color("TextPrimary"))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color("TextSecondary"))
                        .frame(width: 30, height: 30)
                        .background(Color("Surface"))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    private func secondaryButton(_ title: String, disabled: Bool = false,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color("Surface"))
                .foregroundStyle(Color("TextPrimary"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    private func destructiveButton(_ title: String, disabled: Bool = false,
                                   showsProgress: Bool = false,
                                   action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if showsProgress { ProgressView().tint(.white).scaleEffect(0.8) }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color("Error"))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled && !showsProgress ? 0.5 : 1)
    }

    // MARK: - Delete

    /// DELETE /api/v1/users/me with `{reasons}` — soft-deletes the account and
    /// revokes tokens server-side. Sign-out happens when the user acks goodbye.
    private func deleteAccount() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        let reasons = Self.reasons.filter { selectedReasons.contains($0) }.map { reason in
            reason == "Other"
                ? "Other: \(otherReason.trimmingCharacters(in: .whitespacesAndNewlines))"
                : reason
        }

        do {
            struct DeleteResponse: Decodable { let message: String? }
            let _: DeleteResponse = try await APIClient.shared.request(
                path: Endpoints.deleteMe,
                method: .delete,
                body: ["reasons": reasons],
                requiresAuth: true
            )
            step = .goodbye
        } catch let e as APIError {
            errorMessage = e.errorDescription ?? "Something went wrong. Try again."
        } catch {
            errorMessage = "Something went wrong. Try again."
        }
    }
}
