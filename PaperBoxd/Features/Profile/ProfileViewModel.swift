import Combine
import Foundation

enum ProfileTab: String, CaseIterable {
    case bookshelf = "Bookshelf"
    case diary = "Diary"
    case lists = "Lists"
    case tbr = "TBR"
    case authors = "Authors"
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var selectedTab: ProfileTab = .bookshelf

    // Shelf — the profile bookshelf tab shows 'read' + 'reading' together
    // (merged client-side) so a freshly added book appears immediately.
    @Published var shelfBooks: [BookWithStatus] = []
    @Published var shelfTotal: Int?
    @Published var isLoadingShelf = false
    private var shelfPage = 1
    private var shelfHasMore = true
    private var didLoadReading = false
    private var readingBooks: [BookWithStatus] = []
    private var readBooks: [BookWithStatus] = []
    private var readTotal = 0

    /// The book to surface in the profile "currently reading" card when the
    /// server has no logged-reading entry yet — the most recently added
    /// 'reading' book. Lets an "Add to Bookshelf" show up right away.
    var currentlyReadingFallback: LastLoggedBook? {
        guard let b = readingBooks.first else { return nil }
        return LastLoggedBook(
            bookID: b.id,
            title: b.title,
            slug: b.slug ?? "",
            author: b.authors.first ?? "",
            cover: b.coverURL ?? "",
            currentPage: 0,
            totalPages: b.volumeInfo.pageCount ?? 0
        )
    }

    // Diary
    @Published var diaryEntries: [DiaryEntry] = []
    @Published var isLoadingDiary = false
    private var diaryPage = 1
    private var diaryHasMore = true

    // Lists
    @Published var ownLists: [ReadingList] = []
    @Published var savedLists: [ReadingList] = []

    // TBR (to be read)
    @Published var tbrItems: [TBRItem] = []
    @Published var isLoadingTBR = false

    // Authors read
    @Published var authors: [AuthorSummary] = []
    @Published var isLoadingAuthors = false

    // Favourites ("Four books I love")
    @Published var favoriteBooks: [FavoriteBook] = []

    // Last logged book (drives the currently-reading card)
    @Published var lastLoggedBook: LastLoggedBook?

    // Reading streak (server-computed)
    @Published var streak: Int?

    // Reading heatmap (GitHub-style per-day page log)
    @Published var activity: ReadingActivity?
    @Published var activityYear: Int = Calendar(identifier: .gregorian).component(.year, from: Date())

    // Follow
    @Published var isFollowLoading = false
    @Published var toastMessage: String?

    let profileUsername: String
    let viewerUser: User

    init(username: String, viewer: User, loadOnInit: Bool = true) {
        self.profileUsername = username
        self.viewerUser = viewer
        if loadOnInit {
            Task { await fetchAll() }
        }
    }

    var isOwnProfile: Bool {
        viewerUser.username?.lowercased() == profileUsername.lowercased()
    }

    func fetchAll() async {
        isLoading = true
        errorMessage = nil
        async let profileTask: UserProfile = fetchProfile()
        async let lastBookTask: LastLoggedBookResponse? = loadLastLoggedBook()
        async let favoritesTask: [FavoriteBook]? = loadFavorites()
        async let streakTask: Int? = loadStreak()
        async let activityTask: ReadingActivity? = loadActivity(year: activityYear)
        do {
            profile = try await profileTask
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        // Only overwrite on a successful fetch. A transient failure during
        // pull-to-refresh must never blank data that's already on screen.
        if let resp = await lastBookTask { lastLoggedBook = resp.lastBook }
        if let favs = await favoritesTask { favoriteBooks = favs }
        if let s = await streakTask { streak = s }
        if let act = await activityTask { activity = act }
        isLoading = false
        await refreshShelf()
        await refreshActiveTab()
    }

    /// Re-fetches the currently selected secondary tab (page 1), replacing its
    /// contents only on success. Without this, pull-to-refresh spins but the
    /// diary/lists/tbr/authors lists never reload because their fetchers guard
    /// on isEmpty/hasMore.
    private func refreshActiveTab() async {
        switch selectedTab {
        case .bookshelf:
            break // refreshShelf() already handled this
        case .diary:
            if let resp: DiaryEntriesResponse = try? await APIClient.shared.request(
                path: Endpoints.userDiary(username: profileUsername) + "?page=1&page_size=20",
                method: .get, requiresAuth: true
            ) {
                diaryEntries = resp.entries
                diaryPage = 2
                diaryHasMore = resp.entries.count == 20
            }
        case .lists:
            if let resp: UserListsResponse = try? await APIClient.shared.request(
                path: Endpoints.userLists(username: profileUsername),
                method: .get, requiresAuth: true
            ) {
                ownLists = resp.ownLists
                savedLists = resp.savedLists
            }
        case .tbr:
            if let items: [TBRItem] = try? await APIClient.shared.request(
                path: Endpoints.userTBR(username: profileUsername),
                method: .get, requiresAuth: true
            ) {
                tbrItems = items
            }
        case .authors:
            if let items: [AuthorSummary] = try? await APIClient.shared.request(
                path: Endpoints.userAuthors(username: profileUsername),
                method: .get, requiresAuth: true
            ) {
                authors = items
            }
        }
    }

    /// Re-fetches the shelf without clearing what's already shown, so a failed
    /// refresh keeps the existing books instead of blanking the grid.
    private func refreshShelf() async {
        guard !isLoadingShelf else { return }
        isLoadingShelf = true
        defer { isLoadingShelf = false }

        var freshReading = readingBooks
        if let resp: BookshelfResponse = try? await APIClient.shared.request(
            path: Endpoints.userBookshelf(username: profileUsername) + "?status=reading&page=1&page_size=40",
            method: .get,
            requiresAuth: true
        ) {
            freshReading = resp.books
        }

        do {
            let resp: BookshelfResponse = try await APIClient.shared.request(
                path: Endpoints.userBookshelf(username: profileUsername) + "?status=read&page=1&page_size=20",
                method: .get,
                requiresAuth: true
            )
            readingBooks = freshReading
            readBooks = resp.books
            readTotal = Int(resp.totalCount)
            shelfPage = 2
            shelfHasMore = resp.books.count == 20
            didLoadReading = true
            rebuildShelf()
        } catch {
            // Keep the current shelf on failure.
        }
    }

    /// Uploads a new banner image, then refreshes the profile so the new URL renders.
    func uploadBanner(_ data: Data) async {
        do {
            let _: UserProfile = try await APIClient.shared.upload(
                path: Endpoints.bannerUpload,
                fileData: data, fileName: "banner.jpg", mimeType: "image/jpeg",
                requiresAuth: true
            )
            await fetchAll()
            toastMessage = "Banner updated"
        } catch let e as APIError {
            toastMessage = e.errorDescription
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    private func loadLastLoggedBook() async -> LastLoggedBookResponse? {
        try? await APIClient.shared.request(
            path: Endpoints.lastLoggedBook(username: profileUsername),
            method: .get,
            requiresAuth: true
        )
    }

    private func loadStreak() async -> Int? {
        let resp: StreakResponse? = try? await APIClient.shared.request(
            path: Endpoints.userStreak(username: profileUsername),
            method: .get,
            requiresAuth: true
        )
        return resp?.streak
    }

    private func loadActivity(year: Int) async -> ReadingActivity? {
        try? await APIClient.shared.request(
            path: Endpoints.readingActivity(username: profileUsername, year: year),
            method: .get,
            requiresAuth: true
        )
    }

    /// Switches the heatmap year and reloads just the activity payload.
    func selectActivityYear(_ year: Int) {
        guard year != activityYear else { return }
        activityYear = year
        Task { activity = await loadActivity(year: year) }
    }

    private func loadFavorites() async -> [FavoriteBook]? {
        let favs: [FavoriteBook]? = try? await APIClient.shared.request(
            path: Endpoints.userFavorites(username: profileUsername),
            method: .get,
            requiresAuth: true
        )
        return favs?.sorted { $0.displayOrder < $1.displayOrder }
    }

    func retry() async { await fetchAll() }

    private func fetchProfile() async throws -> UserProfile {
        try await APIClient.shared.request(
            path: Endpoints.profile(username: profileUsername),
            method: .get,
            requiresAuth: true
        )
    }

    // MARK: - Shelf

    func fetchShelf() async {
        guard shelfHasMore || !didLoadReading, !isLoadingShelf else { return }
        isLoadingShelf = true
        defer { isLoadingShelf = false }

        // Currently-reading books have no finished_at and never come back under
        // status=read, so fetch them once and pin them to the top of the shelf.
        if !didLoadReading {
            didLoadReading = true
            if let resp: BookshelfResponse = try? await APIClient.shared.request(
                path: Endpoints.userBookshelf(username: profileUsername) + "?status=reading&page=1&page_size=40",
                method: .get,
                requiresAuth: true
            ) {
                readingBooks = resp.books
            }
        }

        if shelfHasMore {
            do {
                let resp: BookshelfResponse = try await APIClient.shared.request(
                    path: Endpoints.userBookshelf(username: profileUsername) + "?status=read&page=\(shelfPage)&page_size=20",
                    method: .get,
                    requiresAuth: true
                )
                readBooks += resp.books
                readTotal = Int(resp.totalCount)
                shelfPage += 1
                shelfHasMore = resp.books.count == 20
            } catch {}
        }

        rebuildShelf()
    }

    /// Reading books first, then read books, de-duplicated by id.
    private func rebuildShelf() {
        var seen = Set<String>()
        var merged: [BookWithStatus] = []
        for b in readingBooks + readBooks where !seen.contains(b.id) {
            seen.insert(b.id)
            merged.append(b)
        }
        shelfBooks = merged
        shelfTotal = readingBooks.count + readTotal
    }

    func fetchShelfIfNeeded(item: BookWithStatus) async {
        guard let last = shelfBooks.last, last.id == item.id else { return }
        await fetchShelf()
    }

    // MARK: - Diary

    func fetchDiary() async {
        guard diaryHasMore, !isLoadingDiary else { return }
        isLoadingDiary = true
        defer { isLoadingDiary = false }
        do {
            let resp: DiaryEntriesResponse = try await APIClient.shared.request(
                path: Endpoints.userDiary(username: profileUsername) + "?page=\(diaryPage)&page_size=20",
                method: .get,
                requiresAuth: true
            )
            diaryEntries += resp.entries
            diaryPage += 1
            diaryHasMore = resp.entries.count == 20
        } catch {}
    }

    func fetchDiaryIfNeeded(item: DiaryEntry) async {
        guard let last = diaryEntries.last, last.id == item.id else { return }
        await fetchDiary()
    }

    func handleDeletedEntry(_ id: String) {
        diaryEntries.removeAll { $0.id == id }
    }

    // MARK: - Lists

    func fetchLists() async {
        guard ownLists.isEmpty && savedLists.isEmpty else { return }
        do {
            let resp: UserListsResponse = try await APIClient.shared.request(
                path: Endpoints.userLists(username: profileUsername),
                method: .get,
                requiresAuth: true
            )
            ownLists = resp.ownLists
            savedLists = resp.savedLists
        } catch {}
    }

    struct CreateListBody: Encodable {
        let title: String
        let description: String?
        let isPrivate: Bool
        enum CodingKeys: String, CodingKey {
            case title, description
            case isPrivate = "is_private"
        }
    }

    /// Creates a list for the current profile. Returns true on success; prepends
    /// the new list to `ownLists` so the tab updates without a full refetch.
    func createList(title: String, description: String?, isPrivate: Bool) async -> Bool {
        do {
            let created: ReadingList = try await APIClient.shared.request(
                path: Endpoints.userLists(username: profileUsername),
                method: .post,
                body: CreateListBody(title: title, description: description, isPrivate: isPrivate),
                requiresAuth: true
            )
            ownLists.insert(created, at: 0)
            return true
        } catch {
            return false
        }
    }

    // MARK: - TBR

    func fetchTBR() async {
        guard tbrItems.isEmpty, !isLoadingTBR else { return }
        isLoadingTBR = true
        defer { isLoadingTBR = false }
        do {
            let items: [TBRItem] = try await APIClient.shared.request(
                path: Endpoints.userTBR(username: profileUsername),
                method: .get,
                requiresAuth: true
            )
            tbrItems = items
        } catch {}
    }

    // MARK: - Authors

    func fetchAuthors() async {
        guard authors.isEmpty, !isLoadingAuthors else { return }
        isLoadingAuthors = true
        defer { isLoadingAuthors = false }
        do {
            let items: [AuthorSummary] = try await APIClient.shared.request(
                path: Endpoints.userAuthors(username: profileUsername),
                method: .get,
                requiresAuth: true
            )
            authors = items
        } catch {}
    }

    // MARK: - Tab switching

    func onTabSelected(_ tab: ProfileTab) {
        selectedTab = tab
        Task {
            switch tab {
            case .bookshelf: if shelfBooks.isEmpty { await fetchShelf() }
            case .diary:     if diaryEntries.isEmpty { await fetchDiary() }
            case .lists:     await fetchLists()
            case .tbr:       await fetchTBR()
            case .authors:   await fetchAuthors()
            }
        }
    }

    // MARK: - Follow

    func toggleFollow() async {
        guard let prof = profile, !isOwnProfile else { return }
        let isCurrentlyFollowing = prof.isFollowing ?? false
        isFollowLoading = true
        defer { isFollowLoading = false }
        do {
            let resp: FollowResponse = try await APIClient.shared.request(
                path: Endpoints.follow(username: profileUsername),
                method: isCurrentlyFollowing ? .delete : .post,
                requiresAuth: true
            )
            profile?.isFollowing = resp.isFollowing
            profile = profile.map {
                var p = $0
                p = UserProfile(
                    id: p.id, username: p.username, name: p.name, avatarURL: p.avatarURL,
                    bannerURL: p.bannerURL,
                    bio: p.bio, pronouns: p.pronouns,
                    birthday: p.birthday, gender: p.gender, links: p.links,
                    isPublic: p.isPublic,
                    booksReadCount: p.booksReadCount, totalPagesRead: p.totalPagesRead,
                    favoritesCount: p.favoritesCount, listsCount: p.listsCount,
                    diaryEntriesCount: p.diaryEntriesCount,
                    followersCount: resp.followersCount,
                    followingCount: p.followingCount,
                    favoriteGenres: p.favoriteGenres, createdAt: p.createdAt,
                    isFollowing: resp.isFollowing
                )
                return p
            }
        } catch let e as APIError {
            toastMessage = e.errorDescription
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    // MARK: - Moderation

    func reportUser(reason: String) async {
        do {
            try await ModerationService.report(contentType: "user", contentID: profileUsername, reason: reason)
            toastMessage = "Report received — we review within 24 hours"
        } catch {
            toastMessage = "Couldn't send report"
        }
    }

    /// Blocks the profile user. Returns true on success so the view can dismiss.
    func blockUser() async -> Bool {
        guard !isOwnProfile else { return false }
        do {
            try await ModerationService.block(username: profileUsername)
            return true
        } catch {
            toastMessage = "Couldn't block"
            return false
        }
    }
}
