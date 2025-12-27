import SwiftUI
import Kingfisher

struct BookCard: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Book cover image
            if let secureCoverURL = book.secureCoverURL {
                KFImage(secureCoverURL)
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 300, height: 450)))
                    .forceRefresh(false)
                    .cacheMemoryOnly(false)
                    .fade(duration: 0.3)
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(2/3, contentMode: ContentMode.fit)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            } else {
                // Fallback placeholder if no image URL
                Rectangle()
                    .fill(Color.gray)
                    .aspectRatio(2/3, contentMode: .fit)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            
            // Book title
            Text(book.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}

#Preview {
    // Create a sample book using JSON decoder for preview
    let sampleJSON = """
    {
        "id": "1",
        "title": "Sample Book Title",
        "author": "Author Name",
        "cover": "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=600&q=80",
        "description": "This is a sample book description for preview purposes."
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    if let book = try? decoder.decode(Book.self, from: sampleJSON) {
        BookCard(book: book)
    .frame(width: 150)
    .padding()
    } else {
        Text("Preview Error")
    }
}

