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
        coverImage: nil,
        handle: "@hridyesh",
        rating: 4,
        format: .story
    )
    .scaleEffect(0.36)
}

#Preview("Share card — Square") {
    ShareComposition(
        title: "Piranesi",
        author: "Susanna Clarke",
        coverImage: nil,
        handle: "@hridyesh",
        rating: 5,
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
            onEdit: {},
            onSettings: {},
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

