import SwiftUI

struct BookDetailView: View {
    let bookId: String
    let user: User

    @StateObject private var viewModel: BookDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var descriptionExpanded = false
    @State private var selectedTab = 0
    @State private var showShare = false
    @State private var showWrite = false

    private let tabs = ["Overview", "Reviews", "Highlights", "Lists"]

    private var shareStatus: ShareStatus {
        if viewModel.bookState.isLiked { return .favourite }
        if viewModel.bookState.isRead { return .finished }
        if viewModel.bookState.isTBR { return .want }
        return .reading
    }

    init(bookId: String, user: User) {
        self.bookId = bookId
        self.user = user
        _viewModel = StateObject(wrappedValue: BookDetailViewModel(bookId: bookId, user: user))
    }

    #if DEBUG
    init(preview viewModel: BookDetailViewModel) {
        self.bookId = viewModel.bookId
        self.user = viewModel.user
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    #endif

    var body: some View {
        ZStack(alignment: .bottom) {
            Color("Background").ignoresSafeArea()

            VStack(spacing: 0) {
                miniHeader

                if viewModel.isLoading {
                    loadingView
                } else if let book = viewModel.book {
                    content(book)
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                }
            }

            if viewModel.book != nil {
                bottomBar
            }
        }
        .navigationBarHidden(true)
        .overlay(toastOverlay, alignment: .bottom)
        .hidesBottomDock()
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showShare) {
            if let book = viewModel.book {
                BookShareSheet(book: book, user: user, status: shareStatus)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
        }
        .fullScreenCover(isPresented: $showWrite) {
            if let book = viewModel.book {
                WriteView(username: user.username ?? "", preselectedBook: book)
            }
        }
    }

    // MARK: - Mini header

    private var miniHeader: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color("TextPrimary"))
                    .frame(width: 30, height: 30)
                    .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer()

            if let book = viewModel.book, !book.categories.isEmpty {
                Text(book.categories.prefix(2).joined(separator: " · "))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color("TextSecondary"))
                    .lineLimit(1)
            }

            Spacer()

            Button { showWrite = true } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color("TextPrimary"))
                    .frame(width: 30, height: 30)
                    .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color("Background"))
        .overlay(alignment: .bottom) { Rectangle().fill(Color("Border")).frame(height: 1) }
    }

    // MARK: - Scroll content

    private func content(_ book: Book) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection(book)
                friendsReadingRow
                progressCard
                tabBar
                tabContent(book)
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Hero

    private func heroSection(_ book: Book) -> some View {
        VStack(spacing: 0) {
            // Cover + title + author over gradient halo
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [PB.terracotta.opacity(0.12), Color("Background").opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 320)

                VStack(spacing: 0) {
                    BookCoverView(url: book.coverURL, width: 140, cornerRadius: 8)
                        .shadow(color: .black.opacity(0.32), radius: 22, y: 12)
                        .padding(.top, 22)
                        .padding(.bottom, 16)

                    Text(book.title)
                        .font(.system(size: 26, weight: .heavy, design: .serif))
                        .tracking(-0.4)
                        .foregroundStyle(Color("TextPrimary"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 24)

                    if let tagline = bookTagline(book) {
                        Text(tagline)
                            .font(PB.serifItalic(14))
                            .foregroundStyle(Color("TextSecondary"))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.top, 6)
                            .padding(.horizontal, 36)
                    }

                    if !book.authorLine.isEmpty {
                        (Text("by ").foregroundStyle(Color("TextSecondary"))
                         + Text(book.authorLine).fontWeight(.semibold).foregroundStyle(Color("TextPrimary")))
                            .font(.system(size: 12))
                            .padding(.top, 10)
                    }
                }
            }

            // 3-stat strip — Rating · Time to read · Pages
            HStack(spacing: 0) {
                statCell(
                    value: book.averageRating.map { String(format: "%.1f", $0) } ?? "—",
                    label: "★ Rating"
                )
                Divider().frame(height: 28).opacity(0.4)
                statCell(
                    value: readingTime(book),
                    label: "Time to read"
                )
                Divider().frame(height: 28).opacity(0.4)
                statCell(
                    value: book.pageCount.map { "\($0)" } ?? "—",
                    label: "Pages"
                )
            }
            .padding(.vertical, 14)
            .overlay(alignment: .top) { Rectangle().fill(Color("Border")).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(Color("Border")).frame(height: 1) }

            // Genre pills (kept — they were good)
            if !book.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(book.categories.prefix(5).enumerated()), id: \.offset) { _, cat in
                            Text(cat)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color("TextSecondary"))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color("Surface"), in: Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
            }
        }
    }

    private func bookTagline(_ book: Book) -> String? {
        guard let desc = book.description else { return nil }
        // Use first sentence as tagline if short enough
        let firstSentence = desc.split(whereSeparator: { ".!?".contains($0) }).first.map(String.init) ?? desc
        let trimmed = firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 20, trimmed.count < 140 else { return nil }
        return trimmed + "."
    }

    /// Estimated time to read, derived from page count at ~40 pages/hour —
    /// matches the web book page's readTime calculation.
    private func readingTime(_ book: Book) -> String {
        guard let pages = book.pageCount, pages > 0 else { return "—" }
        let totalMin = Int((Double(pages) / 40.0 * 60.0).rounded())
        let h = totalMin / 60
        let m = totalMin % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Color("TextSecondary"))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Friends-reading row

    @ViewBuilder
    private var friendsReadingRow: some View {
        if !viewModel.friendsOnBook.isEmpty {
            HStack(spacing: 9) {
                HStack(spacing: -6) {
                    ForEach(viewModel.friendsOnBook.prefix(4)) { friend in
                        avatarBadge(friend)
                    }
                }
                Text(friendsReadingCopy)
                    .font(.system(size: 12))
                    .foregroundStyle(Color("TextSecondary"))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
        }
    }

    private func avatarBadge(_ friend: FriendOnBook) -> some View {
        ZStack {
            if let urlStr = friend.avatarURL,
               let url = URL(string: urlStr.replacingOccurrences(of: "http://", with: "https://")) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: PB.avatarGradient
                    }
                }
            } else {
                PB.avatarGradient
                Text(friend.displayName.prefix(1).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color("Background"), lineWidth: 2))
    }

    private var friendsReadingCopy: String {
        let activeCount = viewModel.friendsReadingCount
        if activeCount > 0 {
            return "\(activeCount) friend\(activeCount == 1 ? "" : "s") reading now"
        }
        let n = viewModel.friendsOnBook.count
        return "\(n) of your friends"
    }

    // MARK: - Progress card

    @ViewBuilder
    private var progressCard: some View {
        if let book = viewModel.book {
            VStack(spacing: 12) {
                if book.pageCount != nil || (viewModel.progress?.onShelf ?? false) {
                    PageProgressView(
                        progress: viewModel.progress,
                        bookPageCount: book.pageCount,
                        isSaving: viewModel.isSavingProgress,
                        onUpdate: { cp, tp in await viewModel.updateProgress(currentPage: cp, totalPages: tp) }
                    )
                }
                writeAboutButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
        }
    }

    private var writeAboutButton: some View {
        Button { showWrite = true } label: {
            HStack(spacing: 7) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .semibold))
                Text("Write about it")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Color("Background"))
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(Color("TextPrimary"), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabs.indices, id: \.self) { i in
                    Button {
                        selectedTab = i
                    } label: {
                        VStack(spacing: 0) {
                            HStack(spacing: 5) {
                                Text(tabs[i])
                                    .font(.system(size: 13, weight: selectedTab == i ? .semibold : .medium))
                                    .foregroundStyle(selectedTab == i ? Color("TextPrimary") : Color("TextSecondary"))
                                if let cnt = tabCount(for: i) {
                                    Text(cnt)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color("TextSecondary"))
                                        .padding(.horizontal, 6).padding(.vertical, 1)
                                        .background(Color("Surface"), in: Capsule())
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            Rectangle()
                                .fill(selectedTab == i ? Color("TextPrimary") : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Color("Border")).frame(height: 1) }
    }

    private func tabCount(for index: Int) -> String? {
        switch index {
        case 1:
            let n = viewModel.friendReviews.count
            return n > 0 ? "\(n)" : nil
        default:
            return nil
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private func tabContent(_ book: Book) -> some View {
        switch selectedTab {
        case 0: overviewTab(book)
        default:
            VStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 28)).foregroundStyle(Color("TextSecondary").opacity(0.5))
                Text("Coming soon")
                    .font(PB.serifItalic(14)).foregroundStyle(Color("TextSecondary"))
            }
            .frame(maxWidth: .infinity).padding(.top, 60)
        }
    }

    private func overviewTab(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let desc = book.description {
                VStack(alignment: .leading, spacing: 10) {
                    Text(desc)
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(Color("TextPrimary").opacity(0.88))
                        .lineSpacing(5)
                        .lineLimit(descriptionExpanded ? nil : 6)

                    if desc.count > 280 {
                        Button(descriptionExpanded ? "Show less" : "Read full description →") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                descriptionExpanded.toggle()
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color("Accent"))
                    }
                }
                .padding(16)

                Rectangle().fill(Color("Border")).frame(height: 1).padding(.horizontal, 16)
            }

            if !viewModel.similarBooks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Readers also enjoyed")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .tracking(-0.2)
                        .foregroundStyle(Color("TextPrimary"))
                        .padding(.horizontal, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(viewModel.similarBooks) { item in
                                NavigationLink(value: item.id) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        BookCoverView(url: item.coverURL, width: 88, cornerRadius: 6)
                                        Text(item.title)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Color("TextPrimary"))
                                            .lineLimit(2).frame(width: 88, alignment: .leading)
                                        if !item.authors.isEmpty {
                                            Text(item.authorLine)
                                                .font(.system(size: 10))
                                                .foregroundStyle(Color("TextSecondary"))
                                                .lineLimit(1).frame(width: 88, alignment: .leading)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)

                Rectangle().fill(Color("Border")).frame(height: 1).padding(.horizontal, 16)
            }

            // "What friends say" — real friend reviews
            VStack(alignment: .leading, spacing: 12) {
                Text("What friends say")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .tracking(-0.2)
                    .foregroundStyle(Color("TextPrimary"))

                if viewModel.friendReviews.isEmpty {
                    Text("No reviews from people you follow yet.")
                        .font(PB.serifItalic(13))
                        .foregroundStyle(Color("TextSecondary"))
                } else {
                    VStack(spacing: 14) {
                        ForEach(viewModel.friendReviews.prefix(5)) { review in
                            friendReviewRow(review)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func friendReviewRow(_ review: FriendBookReview) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                if let urlStr = review.avatarURL,
                   let url = URL(string: urlStr.replacingOccurrences(of: "http://", with: "https://")) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: PB.avatarGradient
                        }
                    }
                } else {
                    PB.avatarGradient
                    Text(review.displayName.prefix(1).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(review.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color("TextPrimary"))
                    if let rating = review.rating, rating > 0 {
                        Text(starsString(rating))
                            .font(.system(size: 11))
                            .foregroundStyle(PB.terracotta)
                    }
                }
                if let text = review.review {
                    Text(text)
                        .font(.system(size: 13.5, design: .serif))
                        .foregroundStyle(Color("TextPrimary").opacity(0.88))
                        .lineSpacing(3)
                        .lineLimit(5)
                }
            }
        }
    }

    private func starsString(_ rating: Int) -> String {
        let n = max(0, min(rating, 5))
        return String(repeating: "★", count: n) + String(repeating: "☆", count: 5 - n)
    }

    // MARK: - Bottom action bar

    private var bottomBar: some View {
        HStack(spacing: 8) {
            // Like — no border
            Button { Task { await viewModel.toggleLike() } } label: {
                Image(systemName: viewModel.bookState.isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 17))
                    .foregroundStyle(viewModel.bookState.isLiked ? PB.likeRed : Color("TextPrimary"))
                    .frame(width: 44, height: 44)
                    .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            // Mark as Reading — reduced, hugs its content
            Button {
                Task { await viewModel.toggleRead() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.bookState.isRead ? "checkmark" : "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text(primaryLabel)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(Color("Background"))
                .padding(.horizontal, 16).frame(maxWidth: .infinity).frame(height: 44)
                .background(Color("TextPrimary"), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)

            // TBR — labeled
            Button { Task { await viewModel.toggleTBR() } } label: {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.bookState.isTBR ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14))
                    Text("TBR").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(viewModel.bookState.isTBR ? Color("Accent") : Color("TextPrimary"))
                .padding(.horizontal, 12).frame(height: 44)
                .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(viewModel.bookState.isTBR ? Color("Accent") : Color("Border"), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Share
            actionIcon(icon: "square.and.arrow.up", active: false) { showShare = true }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 26)
        .background(Color("Background").opacity(0.97))
        .overlay(alignment: .top) { Rectangle().fill(Color("Border")).frame(height: 1) }
    }

    private func actionIcon(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(active ? Color("Accent") : Color("TextPrimary"))
                .frame(width: 44, height: 44)
                .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(active ? Color("Accent") : Color("Border"), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var primaryLabel: String {
        if viewModel.bookState.isRead { return "Read ✓" }
        if viewModel.bookState.isTBR { return "Want to Read" }
        return "Mark as Reading"
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack { Spacer(); ProgressView().tint(Color("Accent")); Spacer() }
            .frame(maxWidth: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(message).font(.system(size: 14)).foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Retry") { Task { await viewModel.retry() } }
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color("Accent"))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = viewModel.toastMessage {
            Text(msg)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(white: 0.15), in: Capsule())
                .padding(.bottom, 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    Task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        withAnimation { viewModel.toastMessage = nil }
                    }
                }
        }
    }
}
