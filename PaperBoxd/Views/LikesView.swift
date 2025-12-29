import SwiftUI
import Kingfisher

struct LikesView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var profileViewModel = ProfileViewModel.shared
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text("Likes")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Invisible button to center the title
                    Button(action: {}) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.clear)
                    }
                    .disabled(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(uiColor: .systemBackground))
                
                Divider()
                
                // Liked Books Grid (2 columns)
                if let likedBooks = profileViewModel.profile?.likedBooks, !likedBooks.isEmpty {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 16
                        ) {
                            ForEach(likedBooks, id: \.bookId) { likedBook in
                                LikedBookCard(book: likedBook)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "heart")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No liked books yet")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

struct LikedBookCard: View {
    let book: LikedBook
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Book cover
            if let coverURL = book.cover, let url = URL(string: coverURL) {
                KFImage(url)
                    .placeholder {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.2))
                            .aspectRatio(2/3, contentMode: .fit)
                            .overlay(
                                Image(systemName: "book.closed")
                                    .foregroundColor(.secondary)
                            )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .aspectRatio(2/3, contentMode: .fit)
                    .overlay(
                        Image(systemName: "book.closed")
                            .foregroundColor(.secondary)
                    )
            }
            
            // Book title
            Text(book.title ?? "Unknown Title")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}

