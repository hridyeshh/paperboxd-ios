import Combine
import Foundation

@MainActor
final class WriteViewModel: ObservableObject {
    @Published var content = ""
    @Published var selectedBook: Book?
    @Published var rating: Int?
    @Published var readingDate = Date()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var didSubmit = false

    @Published var bookSearchQuery = ""
    @Published var bookSearchResults: [Book] = []
    @Published var isSearchingBooks = false

    let username: String
    private var searchTask: Task<Void, Never>?

    var canSubmit: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 && !isLoading
    }

    var charCount: Int {
        content.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    init(preselectedBook: Book? = nil, username: String) {
        self.username = username
        self.selectedBook = preselectedBook
    }

    func onSearchChange() {
        let q = bookSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTask?.cancel()
        guard !q.isEmpty else { bookSearchResults = []; return }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(q)
        }
    }

    private func performSearch(_ q: String) async {
        isSearchingBooks = true
        defer { isSearchingBooks = false }
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        let resp: BookSearchResponse? = try? await APIClient.shared.request(
            path: Endpoints.searchBooks + "?q=\(encoded)&page_size=8",
            method: .get,
            requiresAuth: false
        )
        guard !Task.isCancelled else { return }
        bookSearchResults = resp?.books ?? []
    }

    func submit() async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime]
        let body = DiaryCreateBody(
            bookID: selectedBook?.id,
            content: trimmed,
            rating: rating,
            readingDate: df.string(from: readingDate)
        )
        do {
            let entry: DiaryEntry = try await APIClient.shared.request(
                path: Endpoints.userDiary(username: username),
                method: .post,
                body: body,
                requiresAuth: true
            )
            NotificationCenter.default.post(name: .diaryEntryCreated, object: entry)
            didSubmit = true
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct DiaryCreateBody: Encodable {
    let bookID: String?
    let content: String
    let rating: Int?
    let readingDate: String

    enum CodingKeys: String, CodingKey {
        case bookID = "book_id"
        case content, rating
        case readingDate = "reading_date"
    }
}

private struct BookSearchResponse: Decodable {
    let books: [Book]
}
