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
        HStack(alignment: .top, spacing: 12) {
            Image("ReadingBuddyIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 50)
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

// MARK: - Step 3: Genres — swipe away

/// Deck of 15 genre cards. Swipe (or tap) right to like, left to skip.
/// Like as many as you want; Continue unlocks at 3, and running out of
/// cards with 3+ liked moves on by itself.
struct SwipeGenresStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var deck: [Genre] = Genre.all.shuffled()
    @State private var dragOffset: CGSize = .zero
    @State private var pastThreshold = false
    @State private var flying = false

    private let commitDistance: CGFloat = 90

    private var topGenre: Genre? { deck.first }
    /// -1…1: how far the top card leans toward skip (−) or add (+).
    private var lean: CGFloat { max(-1, min(1, dragOffset.width / commitDistance)) }
    private var leaningAdd: Bool { lean > 0.3 }
    private var leaningSkip: Bool { lean < -0.3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Swipe away!")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(BK.ink)
                Text("Right for genres you love, left to skip. Pick at least 3.")
                    .font(.system(size: 14))
                    .foregroundStyle(BK.muted)
                    .lineSpacing(2)
            }
            .padding(.top, 18)

            shelfTray.padding(.top, 16)

            Spacer(minLength: 12)

            // Shrinks the deck on short phones (SE) so Continue stays on screen.
            GeometryReader { geo in
                ZStack {
                    ForEach(deck.prefix(3).reversed(), id: \.id) { genre in
                        card(genre)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(min(1, geo.size.height / 330))
            }
            .frame(maxHeight: 330)
            .layoutPriority(1)

            hintRow.padding(.top, 10)

            Spacer(minLength: 12)

            HStack {
                swipeButton(add: false)
                Spacer()
                mascot
                Spacer()
                swipeButton(add: true)
            }

            OnboardingPrimaryButton(title: "Continue", isEnabled: viewModel.selectedGenres.count >= 3) {
                viewModel.continueFromGenres()
            }
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 26)
        .task { await CatClipStore.shared.preload(["CatPlayFrames", "CatMatchFrames"]) }
    }

    // MARK: - Shelf tray

    private var shelfTray: some View {
        let picked = viewModel.selectedGenres.compactMap { id in Genre.all.first { $0.id == id } }
        let pending = leaningAdd ? topGenre : nil
        return VStack(alignment: .leading, spacing: 8) {
            Text(picked.count < 3 ? "YOUR SHELF · \(picked.count) OF 3" : "YOUR SHELF · \(picked.count) PICKED")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .kerning(1.6)
                .foregroundStyle(BK.muted)
            // Scrolls once it outgrows the screen, following the newest (or
            // about-to-be-added) chip at the end.
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(picked) { genre in
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                                Text(genre.label).font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(BK.card)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(BK.ink, in: Capsule())
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                        }
                        if let pending {
                            HStack(spacing: 5) {
                                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                                Text(pending.label).font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(BK.sage)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .overlay(Capsule().strokeBorder(BK.sage, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                            .transition(.opacity)
                            .id(pending.id)
                        } else if picked.count < 3 {
                            Text("\(3 - picked.count) more")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(BK.muted)
                                .padding(.horizontal, 13)
                                .frame(height: 32)
                                .overlay(Capsule().strokeBorder(BK.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: picked.count)
                    .animation(.easeOut(duration: 0.15), value: pending?.id)
                }
                .onChange(of: pending?.id ?? picked.last?.id) { _, target in
                    guard let target else { return }
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(target, anchor: .trailing) }
                }
            }
        }
    }

    // MARK: - Cards

    private func card(_ genre: Genre) -> some View {
        let isTop = genre.id == topGenre?.id
        let depth = deck.firstIndex(of: genre) ?? 0
        let number = (Genre.all.firstIndex(of: genre) ?? 0) + 1
        return ZStack(alignment: .topLeading) {
            if isTop {
                BK.ink
                (lean >= 0 ? BK.sage : BK.crimson).opacity(Double(abs(lean)))
                VStack(alignment: .leading, spacing: 0) {
                    Text(String(format: "GENRE %02d / %d", number, Genre.all.count))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .kerning(1.6)
                        .opacity(0.65)
                    Spacer()
                    Text(genre.label)
                        .font(.system(size: 46, weight: .bold, design: .serif))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .foregroundStyle(.white)
                .padding(22)
            } else {
                depth == 1 ? BK.paper2 : BK.card
            }
        }
        .frame(width: 260, height: 320)
        .overlay(Rectangle().stroke(BK.ink, lineWidth: 2))
        .overlay(alignment: .topLeading) {
            if isTop { stamp(add: true).opacity(Double(max(0, lean))).padding(.top, 48).padding(.leading, 18) }
        }
        .overlay(alignment: .topTrailing) {
            if isTop { stamp(add: false).opacity(Double(max(0, -lean))).padding(.top, 48).padding(.trailing, 18) }
        }
        .rotationEffect(.degrees(isTop ? Double(dragOffset.width / 14) : (depth == 1 ? -4 : 5)))
        .offset(isTop ? dragOffset : .zero)
        // The stack order (topGenre drawn last) means only the front card
        // ever receives the drag; `isTop` just guards state writes.
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard isTop, !flying else { return }
                    dragOffset = value.translation
                    let past = abs(value.translation.width) > commitDistance
                    if past != pastThreshold {
                        pastThreshold = past
                        if past { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                    }
                }
                .onEnded { value in
                    guard isTop, !flying else { return }
                    pastThreshold = false
                    if value.translation.width > commitDistance {
                        swipe(liked: true)
                    } else if value.translation.width < -commitDistance {
                        swipe(liked: false)
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = .zero }
                    }
                }
        )
    }

    private func stamp(add: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: add ? "checkmark" : "xmark").font(.system(size: 20, weight: .heavy))
            Text(add ? "ADD" : "SKIP").font(.system(size: 24, weight: .heavy)).kerning(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .overlay(Rectangle().stroke(.white, lineWidth: 3))
        .rotationEffect(.degrees(add ? -14 : 14))
    }

    private var hintRow: some View {
        HStack {
            Text("← SKIP")
                .foregroundStyle(leaningSkip ? BK.crimson : BK.muted)
                .opacity(leaningAdd ? 0.4 : 1)
            Spacer()
            Text("ADD →")
                .foregroundStyle(leaningAdd ? BK.sage : BK.muted)
                .opacity(leaningSkip ? 0.4 : 1)
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .kerning(1.4)
    }

    // MARK: - Controls

    private func swipeButton(add: Bool) -> some View {
        let active = add ? leaningAdd : leaningSkip
        let dimmed = add ? leaningSkip : leaningAdd
        let fill: Color = active ? (add ? BK.sage : BK.crimson) : (add ? BK.ink : BK.card)
        return Button { swipe(liked: add) } label: {
            HStack(spacing: 7) {
                Image(systemName: add ? "checkmark" : "xmark").font(.system(size: 14, weight: .bold))
                Text(add ? "Add" : "Skip").font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(active || add ? Color.white : BK.ink)
            .frame(width: 108, height: 54)
            .background(fill)
            .overlay(Rectangle().stroke(BK.ink, lineWidth: 2))
            .background(Rectangle().fill(BK.ink).offset(x: 4, y: 4))
        }
        .buttonStyle(.plain)
        .scaleEffect(active ? 1.06 : 1)
        .opacity(dimmed ? 0.35 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: active)
        .disabled(topGenre == nil || flying)
        .accessibilityLabel("\(add ? "Add" : "Skip") \(topGenre?.label ?? "")")
    }

    private var mascot: some View {
        let quip: String? = leaningAdd ? "ooh, yes!" : (leaningSkip ? "nah, next!" : nil)
        return Image("SwipeMascotIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 70)
            .scaleEffect(x: leaningSkip ? -1 : 1, y: 1)
            .rotationEffect(.degrees(Double(lean) * -6))
            .overlay(alignment: .top) {
                if let quip {
                    Text(quip)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(BK.ink)
                        .fixedSize()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(BK.card)
                        .overlay(Rectangle().stroke(BK.ink, lineWidth: 2))
                        .rotationEffect(.degrees(lean > 0 ? -3 : 3))
                        .offset(y: -36)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: quip)
            .accessibilityHidden(true)
    }

    private func swipe(liked: Bool) {
        guard let genre = topGenre, !flying else { return }
        flying = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeIn(duration: 0.2)) {
            dragOffset = CGSize(width: liked ? 520 : -520, height: dragOffset.height + 30)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                dragOffset = .zero
                if deck.first?.id == genre.id { deck.removeFirst() }
                if liked { viewModel.toggleGenre(genre.id) }
            }
            if deck.isEmpty {
                if viewModel.selectedGenres.count < 3 {
                    // Ran out of cards before hitting 3 — reshuffle the skipped
                    // ones so the reader isn't stuck.
                    deck = Genre.all.filter { !viewModel.selectedGenres.contains($0.id) }.shuffled()
                } else {
                    // Seen every genre: nothing left to decide, so move on.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        viewModel.continueFromGenres()
                    }
                }
            }
            flying = false
        }
    }
}
