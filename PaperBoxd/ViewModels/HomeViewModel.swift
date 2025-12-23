import Foundation
import Combine

/// ViewModel for the Home screen that manages book data
@MainActor
class HomeViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading: Bool = false
    
    /// Load books from the API
    func loadBooks() async {
        isLoading = true
        
        do {
            let response = try await APIClient.shared.fetchSphereBooks()
            books = response.books
            print("✅ HomeViewModel: Successfully loaded \(books.count) books")
        } catch {
            print("❌ HomeViewModel: Failed to load books: \(error.localizedDescription)")
            // Optionally, you could add error handling here (e.g., show alert to user)
        }
        
        isLoading = false
    }
}

