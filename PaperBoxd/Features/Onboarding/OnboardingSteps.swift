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

// MARK: - Step 3: Tempo

struct TempoStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    /// Each tempo carries a step of the reading-heatmap ramp, so the choice
    /// previews the colour the user will live with on their profile.
    private static let ramp: [String: String] = [
        "casual": "E7A87D", "regular": "D97A4A", "voracious": "C0271C",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set a tempo,\nnot a target.")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(BK.ink)
                            .lineSpacing(2)
                        Text("Helps us pace recommendations. No streaks, no pressure.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(BK.muted)
                            .lineSpacing(2)
                    }
                    .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        ForEach(ReadingTempo.all) { option in
                            tempoRow(option)
                        }
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)

            OnboardingPrimaryButton(title: "Get my recommendations") {
                viewModel.continueFromTempo()
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 20)
        }
    }

    private func tempoRow(_ option: ReadingTempo) -> some View {
        let active = viewModel.tempo == option.id
        let ramp = Color(hex: Self.ramp[option.id] ?? "D97A4A")
        return Button {
            viewModel.tempo = option.id
        } label: {
            HStack(spacing: 13) {
                Rectangle()
                    .fill(active ? Color.white.opacity(0.75) : ramp)
                    .frame(width: 6, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(active ? .white : BK.ink)
                    Text(option.sub)
                        .font(.system(size: 12.5))
                        .foregroundStyle(active ? .white.opacity(0.78) : BK.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(active ? .white : .clear)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(active ? ramp : BK.card)
            .overlay(Rectangle().stroke(active ? ramp : BK.ink.opacity(0.14), lineWidth: 2))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
