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
    @Published var reviews: [BookReview] = []
    @Published var isSubmittingReview = false
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
        async let reviewsTask: BookReviewsResponse? = fetchReviews()
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
            bookState.isRead    = status.isRead
            bookState.isLiked   = status.isLiked
            bookState.isTBR     = status.isTBR
            bookState.isOnShelf = status.isOnShelf
        }
        if let f = await friendsTask {
            friendsOnBook = f.friends
            friendsReadingCount = f.readingCount
        }
        friendReviews = (await friendReviewsTask)?.reviews ?? []
        reviews = (await reviewsTask)?.reviews ?? []
        progress = await progressTask
        isLoading = false
    }

    /// The viewer's own review, if they've rated or reviewed this book.
    var myReview: BookReview? {
        guard let uname = user.username?.lowercased() else { return nil }
        return reviews.first { $0.username.lowercased() == uname }
    }

    private func fetchReviews() async -> BookReviewsResponse? {
        try? await APIClient.shared.request(
            path: Endpoints.bookReviews(bookId),
            method: .get,
            requiresAuth: false
        )
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
                currentPage: resp.currentPage ?? currentPage,
                totalPages: resp.totalPages ?? progress?.totalPages,
                percent: resp.percent ?? progress?.percent,
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

    /// Posts the viewer's rating + optional review. The backend stores reviews
    /// on the bookshelf entry, so the book is added to the shelf first if needed.
    /// Returns true on success so the sheet can dismiss.
    func submitReview(rating: Int, review: String?) async -> Bool {
        guard let uname = user.username else { return false }
        isSubmittingReview = true
        defer { isSubmittingReview = false }

        do {
            if !bookState.isOnShelf {
                let _: Empty = try await APIClient.shared.request(
                    path: Endpoints.addToBookshelf(username: uname),
                    method: .post,
                    body: ["book_id": bookId, "status": "reading"],
                    requiresAuth: true
                )
                bookState.isOnShelf = true
            }
            let _: ReviewUpdateResponse = try await APIClient.shared.request(
                path: Endpoints.updateBookshelfRating(username: uname, bookId: bookId),
                method: .patch,
                body: ReviewBody(rating: rating, review: review),
                requiresAuth: true
            )
            reviews = (await fetchReviews())?.reviews ?? reviews
            toastMessage = "Review posted"
            return true
        } catch let e as APIError {
            toastMessage = e.errorDescription
            return false
        } catch {
            toastMessage = error.localizedDescription
            return false
        }
    }

    /// Clears the viewer's rating AND review for this book (PATCH rating:0, review:null).
    /// The backend sets both columns to NULL. Returns true on success.
    @discardableResult
    func deleteReview() async -> Bool {
        guard let uname = user.username else { return false }
        isSubmittingReview = true
        defer { isSubmittingReview = false }
        do {
            let _: ReviewUpdateResponse = try await APIClient.shared.request(
                path: Endpoints.updateBookshelfRating(username: uname, bookId: bookId),
                method: .patch,
                body: ReviewBody(rating: 0, review: nil),
                requiresAuth: true
            )
            reviews = (await fetchReviews())?.reviews ?? reviews
            toastMessage = "Rating & review removed"
            return true
        } catch let e as APIError {
            toastMessage = e.errorDescription
            return false
        } catch {
            toastMessage = error.localizedDescription
            return false
        }
    }

    private struct ReviewBody: Encodable {
        let rating: Int
        let review: String?

        // Encode review as explicit JSON null when nil so the backend clears it.
        enum CodingKeys: String, CodingKey { case rating, review }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(rating, forKey: .rating)
            try c.encode(review, forKey: .review) // writes null when nil
        }
    }

    private struct ReviewUpdateResponse: Decodable {
        let rating: Int?
        let review: String?
        let edited: Bool?
    }

    // MARK: - Toggle actions (optimistic UI)

    /// Adds or removes the book from the user's bookshelf. Adding defaults to
    /// "reading" status; use toggleTBR/updateProgress-to-completion for the
    /// to-read / finished states.
    func toggleBookshelf() async {
        guard let uname = user.username else { return }
        let prev = bookState.isOnShelf
        bookState.isOnShelf = !prev
        if prev { bookState.isRead = false; bookState.isTBR = false }
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
                    body: ["book_id": bookId, "status": "reading"],
                    requiresAuth: true
                )
            }
        } catch let e as APIError {
            bookState.isOnShelf = prev
            toastMessage = e.errorDescription
        } catch {
            bookState.isOnShelf = prev
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
        let currentPage: Int?
        let totalPages: Int?
        let percent: Double?
        enum CodingKeys: String, CodingKey {
            case currentPage = "current_page"
            case totalPages = "total_pages"
            case percent
        }
    }

    // MARK: - Add to Library (brutalist sheet: 3 shelves)

    /// The three library shelves surfaced in the Add-to-Library sheet.
    enum LibraryShelf {
        case bookshelf   // owned / reading — lands on the profile Bookshelf tab
        case tbr         // want-to-read — lands on the profile TBR tab
        case read        // finished — lands on Bookshelf with 100% progress

        var status: String {
            switch self {
            case .bookshelf: return "reading"
            case .tbr:       return "to-read"
            case .read:      return "read"
            }
        }
        var toast: String {
            switch self {
            case .bookshelf: return "Added to Bookshelf"
            case .tbr:       return "Added to TBR"
            case .read:      return "Marked as read"
            }
        }
    }

    /// The shelf the book currently sits on, derived from bookState.
    var currentShelf: LibraryShelf? {
        if bookState.isRead { return .read }
        if bookState.isTBR { return .tbr }
        if bookState.isOnShelf { return .bookshelf }
        return nil
    }

    /// Moves the book to `target`, or removes it when `target` is nil (tapping the
    /// current shelf again). Mark-as-read also pushes reading progress to 100%.
    func selectShelf(_ target: LibraryShelf?) async {
        guard let uname = user.username else { return }
        let prev = bookState

        switch target {
        case .none:
            bookState.isOnShelf = false; bookState.isTBR = false; bookState.isRead = false
        case .bookshelf:
            bookState.isOnShelf = true;  bookState.isTBR = false; bookState.isRead = false
        case .tbr:
            bookState.isTBR = true;      bookState.isOnShelf = false; bookState.isRead = false
        case .read:
            bookState.isRead = true;     bookState.isOnShelf = true;  bookState.isTBR = false
        }
        bookState.isLoading = true
        defer { bookState.isLoading = false }

        do {
            if let target {
                let _: Empty = try await APIClient.shared.request(
                    path: Endpoints.addToBookshelf(username: uname),
                    method: .post,
                    body: ["book_id": bookId, "status": target.status],
                    requiresAuth: true
                )
                if target == .read, let total = book?.pageCount, total > 0 {
                    await updateProgress(currentPage: total, totalPages: total)
                }
                toastMessage = target.toast
            } else {
                let _: Empty = try await APIClient.shared.request(
                    path: Endpoints.removeFromBookshelf(username: uname, bookId: bookId),
                    method: .delete,
                    requiresAuth: true
                )
                toastMessage = "Removed from library"
            }
        } catch let e as APIError {
            bookState = prev
            toastMessage = e.errorDescription
        } catch {
            bookState = prev
            toastMessage = error.localizedDescription
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
