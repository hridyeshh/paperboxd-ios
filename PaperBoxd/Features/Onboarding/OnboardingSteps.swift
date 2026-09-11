import SwiftUI

// MARK: - Step 1: Username + avatar + display name

struct UsernameStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showPicker = false
    @FocusState private var focused: Field?

    enum Field { case username, displayName }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleBlock
                avatarRow.padding(.bottom, 22)

                onboardingFieldLabel("Username").padding(.bottom, 6)
                usernameField
                availabilityHint.padding(.top, 6)

                onboardingFieldLabel("Display name").padding(.top, 18).padding(.bottom, 6)
                displayNameField

                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(BK.crimson)
                        .padding(.top, 10)
                }

                OnboardingPrimaryButton(
                    title: "Continue",
                    isLoading: viewModel.isSubmitting,
                    isEnabled: viewModel.availability == .available
                ) {
                    Task { await viewModel.submitUsername() }
                }
                .padding(.top, 28)

                Text("You can change this any time.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "A6A092"))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 26)
            .padding(.top, 28)
            .padding(.bottom, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: viewModel.username) { _, newValue in
            viewModel.usernameChanged(newValue)
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(source: .photoLibrary) { image in
                viewModel.pickedAvatar(image)
            }
            .ignoresSafeArea()
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose your name\non the shelves.")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(BK.ink)
                .lineSpacing(2)
            Text("This is how readers will find and follow you.")
                .font(.system(size: 13.5))
                .foregroundStyle(BK.muted)
                .lineSpacing(2)
        }
        .padding(.bottom, 24)
    }

    private var avatarRow: some View {
        Button {
            focused = nil
            showPicker = true
        } label: {
            HStack(spacing: 14) {
                avatarCircle
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.avatarImage == nil && viewModel.avatarURL == nil ? "Add a picture" : "Change picture")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(BK.ink)
                    Text("Optional · square, 400px+")
                        .font(.system(size: 12))
                        .foregroundStyle(BK.muted)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var avatarCircle: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let img = viewModel.avatarImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else if let urlStr = viewModel.avatarURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            gradientFill
                        }
                    }
                } else {
                    gradientFill
                }
            }
            .frame(width: 76, height: 76)
            .clipShape(Circle())
            .overlay(
                Circle().strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: viewModel.avatarImage == nil && viewModel.avatarURL == nil ? [4, 3] : [])
                )
                .foregroundStyle(BK.ink.opacity(0.28))
            )
            .overlay {
                if viewModel.isUploadingAvatar {
                    ZStack {
                        Circle().fill(.black.opacity(0.45))
                        ProgressView().tint(.white)
                    }
                    .frame(width: 76, height: 76)
                }
            }

            Circle()
                .fill(BK.crimson)
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
    }

    private var gradientFill: some View {
        LinearGradient(
            colors: [Color(hex: "F2D19E"), Color(hex: "7A52B8")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var usernameField: some View {
        HStack(spacing: 0) {
            Text("@")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BK.muted)
                .padding(.leading, 14)
                .padding(.trailing, 2)
            TextField("yourname", text: $viewModel.username)
                .font(.system(size: 14))
                .foregroundStyle(BK.ink)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                .textContentType(.username)
                .focused($focused, equals: .username)
                .submitLabel(.next)
                .onSubmit { focused = .displayName }
                .padding(.vertical, 13)
                .padding(.trailing, 8)
            availabilityIcon.padding(.trailing, 14)
        }
        .frame(height: 48)
        .background(BK.card)
        .overlay(Rectangle().stroke(usernameBorderColor, lineWidth: 2))
    }

    private var usernameBorderColor: Color {
        switch viewModel.availability {
        case .available:     return BK.sage
        case .taken, .error: return BK.crimson
        case .checking:      return BK.ink.opacity(0.45)
        case .idle:          return BK.ink.opacity(0.30)
        }
    }

    @ViewBuilder
    private var availabilityIcon: some View {
        switch viewModel.availability {
        case .idle:
            Color.clear.frame(width: 18, height: 18)
        case .checking:
            ProgressView().progressViewStyle(.circular)
                .tint(BK.muted).scaleEffect(0.72)
                .frame(width: 18, height: 18)
        case .available:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(BK.sage)
                .frame(width: 18, height: 18)
        case .taken, .error:
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(BK.crimson)
                .frame(width: 18, height: 18)
        }
    }

    @ViewBuilder
    private var availabilityHint: some View {
        switch viewModel.availability {
        case .idle, .checking:
            Text("Letters, numbers, _ or -")
                .font(.system(size: 12.5)).foregroundStyle(BK.muted)
        case .available:
            Text("@\(viewModel.username) is available")
                .font(.system(size: 12.5)).foregroundStyle(BK.sage)
        case .taken(let reason):
            Text(reason ?? "@\(viewModel.username) is taken")
                .font(.system(size: 12.5)).foregroundStyle(BK.crimson)
        case .error(let msg):
            Text(msg)
                .font(.system(size: 12.5)).foregroundStyle(BK.crimson)
        }
    }

    private var displayNameField: some View {
        TextField("Your name", text: $viewModel.displayName)
            .font(.system(size: 14))
            .foregroundStyle(BK.ink)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.words)
            .focused($focused, equals: .displayName)
            .submitLabel(.done)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(BK.card)
            .overlay(Rectangle().stroke(BK.ink.opacity(0.30), lineWidth: 2))
    }
}

// MARK: - Step 2: Genres — pull them off the shelf

/// Cloth and foil for each genre, plus how tall its board stands. Same shelf
/// language as the sign-in hero, so the metaphor carries from the first screen
/// into the first task. Keyed by `Genre.id`.
private let genreBoards: [String: (cloth: String, foil: String, height: CGFloat)] = [
    "fiction":         ("6A2350", "EDD9A8", 112),
    "mystery":         ("23304F", "D8B45C", 122),
    "thriller":        ("C0271C", "FFF0CC", 106),
    "romance":         ("B5456B", "FFF0CC", 118),
    "science-fiction": ("14595E", "E7C77A", 110),
    "fantasy":         ("33306B", "D8B45C", 124),
    "horror":          ("23211E", "D8B45C", 104),
    "historical":      ("C9962B", "3A2C1C", 120),
    "biography":       ("7A2E1B", "E7C77A", 114),
    "self-help":       ("4F7A1E", "F2EDE1", 108),
    "business":        ("2A3A5A", "C9962B", 116),
    "non-fiction":     ("1B4B3C", "EDD9A8", 122),
    "young-adult":     ("B5642A", "2A1C0E", 110),
    "classics":        ("8C2B22", "E7C77A", 126),
    "poetry":          ("2F7D5A", "FFF0CC", 106),
]

struct GenresStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private var remaining: Int { max(0, 3 - viewModel.selectedGenres.count) }

    /// Fifteen boards across three shelves.
    private var shelves: [[Genre]] {
        stride(from: 0, to: Genre.all.count, by: 5).map {
            Array(Genre.all[$0 ..< min($0 + 5, Genre.all.count)])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Pull the ones\nyou'd reread.")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(BK.ink)
                    .lineSpacing(2)
                Text("Tap a spine to pull it off the shelf. Three or more and we can start.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(BK.muted)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.top, 22)
            .padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(shelves.indices, id: \.self) { i in
                        shelf(shelves[i])
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 12) {
                tallyRow
                OnboardingPrimaryButton(
                    title: remaining == 0 ? "Continue" : "Pull \(remaining) more",
                    isEnabled: remaining == 0
                ) {
                    viewModel.continueFromGenres()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
    }

    private func shelf(_ books: [Genre]) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(books) { genre in
                    board(genre)
                }
            }
            .frame(height: 128, alignment: .bottom)
            Rectangle().fill(BK.plank).frame(height: 5)
            LinearGradient(colors: [BK.plank.opacity(0.26), BK.plank.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 14)
        }
        .padding(.top, 14)
    }

    private func board(_ genre: Genre) -> some View {
        let spec = genreBoards[genre.id] ?? ("23211E", "D8B45C", 114)
        let pulled = viewModel.selectedGenres.contains(genre.id)
        return Button {
            viewModel.toggleGenre(genre.id)
        } label: {
            VStack(spacing: 0) {
                foilRule(Color(hex: spec.foil))
                Spacer(minLength: 0)
                SpineTitle(
                    text: genre.label,
                    size: 12,
                    weight: .bold,
                    kerning: 0.3,
                    color: Color(hex: spec.foil),
                    run: spec.height - 36
                )
                Spacer(minLength: 0)
                foilRule(Color(hex: spec.foil))
            }
            .padding(.vertical, 8)
            .frame(width: 61, height: spec.height)
            .background(Color(hex: spec.cloth))
            // Untouched boards sit back under a shadow veil; a pulled one is
            // lifted out of the row and into the light.
            .overlay(pulled ? Color.clear : Color(hex: "1A140C").opacity(0.30))
            .overlay(Rectangle().strokeBorder(BK.ink, lineWidth: 2))
            .shadow(color: BK.plank.opacity(pulled ? 0.38 : 0), radius: 7, y: 8)
            .offset(y: pulled ? -14 : 0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: pulled)
        .accessibilityLabel(genre.label)
        .accessibilityAddTraits(pulled ? [.isButton, .isSelected] : .isButton)
    }

    private func foilRule(_ color: Color) -> some View {
        Rectangle().fill(color).frame(width: 61 * 0.66, height: 2)
    }

    private var tallyRow: some View {
        HStack(spacing: 8) {
            Text("Pulled")
                .font(.system(size: 10, design: .monospaced))
                .textCase(.uppercase)
                .kerning(1.6)
                .foregroundStyle(BK.muted)
            HStack(spacing: 4) {
                ForEach(0 ..< 3, id: \.self) { i in
                    Rectangle()
                        .fill(i < viewModel.selectedGenres.count ? BK.crimson : BK.card)
                        .frame(height: 8)
                        .overlay(Rectangle().stroke(BK.ink, lineWidth: 1.5))
                }
            }
            Text("\(viewModel.selectedGenres.count)/\(Genre.all.count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(BK.ink)
        }
    }
}

// MARK: - Step 3: Books you love

/// Up to four books the reader already loves. Search on top, a suggestion
/// grid underneath; picks sit in a tray of four slots so the cap is visible
/// before it bites.
struct BooksStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @FocusState private var searchFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Books you\nalready love.")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(BK.ink)
                    .lineSpacing(2)
                Text("Pick up to \(onboardingMaxPicks). They become your Top 4 and teach us your taste.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(BK.muted)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.top, 22)
            .padding(.bottom, 14)

            tray
                .padding(.horizontal, 26)
                .padding(.bottom, 12)

            searchField
                .padding(.horizontal, 26)
                .padding(.bottom, 12)

            ScrollView {
                grid.padding(.horizontal, 26).padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.immediately)

            VStack(spacing: 8) {
                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(BK.crimson)
                        .frame(maxWidth: .infinity)
                }
                OnboardingPrimaryButton(title: viewModel.picks.isEmpty ? "Skip for now" : "Continue") {
                    viewModel.continueFromBooks()
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    private var tray: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< onboardingMaxPicks, id: \.self) { i in
                if i < viewModel.picks.count {
                    let book = viewModel.picks[i]
                    Button { viewModel.togglePick(book) } label: {
                        PickCover(url: book.coverURL, title: book.title)
                            .frame(width: 48, height: 72)
                            .overlay(Rectangle().stroke(BK.ink, lineWidth: 2))
                            .shadow(color: BK.plank.opacity(0.35), radius: 6, y: 5)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("Remove \(book.title)")
                } else {
                    Rectangle()
                        .fill(BK.card)
                        .frame(width: 48, height: 72)
                        .overlay(Rectangle().stroke(BK.ink.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                }
            }
            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.75), value: viewModel.picks)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BK.muted)
            TextField("Search a title or author", text: $viewModel.searchQuery)
                .font(.system(size: 15))
                .foregroundStyle(BK.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($searchFocused)
                .onChange(of: viewModel.searchQuery) { _, q in viewModel.searchChanged(q) }
            if viewModel.isSearching {
                ProgressView().tint(BK.muted).scaleEffect(0.8)
            } else if !viewModel.searchQuery.isEmpty {
                Button { viewModel.searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(BK.muted)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(BK.card)
        .overlay(Rectangle().stroke(searchFocused ? BK.ink : BK.ink.opacity(0.25), lineWidth: 2))
    }

    @ViewBuilder
    private var grid: some View {
        let items = viewModel.pickGrid
        if viewModel.isLoadingSuggestions && items.isEmpty {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0 ..< 8, id: \.self) { _ in
                    Rectangle().fill(BK.paper2).aspectRatio(2 / 3, contentMode: .fit)
                        .overlay(Rectangle().stroke(BK.ink.opacity(0.12), lineWidth: 1.5))
                }
            }
        } else if items.isEmpty {
            Text(viewModel.searchQuery.count >= 2 ? "Nothing found — try another title." : "Search for a book you love.")
                .font(.system(size: 13))
                .foregroundStyle(BK.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        } else {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(items) { book in
                    let picked = viewModel.isPicked(book)
                    Button { viewModel.togglePick(book) } label: {
                        PickCover(url: book.coverURL, title: book.title)
                            .aspectRatio(2 / 3, contentMode: .fit)
                            .overlay(picked ? BK.ink.opacity(0.35) : Color.clear)
                            .overlay(alignment: .center) {
                                if picked {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(BK.cream)
                                }
                            }
                            .overlay(Rectangle().stroke(picked ? BK.ink : BK.ink.opacity(0.18), lineWidth: picked ? 2.5 : 1.5))
                            .scaleEffect(picked ? 0.96 : 1)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .animation(.spring(response: 0.28, dampingFraction: 0.7), value: picked)
                    .accessibilityLabel(book.title)
                    .accessibilityAddTraits(picked ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }
}

/// Cover with a titled fallback, so a book with no image is still pickable.
struct PickCover: View {
    let url: String?
    let title: String

    var body: some View {
        ZStack {
            BK.paper2
            if let url, let u = URL(string: url) {
                AsyncImage(url: u) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .clipped()
    }

    private var fallback: some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(BK.muted)
            .multilineTextAlignment(.center)
            .lineLimit(4)
            .padding(4)
    }
}

// MARK: - Step 4: Readers to follow

/// The home feed is empty until you follow someone. Suggestions come with a
/// server-authored reason, so the same line shows on every platform.
struct ReadersStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Readers\nto follow.")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(BK.ink)
                    .lineSpacing(2)
                Text("Your home fills up with what they read, finish and write.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(BK.muted)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.top, 22)
            .padding(.bottom, 18)

            ScrollView {
                VStack(spacing: 8) {
                    if viewModel.isLoadingReaders && viewModel.readers.isEmpty {
                        ForEach(0 ..< 4, id: \.self) { _ in
                            Rectangle().fill(BK.paper2).frame(height: 62)
                                .overlay(Rectangle().stroke(BK.ink.opacity(0.12), lineWidth: 1.5))
                        }
                    } else if viewModel.readers.isEmpty {
                        Text("You're early — no readers to suggest yet. You can find people from search any time.")
                            .font(.system(size: 13))
                            .foregroundStyle(BK.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                    } else {
                        ForEach(viewModel.readers) { reader in
                            readerRow(reader)
                        }
                    }
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 8) {
                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(BK.crimson)
                        .frame(maxWidth: .infinity)
                }
                OnboardingPrimaryButton(title: viewModel.followed.isEmpty ? "Skip for now" : "Get my recommendations") {
                    viewModel.continueFromReaders()
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    private func readerRow(_ reader: SuggestedReader) -> some View {
        let done = viewModel.followed.contains(reader.username)
        return HStack(spacing: 12) {
            avatar(reader)
            VStack(alignment: .leading, spacing: 2) {
                Text(reader.displayName)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(BK.ink)
                    .lineLimit(1)
                Text(reader.booksReadCount > 0 ? "\(reader.reason) · \(reader.booksReadCount) read" : reader.reason)
                    .font(.system(size: 12))
                    .foregroundStyle(BK.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button { viewModel.follow(reader) } label: {
                HStack(spacing: 5) {
                    Image(systemName: done ? "checkmark" : "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text(done ? "Following" : "Follow")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(done ? BK.ink : BK.cream)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(done ? BK.ochre : BK.ink)
                .overlay(Rectangle().stroke(BK.ink, lineWidth: 2))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(done)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BK.card)
        .overlay(Rectangle().stroke(BK.ink.opacity(0.18), lineWidth: 1.5))
        .animation(.easeInOut(duration: 0.18), value: done)
    }

    private func avatar(_ reader: SuggestedReader) -> some View {
        ZStack {
            BK.paper2
            if let url = reader.avatarURL, let u = URL(string: url) {
                AsyncImage(url: u) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        initial(reader)
                    }
                }
            } else {
                initial(reader)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(Circle().stroke(BK.ink, lineWidth: 1.5))
    }

    private func initial(_ reader: SuggestedReader) -> some View {
        Text(String(reader.displayName.prefix(1)).uppercased())
            .font(.system(size: 15, weight: .bold, design: .serif))
            .foregroundStyle(BK.ink)
    }
}
