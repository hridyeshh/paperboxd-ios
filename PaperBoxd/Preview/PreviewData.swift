#if DEBUG
import Foundation
import UIKit

enum PreviewData {
    static let user = User(
        id: "preview-user",
        username: "hridyesh",
        email: "hridyesh@paperboxd.app",
        avatarURL: nil,
        level: 3,
        xp: 420,
        onboardingCompleted: true
    )

    static let otherViewer = User(
        id: "preview-viewer",
        username: "hridyesh",
        email: "hridyesh@paperboxd.app",
        avatarURL: nil,
        level: 3,
        xp: 420,
        onboardingCompleted: true
    )

    static let profile = UserProfile(
        id: "preview-profile",
        username: "hridyesh",
        name: "Hridyesh Pillai",
        avatarURL: nil,
        bannerURL: nil,
        bio: "Slow reader. Long letters. Fiction that wanders. Probably re-reading Norwegian Wood when you read this.",
        pronouns: ["he", "him"],
        birthday: "1998-09-15",
        gender: "Male",
        links: ["https://hridyesh.com"],
        isPublic: true,
        booksReadCount: 87,
        totalPagesRead: 12_400,
        favoritesCount: 4,
        listsCount: 5,
        diaryEntriesCount: 23,
        followersCount: 142,
        followingCount: 89,
        favoriteGenres: ["Literary Fiction"],
        createdAt: "2024-01-15T00:00:00Z",
        isFollowing: nil
    )

    static let otherProfile = UserProfile(
        id: "preview-other-profile",
        username: "anais",
        name: "Anaïs Bouchard",
        avatarURL: nil,
        bannerURL: nil,
        bio: "Translator by day, slow reader by night. French fiction, post-colonial voices, and the occasional thriller for the metro.",
        pronouns: ["she", "her"],
        birthday: "1991-04-22",
        gender: "Female",
        links: ["https://anais.fr"],
        isPublic: true,
        booksReadCount: 248,
        totalPagesRead: 48_000,
        favoritesCount: 4,
        listsCount: 14,
        diaryEntriesCount: 64,
        followersCount: 311,
        followingCount: 180,
        favoriteGenres: ["Fiction"],
        createdAt: "2022-03-10T00:00:00Z",
        isFollowing: false
    )

    static let lastLoggedBook = LastLoggedBook(
        bookID: "book-norwegian-wood",
        title: "Norwegian Wood",
        slug: "norwegian-wood-haruki-murakami",
        author: "Haruki Murakami",
        cover: "",
        currentPage: 142,
        totalPages: 389
    )

    static var favorites: [FavoriteBook] {
        [
            favorite(title: "Norwegian Wood", order: 0, note: "loved 2023"),
            favorite(title: "Kafka on the Shore", order: 1),
            favorite(title: "The Wind-Up Bird Chronicle", order: 2),
            favorite(title: "1Q84", order: 3, note: "reread 3×"),
        ]
    }

    static var shelfBooks: [BookWithStatus] {
        [
            shelfBook(title: "Norwegian Wood"),
            shelfBook(title: "Beloved"),
            shelfBook(title: "Pachinko"),
            shelfBook(title: "The God of Small Things"),
            shelfBook(title: "Normal People"),
            shelfBook(title: "A Little Life"),
        ]
    }

    static var diaryEntries: [DiaryEntry] {
        [
            DiaryEntry(
                id: "diary-1",
                userID: profile.id,
                username: profile.username,
                name: profile.name,
                avatarURL: nil,
                bookID: "book-norwegian-wood",
                book: book(title: "Norwegian Wood"),
                title: "Rain and vinyl",
                content: "Finished the middle third tonight. The dorm scenes feel different on a second read.",
                isPrivate: false,
                rating: 5,
                likesCount: 12,
                isLiked: false,
                canEdit: true,
                createdAt: "2026-05-28T20:00:00Z",
                updatedAt: "2026-05-28T20:00:00Z"
            )
        ]
    }

    static var ownLists: [ReadingList] {
        [
            ReadingList(
                id: "list-1",
                userID: profile.id,
                username: profile.username,
                title: "kafka",
                description: "Kafka rabbit hole",
                isPrivate: false,
                bookCount: 8,
                saveCount: 3,
                isSaved: false,
                canEdit: true,
                canView: true,
                coverURLs: [],
                createdAt: "2025-01-01T00:00:00Z",
                updatedAt: "2025-05-01T00:00:00Z"
            )
        ]
    }

    static var recommendations: [RecommendationItem] {
        [
            RecommendationItem(
                id: "rec-1",
                title: "The Amazing Spider-Man",
                authors: ["Stan Lee"],
                coverURL: nil,
                categories: ["Comics"],
                similarityScore: 0.82,
                reason: "Because you shelved Marvel",
                reasonType: "genre"
            ),
            RecommendationItem(
                id: "rec-2",
                title: "Incredible Hulk",
                authors: ["Stan Lee"],
                coverURL: nil,
                categories: ["Comics"],
                similarityScore: 0.79,
                reason: "Popular on your shelf",
                reasonType: "social"
            ),
            RecommendationItem(
                id: "rec-3",
                title: "Daredevil",
                authors: ["Frank Miller"],
                coverURL: nil,
                categories: ["Comics"],
                similarityScore: 0.75,
                reason: "Similar pacing",
                reasonType: "vibe"
            ),
        ]
    }

    static var friendActivities: [FriendActivity] {
        [
            FriendActivity(
                id: "act-1",
                userID: "friend-1",
                username: "irishcoffee_",
                name: "Irish Coffee",
                avatarURL: nil,
                activityType: "book_tbr",
                bookID: "book-housemaid",
                bookTitle: "The Housemaid's Wedding",
                bookSlug: "the-housemaids-wedding",
                listID: nil,
                listTitle: nil,
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3_600))
            )
        ]
    }

    static var todayProgress: TodayProgress {
        decode("""
        {
          "today_pages": 61,
          "today_books": 1,
          "last_book": {
            "book_id": "book-norwegian-wood",
            "title": "Norwegian Wood",
            "slug": "norwegian-wood",
            "author": "Haruki Murakami",
            "cover": "",
            "current_page": 142,
            "total_pages": 389
          },
          "week_bars": [
            {"date": "2026-05-24", "pages": 0, "books": 0},
            {"date": "2026-05-25", "pages": 40, "books": 1},
            {"date": "2026-05-26", "pages": 22, "books": 1},
            {"date": "2026-05-27", "pages": 0, "books": 0},
            {"date": "2026-05-28", "pages": 55, "books": 1},
            {"date": "2026-05-29", "pages": 18, "books": 1},
            {"date": "2026-05-30", "pages": 61, "books": 1}
          ]
        }
        """)
    }

    static var currentlyReading: CurrentlyReading {
        CurrentlyReading(
            id: "cr-1",
            bookID: "book-norwegian-wood",
            book: book(title: "Norwegian Wood"),
            status: "reading",
            currentPage: 142,
            progressPercentage: 36.5,
            pagesRemaining: 247,
            startedAt: "2026-05-27T00:00:00Z",
            createdAt: "2026-05-27T00:00:00Z",
            updatedAt: "2026-05-30T00:00:00Z"
        )
    }

    static var leaderboardEntries: [LeaderboardEntry] {
        let names = ["mira", "theo", "saoirse", "jules", "akira", "priya", "hridyesh", "lucas", "femi"]
        let levels = ["Sage", "Sage", "Sage", "Scholar", "Scholar", "Scholar", "Scholar", "Scholar", "Scholar"]
        let xps = [48280, 46115, 43890, 41204, 39667, 38420, 36905, 35740, 34188]
        let books = [184, 172, 159, 148, 142, 138, 131, 128, 124]
        let streaks = [127, 91, 215, 82, 64, 103, 48, 71, 55]
        let objs: [[String: Any]] = names.enumerated().map { i, name in
            [
                "user_id": "user-\(name)",
                "username": name,
                "books_read": books[i],
                "pages_read": books[i] * 280,
                "diary_entries": 20 + i,
                "genres_explored": 8 + i,
                "total_xp": xps[i],
                "level": 4,
                "current_streak": streaks[i],
                "xp_rank": i + 1,
                "books_rank": i + 1,
                "pages_rank": i + 1,
                "diary_rank": i + 1,
                "genres_rank": i + 1,
                "streak_rank": i + 1,
                "level_name": levels[i],
                "level_badge": "",
            ]
        }
        let data = try! JSONSerialization.data(withJSONObject: objs)
        return try! JSONDecoder().decode([LeaderboardEntry].self, from: data)
    }

    static func book(title: String, id: String? = nil) -> Book {
        Book(
            id: id ?? "book-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))",
            slug: title.lowercased().replacingOccurrences(of: " ", with: "-"),
            volumeInfo: volumeInfo(title: title),
            paperboxdStats: Book.PaperboxdStats(
                rating: 4.2,
                ratingsCount: 120,
                totalReads: 340,
                totalLikes: 88,
                totalTBR: 45
            ),
            googleBooksId: nil,
            apiSource: "paperboxd"
        )
    }

    private static func volumeInfo(title: String, authors: [String] = ["Haruki Murakami"]) -> Book.VolumeInfo {
        Book.VolumeInfo(
            title: title,
            authors: authors,
            publishedDate: "2000",
            description: "A preview description for \(title).",
            pageCount: 389,
            categories: ["Fiction"],
            imageLinks: nil,
            averageRating: 4.1,
            publisher: "Vintage",
            language: "en"
        )
    }

    private static func favorite(title: String, order: Int, note: String? = nil) -> FavoriteBook {
        FavoriteBook(
            id: "fav-\(order)",
            bookID: "book-\(order)",
            displayOrder: order,
            note: note,
            book: book(title: title, id: "book-\(order)"),
            createdAt: "2025-01-01T00:00:00Z"
        )
    }

    private static func shelfBook(title: String) -> BookWithStatus {
        BookWithStatus(
            id: "shelf-\(title)",
            volumeInfo: volumeInfo(title: title),
            paperboxdStats: nil,
            googleBooksId: nil,
            slug: title.lowercased().replacingOccurrences(of: " ", with: "-"),
            status: "read",
            rating: 4,
            finishedAt: "2025-12-01T00:00:00Z",
            addedAt: "2025-11-01T00:00:00Z"
        )
    }

    private static func decode<T: Decodable>(_ json: String) -> T {
        try! JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}

extension ProfileViewModel {
    static func preview(isOwn: Bool = true) -> ProfileViewModel {
        let viewer = PreviewData.user
        let username = isOwn ? PreviewData.profile.username : PreviewData.otherProfile.username
        let vm = ProfileViewModel(username: username, viewer: viewer, loadOnInit: false)
        vm.profile = isOwn ? PreviewData.profile : PreviewData.otherProfile
        vm.isLoading = false
        vm.streak = isOwn ? 12 : 28
        vm.lastLoggedBook = PreviewData.lastLoggedBook
        vm.favoriteBooks = PreviewData.favorites
        vm.shelfBooks = PreviewData.shelfBooks
        vm.diaryEntries = PreviewData.diaryEntries
        vm.ownLists = PreviewData.ownLists
        vm.savedLists = []
        return vm
    }
}

extension HomeViewModel {
    static func preview() -> HomeViewModel {
        let vm = HomeViewModel(user: PreviewData.user, loadOnInit: false)
        vm.isLoading = false
        vm.recommendations = PreviewData.recommendations
        vm.lastLoggedBook = PreviewData.lastLoggedBook
        vm.friendsActivities = PreviewData.friendActivities
        return vm
    }
}

extension BookDetailViewModel {
    static func preview() -> BookDetailViewModel {
        let vm = BookDetailViewModel(bookId: "book-norwegian-wood", user: PreviewData.user, loadOnInit: false)
        vm.isLoading = false
        vm.book = PreviewData.book(title: "Norwegian Wood", id: "book-norwegian-wood")
        vm.similarBooks = PreviewData.recommendations
        return vm
    }
}

extension LeaderboardViewModel {
    static func preview() -> LeaderboardViewModel {
        let vm = LeaderboardViewModel(viewer: PreviewData.user, loadOnInit: false)
        vm.isLoading = false
        vm.entries = PreviewData.leaderboardEntries
        vm.myStats = PreviewData.leaderboardEntries.first { $0.username == "hridyesh" }
        return vm
    }
}

extension SearchViewModel {
    static func preview() -> SearchViewModel {
        let vm = SearchViewModel()
        vm.query = "murakami"
        vm.books = [PreviewData.book(title: "Norwegian Wood"), PreviewData.book(title: "Kafka on the Shore")]
        vm.users = [PreviewData.otherProfile]
        return vm
    }
}
#endif
