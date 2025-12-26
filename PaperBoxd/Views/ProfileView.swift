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
                        
                        // 3. THE BOARD GRID
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ],
                            spacing: 20
                        ) {
                            ForEach(boards(for: selectedTab)) { board in
                                BoardPreviewCard(board: board)
                            }
                        }
                        .padding(.horizontal)
                        
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
    
    // Get boards for selected tab
    func boards(for tab: String) -> [BookBoard] {
        switch tab {
        case "Favorites":
            return viewModel.favoriteBoards
        case "Lists":
            return viewModel.readingListBoards
        case "Bookshelf":
            return viewModel.bookshelfBoards
        case "DNF":
            return viewModel.dnfBoards
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
    
    var body: some View {
        Group {
            if let urlString = url, let imageURL = URL(string: urlString) {
                KFImage(imageURL)
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

#Preview {
    ProfileView()
}

