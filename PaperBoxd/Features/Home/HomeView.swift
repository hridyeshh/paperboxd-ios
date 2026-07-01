import SwiftUI

struct HomeView: View {
    let user: User
    @StateObject private var viewModel: HomeViewModel
    @State private var showNotifications = false
    @State private var showWrite = false

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
                Color("Background").ignoresSafeArea()
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
    }

    // MARK: - Header (cursive wordmark + actions)

    private var header: some View {
        HStack(alignment: .center) {
            Text("PaperBoxd")
                .font(PB.wordmark(30))
                .foregroundStyle(Color("TextPrimary"))
            Spacer()
            HStack(spacing: 8) {
            Button { showWrite = true } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color("TextPrimary"))
                    .frame(width: 44, height: 44)
                    .background(Color("Surface"))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Button { showNotifications = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Color("TextPrimary"))
                        .frame(width: 44, height: 44)
                        .background(Color("Surface"))
                        .clipShape(Circle())
                    if viewModel.hasNewActivities {
                        Circle()
                            .fill(PB.terracotta)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().strokeBorder(Color("Background"), lineWidth: 2))
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
        .background(Color("Background").opacity(0.95))
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
                             with: .color(.white.opacity(0.04)))
                    y += spacing
                }
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Feed scroll

    private var feedScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                greetingBlock.padding(.horizontal, 20).padding(.top, 12)

                if let lb = viewModel.lastLoggedBook {
                    VStack(spacing: 10) {
                        NavigationLink(value: lb.bookID) {
                            LastLoggedBookCard(book: lb)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)

                        // Opens the book detail, where PageProgressView lets the
                        // user log today's pages.
                        NavigationLink(value: lb.bookID) {
                            HStack(spacing: 6) {
                                Text("Log today's pages")
                                    .font(.system(size: 14, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color("Background"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color("TextPrimary"), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }
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
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Friends rail

    private var friendsRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(text: "Your friends").padding(.horizontal, 20)
                Text("Between covers.")
                    .font(PB.serif(18)).foregroundStyle(Color("TextPrimary"))
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

    private func friendCard(_ a: FriendActivity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                .clipShape(Circle())

                Text(a.displayName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color("TextPrimary"))
                    .lineLimit(1)

                Spacer(minLength: 0)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color("Surface"))
                    .frame(width: 14, height: 21)
            }

            Group {
                Text(a.verbPhrase + " ")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color("TextSecondary"))
                +
                Text(a.objectTitle ?? "")
                    .font(.system(size: 11.5, design: .serif).italic())
                    .foregroundStyle(Color("TextPrimary"))
            }
            .lineLimit(2)

            Text(a.relativeTime)
                .font(PB.mono(9.5)).tracking(0.5)
                .foregroundStyle(Color("TextSecondary"))
        }
        .padding(12)
        .frame(width: 162)
        .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color("Border"), lineWidth: 1))
    }

    // MARK: - Greeting

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hello, \(user.username ?? "reader")")
                .font(PB.serif(26))
                .foregroundStyle(Color("TextPrimary"))
            Text("what are you reading?")
                .font(PB.serifItalic(22, .regular))
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    // MARK: - Carousels

    private func carouselSection(eyebrow: String, title: String, items: [RecommendationItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(eyebrow: eyebrow, title: title)
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
                    .fill(Color("Surface"))
                    .frame(height: 120).pbShimmer()
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(0..<9, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 6).fill(Color("Surface"))
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
                .foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry") { Task { await viewModel.load() } }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color("Accent"))
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
                    .foregroundStyle(Color("TextPrimary"))
                    .lineLimit(2)
                if !item.authors.isEmpty {
                    Text(item.authorLine)
                        .font(.system(size: 11))
                        .foregroundStyle(Color("TextSecondary"))
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
                .fill(Color("Surface"))
                .aspectRatio(2.0/3.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color("Surface")).frame(maxWidth: .infinity, minHeight: 12, maxHeight: 12)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color("Surface")).frame(width: 80, height: 10)
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
