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
                        .foregroundStyle(Color(red: 0.82, green: 0.22, blue: 0.22))
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
                    .foregroundStyle(Color(white: 0.65))
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
                .foregroundStyle(Color(white: 0.07))
                .lineSpacing(2)
            Text("This is how readers will find and follow you.")
                .font(.system(size: 13.5))
                .foregroundStyle(Color(white: 0.53))
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
                        .foregroundStyle(Color(white: 0.07))
                    Text("Optional · square, 400px+")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.6))
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
            .frame(width: 64, height: 64)
            .clipShape(Circle())
            .overlay(
                Circle().strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: viewModel.avatarImage == nil && viewModel.avatarURL == nil ? [4, 3] : [])
                )
                .foregroundStyle(Color(white: 0.78))
            )
            .overlay {
                if viewModel.isUploadingAvatar {
                    ZStack {
                        Circle().fill(.black.opacity(0.45))
                        ProgressView().tint(.white)
                    }
                    .frame(width: 64, height: 64)
                }
            }

            Circle()
                .fill(Color(white: 0.07))
                .frame(width: 22, height: 22)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .offset(x: 2, y: 2)
        }
    }

    private var gradientFill: some View {
        LinearGradient(
            colors: [Color(red: 0.95, green: 0.82, blue: 0.62), Color(red: 0.48, green: 0.32, blue: 0.72)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var usernameField: some View {
        HStack(spacing: 0) {
            Text("@")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(white: 0.4))
                .padding(.leading, 14)
                .padding(.trailing, 2)
            TextField("yourname", text: $viewModel.username)
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.07))
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
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(usernameBorderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var usernameBorderColor: Color {
        switch viewModel.availability {
        case .available:     return Color(red: 0.18, green: 0.68, blue: 0.3)
        case .taken, .error: return Color(red: 0.82, green: 0.22, blue: 0.22)
        case .checking:      return Color(white: 0.6)
        case .idle:          return Color(white: 0.88)
        }
    }

    @ViewBuilder
    private var availabilityIcon: some View {
        switch viewModel.availability {
        case .idle:
            Color.clear.frame(width: 18, height: 18)
        case .checking:
            ProgressView().progressViewStyle(.circular)
                .tint(Color(white: 0.55)).scaleEffect(0.72)
                .frame(width: 18, height: 18)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(red: 0.18, green: 0.68, blue: 0.3))
                .frame(width: 18, height: 18)
        case .taken, .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color(red: 0.82, green: 0.22, blue: 0.22))
                .frame(width: 18, height: 18)
        }
    }

    @ViewBuilder
    private var availabilityHint: some View {
        switch viewModel.availability {
        case .idle, .checking:
            Text("Letters, numbers, _ or -")
                .font(.system(size: 12)).foregroundStyle(Color(white: 0.65))
        case .available:
            Text("@\(viewModel.username) is available ✓")
                .font(.system(size: 12)).foregroundStyle(Color(red: 0.18, green: 0.68, blue: 0.3))
        case .taken(let reason):
            Text(reason ?? "@\(viewModel.username) is taken")
                .font(.system(size: 12)).foregroundStyle(Color(red: 0.82, green: 0.22, blue: 0.22))
        case .error(let msg):
            Text(msg)
                .font(.system(size: 12)).foregroundStyle(Color(red: 0.82, green: 0.22, blue: 0.22))
        }
    }

    private var displayNameField: some View {
        TextField("Your name", text: $viewModel.displayName)
            .font(.system(size: 14))
            .foregroundStyle(Color(white: 0.07))
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.words)
            .focused($focused, equals: .displayName)
            .submitLabel(.done)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(white: 0.88), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Step 2: Genres

struct GenresStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private var remaining: Int { max(0, 3 - viewModel.selectedGenres.count) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What lives on\nyour shelves?")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(Color(white: 0.07))
                            .lineSpacing(2)
                        Text("Pick at least three. Your recs are built on these — you can tune later.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Color(white: 0.53))
                            .lineSpacing(2)
                    }
                    .padding(.bottom, 22)

                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(Genre.all) { genre in
                            OnboardingChip(
                                label: genre.label,
                                isOn: viewModel.selectedGenres.contains(genre.id)
                            ) {
                                viewModel.toggleGenre(genre.id)
                            }
                        }
                    }

                    Text(remaining == 0
                         ? "\(viewModel.selectedGenres.count) selected · Ready"
                         : "\(viewModel.selectedGenres.count) selected · Pick \(remaining) more")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .textCase(.uppercase)
                        .kerning(0.8)
                        .foregroundStyle(Color(white: 0.55))
                        .padding(.top, 18)
                }
                .padding(.horizontal, 26)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)

            OnboardingPrimaryButton(
                title: "Continue",
                isEnabled: viewModel.selectedGenres.count >= 3
            ) {
                viewModel.continueFromGenres()
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Step 3: Tempo

struct TempoStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set a tempo,\nnot a target.")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(Color(white: 0.07))
                            .lineSpacing(2)
                        Text("Helps us pace recommendations. No streaks, no pressure.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Color(white: 0.53))
                            .lineSpacing(2)
                    }
                    .padding(.bottom, 22)

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
            .padding(.bottom, 16)
        }
    }

    private func tempoRow(_ option: ReadingTempo) -> some View {
        let active = viewModel.tempo == option.id
        return Button {
            viewModel.tempo = option.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(active ? .white : Color(white: 0.12))
                    Text(option.sub)
                        .font(.system(size: 12.5))
                        .foregroundStyle(active ? .white.opacity(0.7) : Color(white: 0.5))
                }
                Spacer()
                if active {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(active ? Color(white: 0.07) : Color(white: 0.97))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(white: active ? 0.07 : 0.9), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Flow layout (wrapping chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
