import SwiftUI

struct HomeView: View {
    let user: User
    @StateObject private var viewModel: HomeViewModel
    @State private var showNotifications = false
    @State private var showWrite = false

    // Home is light-mode only. The app window is globally forced dark
    // (UIWindow.appearance().overrideUserInterfaceStyle = .dark) and the asset
    // colors are single-appearance dark, so we use fixed light values here —
    // same approach as the book page (BrutalKit.BK). Mirrors "Home - Brutalist
    // Mobile.html" tokens.
    private let hlBg    = Color(red: 0.949, green: 0.929, blue: 0.882) // paper  #f2ede1
    private let hlCard  = Color(red: 0.992, green: 0.984, blue: 0.965) // card   #fdfbf6
    private let hlInk   = Color(red: 0.082, green: 0.082, blue: 0.075) // ink    #151513
    private let hlMuted = Color(red: 0.416, green: 0.392, blue: 0.337) // muted  #6a6456
    private let hlAccent = Color(red: 0.824, green: 0.231, blue: 0.149) // accent #d23b26

    init(user: User) {
        self.user = user
        _viewModel = StateObject(wrappedValue: HomeViewModel(user: user))
    }

    #if DEBUG
    init(preview viewModel: HomeViewModel) {
        self.user = viewModel.user
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                hlBg.ignoresSafeArea()
                dotGrid.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    if viewModel.isLoading {
                        shimmerGrid
                    } else if let error = viewModel.errorMessage {
                        errorView(error)
                    } else {
                        feedScroll
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { bookId in
                BookDetailView(bookId: bookId, user: user)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView(activities: viewModel.friendsActivities, user: user)
                    .onAppear { viewModel.markActivitiesViewed() }
            }
        }
        .environment(\.colorScheme, .light)   // home page is light-mode only
        .preferredColorScheme(.light)
    }

    // MARK: - Header (cursive wordmark + actions)

    private var header: some View {
        HStack(alignment: .center) {
            Text("PaperBoxd")
                .font(PB.wordmark(30))
                .foregroundStyle(hlInk)
            Spacer()
            HStack(spacing: 8) {
            Button { showWrite = true } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(hlInk)
                    .frame(width: 44, height: 44)
                    .background(hlCard)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Button { showNotifications = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(hlInk)
                        .frame(width: 44, height: 44)
                        .background(hlCard)
                        .clipShape(Circle())
                    if viewModel.hasNewActivities {
                        Circle()
                            .fill(PB.terracotta)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().strokeBorder(hlBg, lineWidth: 2))
                            .offset(x: -3, y: 3)
                    }
                }
            }
            .buttonStyle(.plain)
            } // HStack (write + bell)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(hlBg.opacity(0.95))
        .fullScreenCover(isPresented: $showWrite) {
            WriteView(username: user.username ?? "")
        }
    }

    // MARK: - Background

    private var dotGrid: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 26, dot: CGFloat = 1.5
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)),
                             with: .color(hlInk.opacity(0.05)))
                    y += spacing
                }
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Feed scroll

    private var feedScroll: some View {
        BrutalistRefreshable(onRefresh: { await viewModel.refresh() }) {
            VStack(alignment: .leading, spacing: 28) {
                greetingBlock.padding(.horizontal, 20).padding(.top, 12)

                if let lb = viewModel.lastLoggedBook {
                    // Brutalist currently-reading hero. The whole card opens the
                    // book detail, where PageProgressView logs today's pages.
                    NavigationLink(value: lb.bookID) {
                        BrutalReadingHero(book: lb)
                            .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)
                }

                if !viewModel.friendsActivities.isEmpty {
                    friendsRail
                }

                if !viewModel.pickedForYou.isEmpty {
                    carouselSection(
                        eyebrow: "For you",
                        title: "Your friends are liking these.",
                        items: viewModel.pickedForYou
                    )
                }

                if !viewModel.freshShelves.isEmpty {
                    carouselSection(
                        eyebrow: "This week",
                        title: "Newly published.",
                        items: viewModel.freshShelves
                    )
                }

            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Friends rail

    private var friendsRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(text: "Your friends").padding(.horizontal, 20)
                Text("Between covers.")
                    .font(PB.serif(18)).foregroundStyle(hlInk)
                    .padding(.horizontal, 20)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.friendsActivities.prefix(6)) { activity in
                        friendCard(activity)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // Brutalist friend card — always light, ink border + hard offset shadow.
    private func friendCard(_ a: FriendActivity) -> some View {
        let card = Color(red: 0.992, green: 0.984, blue: 0.965)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    if let urlStr = a.avatarURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            PB.avatarGradient
                        }
                    } else {
                        PB.avatarGradient
                    }
                }
                .frame(width: 24, height: 24)
                .clipShape(Rectangle())
                .overlay(Rectangle().strokeBorder(BK.ink, lineWidth: 1))

                Text(a.displayName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(BK.ink)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            Group {
                Text(a.verbPhrase + " ")
                    .font(.system(size: 11.5))
                    .foregroundStyle(BK.muted)
                +
                Text(a.objectTitle ?? "")
                    .font(.system(size: 11.5, design: .serif).italic())
                    .foregroundStyle(BK.ink)
            }
            .lineLimit(2)

            Text(a.relativeTime)
                .font(PB.mono(9.5)).tracking(0.5)
                .foregroundStyle(BK.muted)
        }
        .padding(12)
        .frame(width: 162)
        .background(card)
        .overlay(Rectangle().strokeBorder(BK.ink, lineWidth: 1.5))
        .background(alignment: .topLeading) {
            Rectangle().fill(BK.ink).offset(x: 4, y: 4)
        }
        .padding(.trailing, 4).padding(.bottom, 4) // room for the offset shadow
    }

    // MARK: - Greeting

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hello, \(user.username ?? "reader")")
                .font(PB.serif(26))
                .foregroundStyle(hlInk)
            Text("what are you reading?")
                .font(PB.serifItalic(22, .regular))
                .foregroundStyle(hlMuted)
        }
    }

    // MARK: - Carousels

    private func carouselSection(eyebrow: String, title: String, items: [RecommendationItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(eyebrow: eyebrow, title: title, titleColor: hlInk, eyebrowColor: hlMuted)
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { item in
                        NavigationLink(value: item.id) {
                            CarouselCoverCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Shimmer + error

    private var shimmerGrid: some View {
        ScrollView {
            VStack(spacing: 20) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(hlCard)
                    .frame(height: 120).pbShimmer()
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(0..<9, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 6).fill(hlCard)
                            .aspectRatio(2/3, contentMode: .fit).pbShimmer()
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(message)
                .font(PB.serifItalic(14))
                .foregroundStyle(hlMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry") { Task { await viewModel.load() } }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(hlAccent)
            Spacer()
        }
    }
}

// MARK: - Carousel card

private struct CarouselCoverCard: View {
    let item: RecommendationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BookCoverView(url: item.coverURL, width: 108, cornerRadius: 6)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(PB.serif(13))
                    .foregroundStyle(BK.ink)
                    .lineLimit(2)
                if !item.authors.isEmpty {
                    Text(item.authorLine)
                        .font(.system(size: 11))
                        .foregroundStyle(BK.muted)
                        .lineLimit(1)
                }
            }
            .frame(width: 108, alignment: .leading)
        }
    }
}

private struct ShimmerCardView: View {
    @State private var opacity: Double = 0.3
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(BK.paper2)
                .aspectRatio(2.0/3.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(BK.paper2).frame(maxWidth: .infinity, minHeight: 12, maxHeight: 12)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(BK.paper2).frame(width: 80, height: 10)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                opacity = 0.75
            }
        }
    }
}

private struct PlaceholderItem: Identifiable {
    let id: Int
}
