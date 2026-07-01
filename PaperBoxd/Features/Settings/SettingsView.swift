import SwiftUI

/// Settings screen, presented as a sheet from the profile header's gear icon.
/// Grouped list matching the app's dark aesthetic (Color("Background"), etc.).
///
/// Sign out routes through `onSignOut` (wired to `AppState.signOut()` by the
/// presenter). Account deletion calls `DELETE /api/v1/users/me`. "Free Scans
/// Remaining" reads the live quota persisted after each scan.
struct SettingsView: View {
    let profile: UserProfile
    var onSignOut: () -> Void

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pb_scans_remaining") private var scansRemaining: Int = 7
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var shareItem: ShareItem?

    var body: some View {
        NavigationStack {
            List {
                accountSection
                scanSection
                dataSection
                discoverSection
                aboutSection
                signOutSection
                dangerZoneSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color("Background").ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(PB.serif(18))
                        .foregroundStyle(Color("TextPrimary"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(PB.mono(13, .medium))
                        .foregroundStyle(Color("Accent"))
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
                    .presentationDetents([.medium, .large])
            }
            .alert("Couldn't delete account",
                   isPresented: Binding(get: { deleteError != nil },
                                        set: { if !$0 { deleteError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    // MARK: - Section 1: Account

    private var accountSection: some View {
        Section {
            NavigationLink {
                ChangePasswordView(email: appState.currentUser?.email)
            } label: {
                SettingsRow(icon: "lock", label: "Change Password")
            }
        } header: {
            Eyebrow(text: "Account")
        }
        .listRowBackground(Color("Surface"))
    }

    // MARK: - Section 2: Scan & Know

    private var scanSection: some View {
        Section {
            HStack {
                SettingsRow(icon: "barcode.viewfinder", label: "Free Scans Remaining")
                Spacer()
                Text(scansRemaining == 0 ? "None remaining" : "\(scansRemaining) remaining")
                    .foregroundColor(scansRemaining == 0 ? .red.opacity(0.8) : .secondary)
                    .font(.body)
            }
        } header: {
            Eyebrow(text: "Scan & Know")
        }
        .listRowBackground(Color("Surface"))
    }

    // MARK: - Section 3: Your Data

    private var dataSection: some View {
        Section {
            NavigationLink {
                GoodreadsImportView()
            } label: {
                SettingsRow(icon: "square.and.arrow.down", label: "Import from Goodreads")
            }
            NavigationLink {
                ComingSoonView(feature: "Export My Data")
            } label: {
                SettingsRow(icon: "square.and.arrow.up", label: "Export My Data")
            }
        } header: {
            Eyebrow(text: "Your Data")
        }
        .listRowBackground(Color("Surface"))
    }

    // MARK: - Section 4: Discover

    private var discoverSection: some View {
        Section {
            Button {
                if let url = URL(string: "https://paperboxd.in") {
                    shareItem = ShareItem(url: url)
                }
            } label: {
                SettingsRow(icon: "person.badge.plus", label: "Invite Friends")
            }
            Button {
                // TODO: replace with real App Store ID before submission
                // if let url = URL(string: "itms-apps://itunes.apple.com/app/idYOUR_ID?action=write-review") {
                //   UIApplication.shared.open(url)
                // }
            } label: {
                SettingsRow(icon: "star.fill", label: "Rate PaperBoxd")
                    .foregroundColor(.secondary)  // visually dimmed to signal not-yet-active
            }
            .disabled(true)
        } header: {
            Eyebrow(text: "Discover")
        }
        .listRowBackground(Color("Surface"))
    }

    // MARK: - Section 5: About

    private var aboutSection: some View {
        Section {
            NavigationLink {
                LegalView(content: .privacyPolicy)
            } label: {
                SettingsRow(icon: "hand.raised", label: "Privacy Policy")
            }
            NavigationLink {
                LegalView(content: .termsOfService)
            } label: {
                SettingsRow(icon: "doc.text", label: "Terms of Service")
            }
            HStack {
                SettingsRow(icon: "info.circle", label: "Version")
                Spacer()
                Text(Bundle.main.appVersionString)
                    .font(PB.mono(12))
                    .foregroundStyle(Color("TextSecondary"))
            }
        } header: {
            Eyebrow(text: "About")
        }
        .listRowBackground(Color("Surface"))
    }

    // MARK: - Section 6: Sign Out

    private var signOutSection: some View {
        Section {
            Button {
                onSignOut()
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                        .font(PB.mono(13, .medium))
                        .foregroundStyle(Color("Error"))
                    Spacer()
                }
            }
        }
        .listRowBackground(Color("Surface"))
    }

    // MARK: - Section 7: Danger Zone

    private var dangerZoneSection: some View {
        Section {
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Delete Account")
                        .font(PB.mono(11))
                        .tracking(0.5)
                        .foregroundStyle(Color("Error").opacity(0.7))
                    Spacer()
                }
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your PaperBoxd account and all your reading data. This cannot be undone.")
            }
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Delete account

    /// DELETE /api/v1/users/me — soft-deletes the account and revokes tokens
    /// server-side. On success we clear the local session via `onSignOut`.
    private func deleteAccount() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            struct DeleteResponse: Decodable { let message: String? }
            let _: DeleteResponse = try await APIClient.shared.request(
                path: Endpoints.deleteMe,
                method: .delete,
                requiresAuth: true
            )
            onSignOut()
        } catch let e as APIError {
            deleteError = e.errorDescription ?? "Something went wrong. Try again."
        } catch {
            deleteError = "Something went wrong. Try again."
        }
    }
}

// MARK: - Reusable row

struct SettingsRow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .frame(width: 24)
                .foregroundStyle(Color("TextPrimary").opacity(0.55))
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color("TextPrimary"))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Change password (no change endpoint → reset via email)

/// The backend exposes password *reset* (email link) but not an in-app change,
/// so this triggers the same forgot-password flow used on the auth screen.
struct ChangePasswordView: View {
    let email: String?

    @State private var isSending = false
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.rotation")
                .font(.largeTitle)
                .foregroundStyle(Color("Accent"))
            Text("Reset your password")
                .font(PB.serif(22))
                .foregroundStyle(Color("TextPrimary"))
            Text(email.map { "We'll email a reset link to \($0)." }
                 ?? "We'll email you a password reset link.")
                .font(.system(size: 14))
                .foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task { await sendReset() }
            } label: {
                HStack {
                    if isSending { ProgressView().tint(.white) }
                    Text(isSending ? "Sending…" : "Send reset link")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color("Accent"))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .disabled(isSending || email == nil)
            .padding(.horizontal, 32)

            if let message {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(isError ? .red : Color("TextSecondary"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .padding(.top, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background").ignoresSafeArea())
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendReset() async {
        guard let email else { return }
        isSending = true
        message = nil
        defer { isSending = false }
        do {
            struct FPResponse: Decodable {}
            let _: FPResponse = try await APIClient.shared.request(
                path: Endpoints.forgotPassword,
                method: .post,
                body: ["email": email]
            )
            isError = false
            message = "Reset link sent — check your inbox."
        } catch let e as APIError {
            isError = true
            message = e.errorDescription ?? "Couldn't send the reset link."
        } catch {
            isError = true
            message = "Couldn't send the reset link. Try again."
        }
    }
}

// MARK: - Legal

enum LegalContent {
    case privacyPolicy, termsOfService

    var title: String {
        switch self {
        case .privacyPolicy:  return "Privacy Policy"
        case .termsOfService: return "Terms of Service"
        }
    }

    var body: String {
        switch self {
        case .privacyPolicy:
            return """
            PaperBoxd stores the reading data you give us — the books you log, \
            reviews, shelves, and profile details — to run the app and show your \
            activity to people you choose to share it with.

            We don't sell your data. Book metadata and ratings shown in the app \
            come from third-party sources (Google Books, Open Library, Hardcover).

            You can request deletion of your account and data at any time by \
            emailing hello@paperboxd.in.

            For the full, current policy see paperboxd.in/privacy.
            """
        case .termsOfService:
            return """
            By using PaperBoxd you agree to use it for personal, non-commercial \
            book tracking and to respect other readers in the community.

            You own the content you post. You grant us a licence to display it \
            within the app so your friends and followers can see your activity.

            The Scan & Know score is a recommendation aid, not a guarantee — \
            it's generated from community data and your reading history.

            We may update these terms as the app evolves. Continued use means \
            you accept the current terms. Full terms at paperboxd.in/terms.
            """
        }
    }
}

struct LegalView: View {
    let content: LegalContent

    var body: some View {
        ScrollView {
            Text(content.body)
                .font(.system(size: 15))
                .foregroundStyle(Color("TextPrimary").opacity(0.85))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .background(Color("Background").ignoresSafeArea())
        .navigationTitle(content.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Coming soon placeholder

struct ComingSoonView: View {
    let feature: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundStyle(Color("TextSecondary"))
            Text("\(feature) is coming soon")
                .font(PB.serif(18))
                .foregroundStyle(Color("TextSecondary"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background").ignoresSafeArea())
        .navigationTitle(feature)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Version helper

extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
