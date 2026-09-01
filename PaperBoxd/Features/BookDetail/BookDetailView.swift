import SwiftUI

struct BookDetailView: View {
    let bookId: String
    let user: User

    @StateObject private var viewModel: BookDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var descriptionExpanded = false
    @State private var showShare = false
    @State private var showWrite = false
    @State private var showLibrarySheet = false
    @State private var activePanel: InlinePanel?
    @State private var likePulse = 0
    @State private var reportReviewTarget: BookReview?

    /// Inline drop-down panels below the action row.
    private enum InlinePanel { case rate, review }

    private let line = BK.ink

    /// The book's status for the share card, mirroring the shelf state. `nil`
    /// when the book isn't in the user's library — the card then hides the badge.
    private var shareStatus: ShareStatus? {
        if viewModel.bookState.isRead { return .finished }
        if viewModel.bookState.isOnShelf { return .reading }
        if viewModel.bookState.isTBR { return .want }
        if viewModel.bookState.isLiked { return .favourite }
        return nil
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
            BK.paper.ignoresSafeArea()

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
                bottomDock
            }
        }
        .environment(\.colorScheme, .light)   // book page is light-mode only
        .preferredColorScheme(.light)
        .navigationBarHidden(true)
        .overlay(toastOverlay, alignment: .bottom)
        .hidesBottomDock()
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog(
            "Report review",
            isPresented: Binding(
                get: { reportReviewTarget != nil },
                set: { if !$0 { reportReviewTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(ModerationService.reportReasons, id: \.self) { reason in
                Button(reason) {
                    guard let target = reportReviewTarget else { return }
                    Task {
                        try? await ModerationService.report(
                            contentType: "review",
                            contentID: "book:\(bookId):user:\(target.userID)",
                            reason: reason
                        )
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showShare) {
            if let book = viewModel.book {
                BookShareSheet(book: book, user: user, status: shareStatus, userRating: viewModel.myReview?.rating, note: viewModel.myReview?.review)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
        }
        .fullScreenCover(isPresented: $showWrite) {
            if let book = viewModel.book {
                WriteView(username: user.username ?? "", preselectedBook: book)
            }
        }
        .sheet(isPresented: $showLibrarySheet) {
            AddToLibrarySheet(current: viewModel.currentShelf) { target in
                showLibrarySheet = false
                Task { await viewModel.selectShelf(target) }
            }
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.hidden)
            .environment(\.colorScheme, .light)
        }
    }

    // MARK: - Mini header (brutalist)

    private var miniHeader: some View {
        HStack {
            squareIcon("chevron.left") { dismiss() }
            Spacer()
            if let book = viewModel.book, !book.categories.isEmpty {
                Text(book.categories.prefix(2).joined(separator: " · ").uppercased())
                    .font(PB.mono(9)).tracking(1.5)
                    .foregroundStyle(BK.muted)
                    .lineLimit(1)
            }
            Spacer()
            squareIcon("square.and.pencil") { showWrite = true }
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background(BK.paper)
        .overlay(alignment: .bottom) { Rectangle().fill(line).frame(height: 2) }
    }

    private func squareIcon(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(BK.ink)
                .frame(width: 36, height: 36)
                .overlay(Rectangle().strokeBorder(line, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scroll content

    private func content(_ book: Book) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                coverBlock(book)
                titleBlock(book)
                statStrip(book)

                VStack(spacing: 16) {
                    progressCard
                    actionRow
                    inlinePanel
                    descriptionSection(book)
                    similarSection
                    friendsSaySection
                    reviewsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
            }
            .padding(.bottom, 120)
            // Pin content to the scroll viewport width. On iOS 17/18 a horizontal
            // ScrollView (Readers also enjoyed) nested in this vertical ScrollView
            // can report an oversized width, stretching the whole column and
            // shifting/clipping every row. This hard frame stops that.
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.horizontal)
        }
    }

    // MARK: - Cover + friends

    private func coverBlock(_ book: Book) -> some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(line)
                    .frame(width: 150, height: 225)
                    .offset(x: 8, y: 8)
                BookCoverView(url: book.coverURL, width: 150, cornerRadius: 0)
                    .overlay(Rectangle().strokeBorder(line, lineWidth: 2.5))
            }
            .padding(.trailing, 8).padding(.bottom, 8)

            if !viewModel.friendsOnBook.isEmpty {
                HStack(spacing: 8) {
                    HStack(spacing: -7) {
                        ForEach(viewModel.friendsOnBook.prefix(3)) { friend in
                            avatarBadge(friend)
                        }
                    }
                    Text(friendsReadingCopy.uppercased())
                        .font(PB.mono(9)).tracking(1)
                        .foregroundStyle(BK.ink)
                }
                .padding(.horizontal, 11).padding(.vertical, 6)
                .overlay(Rectangle().strokeBorder(line, lineWidth: 2))
            }
        }
        .padding(.top, 16)
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
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 20, height: 20)
        .overlay(Rectangle().strokeBorder(BK.paper, lineWidth: 1.5))
    }

    private var friendsReadingCopy: String {
        let activeCount = viewModel.friendsReadingCount
        if activeCount > 0 {
            return "\(activeCount) friend\(activeCount == 1 ? "" : "s") reading"
        }
        let n = viewModel.friendsOnBook.count
        return "\(n) of your friends"
    }

    // MARK: - Title block

    private func titleBlock(_ book: Book) -> some View {
        VStack(spacing: 8) {
            Text(book.title.uppercased())
                .font(.system(size: 30, weight: .black))
                .tracking(-1)
                .foregroundStyle(BK.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
                .padding(.horizontal, 20)

            if let tagline = bookTagline(book) {
                Text(tagline)
                    .font(PB.serifItalic(15))
                    .foregroundStyle(BK.ink.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 30)
            }

            if !book.authorLine.isEmpty {
                Text(book.authorLine.uppercased())
                    .font(PB.mono(10)).tracking(1.5)
                    .foregroundStyle(BK.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 16).padding(.bottom, 18)
    }

    // MARK: - Stat strip (brutalist)

    private func statStrip(_ book: Book) -> some View {
        HStack(spacing: 0) {
            statCell(book.averageRating.map { String(format: "%.1f", $0) } ?? "—", "Rating")
            Rectangle().fill(line).frame(width: 2)
            statCell(readingTime(book), "Time to read")
            Rectangle().fill(line).frame(width: 2)
            statCell(book.pageCount.map { "\($0)" } ?? "—", "Pages")
        }
        .frame(height: 62)
        .overlay(alignment: .top) { Rectangle().fill(line).frame(height: 2) }
        .overlay(alignment: .bottom) { Rectangle().fill(line).frame(height: 2) }
    }

    private func statCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .black))
                .tracking(-0.5)
                .foregroundStyle(BK.ink)
            Text(label.uppercased())
                .font(PB.mono(8)).tracking(1.2)
                .foregroundStyle(BK.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func bookTagline(_ book: Book) -> String? {
        guard let desc = book.description else { return nil }
        let firstSentence = desc.split(whereSeparator: { ".!?".contains($0) }).first.map(String.init) ?? desc
        let trimmed = firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 20, trimmed.count < 140 else { return nil }
        return trimmed + "."
    }

    private func readingTime(_ book: Book) -> String {
        guard let pages = book.pageCount, pages > 0 else { return "—" }
        let totalMin = Int((Double(pages) / 40.0 * 60.0).rounded())
        let h = totalMin / 60
        let m = totalMin % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    // MARK: - Progress card

    @ViewBuilder
    private var progressCard: some View {
        if let book = viewModel.book,
           book.pageCount != nil || (viewModel.progress?.onShelf ?? false) {
            PageProgressView(
                progress: viewModel.progress,
                bookPageCount: book.pageCount,
                isSaving: viewModel.isSavingProgress,
                onUpdate: { cp, tp in await viewModel.updateProgress(currentPage: cp, totalPages: tp) }
            )
        }
    }

    // MARK: - Action row (Review / Rate / Share)

    private var actionRow: some View {
        HStack(spacing: 8) {
            actionTile(icon: "square.and.pencil", label: "Review", active: activePanel == .review) {
                togglePanel(.review)
            }
            let rated = (viewModel.myReview?.rating ?? 0) > 0
            actionTile(
                icon: "star",
                label: rated ? "\(viewModel.myReview!.rating!)/5" : "Rate",
                active: activePanel == .rate || rated
            ) { togglePanel(.rate) }
            actionTile(icon: "square.and.arrow.up", label: "Share", active: false) { showShare = true }
        }
    }

    private func togglePanel(_ panel: InlinePanel) {
        withAnimation(.snappy(duration: 0.24, extraBounce: 0.08)) {
            activePanel = (activePanel == panel) ? nil : panel
        }
    }

    private func actionTile(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .medium))
                Text(label.uppercased())
                    .font(PB.mono(9, .semibold)).tracking(1)
            }
            .foregroundStyle(active ? BK.paper : BK.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
        }
        .buttonStyle(BrutalButtonStyle(
            fill: active ? BK.accent : BK.paper,
            shadowColor: .clear, borderWidth: 2, offset: 3
        ))
    }

    // MARK: - Inline rate / review panels

    private var hasReviewOrRating: Bool {
        let r = viewModel.myReview
        return (r?.rating ?? 0) > 0 || !(r?.review ?? "").isEmpty
    }

    private func deleteMyReview() {
        Task {
            let ok = await viewModel.deleteReview()
            if ok { withAnimation(.snappy(duration: 0.22)) { activePanel = nil } }
        }
    }

    @ViewBuilder
    private var inlinePanel: some View {
        switch activePanel {
        case .rate:
            RatePanel(
                initial: viewModel.myReview?.rating ?? 0,
                isSubmitting: viewModel.isSubmittingReview,
                canDelete: hasReviewOrRating,
                onSubmit: { rating in
                    Task {
                        let ok = await viewModel.submitReview(rating: rating, review: viewModel.myReview?.review)
                        if ok { withAnimation(.snappy(duration: 0.22)) { activePanel = nil } }
                    }
                },
                onDelete: deleteMyReview,
                onClose: { togglePanel(.rate) }
            )
            .transition(.brutalReveal)
        case .review:
            ReviewPanel(
                initial: viewModel.myReview?.review ?? "",
                isSubmitting: viewModel.isSubmittingReview,
                canDelete: hasReviewOrRating,
                onPost: { text in
                    Task {
                        let ok = await viewModel.submitReview(rating: viewModel.myReview?.rating ?? 0, review: text)
                        if ok { withAnimation(.snappy(duration: 0.22)) { activePanel = nil } }
                    }
                },
                onDelete: deleteMyReview,
                onClose: { togglePanel(.review) }
            )
            .transition(.brutalReveal)
        case .none:
            EmptyView()
        }
    }

    // MARK: - Sections

    private func brutalSectionHeader(_ num: String, _ title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(num).font(PB.mono(10)).foregroundStyle(BK.muted)
            Text(title.uppercased())
                .font(.system(size: 13, weight: .black)).tracking(0.5)
                .foregroundStyle(BK.ink)
            Spacer()
        }
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(line).frame(height: 2) }
    }

    @ViewBuilder
    private func descriptionSection(_ book: Book) -> some View {
        if let desc = book.description, !desc.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                brutalSectionHeader("01", "About this book")
                Text(desc)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(BK.ink.opacity(0.9))
                    .lineSpacing(5)
                    .lineLimit(descriptionExpanded ? nil : 6)
                if desc.count > 280 {
                    Button(descriptionExpanded ? "SHOW LESS" : "READ MORE") {
                        withAnimation(.easeInOut(duration: 0.2)) { descriptionExpanded.toggle() }
                    }
                    .font(PB.mono(10, .semibold)).tracking(1)
                    .foregroundStyle(BK.accent)
                }
            }
        }
    }

    @ViewBuilder
    private var similarSection: some View {
        if !viewModel.similarBooks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                brutalSectionHeader("02", "Readers also enjoyed")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.similarBooks) { item in
                            NavigationLink(value: item.id) {
                                VStack(alignment: .leading, spacing: 5) {
                                    BookCoverView(url: item.coverURL, width: 84, cornerRadius: 0)
                                        .overlay(Rectangle().strokeBorder(line, lineWidth: 1.5))
                                    Text(item.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(BK.ink)
                                        .lineLimit(2).frame(width: 84, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var friendsSaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            brutalSectionHeader("03", "What friends say")
            if viewModel.friendReviews.isEmpty {
                Text("No reviews from people you follow yet.")
                    .font(PB.serifItalic(13))
                    .foregroundStyle(BK.muted)
            } else {
                VStack(spacing: 14) {
                    ForEach(viewModel.friendReviews.prefix(5)) { review in
                        friendReviewRow(review)
                    }
                }
            }
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
            .overlay(Rectangle().strokeBorder(line, lineWidth: 2))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(review.displayName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(BK.ink)
                    Spacer(minLength: 4)
                    if let rating = review.rating, rating > 0 {
                        Text(starsString(rating))
                            .font(.system(size: 11))
                            .foregroundStyle(BK.accent)
                    }
                }
                if let text = review.review {
                    Text(text)
                        .font(.system(size: 13.5, design: .serif))
                        .foregroundStyle(BK.ink.opacity(0.88))
                        .lineSpacing(3)
                        .lineLimit(5)
                }
            }
        }
    }

    @ViewBuilder
    private var reviewsSection: some View {
        if !viewModel.reviews.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                brutalSectionHeader("04", "All reviews")
                ForEach(Array(viewModel.reviews.enumerated()), id: \.element.id) { idx, review in
                    BookReviewRow(review: review, onReport: { reportReviewTarget = review })
                        .overlay(alignment: .top) {
                            if idx > 0 { Rectangle().fill(line.opacity(0.3)).frame(height: 1) }
                        }
                }
            }
        }
    }

    private func starsString(_ rating: Int) -> String {
        let n = max(0, min(rating, 5))
        return String(repeating: "★", count: n) + String(repeating: "☆", count: 5 - n)
    }

    // MARK: - Bottom dock (brutalist)

    private var bottomDock: some View {
        HStack(spacing: 10) {
            Button { showLibrarySheet = true } label: {
                HStack(spacing: 9) {
                    Image(systemName: viewModel.currentShelf == nil ? "plus" : "checkmark")
                        .font(.system(size: 15, weight: .bold))
                    Text(dockLabel.uppercased())
                        .font(.system(size: 15, weight: .black)).tracking(0.5)
                        .lineLimit(1)
                }
                .foregroundStyle(BK.paper)
                .frame(maxWidth: .infinity).frame(height: 52)
            }
            .buttonStyle(BrutalButtonStyle(
                fill: viewModel.currentShelf == nil ? BK.ink : BK.accent,
                shadowColor: BK.accent, offset: 4
            ))

            Button {
                if !viewModel.bookState.isLiked { likePulse &+= 1 }
                Task { await viewModel.toggleLike() }
            } label: {
                Image(systemName: viewModel.bookState.isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundStyle(viewModel.bookState.isLiked ? PB.likeRed : BK.ink)
                    .popEffect(trigger: likePulse)
                    .frame(width: 56, height: 52)
            }
            .buttonStyle(BrutalButtonStyle(
                fill: BK.paper,
                shadowColor: line, offset: 4
            ))
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 26)
        .background(BK.paper)
        .overlay(alignment: .top) { Rectangle().fill(line).frame(height: 3) }
    }

    private var dockLabel: String {
        switch viewModel.currentShelf {
        case .bookshelf: return "On Bookshelf"
        case .tbr:       return "On TBR"
        case .read:      return "Read"
        case nil:        return "Add to Library"
        }
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack { Spacer(); PBSpinner(); Spacer() }
            .frame(maxWidth: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(message).font(.system(size: 14)).foregroundStyle(BK.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Retry") { Task { await viewModel.retry() } }
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(BK.accent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = viewModel.toastMessage {
            Text(msg.uppercased())
                .font(PB.mono(10, .semibold)).tracking(1)
                .foregroundStyle(BK.paper)
                .padding(.horizontal, 15).padding(.vertical, 9)
                .background(BK.ink)
                .overlay(Rectangle().strokeBorder(BK.accent, lineWidth: 2))
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

// MARK: - Add to Library sheet (3 shelves)

private struct AddToLibrarySheet: View {
    let current: BookDetailViewModel.LibraryShelf?
    let onSelect: (BookDetailViewModel.LibraryShelf?) -> Void
    @Environment(\.dismiss) private var dismiss

    private let line = BK.ink

    private struct Option {
        let shelf: BookDetailViewModel.LibraryShelf
        let icon: String
        let title: String
        let sub: String
    }

    private let options: [Option] = [
        .init(shelf: .bookshelf, icon: "books.vertical", title: "Add to Bookshelf",
              sub: "Books you own — lands on your bookshelf"),
        .init(shelf: .tbr, icon: "clock", title: "Add to TBR",
              sub: "To-be-read — your want-to-read queue"),
        .init(shelf: .read, icon: "checkmark.circle", title: "Mark as Read",
              sub: "Finished — 100% progress on your bookshelf"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ADD TO LIBRARY")
                    .font(.system(size: 15, weight: .black)).tracking(0.5)
                    .foregroundStyle(BK.ink)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(BK.ink)
                        .frame(width: 30, height: 30)
                        .overlay(Rectangle().strokeBorder(line, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .overlay(alignment: .bottom) { Rectangle().fill(line).frame(height: 2) }

            ForEach(options, id: \.shelf) { opt in
                let on = current == opt.shelf
                Button { onSelect(on ? nil : opt.shelf) } label: {
                    HStack(spacing: 13) {
                        Image(systemName: opt.icon)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 36, height: 36)
                            .overlay(Rectangle().strokeBorder(on ? BK.paper : line, lineWidth: 2))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(opt.title.uppercased())
                                .font(.system(size: 15, weight: .bold)).tracking(0.3)
                            Text(opt.sub)
                                .font(PB.mono(9))
                                .foregroundStyle(on ? BK.paper.opacity(0.85) : BK.muted)
                        }
                        Spacer()
                        if on {
                            Image(systemName: "checkmark").font(.system(size: 15, weight: .black))
                        }
                    }
                    .foregroundStyle(on ? BK.paper : BK.ink)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(on ? BK.accent : BK.paper)
                    .overlay(alignment: .bottom) { Rectangle().fill(line).frame(height: 2) }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .background(BK.paper)
    }
}

extension BookDetailViewModel.LibraryShelf: Hashable {}

// MARK: - Rate panel (inline, animated)

private struct RatePanel: View {
    let isSubmitting: Bool
    let canDelete: Bool
    let onSubmit: (Int) -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var pending: Int
    @State private var starPulse: [Int]   // per-star pop trigger

    private let line = BK.ink

    init(initial: Int, isSubmitting: Bool, canDelete: Bool,
         onSubmit: @escaping (Int) -> Void, onDelete: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.isSubmitting = isSubmitting
        self.canDelete = canDelete
        self.onSubmit = onSubmit
        self.onDelete = onDelete
        self.onClose = onClose
        _pending = State(initialValue: initial)
        _starPulse = State(initialValue: Array(repeating: 0, count: 6))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(line).offset(x: 6, y: 6)

            VStack(spacing: 0) {
                Text("TAP TO SET YOUR RATING")
                    .font(PB.mono(9, .medium)).tracking(2)
                    .foregroundStyle(BK.muted)
                    .padding(.top, 12).padding(.bottom, 8)

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { n in
                        Button {
                            pending = n
                            starPulse[n] &+= 1
                        } label: {
                            Image(systemName: n <= pending ? "star.fill" : "star")
                                .font(.system(size: 30))
                                .foregroundStyle(n <= pending ? BK.accent : BK.muted.opacity(0.4))
                                .popEffect(trigger: starPulse[n])
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 10)

                Text(pending > 0 ? "\(pending).0 / 5" : "—")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(BK.ink)
                    .padding(.bottom, canDelete ? 8 : 12)

                if canDelete {
                    Button(action: onDelete) {
                        Text("REMOVE RATING & REVIEW")
                            .font(PB.mono(9, .semibold)).tracking(1.2)
                            .foregroundStyle(BK.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                    .padding(.bottom, 12)
                }

                Rectangle().fill(line).frame(height: 2)

                HStack(spacing: 0) {
                    Button { onSubmit(pending) } label: {
                        Group {
                            if isSubmitting {
                                ProgressView().tint(BK.paper).scaleEffect(0.8)
                            } else {
                                Text("SUBMIT RATING")
                                    .font(PB.mono(11, .semibold)).tracking(1.5)
                                    .foregroundStyle(BK.paper)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(pending > 0 ? BK.ink : BK.ink.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .disabled(pending == 0 || isSubmitting)

                    Rectangle().fill(line).frame(width: 2)
                    closeButton
                }
            }
            .background(BK.paper2)
            .overlay(Rectangle().strokeBorder(line, lineWidth: 2.5))
        }
        .padding(.trailing, 6).padding(.bottom, 6)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(BK.ink)
                .frame(width: 50, height: 46)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Review panel (inline, animated)

private struct ReviewPanel: View {
    let isSubmitting: Bool
    let canDelete: Bool
    let onPost: (String) -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    private let line = BK.ink

    init(initial: String, isSubmitting: Bool, canDelete: Bool,
         onPost: @escaping (String) -> Void, onDelete: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.isSubmitting = isSubmitting
        self.canDelete = canDelete
        self.onPost = onPost
        self.onDelete = onDelete
        self.onClose = onClose
        _text = State(initialValue: initial)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(line).offset(x: 6, y: 6)

            VStack(alignment: .leading, spacing: 0) {
                Text("WRITE A REVIEW")
                    .font(PB.mono(9, .medium)).tracking(2)
                    .foregroundStyle(BK.muted)
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("What stayed with you? Half-formed thoughts welcome…")
                            .font(PB.serifItalic(15))
                            .foregroundStyle(BK.muted)
                            .padding(.horizontal, 14).padding(.top, 8)
                    }
                    TextEditor(text: $text)
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(BK.ink)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 84)
                        .padding(.horizontal, 10)
                        .focused($focused)
                }

                if canDelete {
                    Rectangle().fill(line).frame(height: 2)
                    Button(action: onDelete) {
                        Text("REMOVE RATING & REVIEW")
                            .font(PB.mono(9, .semibold)).tracking(1.2)
                            .foregroundStyle(BK.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                }

                Rectangle().fill(line).frame(height: 2)

                HStack(spacing: 0) {
                    Button { onPost(text) } label: {
                        Group {
                            if isSubmitting {
                                ProgressView().tint(BK.paper).scaleEffect(0.8)
                            } else {
                                Text("POST REVIEW")
                                    .font(PB.mono(11, .semibold)).tracking(1.5)
                                    .foregroundStyle(BK.paper)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? BK.ink.opacity(0.4) : BK.ink)
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)

                    Rectangle().fill(line).frame(width: 2)
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(BK.ink)
                            .frame(width: 50, height: 46)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(BK.paper2)
            .overlay(Rectangle().strokeBorder(line, lineWidth: 2.5))
        }
        .padding(.trailing, 6).padding(.bottom, 6)
        .onAppear { focused = true }
    }
}

// MARK: - Review row (All reviews)

private struct BookReviewRow: View {
    let review: BookReview
    var onReport: () -> Void = {}
    @State private var expanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            AvatarView(url: review.avatarURL?.replacingOccurrences(of: "http://", with: "https://"), size: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(review.username)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(BK.ink)
                    if let rating = review.rating, rating > 0 {
                        Text(stars(rating))
                            .font(.system(size: 11))
                            .foregroundStyle(BK.accent)
                    }
                    Spacer(minLength: 8)
                    Text(relativeDate(review.reviewedAt))
                        .font(PB.mono(9)).tracking(1)
                        .foregroundStyle(BK.muted)
                    Button(action: onReport) {
                        Image(systemName: "flag")
                            .font(.system(size: 11))
                            .foregroundStyle(BK.muted.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                if let text = review.review, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 13.5, design: .serif))
                        .foregroundStyle(BK.ink.opacity(0.88))
                        .lineSpacing(3)
                        .lineLimit(expanded ? nil : 3)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                        }
                }
            }
        }
        .padding(.vertical, 14)
    }

    private func stars(_ rating: Int) -> String {
        let n = max(0, min(rating, 5))
        return String(repeating: "★", count: n) + String(repeating: "☆", count: 5 - n)
    }

    private func relativeDate(_ s: String?) -> String {
        guard let s else { return "" }
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = df.date(from: s) ?? {
            df.formatOptions = [.withInternetDateTime]
            return df.date(from: s)
        }()
        guard let d = date else { return "" }
        let out = DateFormatter()
        out.dateFormat = "MMM d"
        return out.string(from: d).uppercased()
    }
}
