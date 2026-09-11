import Combine
import Foundation
import SwiftUI

/// Drives the multi-step onboarding flow:
/// username → genres → books you love → readers to follow → aha-loading → aha-reveal.
/// Mirrors the web onboarding-flow.tsx step machine. The view binds to `step`
/// and the per-step fields; navigation between steps is animated by the view.
@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Equatable {
        case username
        case genres
        case books
        case readers
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

    // Books-you-love step. Picks become favourites (Top 4) *and* `read` shelf
    // rows — `read` is what the recommendation engine ranks on.
    @Published var pickSuggestions: [RecBook] = []
    @Published var isLoadingSuggestions = false
    @Published var picks: [RecBook] = []
    @Published var searchQuery: String = ""
    @Published var searchResults: [RecBook] = []
    @Published var isSearching = false

    // Readers-to-follow step
    @Published var readers: [SuggestedReader] = []
    @Published var isLoadingReaders = false
    @Published var followed: Set<String> = []

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
    private var searchTask: Task<Void, Never>?
    private let user: User
    private let startedAt = Date()

    init(user: User) {
        self.user = user
        self.avatarURL = user.avatarURL
    }

    deinit {
        debounceTask?.cancel()
        searchTask?.cancel()
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

    // MARK: - Step 2 → 3: genres → books you love

    /// Genres are saved here, not at the end: the picker suggestions and every
    /// later recommendation call are genre-aware, and a reader who bails after
    /// this step is still onboarded instead of being bounced back in.
    func continueFromGenres() {
        guard selectedGenres.count >= 3 else { return }
        advance(to: .books)
        Task { await loadPickSuggestions() }
    }

    func toggleGenre(_ id: String) {
        if selectedGenres.contains(id) {
            selectedGenres.remove(id)
        } else {
            selectedGenres.insert(id)
        }
    }

    private func loadPickSuggestions() async {
        isLoadingSuggestions = true
        defer { isLoadingSuggestions = false }
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
        let resp: RecommendationsResponse? = try? await APIClient.shared.request(
            path: Endpoints.recommendationsHome,
            method: .get,
            requiresAuth: true
        )
        pickSuggestions = Array(
            (resp?.recommendations ?? [])
                .filter { ($0.coverURL?.isValidCover ?? false) && !$0.title.isEmpty }
                .prefix(12)
        )
    }

    // MARK: - Books you love

    func searchChanged(_ raw: String) {
        searchTask?.cancel()
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
            let resp: BookListResponse? = try? await APIClient.shared.request(
                path: Endpoints.searchBooks + "?q=\(encoded)&page_size=8",
                method: .get,
                requiresAuth: false
            )
            if Task.isCancelled { return }
            await MainActor.run {
                self?.searchResults = (resp?.items ?? []).map(RecBook.init(searchResult:))
                self?.isSearching = false
            }
        }
    }

    /// What the grid shows: search hits while typing, suggestions otherwise.
    var pickGrid: [RecBook] {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 ? searchResults : pickSuggestions
    }

    func isPicked(_ book: RecBook) -> Bool { picks.contains { $0.id == book.id } }

    func togglePick(_ book: RecBook) {
        if let idx = picks.firstIndex(where: { $0.id == book.id }) {
            picks.remove(at: idx)
            return
        }
        guard picks.count < onboardingMaxPicks else {
            errorMessage = "That's your top \(onboardingMaxPicks) — remove one to swap."
            return
        }
        errorMessage = nil
        Analytics.track("book_selected_during_onboarding", bookID: nil, metadata: [
            "title": book.title,
            "source": searchResults.contains { $0.id == book.id } ? "search" : "suggested",
        ])
        picks.append(book)
        searchQuery = ""
        searchResults = []
    }

    // MARK: - Step 3 → 4: books → readers

    /// Persists picks (favourite + read shelf entry, in parallel — one failure
    /// must not block the rest) while the readers list loads.
    func continueFromBooks() {
        advance(to: .readers)
        isLoadingReaders = true
        Task {
            async let saved: Void = savePicks()
            async let loaded: Void = loadReaders()
            _ = await (saved, loaded)
            isLoadingReaders = false
        }
    }

    private func savePicks() async {
        guard let uname = resolvedUsername, !picks.isEmpty else { return }
        // display_order = pick order, so the Top 4 reads in the order they chose.
        await withTaskGroup(of: Void.self) { group in
            for (i, book) in picks.enumerated() {
                group.addTask {
                    _ = try? await APIClient.shared.request(
                        path: Endpoints.addToBookshelf(username: uname),
                        method: .post,
                        body: ["book_id": book.id, "status": "read"],
                        requiresAuth: true
                    ) as Empty
                    _ = try? await APIClient.shared.request(
                        path: Endpoints.userFavorites(username: uname),
                        method: .post,
                        body: AddFavoriteBody(bookID: book.id, displayOrder: i + 1),
                        requiresAuth: true
                    ) as Empty
                }
            }
        }
    }

    private func loadReaders() async {
        let resp: SuggestedReadersResponse? = try? await APIClient.shared.request(
            path: Endpoints.suggestedUsers + "?limit=6",
            method: .get,
            requiresAuth: true
        )
        readers = resp?.users ?? []
    }

    // MARK: - Readers to follow

    func follow(_ reader: SuggestedReader) {
        guard !followed.contains(reader.username) else { return }
        followed.insert(reader.username) // optimistic
        Task {
            do {
                let _: Empty = try await APIClient.shared.request(
                    path: Endpoints.follow(username: reader.username),
                    method: .post,
                    requiresAuth: true
                )
                Analytics.track("person_followed_during_onboarding", metadata: [
                    "username": reader.username,
                    "reason": reader.reason,
                ])
            } catch {
                followed.remove(reader.username)
                errorMessage = "Couldn't follow \(reader.displayName)."
            }
        }
    }

    // MARK: - Step 4 → Aha

    func continueFromReaders() {
        advance(to: .ahaLoading)
        Task { await loadAha() }
    }

    private func loadAha() async {
        // Keep the loading state visible long enough to feel intentional.
        let minLoad = Task { try? await Task.sleep(nanoseconds: 1_600_000_000) }

        let pickedIDs = Set(picks.map(\.id))
        var books: [RecBook] = []
        do {
            let resp: RecommendationsResponse = try await APIClient.shared.request(
                path: Endpoints.recommendationsHome,
                method: .get,
                requiresAuth: true
            )
            books = resp.recommendations.filter {
                ($0.coverURL?.isValidCover ?? false) && !$0.title.isEmpty && !pickedIDs.contains($0.id)
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
            "books_selected": String(picks.count),
            "people_followed": String(followed.count),
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

/// POST /users/{username}/favorites. display_order 1–4; the backend
/// auto-assigns a free slot when it is omitted.
private struct AddFavoriteBody: Encodable {
    let bookID: String
    let displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case bookID = "book_id"
        case displayOrder = "display_order"
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
