import Foundation

/// Possible read states for a book on the user's shelf.
enum BookshelfStatus: String {
    case read = "read"
    case reading = "reading"
    case toRead = "to-read"
}

/// The user's current relationship with a specific book.
/// Initialized from GET .../bookshelf/{bookId}/status; updated optimistically on action.
struct UserBookState {
    var isRead: Bool = false
    var isLiked: Bool = false
    var isTBR: Bool = false
    var isLoading: Bool = false
}

/// Response from GET /api/v1/users/{username}/bookshelf/{bookId}/status
struct BookStatusResponse: Decodable {
    let isRead: Bool
    let isLiked: Bool
    let isTBR: Bool
}
