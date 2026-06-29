import Combine
import Foundation

@MainActor
final class DiaryViewModel: ObservableObject {
    @Published var entries: [DiaryEntry] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var page = 1
    private var hasMore = true
    private var isLoadingMore = false

    let user: User

    init(user: User, loadOnInit: Bool = true) {
        self.user = user
        if loadOnInit {
            Task { await load() }
        }
    }

    func load() async {
        guard let username = user.username else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        page = 1
        hasMore = true
        entries = []
        do {
            let resp: DiaryEntriesResponse = try await APIClient.shared.request(
                path: Endpoints.userDiary(username: username) + "?page=1&page_size=20",
                method: .get,
                requiresAuth: true
            )
            entries = resp.entries
            page = 2
            hasMore = resp.entries.count == 20
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMoreIfNeeded(item: DiaryEntry) async {
        guard let last = entries.last, last.id == item.id,
              hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        guard let username = user.username else { return }
        do {
            let resp: DiaryEntriesResponse = try await APIClient.shared.request(
                path: Endpoints.userDiary(username: username) + "?page=\(page)&page_size=20",
                method: .get,
                requiresAuth: true
            )
            entries += resp.entries
            page += 1
            hasMore = resp.entries.count == 20
        } catch {}
    }

    func refresh() async { await load() }

    func handleNewEntry(_ entry: DiaryEntry) {
        entries.insert(entry, at: 0)
    }

    func handleDeletedEntry(_ id: String) {
        entries.removeAll { $0.id == id }
    }
}
