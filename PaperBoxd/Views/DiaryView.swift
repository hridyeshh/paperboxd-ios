import SwiftUI
import Kingfisher

struct DiaryView: View {
    @ObservedObject private var viewModel = ProfileViewModel.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let entries = viewModel.profile?.diaryEntries, !entries.isEmpty {
                    ForEach(entries) { entry in
                        DiaryEntryCard(entry: entry)
                            .padding(.bottom, 20)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No diary entries yet")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
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

struct DiaryEntryCard: View {
    let entry: DiaryEntry
    @ObservedObject private var viewModel = ProfileViewModel.shared
    @State private var selectedBook: Book? = nil
    @State private var showBookDetail = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isLiked: Bool
    @State private var likesCount: Int
    @State private var showShareSheet = false
    @Namespace private var bookNamespace
    
    init(entry: DiaryEntry) {
        self.entry = entry
        _isLiked = State(initialValue: entry.isLiked ?? false)
        _likesCount = State(initialValue: entry.likesCount ?? 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Avatar, Username, Date
            HStack(spacing: 12) {
                // Avatar
                if let avatarURL = viewModel.profile?.avatar, let url = URL(string: avatarURL) {
                    KFImage(url)
                        .placeholder {
                            Circle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text((viewModel.profile?.name ?? viewModel.profile?.username ?? "U").prefix(1).uppercased())
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.primary)
                                )
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text((viewModel.profile?.name ?? viewModel.profile?.username ?? "U").prefix(1).uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                        )
                }
                
                // Username
                Text(viewModel.profile?.username ?? "username")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                // Date
                Text(entry.formattedDate())
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Delete icon (trash) - only show for profile owner
                if viewModel.isCurrentUserProfile {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                    .disabled(isDeleting)
                }
            }
            
            // Entry Content (always show first)
            if let subject = entry.subject, !subject.isEmpty {
                Text(subject)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(nil)
            } else {
                // Strip HTML tags from content
                Text(stripHtmlTags(entry.content))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(nil)
            }
            
            // Book Card (if it's a book entry, show after content)
            if entry.isBookEntry {
                Button(action: {
                    // Create Book object from diary entry
                    if let bookId = entry.bookId,
                       let bookTitle = entry.bookTitle,
                       let bookAuthor = entry.bookAuthor {
                        let book = Book(
                            id: bookId,
                            bookId: bookId,
                            title: bookTitle,
                            author: bookAuthor,
                            authors: [bookAuthor],
                            src: entry.bookCover,
                            cover: entry.bookCover,
                            alt: nil,
                            description: nil,
                            publishedDate: nil,
                            isbn: nil,
                            isbn13: nil,
                            averageRating: nil,
                            ratingsCount: nil,
                            pageCount: nil,
                            categories: nil,
                            publisher: nil,
                            userInteraction: nil
                        )
                        selectedBook = book
                        showBookDetail = true
                    }
                }) {
                    // Book Entry: Capsule with cover, title, and author
                    HStack(spacing: 12) {
                        // Book Cover
                        if let coverURL = entry.bookCover, let url = URL(string: coverURL) {
                            KFImage(url)
                                .placeholder {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.1))
                                        .frame(width: 60, height: 90)
                                }
                                .resizable()
                                .aspectRatio(2/3, contentMode: .fit)
                                .frame(width: 60, height: 90)
                                .cornerRadius(8)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 60, height: 90)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "book.closed")
                                        .foregroundColor(.secondary)
                                        .font(.title3)
                                )
                        }
                        
                        // Book Title and Author
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.bookTitle ?? "Unknown Title")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            if let author = entry.bookAuthor {
                                Text(author)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Engagement Icons (Repost, Like, Share)
            HStack(spacing: 20) {
                // Repost
                Button(action: {
                    handleRepost()
                }) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                
                // Like
                Button(action: {
                    handleLike()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(isLiked ? .red : .secondary)
                        
                        if likesCount > 0 {
                            Text("\(likesCount)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Share
                Button(action: {
                    showShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 12)
        .fullScreenCover(isPresented: $showBookDetail) {
            if let book = selectedBook {
                BookDetailView(
                    initialBook: book,
                    namespace: bookNamespace,
                    isShowing: $showBookDetail
                )
            }
        }
        .confirmationDialog("Delete Diary Entry", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this diary entry? This action cannot be undone.")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }
    
    private func handleLike() {
        guard let username = viewModel.profile?.username else { return }
        
        // Optimistic update - immediate UI feedback
        let previousLiked = isLiked
        let previousCount = likesCount
        
        isLiked.toggle()
        if isLiked {
            likesCount += 1
        } else {
            likesCount = max(0, likesCount - 1)
        }
        
        // Update in background without showing loading or refreshing the screen
        Task {
            do {
                let response = try await APIClient.shared.toggleDiaryEntryLike(username: username, entryId: entry.id)
                
                // Silently sync with server response in the background
                // Only update if the server response differs from our optimistic update
                await MainActor.run {
                    if response.liked != isLiked || response.likesCount != likesCount {
                        isLiked = response.liked
                        likesCount = response.likesCount
                    }
                }
            } catch {
                // Revert optimistic update on error
                await MainActor.run {
                    isLiked = previousLiked
                    likesCount = previousCount
                    print("❌ DiaryEntryCard: Failed to toggle like: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleRepost() {
        // Repost functionality - could create a repost of this diary entry
        // For now, repost could mean sharing it to your own diary or creating a repost activity
        // This is a placeholder - implement repost API when available
        // For now, we'll use the share functionality as repost
        showShareSheet = true
    }
    
    private var shareItems: [Any] {
        var items: [Any] = []
        
        // Add entry content
        if let subject = entry.subject, !subject.isEmpty {
            items.append(subject)
        } else {
            items.append(stripHtmlTags(entry.content))
        }
        
        // Add book info if it's a book entry
        if entry.isBookEntry, let bookTitle = entry.bookTitle {
            items.append("📚 \(bookTitle)")
            if let author = entry.bookAuthor {
                items.append("by \(author)")
            }
        }
        
        // Add profile URL if available
        if let username = viewModel.profile?.username {
            items.append("Check out my diary entry on PaperBoxd: @\(username)")
        }
        
        return items
    }
    
    private func deleteEntry() {
        guard let username = viewModel.profile?.username else { return }
        
        isDeleting = true
        
        Task {
            do {
                // Use entryId for general entries, bookId for book entries
                if entry.isBookEntry, let bookId = entry.bookId {
                    try await APIClient.shared.deleteDiaryEntry(username: username, bookId: bookId)
                } else {
                    let entryId = entry.id
                    try await APIClient.shared.deleteDiaryEntry(username: username, entryId: entryId)
                }
                
                // Refresh profile to update diary entries
                await MainActor.run {
                    isDeleting = false
                    Task {
                        await viewModel.refreshProfile()
                    }
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    print("❌ DiaryEntryCard: Failed to delete entry: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Helper function to strip HTML tags (matching BookDetailView implementation)
    private func stripHtmlTags(_ html: String) -> String {
        // Remove HTML tags
        var text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decode common HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&apos;", with: "'")
        
        // Clean up multiple spaces and newlines
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n\\s*\n", with: "\n\n", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

