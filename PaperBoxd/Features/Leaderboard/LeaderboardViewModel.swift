import Combine
import Foundation

enum LeaderboardTab: String, CaseIterable, Identifiable {
    case global, books, pages, streak, diary, friends

    var id: String { rawValue }

    var label: String {
        switch self {
        case .global:  return "All-time"
        case .books:   return "Books"
        case .pages:   return "Pages"
        case .streak:  return "Streak"
        case .diary:   return "Diary"
        case .friends: return "Friends"
        }
    }

    /// Backend dimension for the dimension endpoint, or nil when the tab maps
    /// to a dedicated route (global / friends).
    var dimension: String? {
        switch self {
        case .global, .friends: return nil
        case .books:  return "books"
        case .pages:  return "pages"
        case .streak: return "streak"
        case .diary:  return "diary"
        }
    }

    var unit: String {
        switch self {
        case .global:  return "XP"
        case .books:   return "books"
        case .pages:   return "pages"
        case .streak:  return "day streak"
        case .diary:   return "entries"
        case .friends: return "XP"
        }
    }

    func value(_ e: LeaderboardEntry) -> Int {
        switch self {
        case .global, .friends: return e.totalXP
        case .books:  return e.booksRead
        case .pages:  return e.pagesRead
        case .streak: return e.currentStreak
        case .diary:  return e.diaryEntries
        }
    }

    func rank(_ e: LeaderboardEntry) -> Int? {
        switch self {
        case .global, .friends: return e.xpRank
        case .books:  return e.booksRank
        case .pages:  return e.pagesRank
        case .streak: return e.streakRank
        case .diary:  return e.diaryRank
        }
    }
}

@MainActor
final class LeaderboardViewModel: ObservableObject {
    @Published var tab: LeaderboardTab = .global {
        didSet { if oldValue != tab { Task { await loadEntries() } } }
    }
    @Published var entries: [LeaderboardEntry] = []
    @Published var myStats: LeaderboardEntry?
    @Published var isLoading = true
    @Published var errorMessage: String?

    let viewer: User

    init(viewer: User, loadOnInit: Bool = true) {
        self.viewer = viewer
        if loadOnInit {
            Task {
                await loadMyStats()
                await loadEntries()
            }
        }
    }

    func loadEntries() async {
        isLoading = true
        errorMessage = nil
        let path: String
        switch tab {
        case .global:  path = Endpoints.globalLeaderboard
        case .friends: path = Endpoints.friendsLeaderboard
        default:       path = Endpoints.leaderboardDimension(tab.dimension ?? "xp")
        }
        do {
            let resp: LeaderboardResponse = try await APIClient.shared.request(
                path: path, method: .get, requiresAuth: true
            )
            entries = resp.leaderboard
        } catch is CancellationError {
            // Refresh task was torn down (pull-to-refresh gesture ended). Keep the
            // existing list and don't surface an error — avoids the swap-out loop
            // where clearing entries destroys the ScrollView mid-refresh.
        } catch let e as APIError {
            errorMessage = e.errorDescription
            entries = []
        } catch {
            errorMessage = error.localizedDescription
            entries = []
        }
        isLoading = false
    }

    func loadMyStats() async {
        myStats = try? await APIClient.shared.request(
            path: Endpoints.myLeaderboardStats, method: .get, requiresAuth: true
        )
        // Level lives on the leaderboard stats payload — this is where a
        // level-up becomes visible to the client.
        CelebrationCenter.shared.checkLevel(myStats?.level)
    }

    func refresh() async {
        await loadMyStats()
        await loadEntries()
    }

    var myRank: Int? { myStats.flatMap { tab.rank($0) } }
}
