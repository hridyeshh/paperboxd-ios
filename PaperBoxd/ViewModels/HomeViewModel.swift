import Foundation
import Combine

/// ViewModel for the Home screen that manages book data
@MainActor
class HomeViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading: Bool = false
    
<<<<<<< Updated upstream
    /// Load books from the API
=======
    /// Load books from the Mobile API (BFF Pattern)
    /// Fetches: latest + personalized recommendations (if authenticated)
>>>>>>> Stashed changes
    func loadBooks() async {
        isLoading = true
        
        do {
<<<<<<< Updated upstream
            let response = try await APIClient.shared.fetchSphereBooks()
            books = response.books
            print("✅ HomeViewModel: Successfully loaded \(books.count) books")
=======
            // 1. Fetch Latest Feed (Public) - Mobile API
            async let latestBooksTask = APIClient.shared.fetchLatestBooks(page: 1, pageSize: 50)
            
            // 2. Fetch Personalized (Authenticated) - Mobile API
            var personalizedTasks: [Task<PersonalizedBooksResponse, Error>] = []
            
            if APIClient.shared.isAuthenticated {
                // Fetch personalized recommendations in parallel:
                // - recommended (limit 20)
                // - onboarding (limit 20) 
                // - friends (limit 20)
                personalizedTasks = [
                    Task { try await APIClient.shared.fetchPersonalizedBooks(type: "recommended", limit: 20) },
                    Task { try await APIClient.shared.fetchPersonalizedBooks(type: "onboarding", limit: 20) },
                    Task { try await APIClient.shared.fetchPersonalizedBooks(type: "friends", limit: 20) }
                ]
            }
            
            // Wait for latest books
            let latestResponse = try await latestBooksTask
            
            // Wait for personalized books (if authenticated)
            var personalizedResponses: [PersonalizedBooksResponse] = []
            for task in personalizedTasks {
                do {
                    let response = try await task.value
                    personalizedResponses.append(response)
                } catch {
                    // Log error but continue - don't fail entire load if one personalized fetch fails
                    print("⚠️ HomeViewModel: Failed to fetch personalized books: \(error.localizedDescription)")
                }
            }
            
            // Combine and deduplicate books by ID
            var bookMap: [String: Book] = [:]
            
            // Add latest books first (they get priority)
            for book in latestResponse.books {
                bookMap[book.id] = book
            }
            
            // Add personalized books (won't overwrite if already exists)
            for response in personalizedResponses {
                for book in response.books {
                    if bookMap[book.id] == nil {
                        bookMap[book.id] = book
                    }
                }
            }
            
            // Convert map back to array
            books = Array(bookMap.values)
            
            // Update pagination info
            if let pagination = latestResponse.pagination {
                hasMore = pagination.page < pagination.totalPages
                currentPage = pagination.page
            }
            
            let personalizedCount = personalizedResponses.reduce(0) { $0 + $1.books.count }
            print("✅ HomeViewModel: Successfully loaded \(books.count) books (latest: \(latestResponse.books.count), personalized: \(personalizedCount))")
>>>>>>> Stashed changes
        } catch {
            print("❌ HomeViewModel: Failed to load books: \(error.localizedDescription)")
            // Optionally, you could add error handling here (e.g., show alert to user)
        }
        
        isLoading = false
    }
<<<<<<< Updated upstream
=======
    
    /// Load more books (pagination) - Mobile API
    func loadMoreBooks() async {
        guard !isLoading && hasMore else { return }
        
        isLoading = true
        
        do {
            let nextPage = currentPage + 1
            let response = try await APIClient.shared.fetchLatestBooks(page: nextPage, pageSize: 50)
            
            // Add new books, avoiding duplicates
            let existingIds = Set(books.map { $0.id })
            let newBooks = response.books.filter { !existingIds.contains($0.id) }
            books.append(contentsOf: newBooks)
            
            // Update pagination info
            if let pagination = response.pagination {
                hasMore = pagination.page < pagination.totalPages
                currentPage = pagination.page
            }
            
            print("✅ HomeViewModel: Loaded \(newBooks.count) more books (total: \(books.count))")
        } catch {
            print("❌ HomeViewModel: Failed to load more books: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
>>>>>>> Stashed changes
}

