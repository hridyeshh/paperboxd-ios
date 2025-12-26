import Foundation

/// Model for a Pinterest-style book board
struct BookBoard: Identifiable {
    let id = UUID()
    let title: String
    let bookCount: Int
    let covers: [String] // Array of image URLs
}

