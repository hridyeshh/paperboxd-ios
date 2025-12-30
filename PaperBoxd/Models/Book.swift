import Foundation

// MARK: - Nested Types

struct IndustryIdentifier: Codable {
    let type: String
    let identifier: String
}

struct ImageLinks: Codable {
    let smallThumbnail: String?
    let thumbnail: String?
    let small: String?
    let medium: String?
    let large: String?
    let extraLarge: String?
}

struct VolumeInfo: Codable {
    let title: String
    let subtitle: String?
    let authors: [String]
    let publisher: String?
    let publishedDate: String?
    let description: String?
    let industryIdentifiers: [IndustryIdentifier]?
    let pageCount: Int?
    let categories: [String]?
    let averageRating: Double?
    let ratingsCount: Int?
    let language: String?
    let imageLinks: ImageLinks?
    let previewLink: String?
    let infoLink: String?
    let canonicalVolumeLink: String?
}

struct Price: Codable {
    let amount: Double
    let currencyCode: String
}

struct SaleInfo: Codable {
    let country: String?
    let saleability: String?
    let isEbook: Bool?
    let listPrice: Price?
    let retailPrice: Price?
    let buyLink: String?
}

// MARK: - Book
// Note: This model matches the simplified format returned by /api/books/sphere
// The API transforms the full database Book model into this format

struct Book: Codable, Identifiable {
    // The JSON uses "id" (not "_id") - backend already transforms it
    let id: String
    
    // Optional fields from the API response
    let bookId: String?
    let title: String
    let author: String? // Singular string from API (first author) - made optional
    let authors: [String]? // Array of authors (for mobile API)
    let src: String? // Image URL (legacy field)
    let cover: String? // Image URL (mobile API field)
    let alt: String? // Alt text for image
    let description: String? // Truncated description
    let publishedDate: String?
    let isbn: String?
    let isbn13: String?
    let averageRating: Double?
    let ratingsCount: Int?
    let pageCount: Int?
    let categories: [String]?
    let publisher: String?
    let userInteraction: UserInteraction? // User's interaction with this book
    
    // Computed property to get the best available image URL
    var imageURL: String? {
        return cover ?? src
    }
    
    // Computed property to get a secure HTTPS URL for the cover image
    // This ensures iOS App Transport Security compliance by converting HTTP to HTTPS
    var secureCoverURL: URL? {
        guard let imageURL = imageURL else { return nil }
        
        // Check if the URL starts with http:// and replace it with https://
        if imageURL.hasPrefix("http://") {
            let secureSrc = imageURL.replacingOccurrences(of: "http://", with: "https://")
            return URL(string: secureSrc)
        }
        
        return URL(string: imageURL)
    }
    
    // Computed property to get the author string
    var authorString: String {
        if let author = author {
            return author
        }
        if let authors = authors, !authors.isEmpty {
            return authors.joined(separator: ", ")
        }
        return "Unknown Author"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case _id // Support MongoDB's _id format
        case bookId
        case title
        case author
        case authors
        case src
        case cover
        case alt
        case description
        case publishedDate
        case isbn
        case isbn13
        case averageRating
        case ratingsCount
        case pageCount
        case categories
        case publisher
        case userInteraction
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle both "id" and "_id" for the id field
        if let idValue = try? container.decode(String.self, forKey: .id) {
            id = idValue
        } else if let idValue = try? container.decode(String.self, forKey: ._id) {
            id = idValue
        } else {
            throw DecodingError.keyNotFound(CodingKeys.id, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Neither 'id' nor '_id' found in Book"))
        }
        
        bookId = try? container.decode(String.self, forKey: .bookId)
        title = try container.decode(String.self, forKey: .title)
        author = try? container.decode(String.self, forKey: .author)
        authors = try? container.decode([String].self, forKey: .authors)
        src = try? container.decode(String.self, forKey: .src)
        cover = try? container.decode(String.self, forKey: .cover)
        alt = try? container.decode(String.self, forKey: .alt)
        description = try? container.decode(String.self, forKey: .description)
        publishedDate = try? container.decode(String.self, forKey: .publishedDate)
        isbn = try? container.decode(String.self, forKey: .isbn)
        isbn13 = try? container.decode(String.self, forKey: .isbn13)
        averageRating = try? container.decode(Double.self, forKey: .averageRating)
        ratingsCount = try? container.decode(Int.self, forKey: .ratingsCount)
        pageCount = try? container.decode(Int.self, forKey: .pageCount)
        categories = try? container.decode([String].self, forKey: .categories)
        publisher = try? container.decode(String.self, forKey: .publisher)
        userInteraction = try? container.decode(UserInteraction.self, forKey: .userInteraction)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Always encode as "id" (not "_id")
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(bookId, forKey: .bookId)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(author, forKey: .author)
        try container.encodeIfPresent(authors, forKey: .authors)
        try container.encodeIfPresent(src, forKey: .src)
        try container.encodeIfPresent(cover, forKey: .cover)
        try container.encodeIfPresent(alt, forKey: .alt)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(publishedDate, forKey: .publishedDate)
        try container.encodeIfPresent(isbn, forKey: .isbn)
        try container.encodeIfPresent(isbn13, forKey: .isbn13)
        try container.encodeIfPresent(averageRating, forKey: .averageRating)
        try container.encodeIfPresent(ratingsCount, forKey: .ratingsCount)
        try container.encodeIfPresent(pageCount, forKey: .pageCount)
        try container.encodeIfPresent(categories, forKey: .categories)
        try container.encodeIfPresent(publisher, forKey: .publisher)
        try container.encodeIfPresent(userInteraction, forKey: .userInteraction)
    }
}

// MARK: - UserInteraction
struct UserInteraction: Codable {
    let isLiked: Bool?
    let shelfStatus: String? // "None", "Want to Read", "Reading", "Read", "DNF"
}

// MARK: - Book Extension for Manual Creation
extension Book {
    init(
        id: String,
        bookId: String? = nil,
        title: String,
        author: String? = nil,
        authors: [String]? = nil,
        src: String? = nil,
        cover: String? = nil,
        alt: String? = nil,
        description: String? = nil,
        publishedDate: String? = nil,
        isbn: String? = nil,
        isbn13: String? = nil,
        averageRating: Double? = nil,
        ratingsCount: Int? = nil,
        pageCount: Int? = nil,
        categories: [String]? = nil,
        publisher: String? = nil,
        userInteraction: UserInteraction? = nil
    ) {
        self.id = id
        self.bookId = bookId
        self.title = title
        self.author = author
        self.authors = authors
        self.src = src
        self.cover = cover
        self.alt = alt
        self.description = description
        self.publishedDate = publishedDate
        self.isbn = isbn
        self.isbn13 = isbn13
        self.averageRating = averageRating
        self.ratingsCount = ratingsCount
        self.pageCount = pageCount
        self.categories = categories
        self.publisher = publisher
        self.userInteraction = userInteraction
    }
}

// MARK: - SphereResponse

struct SphereResponse: Codable {
    let books: [Book]
    let count: Int?
}


