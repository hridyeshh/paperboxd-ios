import SwiftUI

struct SearchView: View {
    @StateObject private var vm: SearchViewModel
    let viewer: User
    @FocusState private var searchFocused: Bool
    @State private var searchPath = NavigationPath()

    // Search page is light-mode only. The app window is globally forced dark and
    // the asset colors are single-appearance dark, so we use fixed light values
    // here (same approach as the home page / book page BK). Mirrors the tokens in
    // "Search - Brutalist Mobile.html".
    private let slBg    = Color(red: 0.949, green: 0.929, blue: 0.882) // paper  #f2ede1
    private let slCard  = Color(red: 0.992, green: 0.984, blue: 0.965) // card   #fdfbf6
    private let slInk   = Color(red: 0.082, green: 0.082, blue: 0.075) // ink    #151513
    private let slMuted = Color(red: 0.416, green: 0.392, blue: 0.337) // muted  #6a6456
    private let slLine  = Color(red: 0.902, green: 0.874, blue: 0.816) // line   #e6dfd0
    private let slAccent = Color(red: 0.824, green: 0.231, blue: 0.149) // accent #d23b26

    init(viewer: User) {
        self.viewer = viewer
        _vm = StateObject(wrappedValue: SearchViewModel())
    }

    #if DEBUG
    init(viewer: User, preview viewModel: SearchViewModel) {
        self.viewer = viewer
        _vm = StateObject(wrappedValue: viewModel)
    }
    #endif

    var body: some View {
        NavigationStack(path: $searchPath) {
            ZStack(alignment: .top) {
                slBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchHeader
                    contentArea
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { bookId in
                BookDetailView(bookId: bookId, user: viewer)
            }
            .navigationDestination(for: ProfileDestination.self) { dest in
                ProfileView(username: dest.username, viewer: viewer)
            }
        }
        .environment(\.colorScheme, .light)   // search page is light-mode only
        .preferredColorScheme(.light)
    }

    // MARK: - Search header

    private var searchHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if searchFocused {
                    Button {
                        searchFocused = false
                        vm.query = ""
                        vm.books = []
                        vm.users = []
                        vm.vibeBooks = []
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(slInk)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(
                        insertion: .push(from: .leading).combined(with: .opacity),
                        removal: .push(from: .trailing).combined(with: .opacity)
                    ))
                }

                searchBarField
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 12)

            if searchFocused {
                typePicker
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(slBg.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle().fill(slLine).frame(height: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: searchFocused)
    }

    // Brutalist search bar. Idle: hard 5px offset ink shadow behind the face.
    // Focused: the face presses into its own shadow (translate +offset, shadow
    // collapses to 0) — the same instant, no-easing motion as BrutalButtonStyle
    // on the book page.
    private var searchBarField: some View {
        let offset: CGFloat = 5
        let pressed = searchFocused
        return HStack(spacing: 10) {
            Image(systemName: vm.searchType == .vibe ? "sparkles" : "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(vm.searchType == .vibe ? slAccent : slInk)

            TextField(placeholder, text: $vm.query)
                .focused($searchFocused)
                .font(.system(size: 15))
                .foregroundStyle(slInk)
                .tint(slAccent)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onChange(of: vm.query) { _, _ in vm.onQueryChanged() }

            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                    vm.books = []
                    vm.users = []
                    vm.vibeBooks = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(slMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(slCard)
        .overlay(Rectangle().strokeBorder(slInk, lineWidth: 1.5))
        // hard offset shadow sits behind the face; collapses on focus
        .background(alignment: .topLeading) {
            Rectangle()
                .fill(slInk)
                .offset(x: pressed ? 0 : offset, y: pressed ? 0 : offset)
        }
        // face pushes into its own shadow when focused
        .offset(x: pressed ? offset : 0, y: pressed ? offset : 0)
        .animation(nil, value: pressed) // instant, brutalist
        .padding(.trailing, offset)     // reserve room for the idle shadow
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = true }
    }

    private var placeholder: String {
        switch vm.searchType {
        case .books:   return "Title, author, or ISBN..."
        case .readers: return "Find readers by username..."
        case .vibe:    return "Describe a mood or feeling..."
        }
    }

    private var typePicker: some View {
        HStack(spacing: 6) {
            ForEach(SearchType.allCases, id: \.self) { type in
                typeChip(type)
            }
            Spacer()
        }
    }

    private func typeChip(_ type: SearchType) -> some View {
        Button {
            if vm.searchType != type {
                vm.searchType = type
                vm.onTypeChanged()
            }
        } label: {
            Text(type.rawValue)
                .font(.system(size: 12, weight: vm.searchType == type ? .semibold : .medium))
                .foregroundStyle(vm.searchType == type ? slBg : slMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(vm.searchType == type ? slInk : Color.clear)
                .clipShape(Capsule())
                .overlay {
                    if vm.searchType != type {
                        Capsule().strokeBorder(slLine, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content area

    private var contentArea: some View {
        ZStack(alignment: .top) {
            // Wall — always loaded, hidden while search is focused
            wallScrollView
                .opacity(searchFocused ? 0 : 1)
                .animation(.easeInOut(duration: 0.18), value: searchFocused)

            // Focused overlay (history / results)
            if searchFocused {
                focusedOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: searchFocused)
    }

    // MARK: - Focused overlay

    @ViewBuilder
    private var focusedOverlay: some View {
        let q = vm.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            emptyFocusState
        } else {
            searchResultsOverlay
        }
    }

    private var emptyFocusState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if vm.recentSearches.isEmpty {
                    noPriorSearchBanner
                } else {
                    recentSearchesList
                }
            }
        }
        .background(slBg)
    }

    private var noPriorSearchBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("search anything.")
                .font(PB.serif(32))
                .foregroundStyle(slInk)
            Text("Books, readers, or a vibe.")
                .font(PB.serifItalic(18, .regular))
                .foregroundStyle(slMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 40)
    }

    private var recentSearchesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: "Recent")
                Spacer()
                Button("Clear") { vm.clearHistory() }
                    .font(PB.mono(10))
                    .foregroundStyle(slMuted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)

            ForEach(vm.recentSearches, id: \.self) { term in
                Button {
                    vm.query = term
                    vm.onQueryChanged()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                            .foregroundStyle(slMuted.opacity(0.6))
                        Text(term)
                            .font(.system(size: 14))
                            .foregroundStyle(slInk)
                        Spacer()
                        Button {
                            vm.removeFromHistory(term)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(slMuted.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)

                Rectangle().fill(slLine.opacity(0.4)).frame(height: 1)
                    .padding(.leading, 52)
            }
        }
    }

    // MARK: - Search results overlay

    private var searchResultsOverlay: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if vm.isSearching {
                    ProgressView().tint(slAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if vm.searchType == .readers {
                    readerResults
                } else {
                    bookResults(vm.searchType == .vibe ? vm.vibeBooks : vm.books)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(slBg)
    }

    private func bookResults(_ items: [Book]) -> some View {
        Group {
            if items.isEmpty {
                noResults
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { book in
                        Button { searchPath.append(book.id) } label: {
                            BookSearchResultRow(book: book)
                        }
                        .buttonStyle(.plain)
                        Rectangle().fill(slLine.opacity(0.5)).frame(height: 1)
                            .padding(.leading, 20)
                    }
                }
            }
        }
    }

    private var readerResults: some View {
        Group {
            if vm.users.isEmpty && !vm.isSearching {
                noResults
            } else {
                VStack(spacing: 0) {
                    ForEach(vm.users) { user in
                        Button {
                            searchPath.append(ProfileDestination(username: user.username))
                        } label: {
                            UserSearchResultRow(user: user)
                        }
                        .buttonStyle(.plain)
                        Rectangle().fill(slLine.opacity(0.5)).frame(height: 1)
                            .padding(.leading, 20)
                    }
                }
            }
        }
    }

    private var noResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(slMuted.opacity(0.6))
            Text("Nothing found")
                .font(PB.serifItalic(14))
                .foregroundStyle(slMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Wall

    private var wallScrollView: some View {
        BrutalistRefreshable(onRefresh: { await vm.shuffleWall() }) {
            VStack(alignment: .leading, spacing: 14) {
                wallHeader.padding(.horizontal, 18).padding(.top, 16)
                wallGrid
            }
            .padding(.bottom, 16)
        }
        .task { await vm.loadWallIfNeeded() }
    }

    private var wallHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Eyebrow(text: "The wall")
            Text("What everyone is shelving.")
                .font(PB.serif(17))
                .foregroundStyle(slInk)
        }
    }

    @ViewBuilder
    private var wallGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
        if vm.isLoadingWall && vm.wallBooks.isEmpty {
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(0..<12, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6).fill(slCard)
                        .aspectRatio(2/3, contentMode: .fit).pbShimmer()
                }
            }
            .padding(.horizontal, 18)
        } else if vm.wallBooks.isEmpty {
            // fetch failed or returned nothing — offer retry
            VStack(spacing: 14) {
                Text("Couldn't load the wall.")
                    .font(PB.serifItalic(14))
                    .foregroundStyle(slMuted)
                Button("Try again") { Task { await vm.loadWallIfNeeded() } }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(slAccent)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(vm.wallBooks) { book in
                    NavigationLink(value: book.id) {
                        GeometryReader { geo in
                            BookCoverView(url: book.coverURL, width: geo.size.width, cornerRadius: 5)
                        }
                        .aspectRatio(2/3, contentMode: .fit)
                        .onAppear {
                            if book.id == vm.wallBooks.last?.id {
                                Task { await vm.loadMoreWall() }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)

            if vm.isLoadingMoreWall {
                Text("··· loading more ···")
                    .font(PB.mono(10)).tracking(1.5)
                    .foregroundStyle(slMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }
}

struct ProfileDestination: Hashable {
    let username: String
}
