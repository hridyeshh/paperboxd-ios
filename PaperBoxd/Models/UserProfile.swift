import Foundation

// MARK: - UserProfileResponse

struct UserProfileResponse: Codable {
    let user: UserProfile
}

// MARK: - UserProfile

struct UserProfile: Codable {
    let id: String
    let username: String?
    let name: String?
    let email: String?
    let avatar: String?
    let bio: String?
    let birthday: String?
    let gender: String?
    let pronouns: [String]?
    let links: [String]?
    let isPublic: Bool?
    
    // Books & Reading
    let topBooks: [BookReference]?
    let favoriteBooks: [BookReference]?
    let bookshelf: [BookshelfBook]?
    let likedBooks: [LikedBook]?
    let tbrBooks: [TbrBook]?
    let currentlyReading: [BookReference]?
    let readingLists: [ReadingList]?
    
    // Statistics
    let totalBooksRead: Int?
    let totalPagesRead: Int?
    let followers: [String]?
    let following: [String]?
}

// MARK: - BookReference

struct BookReference: Codable {
    let bookId: String?
    let rating: Double?
}

// MARK: - BookshelfBook

struct BookshelfBook: Codable {
    let bookId: String?
    let rating: Double?
    let thoughts: String?
    let finishedDate: String?
}

// MARK: - LikedBook

struct LikedBook: Codable {
    let bookId: String?
    let likedAt: String?
}

// MARK: - TbrBook

struct TbrBook: Codable {
    let bookId: String?
    let urgency: String?
    let addedAt: String?
}

// MARK: - ReadingList

struct ReadingList: Codable {
    let _id: String?
    let title: String
    let description: String?
    let books: [ReadingListBook]?
    let isPublic: Bool?
    let createdAt: String?
    let updatedAt: String?
}

struct ReadingListBook: Codable {
    let _id: String?
    let volumeInfo: ReadingListVolumeInfo?
}

struct ReadingListVolumeInfo: Codable {
    let title: String?
    let authors: [String]?
    let imageLinks: ReadingListImageLinks?
}

struct ReadingListImageLinks: Codable {
    let thumbnail: String?
    let smallThumbnail: String?
    let medium: String?
    let large: String?
}

