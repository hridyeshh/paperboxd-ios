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
    let dnfBooks: [BookshelfBook]? // DNF books (separate from bookshelf for easy access)
    let likedBooks: [LikedBook]?
    let tbrBooks: [TbrBook]?
    let currentlyReading: [BookReference]?
    let readingLists: [ReadingList]?
    let diaryEntries: [DiaryEntry]?
    
    // Statistics
    let totalBooksRead: Int?
    let totalPagesRead: Int?
    let followers: [String]?
    let following: [String]?
    
    // CodingKeys to handle both 'id' (from API) and '_id' (from MongoDB) if needed
    // Mobile API returns 'id', but this ensures compatibility if backend ever returns '_id'
    enum CodingKeys: String, CodingKey {
        case id
        case _id  // Support MongoDB's _id format as fallback
        case username, name, email, avatar, bio, birthday, gender, pronouns, links
        case isPublic = "isPublic"
        case topBooks, favoriteBooks, bookshelf, dnfBooks, likedBooks, tbrBooks, currentlyReading, readingLists, diaryEntries
        case totalBooksRead, totalPagesRead, followers, following
    }
    
    // Custom decoder to handle both 'id' and '_id'
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try 'id' first (API format), fall back to '_id' (MongoDB format)
        if let idValue = try? container.decode(String.self, forKey: .id) {
            id = idValue
        } else if let idValue = try? container.decode(String.self, forKey: ._id) {
            id = idValue
        } else {
            throw DecodingError.keyNotFound(CodingKeys.id, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Neither 'id' nor '_id' found in UserProfile"))
        }
        
        username = try? container.decode(String.self, forKey: .username)
        name = try? container.decode(String.self, forKey: .name)
        email = try? container.decode(String.self, forKey: .email)
        avatar = try? container.decode(String.self, forKey: .avatar)
        bio = try? container.decode(String.self, forKey: .bio)
        birthday = try? container.decode(String.self, forKey: .birthday)
        gender = try? container.decode(String.self, forKey: .gender)
        pronouns = try? container.decode([String].self, forKey: .pronouns)
        links = try? container.decode([String].self, forKey: .links)
        isPublic = try? container.decode(Bool.self, forKey: .isPublic)
        
        topBooks = try? container.decode([BookReference].self, forKey: .topBooks)
        favoriteBooks = try? container.decode([BookReference].self, forKey: .favoriteBooks)
        bookshelf = try? container.decode([BookshelfBook].self, forKey: .bookshelf)
        dnfBooks = try? container.decode([BookshelfBook].self, forKey: .dnfBooks)
        likedBooks = try? container.decode([LikedBook].self, forKey: .likedBooks)
        tbrBooks = try? container.decode([TbrBook].self, forKey: .tbrBooks)
        currentlyReading = try? container.decode([BookReference].self, forKey: .currentlyReading)
        readingLists = try? container.decode([ReadingList].self, forKey: .readingLists)
        diaryEntries = try? container.decode([DiaryEntry].self, forKey: .diaryEntries)
        
        totalBooksRead = try? container.decode(Int.self, forKey: .totalBooksRead)
        totalPagesRead = try? container.decode(Int.self, forKey: .totalPagesRead)
        followers = try? container.decode([String].self, forKey: .followers)
        following = try? container.decode([String].self, forKey: .following)
    }
    
    // Custom encoder to ensure 'id' is encoded (not '_id')
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id) // Always encode as 'id', not '_id'
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(avatar, forKey: .avatar)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(birthday, forKey: .birthday)
        try container.encodeIfPresent(gender, forKey: .gender)
        try container.encodeIfPresent(pronouns, forKey: .pronouns)
        try container.encodeIfPresent(links, forKey: .links)
        try container.encodeIfPresent(isPublic, forKey: .isPublic)
        try container.encodeIfPresent(topBooks, forKey: .topBooks)
        try container.encodeIfPresent(favoriteBooks, forKey: .favoriteBooks)
        try container.encodeIfPresent(bookshelf, forKey: .bookshelf)
        try container.encodeIfPresent(dnfBooks, forKey: .dnfBooks)
        try container.encodeIfPresent(likedBooks, forKey: .likedBooks)
        try container.encodeIfPresent(tbrBooks, forKey: .tbrBooks)
        try container.encodeIfPresent(currentlyReading, forKey: .currentlyReading)
        try container.encodeIfPresent(readingLists, forKey: .readingLists)
        try container.encodeIfPresent(diaryEntries, forKey: .diaryEntries)
        try container.encodeIfPresent(totalBooksRead, forKey: .totalBooksRead)
        try container.encodeIfPresent(totalPagesRead, forKey: .totalPagesRead)
        try container.encodeIfPresent(followers, forKey: .followers)
        try container.encodeIfPresent(following, forKey: .following)
    }
}

// MARK: - BookReference

struct BookReference: Codable {
    let bookId: String?
    let rating: Double?
    // Populated book details (from backend)
    let title: String?
    let author: String?
    let authors: [String]?
    let cover: String?
    let isbn: String?
    let isbn13: String?
    let openLibraryId: String?
    let isbndbId: String?
}

// MARK: - BookshelfBook

struct BookshelfBook: Codable {
    let bookId: String?
    let rating: Double?
    let thoughts: String?
    let finishedDate: String?
    // Populated book details (from backend)
    let title: String?
    let author: String?
    let authors: [String]?
    let cover: String?
    let isbn: String?
    let isbn13: String?
    let openLibraryId: String?
    let isbndbId: String?
}

// MARK: - LikedBook

struct LikedBook: Codable {
    let bookId: String?
    let likedAt: String?
    // Populated book details
    let title: String?
    let author: String?
    let authors: [String]?
    let cover: String?
    let isbn: String?
    let isbn13: String?
    let openLibraryId: String?
    let isbndbId: String?
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

// MARK: - DiaryEntry

struct DiaryEntry: Codable, Identifiable {
    let _id: String?
    let idValue: String? // Renamed to avoid conflict with Identifiable id
    let bookId: String?
    let bookTitle: String?
    let bookAuthor: String?
    let bookCover: String?
    let subject: String?
    let content: String
    let createdAt: String
    let updatedAt: String
    let likesCount: Int?
    let isLiked: Bool?
    
    // Identifiable requirement - non-optional id
    var id: String {
        return idValue ?? _id ?? UUID().uuidString
    }
    
    // Computed property to get the entry ID (for backward compatibility)
    var entryId: String {
        return id
    }
    
    enum CodingKeys: String, CodingKey {
        case _id
        case idValue = "id" // Map "id" from JSON to idValue
        case bookId, bookTitle, bookAuthor, bookCover, subject, content
        case createdAt, updatedAt, likesCount, isLiked
    }
    
    // Public initializer for creating DiaryEntry instances
    init(
        _id: String? = nil,
        idValue: String? = nil,
        bookId: String? = nil,
        bookTitle: String? = nil,
        bookAuthor: String? = nil,
        bookCover: String? = nil,
        subject: String? = nil,
        content: String,
        createdAt: String,
        updatedAt: String,
        likesCount: Int? = nil,
        isLiked: Bool? = nil
    ) {
        self._id = _id
        self.idValue = idValue
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.bookCover = bookCover
        self.subject = subject
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.likesCount = likesCount
        self.isLiked = isLiked
    }
    
    // Check if this is a book-related entry
    var isBookEntry: Bool {
        return bookId != nil && bookTitle != nil
    }
    
    // Format date for display
    func formattedDate() -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Try parsing with fractional seconds first, then without
        var date: Date?
        if let parsedDate = isoFormatter.date(from: updatedAt) ?? isoFormatter.date(from: createdAt) {
            date = parsedDate
        } else {
            // Try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: updatedAt) ?? isoFormatter.date(from: createdAt)
        }
        
        if let date = date {
            let displayFormatter = DateFormatter()
            let calendar = Calendar.current
            
            if calendar.isDateInToday(date) {
                return "today"
            } else if calendar.isDateInYesterday(date) {
                return "yesterday"
            } else {
                displayFormatter.dateFormat = "dd/MM/yy"
                return displayFormatter.string(from: date)
            }
        }
        
        // Fallback: return the date string as-is or a formatted version
        return updatedAt.isEmpty ? createdAt : updatedAt
    }
}

