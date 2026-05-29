import Combine
import Foundation
import SwiftUI

/// Drives the multi-step onboarding flow:
/// username → genres → tempo → aha-loading → aha-reveal.
/// Mirrors the web onboarding-flow.tsx step machine. The view binds to `step`
/// and the per-step fields; navigation between steps is animated by the view.
@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Equatable {
        case username
        case genres
        case tempo
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
    @Published var selectedGenres: Set<String> = []

    // Tempo step
    @Published var tempo: String = "regular"

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

    init(user: User) {
        self.user = user
        self.avatarURL = user.avatarURL
    }

    deinit { debounceTask?.cancel() }

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
        onFinished()
    }

    // MARK: - Step 2 → 3

    func continueFromGenres() {
        guard selectedGenres.count >= 3 else { return }
        advance(to: .tempo)
    }

    func toggleGenre(_ id: String) {
        if selectedGenres.contains(id) {
            selectedGenres.remove(id)
        } else {
            selectedGenres.insert(id)
        }
    }

    // MARK: - Step 3 → Aha

    /// Persists genres (the only data the backend stores) then fetches the first
    /// recommendation. Tempo is collected but not persisted — matches web.
    func continueFromTempo() {
        advance(to: .ahaLoading)
        Task { await loadAha() }
    }

    private func loadAha() async {
        // Save genres first so the engine has them before we query.
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

        // Keep the loading state visible long enough to feel intentional.
        let minLoad = Task { try? await Task.sleep(nanoseconds: 1_600_000_000) }

        var books: [RecBook] = []
        do {
            let resp: RecommendationsResponse = try await APIClient.shared.request(
                path: Endpoints.recommendationsHome,
                method: .get,
                requiresAuth: true
            )
            books = resp.recommendations.filter { ($0.coverURL?.isValidCover ?? false) && !$0.title.isEmpty }
        } catch {
            books = []
        }

        await minLoad.value

        if books.isEmpty {
            onFinished()
            return
        }
        ahaBooks = Array(books.prefix(8))
        ahaIndex = 0
        advance(to: .ahaReveal)
    }

    // MARK: - Aha reveal actions

    func showAnother() {
        guard !ahaBooks.isEmpty else { onFinished(); return }
        ahaIndex = (ahaIndex + 1) % ahaBooks.count
    }

    func saveToShelf() async {
        guard let book = currentAhaBook else { onFinished(); return }
        let uname = claimedUsername?.nonEmpty ?? username.nonEmpty ?? user.username?.nonEmpty
        guard let uname else {
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
            onFinished()
        } catch let e as APIError {
            errorMessage = e.errorDescription ?? "Couldn't add the book. Try again."
        } catch {
            errorMessage = error.localizedDescription
        }
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
