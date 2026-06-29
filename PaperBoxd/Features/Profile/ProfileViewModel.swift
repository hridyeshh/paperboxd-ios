import Combine
import Foundation

enum ProfileTab: String, CaseIterable {
    case bookshelf = "Bookshelf"
    case diary = "Diary"
    case lists = "Lists"
    case dnf = "DNF"
    case authors = "Authors"
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var selectedTab: ProfileTab = .bookshelf

    // Shelf
    @Published var shelfBooks: [BookWithStatus] = []
    @Published var isLoadingShelf = false
    private var shelfPage = 1
    private var shelfHasMore = true

    // Diary
    @Published var diaryEntries: [DiaryEntry] = []
    @Published var isLoadingDiary = false
    private var diaryPage = 1
    private var diaryHasMore = true

    // Lists
    @Published var ownLists: [ReadingList] = []
    @Published var savedLists: [ReadingList] = []

    // DNF (started but not finished)
    @Published var dnfItems: [TBRItem] = []
    @Published var isLoadingDNF = false

    // Authors read
    @Published var authors: [AuthorSummary] = []
    @Published var isLoadingAuthors = false

    // Favourites ("Four books I love")
    @Published var favoriteBooks: [FavoriteBook] = []

    // Last logged book (drives the currently-reading card)
    @Published var lastLoggedBook: LastLoggedBook?

    // Reading streak (server-computed)
    @Published var streak: Int?

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
        async let lastBookTask: LastLoggedBook? = loadLastLoggedBook()
        async let favoritesTask: [FavoriteBook] = loadFavorites()
        async let streakTask: Int? = loadStreak()
        do {
            profile = try await profileTask
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        lastLoggedBook = await lastBookTask
        favoriteBooks = await favoritesTask
        streak = await streakTask
        isLoading = false
        await fetchShelf()
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

    private func loadLastLoggedBook() async -> LastLoggedBook? {
        let resp: LastLoggedBookResponse? = try? await APIClient.shared.request(
            path: Endpoints.lastLoggedBook(username: profileUsername),
            method: .get,
            requiresAuth: true
        )
        return resp?.lastBook
    }

    private func loadStreak() async -> Int? {
        let resp: StreakResponse? = try? await APIClient.shared.request(
            path: Endpoints.userStreak(username: profileUsername),
            method: .get,
            requiresAuth: true
        )
        return resp?.streak
    }

    private func loadFavorites() async -> [FavoriteBook] {
        let favs: [FavoriteBook]? = try? await APIClient.shared.request(
            path: Endpoints.userFavorites(username: profileUsername),
            method: .get,
            requiresAuth: true
        )
        return (favs ?? []).sorted { $0.displayOrder < $1.displayOrder }
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
        guard shelfHasMore, !isLoadingShelf else { return }
        isLoadingShelf = true
        defer { isLoadingShelf = false }
        do {
            let resp: BookshelfResponse = try await APIClient.shared.request(
                path: Endpoints.userBookshelf(username: profileUsername) + "?status=read&page=\(shelfPage)&page_size=20",
                method: .get,
                requiresAuth: true
            )
            shelfBooks += resp.books
            shelfPage += 1
            shelfHasMore = resp.books.count == 20
        } catch {}
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

    // MARK: - DNF

    func fetchDNF() async {
        guard dnfItems.isEmpty, !isLoadingDNF else { return }
        isLoadingDNF = true
        defer { isLoadingDNF = false }
        do {
            let items: [TBRItem] = try await APIClient.shared.request(
                path: Endpoints.userDNF(username: profileUsername),
                method: .get,
                requiresAuth: true
            )
            dnfItems = items
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
            case .dnf:       await fetchDNF()
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
                    bio: p.bio, pronouns: p.pronouns, isPublic: p.isPublic,
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
}
