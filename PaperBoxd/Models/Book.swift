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
    let author: String // Singular string from API (first author)
    let src: String? // Image URL
    let alt: String? // Alt text for image
    let description: String? // Truncated description
    
    enum CodingKeys: String, CodingKey {
        case id
        case bookId
        case title
        case author
        case src
        case alt
        case description
    }
}

// MARK: - SphereResponse

struct SphereResponse: Codable {
    let books: [Book]
    let count: Int?
}


