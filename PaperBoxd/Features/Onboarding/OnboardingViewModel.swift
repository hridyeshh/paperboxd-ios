import Combine
import Foundation
import SwiftUI

/// Drives the multi-step onboarding flow: username → genres (swipe) →
/// aha-loading → aha-reveal. Three visible steps, to match the signup step
/// counter (signup is step 1, this flow is steps 2–3).
@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Equatable {
        case username
        case genres
        case ahaLoading
        case ahaReveal
    }

    enum Availability: Equatable {
        case idle
        case checking
        case available
        case taken(reason: String?)
        case error(String)
    }

    // Navigation
    @Published var step: Step = .username

    // Username step
    @Published var username: String = ""
    @Published var displayName: String = ""
    @Published var availability: Availability = .idle
    /// Server-confirmed username after the claim PATCH. Authoritative for later
    /// API calls (e.g. add-to-shelf) — the init-time `user.username` may be a
    /// stale auto-generated handle that no longer exists once it's been changed.
    @Published private(set) var claimedUsername: String?
    @Published var avatarImage: UIImage?
    @Published var avatarURL: String?
    @Published var isUploadingAvatar = false

    // Genres step
    @Published var selectedGenres: [String] = [] // pick order: the shelf tray grows at its end

    // Aha step
    @Published var ahaBooks: [RecBook] = []
    @Published var ahaIndex: Int = 0
    @Published var isAddingBook = false

    // Shared async UX
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    /// Set by the container; updates AppState.currentUser.username without routing.
    var onUsernameSet: (String) -> Void = { _ in }
    /// Set by the container; marks onboarding complete and routes to .main.
    var onFinished: () -> Void = {}

    private var debounceTask: Task<Void, Never>?
    private let user: User
    private let startedAt = Date()

    init(user: User) {
        self.user = user
        self.avatarURL = user.avatarURL
    }

    deinit {
        debounceTask?.cancel()
    }

    /// Resolved username for per-user API paths. The claimed one wins; the
    /// init-time handle may be a stale auto-generated value.
    private var resolvedUsername: String? {
        claimedUsername?.nonEmpty ?? username.nonEmpty ?? user.username?.nonEmpty
    }

    var currentAhaBook: RecBook? {
        guard ahaBooks.indices.contains(ahaIndex) else { return nil }
        return ahaBooks[ahaIndex]
    }

    // MARK: - Username availability

    func usernameChanged(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed != raw {
            username = trimmed
            return // second onChange drives the work
        }
        debounceTask?.cancel()

        if trimmed.isEmpty {
            availability = .idle
            return
        }
        if !isLocallyValid(trimmed) {
            availability = .taken(reason: "3–50 chars, letters / numbers / _ / - only.")
            return
        }

        availability = .checking
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            await self?.check(trimmed)
        }
    }

    private func check(_ username: String) async {
        do {
            let resp: CheckUsernameResponse = try await APIClient.shared.request(
                path: Endpoints.checkUsername(username),
                method: .get,
                requiresAuth: false
            )
            if self.username != username { return } // user typed more
            availability = resp.available ? .available : .taken(reason: resp.reason)
        } catch let e as APIError {
            availability = .error(e.errorDescription ?? "Could not check username.")
        } catch {
            availability = .error(error.localizedDescription)
        }
    }

    // MARK: - Avatar

    func pickedAvatar(_ image: UIImage) {
        avatarImage = image
        Task { await uploadAvatar(image) }
    }

    private func uploadAvatar(_ image: UIImage) async {
        guard let data = image.avatarJPEGData() else {
            errorMessage = "Couldn't process that image."
            return
        }
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        do {
            let resp: AvatarUploadResponse = try await APIClient.shared.upload(
                path: Endpoints.avatarUpload,
                fileData: data,
                fileName: "avatar.jpg",
                mimeType: "image/jpeg"
            )
            avatarURL = resp.avatarURL
        } catch let e as APIError {
            errorMessage = e.errorDescription
            avatarImage = nil // revert preview so the user knows it didn't stick
        } catch {
            errorMessage = error.localizedDescription
            avatarImage = nil
        }
    }

    // MARK: - Step 1 → 2: claim username (+ display name)

    func submitUsername() async {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard availability == .available else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        var body: [String: String] = ["username": trimmed]
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { body["name"] = name }

        do {
            let resp: MobileUserResponse = try await APIClient.shared.request(
                path: Endpoints.mobileUpdateMe,
                method: .patch,
                body: body,
                requiresAuth: true
            )
            claimedUsername = resp.user.username ?? trimmed
            onUsernameSet(claimedUsername ?? trimmed)
            advance(to: .genres)
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Skips the whole flow: claims the auto-generated username so the user isn't
    /// re-prompted, then finishes.
    func skip() async {
        let fallback = user.username
            ?? user.email.components(separatedBy: "@").first
            ?? "reader"
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let resp: MobileUserResponse = try await APIClient.shared.request(
                path: Endpoints.mobileUpdateMe,
                method: .patch,
                body: ["username": fallback],
                requiresAuth: true
            )
            claimedUsername = resp.user.username ?? fallback
            onUsernameSet(claimedUsername ?? fallback)
        } catch {
            claimedUsername = fallback
            onUsernameSet(fallback) // best-effort: let the user through
        }
        finish(aha: "skipped_all")
    }

    // MARK: - Step 2 → 3: genres → aha

    /// Genres are saved here, not at the end, and the flow goes straight to
    /// the recommendation reveal — no "books you love" / "readers" detour.
    func continueFromGenres() {
        // Step check: Continue and the end-of-deck hand-off can both fire.
        guard step == .genres, selectedGenres.count >= 3 else { return }
        advance(to: .ahaLoading)
        Task { await loadAha() }
    }

    func toggleGenre(_ id: String) {
        if let i = selectedGenres.firstIndex(of: id) {
            selectedGenres.remove(at: i)
        } else {
            selectedGenres.append(id)
        }
    }

    private func loadAha() async {
        // Long enough for all three loading stages (1s apiece) to play out.
        let minLoad = Task { try? await Task.sleep(nanoseconds: 3_000_000_000) }

        let genres = Array(selectedGenres)
        do {
            let _: Empty = try await APIClient.shared.request(
                path: Endpoints.saveOnboarding,
                method: .post,
                body: ["genres": genres, "authors": [String]()] as [String: [String]],
                requiresAuth: true
            )
        } catch {
            // Non-fatal: genres may already be saved or the call flaked. Keep going.
        }

        var books: [RecBook] = []
        do {
            let resp: RecommendationsResponse = try await APIClient.shared.request(
                path: Endpoints.recommendationsHome,
                method: .get,
                requiresAuth: true
            )
            books = resp.recommendations.filter {
                ($0.coverURL?.isValidCover ?? false) && !$0.title.isEmpty
            }
        } catch {
            books = []
        }

        await minLoad.value

        if books.isEmpty {
            finish(aha: "none")
            return
        }
        ahaBooks = Array(books.prefix(8))
        ahaIndex = 0
        advance(to: .ahaReveal)
    }

    // MARK: - Aha reveal actions

    func showAnother() {
        guard !ahaBooks.isEmpty else { finish(aha: "none"); return }
        ahaIndex = (ahaIndex + 1) % ahaBooks.count
    }

    func skipAha() { finish(aha: "skipped") }

    func saveToShelf() async {
        guard let book = currentAhaBook else { finish(aha: "none"); return }
        guard let uname = resolvedUsername else {
            errorMessage = "Couldn't find your username — restart onboarding."
            return
        }
        isAddingBook = true
        errorMessage = nil
        defer { isAddingBook = false }
        do {
            let _: Empty = try await APIClient.shared.request(
                path: Endpoints.addToBookshelf(username: uname),
                method: .post,
                body: ["book_id": book.id, "status": "to-read"],
                requiresAuth: true
            )
            finish(aha: "saved")
        } catch let e as APIError {
            errorMessage = e.errorDescription ?? "Couldn't add the book. Try again."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Completion

    /// Single exit so `onboarding_completed` is emitted exactly once with the
    /// same metadata the web flow records.
    private func finish(aha: String) {
        Analytics.track("onboarding_completed", metadata: [
            "genres": String(selectedGenres.count),
            "seconds": String(Int(Date().timeIntervalSince(startedAt))),
            "aha": aha,
        ])
        onFinished()
    }

    // MARK: - Helpers

    private func advance(to next: Step) {
        errorMessage = nil
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
            step = next
        }
    }

    private func isLocallyValid(_ s: String) -> Bool {
        guard (3...50).contains(s.count) else { return false }
        return s.range(of: "^[a-z0-9_-]+$", options: .regularExpression) != nil
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }

    var isValidCover: Bool {
        let l = lowercased()
        guard l.hasPrefix("http") else { return false }
        let bad = ["no_cover", "nocover", "placeholder", "default_cover", "missing"]
        return !bad.contains { l.contains($0) }
    }
}
