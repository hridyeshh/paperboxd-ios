import SwiftUI
import Kingfisher

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedTab = "Bookshelf"
    // Your 4 specific items (Liked removed for now, kept in DB for future use)
    let navigationItems = ["Favorites", "Lists", "Bookshelf", "DNF"]
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                VStack {
                    Text(errorMessage)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task {
                            await viewModel.loadProfile()
                        }
                    }
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        // 1. CLEAN HEADER (No search or tags)
                        ProfileSimpleHeader(
                            name: viewModel.profile?.name ?? "User",
                            avatar: viewModel.profile?.avatar,
                            bio: viewModel.profile?.bio
                        )
                        
                        // 2. TOP NAVIGATION (Pinterest Style)
                        CategoryPicker(selection: $selectedTab, options: navigationItems)
                        
                        // 3. CONTENT (Boards for Lists, Collection for Books)
                        if selectedTab == "Lists" {
                            // Lists: Show as boards (Pinterest style)
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 16),
                                    GridItem(.flexible(), spacing: 16)
                                ],
                                spacing: 20
                            ) {
                                ForEach(viewModel.readingListBoards) { board in
                                    BoardPreviewCard(board: board)
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            // Favorites, Bookshelf, DNF: Show as book collection (grid)
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ],
                                spacing: 16
                            ) {
                                ForEach(books(for: selectedTab)) { book in
                                    BookCoverCard(book: book)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer().frame(height: 120) // Dock padding
                    }
                    .padding(.top, 10)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadProfile()
            }
        }
    }
    
    // Get books for selected tab (for collection view)
    func books(for tab: String) -> [ProfileBook] {
        switch tab {
        case "Favorites":
            return viewModel.favoriteBooksList.map { ref in
                ProfileBook(
                    id: ref.bookId ?? UUID().uuidString,
                    title: ref.title ?? "Unknown Title",
                    author: ref.author ?? "Unknown Author",
                    cover: ref.cover
                )
            }
        case "Bookshelf":
            return viewModel.bookshelfBooksList.map { book in
                ProfileBook(
                    id: book.bookId ?? UUID().uuidString,
                    title: book.title ?? "Unknown Title",
                    author: book.author ?? "Unknown Author",
                    cover: book.cover
                )
            }
        case "DNF":
            return viewModel.dnfBooksList.map { book in
                ProfileBook(
                    id: book.bookId ?? UUID().uuidString,
                    title: book.title ?? "Unknown Title",
                    author: book.author ?? "Unknown Author",
                    cover: book.cover
                )
            }
        default:
            return []
        }
    }
}

// MARK: - COMPONENT: SIMPLIFIED PROFILE HEADER
struct ProfileSimpleHeader: View {
    let name: String
    let avatar: String?
    let bio: String?
    
    var body: some View {
        VStack(spacing: 16) {
            // Centered Avatar
            if let avatarURL = avatar, let url = URL(string: avatarURL) {
                KFImage(url)
                    .placeholder {
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 90, height: 90)
                            .overlay(
                                Text(name.prefix(1))
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundColor(.primary)
                            )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 90, height: 90)
                    .clipShape(Circle())
                    .padding(.top, 10)
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 90, height: 90)
                    .overlay(
                        Text(name.prefix(1))
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(.primary)
                    )
                    .padding(.top, 10)
            }
            
            VStack(spacing: 4) {
                Text(name)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                if let bio = bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                } else {
                    Text("@username")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - COMPONENT: CATEGORY PICKER (Pinterest Style)
struct CategoryPicker: View {
    @Binding var selection: String
    let options: [String]
    @Namespace private var namespace
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = option
                        // Haptic feedback for premium feel
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(option)
                            .fontWeight(selection == option ? .bold : .medium)
                            .foregroundColor(selection == option ? .primary : .secondary)
                        
                        if selection == option {
                            Capsule()
                                .fill(Color.primary)
                                .frame(height: 3)
                                .matchedGeometryEffect(id: "tab", in: namespace)
                        } else {
                            Capsule()
                                .fill(Color.clear)
                                .frame(height: 3)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - COMPONENT: PINTEREST BOARD PREVIEW CARD
struct BoardPreviewCard: View {
    let board: BookBoard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // THE MULTI-IMAGE CONTAINER
            HStack(spacing: 2) {
                // Large Lead Cover (Left) - takes 2/3 of height
                BoardImage(
                    url: board.covers.indices.contains(0) ? board.covers[0] : nil,
                    height: 160
                )
                .frame(width: 100)
                
                // Vertical Stack of 3 smaller covers (Right) - each ~1/3 of height
                VStack(spacing: 2) {
                    BoardImage(
                        url: board.covers.indices.contains(1) ? board.covers[1] : nil,
                        height: 52.67
                    )
                    BoardImage(
                        url: board.covers.indices.contains(2) ? board.covers[2] : nil,
                        height: 52.67
                    )
                    BoardImage(
                        url: board.covers.indices.contains(3) ? board.covers[3] : nil,
                        height: 52.67
                    )
                }
                .frame(width: 55)
            }
            .frame(height: 160)
            .cornerRadius(18) // High rounding for the Pinterest aesthetic
            .clipped()
            
            // TITLES
            VStack(alignment: .leading, spacing: 2) {
                Text(board.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("\(board.bookCount) Books")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - COMPONENT: BOARD IMAGE
struct BoardImage: View {
    let url: String?
    var height: CGFloat? = nil // Optional explicit height
    
    // Helper to ensure HTTPS for the image URL
    private var secureImageURL: URL? {
        guard let urlString = url else { return nil }
        if urlString.hasPrefix("http://") {
            let secureSrc = urlString.replacingOccurrences(of: "http://", with: "https://")
            return URL(string: secureSrc)
        }
        return URL(string: urlString)
    }
    
    var body: some View {
        Group {
            if let secureImageURL = secureImageURL {
                KFImage(secureImageURL)
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 200, height: 200)))
                    .placeholder {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                    }
                    .forceRefresh(false)
                    .cacheMemoryOnly(false)
                    .fade(duration: 0.2)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: height)
            }
        }
    }
}

// MARK: - PROFILE BOOK MODEL
struct ProfileBook: Identifiable {
    let id: String
    let title: String
    let author: String
    let cover: String?
    
    // Helper to ensure HTTPS for the cover image (ProfileBook-specific)
    var secureCoverURL: URL? {
        guard let coverURL = cover else { return nil }
        if coverURL.hasPrefix("http://") {
            let secureSrc = coverURL.replacingOccurrences(of: "http://", with: "https://")
            return URL(string: secureSrc)
        }
        return URL(string: coverURL)
    }
}

// MARK: - COMPONENT: BOOK COVER CARD (For Collection View)
struct BookCoverCard: View {
    let book: ProfileBook
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Book Cover
            if let secureCoverURL = book.secureCoverURL {
                KFImage(secureCoverURL)
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
            Text(book.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Book Author
            Text(book.author)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

#Preview {
    ProfileView()
}

