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
extension PreviewData {
    /// A month of Wrapped, decoded from the exact JSON the backend sends so a
    /// drift between `Wrapped`'s CodingKeys and GET /users/me/wrapped shows up
    /// here as a failed preview rather than as an empty story on a device.
    static let wrapped: Wrapped = {
        let json = """
        {
          "has_data": true,
          "month": "August", "month_short": "AUG", "year": "2026", "next_month": "September",
          "reader": { "name": "Hridyesh Pillai", "handle": "@hridyesh", "first": "Hridyesh" },
          "totals": {
            "books": 9, "pages": 2847, "estimated_hours": 71, "estimated_minutes": 10,
            "sessions": 68, "active_days": 26, "biggest_day_pages": 142, "biggest_day": "Aug 17"
          },
          "books": [
            { "title": "Norwegian Wood", "author": "Haruki Murakami", "cover": "", "pages": 389, "days": 6, "rating": 4 },
            { "title": "The Vegetarian", "author": "Han Kang", "cover": "", "pages": 188, "days": 2, "rating": 5 },
            { "title": "Convenience Store Woman", "author": "Sayaka Murata", "cover": "", "pages": 163, "days": 2, "rating": 4 },
            { "title": "Kitchen", "author": "Banana Yoshimoto", "cover": "", "pages": 152, "days": 3, "rating": 4 },
            { "title": "Tokyo Ueno Station", "author": "Miri Yu", "cover": "", "pages": 180, "days": 4, "rating": 3 }
          ],
          "authors": [
            { "name": "Haruki Murakami", "books": 3, "pages": 921, "note": "3 books this month." },
            { "name": "Han Kang", "books": 2, "pages": 372 },
            { "name": "Sayaka Murata", "books": 1, "pages": 163 },
            { "name": "Banana Yoshimoto", "books": 1, "pages": 152 },
            { "name": "Miri Yu", "books": 1, "pages": 180 }
          ],
          "genres": [
            { "name": "Translated Fiction", "pct": 41 },
            { "name": "Literary Fiction", "pct": 28 },
            { "name": "Magical Realism", "pct": 17 },
            { "name": "Essays", "pct": 9 },
            { "name": "Poetry", "pct": 5 }
          ],
          "rhythm": {
            "label": "Night Owl", "peak": "11PM — 1AM", "pct_after_midnight": 62,
            "line": "You read when the rest of the house had given up.",
            "hours": [42,18,6,2,0,0,0,4,12,8,6,10,14,9,7,11,16,22,31,38,52,74,96,88]
          },
          "streak": {
            "days": 23, "start": "Aug 2", "end": "Aug 24", "broke": "Aug 25", "longest_ever": 31,
            "calendar": [0,62,88,41,120,96,74,55,132,108,91,47,86,119,73,64,142,97,58,111,84,69,127,93,0,0,76,104,61,88,115],
            "streak_start": 1, "streak_end": 23, "broke_index": 24
          },
          "top_rated": {
            "title": "The Vegetarian", "author": "Han Kang", "cover": "", "rating": 5, "date": "Aug 11",
            "review": "Finished it on the balcony at 1am and just sat there. I have no notes, only a small hole where my appetite used to be."
          },
          "abandoned": {
            "title": "A Little Life", "author": "Hanya Yanagihara", "page": 84, "of": 814,
            "started": "Aug 6", "last_opened": "Aug 9",
            "roast": "You left it on page 84. It is still waiting, and it has 730 pages of things to tell you."
          },
          "rank": {
            "percentile": 3, "label": "Top 3%", "readers": 1204, "beat": 97,
            "line": "You out-read 97 out of every 100 people on PaperBoxd this month."
          },
          "archetype": {
            "name": "The Midnight Romantic", "kicker": "Your August type",
            "definition": "Reads for feeling, not for finishing. Will stay up for one more chapter and then three more.",
            "traits": ["Nocturnal", "One more chapter", "Slow, then all at once"],
            "stat_label": "AFTER DARK", "stat_value": "62%", "pairs": "The Early Riser"
          },
          "dare": {
            "title": "Finish what you started.",
            "body": "A Little Life is sitting on page 84 with 730 pages left. September dares you to close it properly.",
            "target": "1 book", "tag": "THE SEPTEMBER DARE"
          }
        }
        """
        return try! JSONDecoder().decode(Wrapped.self, from: Data(json.utf8))
    }()
}
#endif
