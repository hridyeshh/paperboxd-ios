#if DEBUG
import SwiftUI

// Open this file in Xcode and press ⌥⌘↩ (Option+Cmd+Return) to show the canvas.
// Each preview below renders a screen with mock data — no network calls.

#Preview("Splash") {
    SplashView()
        .environmentObject(AppStaty ye())
}

#Preview("Auth — Login") {
    AuthContainerView()
        .environmentObject(AppState())
}

#Preview("Auth — Login only") {
    ZStack {
        Color(red: 0.09, green: 0.09, blue: 0.09).ignoresSafeArea()
        LoginView(viewModel: AuthViewModel())
    }
}

#Preview("Auth — Register") {
    ZStack {
        Color(red: 0.09, green: 0.09, blue: 0.09).ignoresSafeArea()
        RegisterView(viewModel: {
            let vm = AuthViewModel()
            vm.mode = .register
            return vm
        }())
    }
}

#Preview("Onboarding") {
    OnboardingContainerView(user: PreviewData.user)
        .environmentObject(AppState())
}

#Preview("Home") {
    HomeView(preview: .preview())
}

#Preview("Search") {
    SearchView(viewer: PreviewData.user, preview: .preview())
}

#Preview("Profile — Own") {
    ProfileView(preview: .preview(isOwn: true))
}

#Preview("Profile — Other user") {
    ProfileView(preview: .preview(isOwn: false))
}

#Preview("Book detail") {
    NavigationStack {
        BookDetailView(preview: .preview())
    }
}

#Preview("Leaderboard") {
    LeaderboardView(preview: .preview())
}

#Preview("Share sheet") {
    BookShareSheet(
        book: PreviewData.book(title: "Norwegian Wood", id: "book-norwegian-wood"),
        user: PreviewData.user
    )
}

#Preview("Share card — Story") {
    BookShareCardView(
        title: "Norwegian Wood",
        author: "Haruki Murakami",
        year: "1987",
        handle: "@hridyesh",
        rating: 4,
        note: "Loved the rain scene. A whole evening lost — happily.",
        statusLabel: "Just finished",
        format: .story
    )
    .scaleEffect(0.42)
}

#Preview("Share card — Quote · Terra") {
    BookShareCardView(
        title: "Beloved",
        author: "Toni Morrison",
        year: "1987",
        handle: "@hridyesh",
        rating: 5,
        note: "Read it twice. Will read it again. Then again.",
        statusLabel: "Favourite of 2026",
        ground: .terra,
        layout: .quote,
        format: .story
    )
    .scaleEffect(0.42)
}

#Preview("Share card — Square · Paper") {
    BookShareCardView(
        title: "Piranesi",
        author: "Susanna Clarke",
        year: "2020",
        handle: "@hridyesh",
        rating: 5,
        note: nil,
        statusLabel: "Just finished",
        ground: .paper,
        format: .square
    )
    .scaleEffect(0.5)
}

#Preview("Main tabs") {
    MainTabView(user: PreviewData.user)
        .environmentObject(AppState())
}

#Preview("Profile header") {
    ScrollView {
        ProfileHeaderView(
            profile: PreviewData.profile,
            isOwnProfile: true,
            isFollowLoading: false,
            streak: 12,
            bannerCovers: [],
            onFollow: {},
            onEdit: {},
            onSettings: {},
            onFollowers: {},
            onFollowing: {}
        )
    }
    .background(Color("Backgroundha"))
}

#Preview("Currently reading card") {
    LastLoggedBookCard(book: PreviewData.lastLoggedBook)
        .padding()
        .background(Color("Background"))
}

#Preview("Favourites row") {
    FavouriteFourView(books: PreviewData.favorites, title: "Four books I love.")
        .padding()
        .background(Color("Background"))
}
#endif

