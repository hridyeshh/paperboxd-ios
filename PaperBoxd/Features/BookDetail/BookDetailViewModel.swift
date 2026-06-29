import Combine
import Foundation

@MainActor
final class BookDetailViewModel: ObservableObject {
    @Published var book: Book?
    @Published var isLoading = true
    @Published var similarBooks: [RecommendationItem] = []
    @Published var bookState = UserBookState()
    @Published var errorMessage: String?
    @Published var toastMessage: String?

    @Published var friendsOnBook: [FriendOnBook] = []
    @Published var friendsReadingCount: Int = 0
    @Published var friendReviews: [FriendBookReview] = []
    @Published var progress: ReadingProgress?
    @Published var isSavingProgress = false

    let bookId: String
    let user: User

    init(bookId: String, user: User, loadOnInit: Bool = true) {
        self.bookId = bookId
        self.user = user
        if loadOnInit {
            Task { await fetchAll() }
        }
    }

    // MARK: - Fetch

    private func fetchAll() async {
        isLoading = true
        errorMessage = nil
        async let bookTask: Book = fetchBook()
        async let similarTask: [RecommendationItem] = fetchSimilar()
        async let statusTask: BookStatusResponse? = fetchStatus()
        async let friendsTask: FriendsReadingResponse? = fetchFriendsOnBook()
        async let friendReviewsTask: FriendReviewsResponse? = fetchFriendReviews()
        async let progressTask: ReadingProgress? = fetchProgress()
        do {
            book = try await bookTask
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        similarBooks = (try? await similarTask) ?? []
        if let status = await statusTask {
            bookState.isRead  = status.isRead
            bookState.isLiked = status.isLiked
            bookState.isTBR   = status.isTBR
        }
        if let f = await friendsTask {
            friendsOnBook = f.friends
            friendsReadingCount = f.readingCount
        }
        friendReviews = (await friendReviewsTask)?.reviews ?? []
        progress = await progressTask
        isLoading = false
    }

    private func fetchFriendsOnBook() async -> FriendsReadingResponse? {
        try? await APIClient.shared.request(
            path: Endpoints.bookFriendsReading(bookId),
            method: .get,
            requiresAuth: true
        )
    }

    private func fetchFriendReviews() async -> FriendReviewsResponse? {
        try? await APIClient.shared.request(
            path: Endpoints.bookReviewsByFriends(bookId),
            method: .get,
            requiresAuth: true
        )
    }

    private func fetchProgress() async -> ReadingProgress? {
        guard let uname = user.username else { return nil }
        return try? await APIClient.shared.request(
            path: Endpoints.readingProgress(username: uname, bookId: bookId),
            method: .get,
            requiresAuth: true
        )
    }

    private func fetchStatus() async -> BookStatusResponse? {
        guard let uname = user.username else { return nil }
        return try? await APIClient.shared.request(
            path: Endpoints.bookStatus(username: uname, bookId: bookId),
            method: .get,
            requiresAuth: true
        )
    }

    private func fetchBook() async throws -> Book {
        try await APIClient.shared.request(
            path: Endpoints.book(bookId),
            method: .get,
            requiresAuth: false
        )
    }

    private func fetchSimilar() async throws -> [RecommendationItem] {
        let resp: SimilarBooksResponse = try await APIClient.shared.request(
            path: Endpoints.similarBooks(bookId),
            method: .get,
            requiresAuth: false
        )
        return resp.similar
    }

    func retry() async {
        await fetchAll()
    }

    func updateProgress(currentPage: Int, totalPages: Int) async {
        guard let uname = user.username else { return }
        isSavingProgress = true
        defer { isSavingProgress = false }
        do {
            let resp: ProgressUpdateResponse = try await APIClient.shared.request(
                path: Endpoints.readingProgress(username: uname, bookId: bookId),
                method: .put,
                body: ProgressBody(currentPage: currentPage, totalPages: totalPages),
                requiresAuth: true
            )
            progress = ReadingProgress(
                onShelf: progress?.onShelf ?? true,
                status: progress?.status ?? "reading",
                currentPage: resp.currentPage,
                totalPages: resp.totalPages,
                percent: resp.percent,
                estimatedFinishDate: progress?.estimatedFinishDate,
                startedAt: progress?.startedAt,
                finishedAt: nil
            )
            toastMessage = "Progress saved"
        } catch let e as APIError {
            toastMessage = e.errorDescription
        } catch {
            toastMessage = error.localizedDescription
        }
    }

    // MARK: - Toggle actions (optimistic UI)

    func toggleRead() async {
        guard let uname = user.username else { return }
        let prev = bookState.isRead
        bookState.isRead = !prev
        if prev { bookState.isRead = false } else { bookState.isTBR = false }
        bookState.isLoading = true
        defer { bookState.isLoading = false }

        do {
            if prev {
                let _: Empty = try await APIClient.shared.request(
                    path: Endpoints.removeFromBookshelf(username: uname, bookId: bookId),
                    method: .delete,
                    requiresAuth: true
                )
            } else {
                let _: Empty = try await APIClient.shared.request(
                    path: Endpoints.addToBookshelf(username: uname),
                    method: .post,
                    body: ["book_id": bookId, "status": "read"],
                    requiresAuth: true
                )
            }
        } catch let e as APIError {
            bookState.isRead = prev
            toastMessage = e.errorDescription
        } catch {
            bookState.isRead = prev
            toastMessage = error.localizedDescription
        }
    }

    func toggleLike() async {
        let prev = bookState.isLiked
        bookState.isLiked = !prev
        bookState.isLoading = true
        defer { bookState.isLoading = false }

        do {
            if prev {
                let _: Empty = try await APIClient.shared.request(
                    path: Endpoints.likeBook(bookId),
                    method: .delete,
                    requiresAuth: true
                )
            } else {
                let _: Empty = try await APIClient.shared.request(
                    path: Endpoints.likeBook(bookId),
                    method: .post,
                    requiresAuth: true
                )
            }
        } catch let e as APIError {
            bookState.isLiked = prev
            toastMessage = e.errorDescription
        } catch {
            bookState.isLiked = prev
            toastMessage = error.localizedDescription
        }
    }

    // MARK: - Progress structs (private)

    private struct ProgressBody: Encodable {
        let currentPage: Int
        let totalPages: Int
        enum CodingKeys: String, CodingKey {
            case currentPage = "current_page"
            case totalPages = "total_pages"
        }
    }

    private struct ProgressUpdateResponse: Decodable {
        let currentPage: Int
        let totalPages: Int
        let percent: Double
        enum CodingKeys: String, CodingKey {
            case currentPage = "current_page"
            case totalPages = "total_pages"
            case percent
        }
    }

    func toggleTBR() async {
        guard let uname = user.username else { return }
        let prev = bookState.isTBR
        bookState.isTBR = !prev
        if !prev { bookState.isRead = false }
        bookState.isLoading = true
        defer { bookState.isLoading = false }

        do {
            if prev {
                let _: Empty = try await APIClient.shared.request(
                    path: Endpoints.removeFromBookshelf(username: uname, bookId: bookId),
                    method: .delete,
                    requiresAuth: true
                )
            } else {
                let _: Empty = try await APIClient.shared.request(
                    path: Endpoints.addToBookshelf(username: uname),
                    method: .post,
                    body: ["book_id": bookId, "status": "to-read"],
                    requiresAuth: true
                )
            }
        } catch let e as APIError {
            bookState.isTBR = prev
            toastMessage = e.errorDescription
        } catch {
            bookState.isTBR = prev
            toastMessage = error.localizedDescription
        }
    }
}
