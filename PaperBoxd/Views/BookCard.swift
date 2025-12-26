import SwiftUI
import Kingfisher

struct BookCard: View {
    let book: Book
    
<<<<<<< Updated upstream
    // A simple helper to ensure we try HTTPS first
    // Converts HTTP URLs to HTTPS for secure loading
    private var secureCoverURL: URL? {
        guard let src = book.src else { return nil }
        if src.hasPrefix("http://") {
            let secureSrc = src.replacingOccurrences(of: "http://", with: "https://")
            return URL(string: secureSrc)
        }
        return URL(string: src)
    }
    
=======
>>>>>>> Stashed changes
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
    BookCard(book: Book(
        id: "1",
        bookId: "1",
        title: "Sample Book Title",
        author: "Author Name",
        src: "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=600&q=80",
        alt: "Sample Book Cover",
        description: "This is a sample book description for preview purposes."
    ))
    .frame(width: 150)
    .padding()
}

