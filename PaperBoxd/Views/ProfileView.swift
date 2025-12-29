import SwiftUI
import Kingfisher

struct ProfileView: View {
    // Use shared instance instead of creating new one
    @ObservedObject private var viewModel = ProfileViewModel.shared
    @State private var selectedTab = "Bookshelf"
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var showShare = false
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
                    VStack(spacing: 20) {
                        // 1. PROFILE INFO CONTAINER (Avatar, username, pronouns, name, stats, bio)
                        VStack(spacing: 0) {
                            // Settings and Share buttons overlay at top
                            HStack {
                                // Settings button on the left
                                Button(action: {
                                    showSettings = true
                                }) {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 20))
                                        .foregroundColor(.primary)
                                        .padding(8)
                                }
                                
                                Spacer()
                                
                                // Share button on the right
                                Button(action: {
                                    showShare = true
                                }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 20))
                                        .foregroundColor(.primary)
                                        .padding(8)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            
                            ProfileHeader(
                                username: viewModel.profile?.username,
                                name: viewModel.profile?.name,
                                avatar: viewModel.profile?.avatar,
                                pronouns: viewModel.profile?.pronouns,
                                bookshelfCount: viewModel.bookshelfBooksList.count,
                                followersCount: viewModel.profile?.followers?.count ?? 0,
                                followingCount: viewModel.profile?.following?.count ?? 0,
                                bio: viewModel.profile?.bio
                            )
                            
                            // Edit Profile Button (below the container)
                            Button(action: {
                                showEditProfile = true
                            }) {
                                Text("Edit profile")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        }
                        
                        // 2. TOP NAVIGATION TABS (Below header)
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
                .refreshable {
                    // Pull-to-refresh: Force reload profile data
                    await viewModel.refreshProfile()
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            if let profile = viewModel.profile {
                EditProfileView(profile: profile) {
                    // After saving, refresh profile
                    Task {
                        await viewModel.refreshProfile()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showShare) {
            ShareView()
        }
        .onAppear {
            // Only load if not already loaded (shared instance handles caching)
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
// MARK: - PROFILE HEADER (Avatar left, info right - matching image design)
struct ProfileHeader: View {
    let username: String?
    let name: String?
    let avatar: String?
    let pronouns: [String]?
    let bookshelfCount: Int
    let followersCount: Int
    let followingCount: Int
    let bio: String?
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Avatar on the left
            if let avatarURL = avatar, let url = URL(string: avatarURL) {
                KFImage(url)
                    .placeholder {
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text((name ?? username ?? "U").prefix(1).uppercased())
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundColor(.primary)
                            )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            } else {
            Circle()
                .fill(Color.secondary.opacity(0.1))
                    .frame(width: 80, height: 80)
                .overlay(
                        Text((name ?? username ?? "U").prefix(1).uppercased())
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.primary)
                    )
            }
            
            // User info on the right
            VStack(alignment: .leading, spacing: 6) {
                // Username and pronouns
                HStack(spacing: 8) {
                    Text(username ?? "username")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let pronouns = pronouns, !pronouns.isEmpty {
                        Text(pronouns.joined(separator: "/"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                
                // Full name
                if let name = name {
                Text(name)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Stats: books, followers, following (count on top, label below)
                HStack(spacing: 20) {
                    // Books count (bookshelf count)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(bookshelfCount)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        Text("books")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.primary)
                    }
                    
                    // Followers count
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(followersCount)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        Text("followers")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.primary)
                    }
                    
                    // Following count
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(followingCount)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        Text("following")
                            .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.primary)
                    }
                }
                
                // Bio (if available)
                if let bio = bio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.primary)
                        .padding(.top, 4)
                }
            }
            
            Spacer()
            }
        .padding(.horizontal, 20)
        .padding(.top, 10)
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
                        // Icon only (no text)
                        ProfileTabIcon(tabName: option, isActive: selection == option)
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

