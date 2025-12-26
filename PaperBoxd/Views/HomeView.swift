import SwiftUI
import Kingfisher

struct HomeView: View {
    // Controls which tab is active
    @State private var selectedTab: Int = 0
    
    // Matched Geometry Effect namespace for premium transitions
    @Namespace var animationNamespace
    
    // Track selected book for detail view
    @State private var selectedBook: Book? = nil
    @State private var showDetail = false
    
    // Hide the default standard tab bar so we can make our own custom one
    init() {
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack {
            // 1. THE MAIN CONTENT
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case 0:
                        HomeFeedContent(
                            namespace: animationNamespace,
                            selectedBook: $selectedBook,
                            showDetail: $showDetail
                        )
                        .opacity(showDetail ? 0 : 1) // Hide feed slightly to focus on detail
                    case 1:
                        Text("Search Page") // Placeholder
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(uiColor: .systemBackground))
                    case 2:
                        Text("Write/Log Page") // Placeholder
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(uiColor: .systemBackground))
                    case 3:
                        ProfileView()
                            .opacity(showDetail ? 0 : 1) // Hide profile when detail is showing
                    default:
                        HomeFeedContent(
                            namespace: animationNamespace,
                            selectedBook: $selectedBook,
                            showDetail: $showDetail
                        )
                        .opacity(showDetail ? 0 : 1) // Hide feed slightly to focus on detail
                    }
                }
                
                // 2. THE BOTTOM DOCK (Stuck to bottom like web version)
                if !showDetail {
                    VStack {
                        Spacer()
                        PinterestNavBar(selectedTab: $selectedTab)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            
            // 3. FULL SCREEN DETAIL OVERLAY (Premium transition)
            if let book = selectedBook, showDetail {
                BookDetailView(
                    initialBook: book,
                    namespace: animationNamespace,
                    isShowing: $showDetail
                )
                .transition(.asymmetric(
                    insertion: .identity,
                    removal: .offset(y: 5)
                ))
                .zIndex(2) // Ensure it sits above the dock
            }
        }
        .ignoresSafeArea(.keyboard) // Prevents keyboard from pushing it up awkwardly
    }
}

// MARK: - THE HOME FEED (Masonry Style)
struct HomeFeedContent: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var showUpdates = false
    @State private var currentPage = 1
    @State private var hasMore = true
    @State private var isLoadingMore = false
    
    // Matched Geometry Effect props
    var namespace: Namespace.ID
    @Binding var selectedBook: Book?
    @Binding var showDetail: Bool
    
    // Pinterest-style height variation for visual interest
    private let heightPattern: [CGFloat] = [220, 280, 240, 310, 200, 290]
    
    func getCardHeight(for index: Int) -> CGFloat {
        return heightPattern[index % heightPattern.count]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar with PaperBoxd and Updates Icon
                    HStack {
                        Text("PaperBoxd")
                            .font(.system(size: 24, weight: .black)) // Bold branding
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            showUpdates = true
                        }) {
                            Image(systemName: "bell")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .systemBackground))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.primary.opacity(0.1)),
                        alignment: .bottom
                    )
                    
                    // Endless Feed
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // THE "PINTEREST" MASONRY GRID
                            if viewModel.isLoading {
                                // Show skeleton cards while loading
                                HStack(alignment: .top, spacing: 12) {
                                    LazyVStack(spacing: 12) {
                                        ForEach(0..<5, id: \.self) { _ in
                                            BookSkeletonCard()
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    LazyVStack(spacing: 12) {
                                        ForEach(0..<5, id: \.self) { _ in
                                            BookSkeletonCard()
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 12)
                            } else {
                                // Pinterest-style Masonry Grid - Visual-first design
                                HStack(alignment: .top, spacing: 12) {
                                    // Left Column (Even Indices)
                                    LazyVStack(spacing: 12) {
                                        ForEach(Array(viewModel.books.enumerated()), id: \.element.id) { index, book in
                                            if index % 2 == 0 {
                                                Button(action: {
                                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                                        selectedBook = book
                                                        showDetail = true
                                                    }
                                                }) {
                                                    FeedPinCard(book: book, height: getCardHeight(for: index))
                                                        .matchedGeometryEffect(id: book.id, in: namespace)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    // Right Column (Odd Indices)
                                    LazyVStack(spacing: 12) {
                                        ForEach(Array(viewModel.books.enumerated()), id: \.element.id) { index, book in
                                            if index % 2 != 0 {
                                                Button(action: {
                                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                                        selectedBook = book
                                                        showDetail = true
                                                    }
                                                }) {
                                                    FeedPinCard(book: book, height: getCardHeight(for: index))
                                                        .matchedGeometryEffect(id: book.id, in: namespace)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 12)
                                
                                // Load More Indicator
                                if isLoadingMore {
                                    ProgressView()
                                        .padding()
                                }
                                
                                // End of feed message
                                if !hasMore && viewModel.books.count > 0 {
                                    Text("You've reached the end of your feed")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding()
                                }
                            }
                            
                            // Bottom padding for the dock
                            Spacer()
                                .frame(height: 100)
                        }
                    }
                    .onAppear {
                        if viewModel.books.isEmpty {
                            Task {
                                await viewModel.loadBooks()
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.loadBooks()
                    }
                }
            }
            .sheet(isPresented: $showUpdates) {
                UpdatesView()
            }
        }
    }
}

// MARK: - COMPONENT: BOTTOM NAV BAR (Stuck to bottom like web version)
struct PinterestNavBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            // 1. Home
            NavIcon(icon: "house.fill", index: 0, selectedTab: $selectedTab)
            
            Spacer()
            
            // 2. Search
            NavIcon(icon: "magnifyingglass", index: 1, selectedTab: $selectedTab)
            
            Spacer()
            
            // 3. Write (The Pen Button)
            NavIcon(icon: "pencil", index: 2, selectedTab: $selectedTab)
            
            Spacer()
            
            // 4. Profile (Avatar button like web version)
            ProfileNavButton(index: 3, selectedTab: $selectedTab)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .padding(.bottom, 8) // Safe area padding for home indicator
        .background(Color(uiColor: .systemBackground)) // Solid background
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.primary.opacity(0.1)),
            alignment: .top
        )
    }
}

struct NavIcon: View {
    let icon: String
    let index: Int
    @Binding var selectedTab: Int
    
    var body: some View {
        Button(action: { 
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(selectedTab == index ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PROFILE NAV BUTTON (Avatar like web version)
struct ProfileNavButton: View {
    let index: Int
    @Binding var selectedTab: Int
    
    var body: some View {
        Button(action: { 
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        }) {
            // Avatar circle with border (matching web version)
            Circle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.8), lineWidth: 2)
                )
                .overlay(
                    // Placeholder: You can replace this with actual user avatar image
                    Text("H")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - COMPONENT: FEED PIN (Pinterest-style - Visual-first, no metadata)
struct FeedPinCard: View {
    let book: Book
    let height: CGFloat
    
<<<<<<< Updated upstream
    // Secure URL helper
    private var secureCoverURL: URL? {
        guard let imageURL = book.imageURL else { return nil }
        if imageURL.hasPrefix("http://") {
            let secureSrc = imageURL.replacingOccurrences(of: "http://", with: "https://")
            return URL(string: secureSrc)
        }
        return URL(string: imageURL)
    }
    
=======
>>>>>>> Stashed changes
    var body: some View {
        ZStack {
            if let secureCoverURL = book.secureCoverURL {
                KFImage(secureCoverURL)
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 300, height: Int(height))))
                    .placeholder {
                        // Pinterest-style colored placeholder while loading
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                    }
                    .forceRefresh(false)
                    .cacheMemoryOnly(false)
                    .fade(duration: 0.3)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16) // Pinterest uses slightly more rounded corners
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - COMPONENT: READING PROGRESS
struct ReadingProgressCard: View {
    let book: Book
    let progress: CGFloat
    
<<<<<<< Updated upstream
    // Secure URL helper
    private var secureCoverURL: URL? {
        guard let imageURL = book.imageURL else { return nil }
        if imageURL.hasPrefix("http://") {
            let secureSrc = imageURL.replacingOccurrences(of: "http://", with: "https://")
            return URL(string: secureSrc)
        }
        return URL(string: imageURL)
    }
    
=======
>>>>>>> Stashed changes
    var body: some View {
        HStack(spacing: 15) {
            // Book cover
            if let secureCoverURL = book.secureCoverURL {
                KFImage(secureCoverURL)
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 60, height: 90)))
                    .forceRefresh(false)
                    .cacheMemoryOnly(false)
                    .fade(duration: 0.3)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(book.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("Page 142 left")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Progress Bar
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 100, height: 4)
                    Capsule()
                        .fill(Color.green)
                        .frame(width: 100 * progress, height: 4)
                }
            }
        }
        .padding(12)
        .padding(.trailing, 20)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(20)
    }
}

#Preview {
    HomeView()
}
