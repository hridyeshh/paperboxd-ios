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
        // Limit to max 4 favorites as per requirement
        let limitedFavorites = Array(favoriteBooks.prefix(4))
        // Group favorites into a single board
        return [BookBoard(
            title: "All Time Favs",
            bookCount: limitedFavorites.count,
            covers: extractBookCovers(from: limitedFavorites)
        )]
    }
    
    // Favorites as books (for collection view)
    var favoriteBooksList: [BookReference] {
        guard let favoriteBooks = profile?.favoriteBooks, !favoriteBooks.isEmpty else {
            return []
        }
        // Limit to max 4 favorites as per requirement
        return Array(favoriteBooks.prefix(4))
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
        // Bookshelf should show as a collection, not boards
        // This is kept for backward compatibility but won't be used
        return []
    }
    
    // Bookshelf as books (for collection view)
    var bookshelfBooksList: [BookshelfBook] {
        guard let bookshelf = profile?.bookshelf, !bookshelf.isEmpty else {
            return []
        }
        // Sort by finishedDate (newest first) like web version
        return bookshelf.sorted { (a, b) -> Bool in
            guard let dateA = a.finishedDate, let dateB = b.finishedDate else {
                // If one has no date, prioritize the one with date
                if a.finishedDate != nil { return true }
                if b.finishedDate != nil { return false }
                return false
            }
            return dateA > dateB // Newest first
        }
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
        // DNF should show as a collection, not boards
        // This is kept for backward compatibility but won't be used
        return []
    }
    
    // DNF as books (for collection view)
    var dnfBooksList: [BookshelfBook] {
        // Use the dedicated dnfBooks field from API (more efficient than filtering)
        guard let dnfBooks = profile?.dnfBooks, !dnfBooks.isEmpty else {
            return []
        }
        return dnfBooks
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
        // Now that backend populates book details, we can extract covers directly
        return references.compactMap { $0.cover }
    }
    
    private func extractBookCovers(from bookshelf: [BookshelfBook]) -> [String] {
        // Now that backend populates book details, we can extract covers directly
        return bookshelf.compactMap { $0.cover }
    }
    
    private func extractBookCovers(from tbrBooks: [TbrBook]) -> [String] {
        // TBR books don't have populated covers yet, but keeping for future
        return []
    }
    
    private func extractBookCovers(from likedBooks: [LikedBook]) -> [String] {
        // Liked books don't have populated covers yet, but keeping for future
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

