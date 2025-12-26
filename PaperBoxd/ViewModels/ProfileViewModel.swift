import Foundation
import Combine

/// ViewModel for the Profile screen that manages user stats and library books
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Computed properties for easy access
    var favoriteBoards: [BookBoard] {
        guard let favoriteBooks = profile?.favoriteBooks, !favoriteBooks.isEmpty else {
            return []
        }
        // Group favorites into a single board
        return [BookBoard(
            title: "All Time Favs",
            bookCount: favoriteBooks.count,
            covers: extractBookCovers(from: favoriteBooks)
        )]
    }
    
    var readingListBoards: [BookBoard] {
        guard let readingLists = profile?.readingLists, !readingLists.isEmpty else {
            return []
        }
        return readingLists.map { list in
            BookBoard(
                title: list.title,
                bookCount: list.books?.count ?? 0,
                covers: extractCoversFromReadingList(list)
            )
        }
    }
    
    var bookshelfBoards: [BookBoard] {
        guard let bookshelf = profile?.bookshelf, !bookshelf.isEmpty else {
            return []
        }
        
        // Group bookshelf into categories
        var boards: [BookBoard] = []
        
        // Currently Reading
        if let currentlyReading = profile?.currentlyReading, !currentlyReading.isEmpty {
            boards.append(BookBoard(
                title: "Currently Reading",
                bookCount: currentlyReading.count,
                covers: extractBookCovers(from: currentlyReading)
            ))
        }
        
        // Want to Read (TBR)
        if let tbrBooks = profile?.tbrBooks, !tbrBooks.isEmpty {
            boards.append(BookBoard(
                title: "Want to Read",
                bookCount: tbrBooks.count,
                covers: extractBookCovers(from: tbrBooks)
            ))
        }
        
        // Completed (bookshelf with finishedDate)
        let completed = bookshelf.filter { $0.finishedDate != nil }
        if !completed.isEmpty {
            boards.append(BookBoard(
                title: "Completed",
                bookCount: completed.count,
                covers: extractBookCovers(from: completed)
            ))
        }
        
        return boards
    }
    
    var likedBoards: [BookBoard] {
        guard let likedBooks = profile?.likedBooks, !likedBooks.isEmpty else {
            return []
        }
        // Group liked books into a single board
        return [BookBoard(
            title: "Liked Books",
            bookCount: likedBooks.count,
            covers: extractBookCovers(from: likedBooks)
        )]
    }
    
    var dnfBoards: [BookBoard] {
        // DNF books are in bookshelf with a specific reason or status
        // Check for books with "DNF" in thoughts or a specific reason field
        guard let bookshelf = profile?.bookshelf, !bookshelf.isEmpty else {
            return []
        }
        
        // Filter bookshelf for DNF books (check thoughts/reason fields)
        let dnfBooks = bookshelf.filter { book in
            // Check if thoughts contain "DNF" or if there's a reason field indicating DNF
            if let thoughts = book.thoughts?.lowercased() {
                return thoughts.contains("dnf") || thoughts.contains("did not finish")
            }
            // Could also check for a specific reason field if it exists
            return false
        }
        
        if dnfBooks.isEmpty {
            return []
        }
        
        return [BookBoard(
            title: "Did Not Finish",
            bookCount: dnfBooks.count,
            covers: extractBookCovers(from: dnfBooks)
        )]
    }
    
    /// Load user profile from the API
    /// - Parameter username: The username to fetch (if nil, will fetch current user's profile)
    func loadProfile(username: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: UserProfileResponse
            
            if let username = username {
                // Fetch specific user's profile
                print("📖 ProfileViewModel: Fetching profile for username: \(username)")
                response = try await APIClient.shared.fetchUserProfile(username: username)
            } else {
                // Fetch current user's profile
                print("📖 ProfileViewModel: Fetching current user's profile")
                response = try await APIClient.shared.fetchCurrentUserProfile()
            }
            
            profile = response.user
            print("✅ ProfileViewModel: Successfully loaded profile for \(response.user.username ?? "unknown")")
        } catch let error as APIError {
            print("❌ ProfileViewModel: API Error - \(error.localizedDescription)")
            switch error {
            case .httpError(let statusCode):
                if statusCode == 404 {
                    errorMessage = "User not found"
                } else if statusCode == 401 {
                    errorMessage = "Please log in again"
                } else {
                    errorMessage = "Failed to load profile (Error \(statusCode))"
                }
            case .invalidResponse:
                errorMessage = "Invalid response from server"
            case .decodingError(let decodingError):
                print("❌ ProfileViewModel: Decoding error details: \(decodingError.localizedDescription)")
                errorMessage = "Failed to parse profile data"
            default:
                errorMessage = "Failed to load profile"
            }
        } catch {
            print("❌ ProfileViewModel: Unexpected error - \(error.localizedDescription)")
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Helper Methods
    
    private func extractBookCovers(from references: [BookReference]) -> [String] {
        // TODO: These only have bookId - we need to fetch book details to get covers
        // For now, return empty - this requires either:
        // 1. API enhancement to include book details in the profile response
        // 2. Batch fetching book details for all bookIds
        // The web version likely populates these on the backend
        return []
    }
    
    private func extractBookCovers(from bookshelf: [BookshelfBook]) -> [String] {
        // TODO: Same as above - need book details to get covers
        return []
    }
    
    private func extractBookCovers(from tbrBooks: [TbrBook]) -> [String] {
        // TODO: Same as above
        return []
    }
    
    private func extractBookCovers(from likedBooks: [LikedBook]) -> [String] {
        // TODO: Same as above - need book details to get covers
        return []
    }
    
    private func extractCoversFromReadingList(_ list: ReadingList) -> [String] {
        guard let books = list.books else { return [] }
        var covers: [String] = []
        for book in books {
            if let volumeInfo = book.volumeInfo,
               let imageLinks = volumeInfo.imageLinks {
                if let thumbnail = imageLinks.thumbnail {
                    covers.append(thumbnail)
                } else if let smallThumbnail = imageLinks.smallThumbnail {
                    covers.append(smallThumbnail)
                } else if let medium = imageLinks.medium {
                    covers.append(medium)
                } else if let large = imageLinks.large {
                    covers.append(large)
                }
            }
        }
        return covers
    }
}

/// Profile statistics model
struct ProfileStats {
    var readCount: Int = 0
    var pagesCount: Int = 0
    var dnfCount: Int = 0
}

