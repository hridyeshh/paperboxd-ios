import SwiftUI
import Kingfisher

struct BookDetailView: View {
    let book: Book
    
    // Helper to ensure HTTPS for the cover image
    private var secureCoverURL: URL? {
        guard let src = book.src else { return nil }
        if src.hasPrefix("http://") {
            let secureSrc = src.replacingOccurrences(of: "http://", with: "https://")
            return URL(string: secureSrc)
        }
        return URL(string: src)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Large book cover image
                if let secureCoverURL = secureCoverURL {
                    KFImage(secureCoverURL)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 400)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                } else {
                    // Fallback placeholder
                    Rectangle()
                        .fill(Color.gray)
                        .frame(height: 400)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                }
                
                // Book title
                Text(book.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // Author
                Text(book.author)
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // Description
                if let description = book.description {
                    Text(description)
                        .font(.body)
                        .lineSpacing(4)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        BookDetailView(book: Book(
            id: "1",
            bookId: "1",
            title: "Sample Book Title",
            author: "Author Name",
            src: "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=600&q=80",
            alt: "Sample Book Cover",
            description: "This is a sample book description for preview purposes. It demonstrates how the description text will appear in the detail view."
        ))
    }
}

