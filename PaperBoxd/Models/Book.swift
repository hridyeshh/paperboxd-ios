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
    let author: String? // Singular string from API (first author) - optional for latest books API
    let authors: [String]? // Array of authors from latest books API
    let src: String? // Image URL
    let cover: String? // Cover URL from latest books API
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
    
    // Computed property to get the best available image URL
    var imageURL: String? {
        return cover ?? src
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
        case _id
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
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle both "id" and "_id" for the id field
        if let idValue = try? container.decode(String.self, forKey: .id) {
            id = idValue
        } else if let idValue = try? container.decode(String.self, forKey: ._id) {
            id = idValue
        } else {
            throw DecodingError.keyNotFound(CodingKeys.id, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Neither 'id' nor '_id' found"))
        }
        
        // Decode optional fields
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
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try? container.encode(bookId, forKey: .bookId)
        try container.encode(title, forKey: .title)
        try? container.encode(author, forKey: .author)
        try? container.encode(authors, forKey: .authors)
        try? container.encode(src, forKey: .src)
        try? container.encode(cover, forKey: .cover)
        try? container.encode(alt, forKey: .alt)
        try? container.encode(description, forKey: .description)
        try? container.encode(publishedDate, forKey: .publishedDate)
        try? container.encode(isbn, forKey: .isbn)
        try? container.encode(isbn13, forKey: .isbn13)
        try? container.encode(averageRating, forKey: .averageRating)
        try? container.encode(ratingsCount, forKey: .ratingsCount)
        try? container.encode(pageCount, forKey: .pageCount)
        try? container.encode(categories, forKey: .categories)
        try? container.encode(publisher, forKey: .publisher)
    }
}

// MARK: - SphereResponse

struct SphereResponse: Codable {
    let books: [Book]
    let count: Int?
}

// MARK: - LatestBooksResponse

struct LatestBooksResponse: Codable {
    let books: [Book]
    let pagination: Pagination?
}

struct Pagination: Codable {
    let page: Int
    let pageSize: Int
    let total: Int
    let totalPages: Int
}

// MARK: - PersonalizedBooksResponse

struct PersonalizedBooksResponse: Codable {
    let books: [Book]
    let count: Int?
}


