#if DEBUG
import SwiftUI

// Open this file in Xcode and press ⌥⌘↩ (Option+Cmd+Return) to show the canvas.
// Each preview below renders a screen with mock data — no network calls.

#Preview("Splash") {
    SplashView()
        .environmentObject(AppState())
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
    ShareComposition(
        title: "Norwegian Wood",
        author: "Haruki Murakami",
        year: "1987",
        rating: 4.5,
        note: "Loved the rain scene. A whole evening lost — happily.",
        coverImage: nil,
        accent: Color(red: 0.30, green: 0.20, blue: 0.42),
        handle: "@hridyesh",
        status: .finished,
        theme: .dark,
        format: .story
    )
    .scaleEffect(0.36)
}

#Preview("Share card — Square") {
    ShareComposition(
        title: "Piranesi",
        author: "Susanna Clarke",
        year: "2020",
        rating: 4,
        note: "The Beauty of the House is immeasurable, its Kindness infinite.",
        coverImage: nil,
        accent: Color(red: 0.20, green: 0.30, blue: 0.34),
        handle: "@hridyesh",
        status: .favourite,
        theme: .light,
        format: .square
    )
    .scaleEffect(0.46)
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
            onMessage: {},
            onEdit: {},
            onShare: {},
            onFollowers: {},
            onFollowing: {}
        )
    }
    .background(Color("Background"))
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

