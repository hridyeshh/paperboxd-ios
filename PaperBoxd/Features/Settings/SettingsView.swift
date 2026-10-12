import SwiftUI

/// Settings screen, presented as a sheet from the profile header's hamburger.
///
/// Brutalist paper aesthetic (see `BrutalKit`): every section is a hard 2pt ink
/// frame with an offset shadow on `BK.paper`, matching `ReadingHeatmapView` and
/// the profile's brutal pill buttons. The palette is monochrome — paper, ink,
/// muted, and `BK.paper2` for chips — so rank reads from fill and pattern, not
/// hue: destructive controls are hazard-hatched rather than red.
///
/// Sign out routes through `onSignOut` (wired to `AppState.signOut()` by the
/// presenter). Account deletion calls `DELETE /api/v1/users/me`. "Free Scans
/// Remaining" reads the live quota persisted after each scan.
struct SettingsView: View {
    let profile: UserProfile
    var onSignOut: () -> Void
    /// Opens the Fusion link window; nil hides the row.
    var onCreateFusion: (() -> Void)? = nil

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pb_scans_remaining") private var scansRemaining: Int = 3
    @AppStorage("pb_scans_unlimited") private var scansUnlimited = false
    @State private var showDeleteSheet = false
    @State private var showRateAlert = false
    @State private var shareItem: ShareItem?
    @State private var isPublic = true
    @State private var followRequests: [FollowRequestUser] = []

    var body: some View {
        NavigationStack {
            ZStack {
                BK.paper.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    ScrollView {
                        VStack(spacing: 24) {
                            if onCreateFusion != nil { fusionSection }
                            privacySection
                            accountSection
                            scanSection
                            dataSection
                            discoverSection
                            aboutSection
                            signOutButton
                            dangerZone
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 44)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showDeleteSheet) {
                DeleteAccountSheet(onDeleted: onSignOut)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .alert("Rate PaperBoxd", isPresented: $showRateAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("We'll enable ratings once we're live on the App Store. Thank you for your support!")
            }
        }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
    }

    // MARK: - Header (grabber + serif title + Done chip)

    private var header: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(BK.ink)
                .frame(width: 44, height: 4)
                .padding(.top, 9)
                .padding(.bottom, 7)

            HStack {
                Color.clear.frame(width: 62, height: 1)
                Spacer()
                Text("Settings")
                    .font(PB.serif(19))
                    .foregroundStyle(BK.ink)
                Spacer()
                Button { dismiss() } label: {
                    Text("DONE")
                        .font(PB.mono(12, .medium))
                        .tracking(0.5)
                        .foregroundStyle(BK.paper)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                }
                .buttonStyle(BrutalButtonStyle(fill: BK.ink, borderWidth: 2, offset: 3))
                .frame(width: 62, alignment: .trailing)
            }
            .frame(height: 50)
            .padding(.horizontal, 20)
        }
        .background(alignment: .bottom) { Rectangle().fill(BK.ink).frame(height: 2) }
    }

    // MARK: - Fusion

    private var fusionSection: some View {
        SettingsSection(title: "Fusion") {
            Button { onCreateFusion?() } label: {
                SettingsRow(icon: "circle.lefthalf.filled", label: "Create a Fusion")
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Private profile

    private var privacySection: some View {
        SettingsSection(title: "Privacy") {
            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 22)
                    .foregroundStyle(BK.ink)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Private account")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BK.ink)
                    Text(isPublic
                         ? "Anyone can see your shelves, thoughts and lists."
                         : "Only followers you approve can see your shelves.")
                        .font(.system(size: 12))
                        .foregroundStyle(BK.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                BrutalSwitch(isOn: !isPublic) { setPublic(!$0) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Only meaningful while private; going public auto-accepts everyone
            // who was waiting, so the list empties itself.
            if !isPublic && !followRequests.isEmpty {
                Rectangle().fill(BK.ink).frame(height: 2)

                Text(followRequests.count == 1 ? "1 FOLLOW REQUEST" : "\(followRequests.count) FOLLOW REQUESTS")
                    .font(PB.mono(9.5, .medium))
                    .tracking(1.8)
                    .foregroundStyle(BK.paper)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(BK.ink)

                ForEach(followRequests) { request in
                    Rectangle().fill(BK.ink.opacity(0.16)).frame(height: 1)
                    followRequestRow(request)
                }
            }
        }
        .task {
            isPublic = profile.isPublic
            if !profile.isPublic { await loadFollowRequests() }
        }
    }

    private func followRequestRow(_ request: FollowRequestUser) -> some View {
        HStack(spacing: 11) {
            Rectangle()
                .fill(LinearGradient(colors: [BK.muted, BK.ink],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 32, height: 32)
                .overlay(Rectangle().strokeBorder(BK.ink, lineWidth: 2))

            VStack(alignment: .leading, spacing: 2) {
                Text(request.name.isEmpty ? request.username : request.name)
                    .font(.system(size: 14))
                    .foregroundStyle(BK.ink)
                Text("@\(request.username)")
                    .font(PB.mono(11))
                    .foregroundStyle(BK.muted)
            }
            Spacer(minLength: 8)

            Button { respond(to: request.username, accept: true) } label: {
                Text("Confirm")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BK.paper)
                    .padding(.horizontal, 10).padding(.vertical, 6)
            }
            .buttonStyle(BrutalButtonStyle(fill: BK.ink, borderWidth: 2, offset: 2))

            Button { respond(to: request.username, accept: false) } label: {
                Text("Decline")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BK.ink)
                    .padding(.horizontal, 10).padding(.vertical, 6)
            }
            .buttonStyle(BrutalButtonStyle(fill: BK.paper, borderWidth: 2, offset: 2))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func setPublic(_ newValue: Bool) {
        let previous = isPublic
        isPublic = newValue
        Task {
            do {
                let _: UserProfile = try await APIClient.shared.request(
                    path: Endpoints.visibility,
                    method: .patch,
                    body: ["is_public": newValue],
                    requiresAuth: true
                )
                if newValue {
                    followRequests = []
                } else {
                    await loadFollowRequests()
                }
            } catch {
                isPublic = previous
            }
        }
    }

    private func loadFollowRequests() async {
        let response: FollowRequestsResponse? = try? await APIClient.shared.request(
            path: Endpoints.followRequests,
            method: .get,
            requiresAuth: true
        )
        followRequests = response?.requests ?? []
    }

    private func respond(to username: String, accept: Bool) {
        Task {
            let path = Endpoints.followRequest(username: username)
            do {
                if accept {
                    let _: FollowResponse = try await APIClient.shared.request(
                        path: path, method: .post, requiresAuth: true
                    )
                } else {
                    let _: Empty = try await APIClient.shared.request(
                        path: path, method: .delete, requiresAuth: true
                    )
                }
                followRequests.removeAll { $0.username == username }
            } catch {
                // Leave the row in place; the next open re-fetches the truth.
            }
        }
    }

    // MARK: - Section 1: Account

    private var accountSection: some View {
        SettingsSection(title: "Account") {
            NavigationLink {
                ChangePasswordView(email: appState.currentUser?.email)
            } label: {
                SettingsRow(icon: "lock", label: "Change Password")
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section 2: Scan & Know

    private var scanSection: some View {
        SettingsSection(title: "Scan & Know") {
            SettingsRow(icon: "barcode.viewfinder", label: "Free Scans Remaining") {
                Text(scansUnlimited ? "UNLIMITED" : (scansRemaining == 0 ? "NONE LEFT" : "\(scansRemaining) LEFT"))
                    .font(PB.mono(12, .medium))
                    .foregroundStyle(BK.ink)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(BK.paper2)
                    .overlay(Rectangle().strokeBorder(BK.ink, lineWidth: 2))
            }
        }
    }

    // MARK: - Section 3: Your Data

    private var dataSection: some View {
        SettingsSection(title: "Your Data") {
            NavigationLink {
                GoodreadsImportView()
            } label: {
                SettingsRow(icon: "square.and.arrow.down", label: "Import from Goodreads")
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section 4: Discover

    private var discoverSection: some View {
        SettingsSection(title: "Discover") {
            Button {
                if let url = URL(string: "https://paperboxd.in") {
                    shareItem = ShareItem(url: url)
                }
            } label: {
                SettingsRow(icon: "person.badge.plus", label: "Invite Friends")
            }
            .buttonStyle(.plain)

            Rectangle().fill(BK.ink.opacity(0.16)).frame(height: 1)

            Button {
                // TODO: Replace with SKStoreReviewController after App Store submission
                showRateAlert = true
            } label: {
                SettingsRow(icon: "star.fill", label: "Rate PaperBoxd")
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section 5: About

    private var aboutSection: some View {
        SettingsSection(title: "About") {
            NavigationLink {
                LegalView(content: .privacyPolicy)
            } label: {
                SettingsRow(icon: "hand.raised", label: "Privacy Policy")
            }
            .buttonStyle(.plain)

            Rectangle().fill(BK.ink.opacity(0.16)).frame(height: 1)

            NavigationLink {
                LegalView(content: .termsOfService)
            } label: {
                SettingsRow(icon: "doc.text", label: "Terms of Service")
            }
            .buttonStyle(.plain)

            Rectangle().fill(BK.ink.opacity(0.16)).frame(height: 1)

            SettingsRow(icon: "info.circle", label: "Version") {
                Text(Bundle.main.appVersionString)
                    .font(PB.mono(12))
                    .foregroundStyle(BK.muted)
            }
        }
    }

    // MARK: - Section 6: Sign Out

    private var signOutButton: some View {
        Button(action: onSignOut) {
            Text("SIGN OUT")
                .font(PB.mono(13, .medium))
                .tracking(1.4)
                .foregroundStyle(BK.paper)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(BrutalButtonStyle(fill: BK.ink, borderWidth: 2, offset: 5))
        .padding(.top, 8)
    }

    // MARK: - Section 7: Danger Zone

    /// Hatched rather than red — the palette is monochrome, so the hazard reads
    /// from the stripe pattern.
    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button { showDeleteSheet = true } label: {
                Text("DELETE ACCOUNT")
                    .font(PB.mono(12, .medium))
                    .tracking(1.2)
                    .foregroundStyle(BK.ink)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(HatchFill(ink: BK.paper, stripe: BK.paper2, period: 14))
            }
            .buttonStyle(BrutalButtonStyle(fill: .clear, borderWidth: 2, offset: 5))
        }
    }

    private func sectionEyebrow(_ title: String) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(BK.ink).frame(width: 7, height: 7)
            Eyebrow(text: title, color: BK.ink)
        }
    }
}

// MARK: - Section plate

/// Eyebrow + a hard ink plate holding the section's rows.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Rectangle().fill(BK.ink).frame(width: 7, height: 7)
                Eyebrow(text: title, color: BK.ink)
            }
            VStack(spacing: 0) { content }
                .brutalPlate()
        }
    }
}

// MARK: - Reusable row

/// Icon + label, with either a trailing accessory or the default "→" affordance.
struct SettingsRow<Accessory: View>: View {
    let icon: String
    let label: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .frame(width: 22)
                .foregroundStyle(BK.ink)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(BK.ink)
            Spacer(minLength: 8)
            accessory
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .contentShape(Rectangle())
    }
}

extension SettingsRow where Accessory == Text {
    /// Default row: the mono arrow standing in for the list chevron.
    init(icon: String, label: String) {
        self.icon = icon
        self.label = label
        self.accessory = Text("→").font(PB.mono(15)).foregroundStyle(BK.ink)
    }
}

// MARK: - Square switch

/// Hard-edged twin of `Toggle` — a 52×30 ink frame whose knob steps across.
struct BrutalSwitch: View {
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Button { onChange(!isOn) } label: {
            Rectangle()
                .fill(isOn ? BK.ink : BK.paper)
                .frame(width: 52, height: 30)
                .overlay(Rectangle().strokeBorder(BK.ink, lineWidth: 2))
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Rectangle()
                        .fill(isOn ? BK.paper : BK.ink)
                        .frame(width: 22, height: 22)
                        .padding(.horizontal, 2)
                }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.14), value: isOn)
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
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(BK.paper)
                    .frame(width: 52, height: 52)
                    .background(BK.ink)
                    .overlay(Rectangle().strokeBorder(BK.ink, lineWidth: 2))

                Text("Reset your password")
                    .font(PB.serif(24))
                    .foregroundStyle(BK.ink)

                Text("We'll email a reset link to the address on your account. It works once and expires in 30 minutes.")
                    .font(.system(size: 14))
                    .foregroundStyle(BK.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let email {
                    Text(email)
                        .font(PB.mono(12))
                        .foregroundStyle(BK.ink)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(BK.paper2)
                        .overlay(Rectangle().strokeBorder(BK.ink, lineWidth: 2))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brutalPlate()

            Button {
                Task { await sendReset() }
            } label: {
                HStack(spacing: 9) {
                    if isSending { ProgressView().tint(BK.paper).scaleEffect(0.8) }
                    Text(isSending ? "SENDING…" : "SEND RESET LINK")
                        .font(PB.mono(13, .medium))
                        .tracking(1.4)
                }
                .foregroundStyle(BK.paper)
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(BrutalButtonStyle(fill: BK.ink, borderWidth: 2, offset: 5))
            .disabled(isSending || email == nil)
            .opacity(email == nil ? 0.5 : 1)

            if let message {
                HStack(spacing: 10) {
                    Image(systemName: isError ? "exclamationmark.triangle" : "checkmark")
                        .font(.system(size: 14, weight: .bold))
                    Text(message)
                        .font(.system(size: 13.5, weight: .medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(BK.paper)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(BK.ink)
                .overlay(Rectangle().strokeBorder(BK.ink, lineWidth: 2))
            }

            Spacer()

            Text("NO IN-APP CHANGE · RESET BY EMAIL")
                .font(PB.mono(10))
                .tracking(2)
                .foregroundStyle(BK.muted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BK.paper.ignoresSafeArea())
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

    var url: URL {
        switch self {
        case .privacyPolicy:  return URL(string: "https://paperboxd.in/privacy")!
        case .termsOfService: return URL(string: "https://paperboxd.in/terms")!
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
            emailing paperboxd@gmail.com.

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
            VStack(alignment: .leading, spacing: 20) {
                Text(content.body)
                    .font(.system(size: 15))
                    .foregroundStyle(BK.ink)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .brutalPlate()

                Link(destination: content.url) {
                    Text("READ THE FULL \(content.title.uppercased()) →")
                        .font(PB.mono(12, .medium))
                        .tracking(1.2)
                        .foregroundStyle(BK.paper)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .brutalPlate(fill: BK.ink)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(BK.paper.ignoresSafeArea())
        .navigationTitle(content.title)
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
