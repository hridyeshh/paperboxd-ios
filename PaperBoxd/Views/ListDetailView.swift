import SwiftUI
import Kingfisher

struct ListDetailView: View {
    let readingList: ReadingList
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(readingList.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let description = readingList.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    
                    if let bookCount = readingList.books?.count {
                        Text("\(bookCount) book\(bookCount == 1 ? "" : "s")")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Books Grid
                if let books = readingList.books, !books.isEmpty {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 16
                    ) {
                        ForEach(Array(books.enumerated()), id: \.offset) { index, book in
                            if let volumeInfo = book.volumeInfo {
                                VStack(alignment: .leading, spacing: 8) {
                                    // Book Cover
                                    if let imageLinks = volumeInfo.imageLinks,
                                       let thumbnail = imageLinks.thumbnail ?? imageLinks.smallThumbnail ?? imageLinks.medium ?? imageLinks.large,
                                       let url = URL(string: thumbnail) {
                                        KFImage(url)
                                            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 150, height: 225)))
                                            .placeholder {
                                                Rectangle()
                                                    .fill(Color.secondary.opacity(0.1))
                                                    .aspectRatio(2/3, contentMode: .fit)
                                            }
                                            .forceRefresh(false)
                                            .cacheMemoryOnly(false)
                                            .fade(duration: 0.2)
                                            .resizable()
                                            .aspectRatio(2/3, contentMode: .fit)
                                            .cornerRadius(8)
                                            .clipped()
                                    } else {
                                        Rectangle()
                                            .fill(Color.secondary.opacity(0.1))
                                            .aspectRatio(2/3, contentMode: .fit)
                                            .cornerRadius(8)
                                            .overlay(
                                                Image(systemName: "book.closed")
                                                    .foregroundColor(.secondary)
                                                    .font(.title2)
                                            )
                                    }
                                    
                                    // Book Title
                                    if let title = volumeInfo.title {
                                        Text(title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    // Book Authors
                                    if let authors = volumeInfo.authors, !authors.isEmpty {
                                        Text(authors.joined(separator: ", "))
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No books in this list yet")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding(.bottom, 120) // Dock padding
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

