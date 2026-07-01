import SwiftUI

struct ProfileView: View {
    @StateObject private var vm: ProfileViewModel
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var shareItem: ShareItem?
    @State private var showEdit = false
    @State private var showBannerPicker = false
    @State private var bannerCropTarget: CropTarget?
    @Environment(\.dismiss) private var dismiss

    init(username: String, viewer: User) {
        _vm = StateObject(wrappedValue: ProfileViewModel(username: username, viewer: viewer))
    }

    #if DEBUG
    init(preview viewModel: ProfileViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }
    #endif

    var body: some View {
        ZStack(alignment: .top) {
            Color("Background").ignoresSafeArea()
            content
            topBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: String.self) { bookId in
            BookDetailView(bookId: bookId, user: vm.viewerUser)
        }
        .overlay(alignment: .bottom) {
            if let toast = vm.toastMessage {
                toastChip(toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            vm.toastMessage = nil
                        }
                    }
            }
        }
        .sheet(isPresented: $showFollowers) {
            NavigationStack {
                FollowListView(username: vm.profileUsername, mode: .followers) { _ in }
            }
        }
        .sheet(isPresented: $showFollowing) {
            NavigationStack {
                FollowListView(username: vm.profileUsername, mode: .following) { _ in }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showEdit) {
            if let profile = vm.profile {
                EditProfileView(profile: profile) {
                    Task { await vm.fetchAll() }
                }
            }
        }
        .sheet(isPresented: $showBannerPicker) {
            // Pick the raw image (no square crop), then crop wide in Mantis.
            ImagePicker(source: .photoLibrary, allowsEditing: false) { image in
                bannerCropTarget = CropTarget(image: image)
            }
        }
        .fullScreenCover(item: $bannerCropTarget) { target in
            ImageCropper(image: target.image, ratio: 2.3) { cropped in
                guard let data = cropped.avatarJPEGData(maxDimension: 1600) else { return }
                Task { await vm.uploadBanner(data) }
            }
        }
    }

    private func shareProfile() {
        guard let url = URL(string: "https://paperboxd.app/u/\(vm.profileUsername)") else { return }
        shareItem = ShareItem(url: url)
    }

    // MARK: - Top floating bar (wordmark + actions)

    private var topBar: some View {
        HStack {
            if vm.isOwnProfile {
                Color.clear.frame(width: 36, height: 36)
            } else {
                circleButton(systemName: "chevron.left") { dismiss() }
            }
            Spacer()
            Text("PaperBoxd")
                .font(PB.wordmark(22))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
            Spacer()
            // right side intentionally empty (settings + ellipsis removed)
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func circleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.55))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.profile == nil {
            ProgressView().tint(Color("Accent")).frame(maxHeight: .infinity)
        } else if let err = vm.errorMessage, vm.profile == nil {
            errorView(err)
        } else if let profile = vm.profile {
            ScrollView {
                VStack(spacing: 0) {
                    ProfileHeaderView(
                        profile: profile,
                        isOwnProfile: vm.isOwnProfile,
                        isFollowLoading: vm.isFollowLoading,
                        streak: vm.streak,
                        bannerCovers: bannerCoverURLs,
                        onFollow: { Task { await vm.toggleFollow() } },
                        onMessage: { },
                        onEdit: { showEdit = true },
                        onShare: shareProfile,
                        onFollowers: { showFollowers = true },
                        onFollowing: { showFollowing = true },
                        onEditBanner: vm.isOwnProfile ? { showBannerPicker = true } : nil
                    )

                    if vm.lastLoggedBook != nil || vm.isOwnProfile {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: vm.isOwnProfile ? "Currently reading" : "\(firstName(of: profile)) is reading")
                                .padding(.horizontal, 20)
                            if let lb = vm.lastLoggedBook {
                                NavigationLink(value: lb.bookID) {
                                    LastLoggedBookCard(book: lb)
                                        .padding(.horizontal, 20)
                                }
                                .buttonStyle(.plain)
                            } else {
                                LastLoggedEmptyCard()
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 28)
                    }

                    if !vm.favoriteBooks.isEmpty {
                        FavouriteFourView(
                            books: vm.favoriteBooks,
                            title: vm.isOwnProfile ? "Four books I love." : "\(firstName(of: profile))'s four."
                        )
                        .padding(.top, 28)
                    }

                    ProfileDockView(
                        selected: $vm.selectedTab,
                        count: tabCount,
                        onSelect: vm.onTabSelected
                    )
                    .padding(.top, 24)

                    tabContent

                    EditorialSignatureView(profile: profile)
                        .padding(.top, 28)
                        .padding(.bottom, 24)
                }
            }
            .refreshable { await vm.fetchAll() }
        }
    }

    private var bannerCoverURLs: [String] {
        vm.favoriteBooks.compactMap { $0.coverURL }
    }

    private func firstName(of profile: UserProfile) -> String {
        profile.displayName.split(separator: " ").first.map(String.init) ?? profile.username
    }

    private func tabCount(_ tab: ProfileTab) -> Int? {
        guard let p = vm.profile else { return nil }
        switch tab {
        case .bookshelf: return p.booksReadCount
        case .diary:     return p.diaryEntriesCount
        case .lists:     return p.listsCount
        case .dnf:       return vm.dnfItems.isEmpty ? nil : vm.dnfItems.count
        case .authors:   return vm.authors.isEmpty ? nil : vm.authors.count
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch vm.selectedTab {
        case .bookshelf:
            ShelfGridView(
                books: vm.shelfBooks,
                isLoading: vm.isLoadingShelf,
                onAppearItem: { await vm.fetchShelfIfNeeded(item: $0) },
                onTapBook: { _ in }
            )
        case .diary:
            DiaryListView(
                entries: vm.diaryEntries,
                isLoading: vm.isLoadingDiary,
                onAppearItem: { await vm.fetchDiaryIfNeeded(item: $0) }
            )
        case .lists:
            ListsTabView(ownLists: vm.ownLists, savedLists: vm.savedLists)
        case .dnf:
            TBRListView(
                items: vm.dnfItems,
                isLoading: vm.isLoadingDNF,
                emptyMessage: "No unfinished books"
            )
        case .authors:
            AuthorsListView(authors: vm.authors, isLoading: vm.isLoadingAuthors)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 40)).foregroundStyle(Color("TextSecondary"))
            Text(msg)
                .font(PB.serifItalic(14))
                .foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await vm.retry() } }
                .foregroundStyle(Color("Accent"))
        }
        .padding(32)
        .frame(maxHeight: .infinity)
    }

    private func toastChip(_ msg: String) -> some View {
        Text(msg)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(white: 0.15).opacity(0.95))
            .clipShape(Capsule())
            .padding(.bottom, 100)
    }
}

// MARK: - Share

struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
