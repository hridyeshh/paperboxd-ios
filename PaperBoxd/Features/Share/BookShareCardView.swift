import SwiftUI

/// Reading status shown in the card's top-right pill. Mirrors the design's
/// STATUS_LABELS.
enum ShareStatus: String, CaseIterable {
    case finished, reading, want, favourite

    var label: String {
        switch self {
        case .finished:  return "Just finished"
        case .reading:   return "Now reading"
        case .want:      return "Want to read"
        case .favourite: return "Favourite of 2026"
        }
    }
}

/// The shareable book card. Built at the design's base point sizes (450×800
/// story, 600² square) so ImageRenderer can rasterise at scale 2.4 / 1.8 → 1080px.
/// Faithful to share/cards.jsx "cover" layout.
struct BookShareCardView: View {
    enum Format {
        case story, square

        /// The card (sticker) base point size.
        var baseSize: CGSize {
            switch self {
            case .story:  return CGSize(width: 450, height: 800)
            case .square: return CGSize(width: 600, height: 600)
            }
        }

        /// The full share canvas (blurred background + card). Same aspect as the
        /// card, sized so the card sits centered with a margin of blurred cover
        /// showing around it — the Spotify "art fills the story" look.
        private var margin: CGFloat { 0.085 }
        var frameSize: CGSize {
            let c = baseSize
            return CGSize(width: c.width / (1 - margin * 2), height: c.height / (1 - margin * 2))
        }

        var cardCorner: CGFloat { self == .story ? 30 : 26 }

        /// scale → ~1080px on the short edge of the full canvas.
        var renderScale: CGFloat { 1080.0 / frameSize.width }

        var pixelSize: CGSize {
            CGSize(width: frameSize.width * renderScale, height: frameSize.height * renderScale)
        }
    }

    let title: String
    let author: String
    let year: String?
    let rating: Double?
    let note: String?
    let coverImage: UIImage?
    let accent: Color
    let handle: String?
    let status: ShareStatus
    let theme: ColorScheme
    let format: Format

    private var base: CGSize { format.baseSize }
    private var isStory: Bool { format == .story }
    private var light: Bool { theme == .light }

    // Design tokens
    private var txt: Color { light ? Color(red: 0.086, green: 0.086, blue: 0.086) : .white }
    private var muted: Color { light ? Color(red: 0.54, green: 0.51, blue: 0.47) : .white.opacity(0.62) }
    private var hair: Color { light ? Color(red: 0.906, green: 0.882, blue: 0.839) : .white.opacity(0.16) }
    private var footBG: Color { light ? Color(red: 0.086, green: 0.086, blue: 0.086) : .white.opacity(0.13) }
    private var footFG: Color { .white }
    private var footBorder: Color { light ? .clear : .white.opacity(0.2) }

    var body: some View {
        ZStack {
            ambient
            inner
        }
        .frame(width: base.width, height: base.height)
        .clipShape(RoundedRectangle(cornerRadius: format.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: format.cardCorner, style: .continuous)
                .strokeBorder(.white.opacity(light ? 0.0 : 0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 40, y: 22)
    }

    // MARK: - Ambient backdrop

    private var ambient: some View {
        ZStack {
            if light {
                Color(red: 0.98, green: 0.972, blue: 0.957)
                if let cover = coverImage {
                    Image(uiImage: cover).resizable().scaledToFill()
                        .frame(width: base.width * 0.8, height: base.height * 0.4)
                        .blur(radius: 90).opacity(0.5)
                        .offset(y: -base.height * 0.32)
                } else {
                    accent.opacity(0.4).blur(radius: 90).frame(height: base.height * 0.4)
                        .offset(y: -base.height * 0.32)
                }
            } else {
                Color(red: 0.07, green: 0.07, blue: 0.08)
                if let cover = coverImage {
                    Image(uiImage: cover).resizable().scaledToFill()
                        .frame(width: base.width, height: base.height)
                        .blur(radius: 80).saturation(1.45).scaleEffect(1.35)
                } else {
                    accent.scaleEffect(1.35).blur(radius: 80)
                }
                scrim
            }
        }
        .frame(width: base.width, height: base.height)
    }

    private var scrim: some View {
        ZStack {
            RadialGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.42)],
                center: UnitPoint(x: 0.5, y: 0.28), startRadius: 0, endRadius: base.height * 0.85
            )
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.42), location: 0),
                    .init(color: .black.opacity(0.12), location: 0.32),
                    .init(color: .black.opacity(0.62), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // MARK: - Inner content

    @ViewBuilder
    private var inner: some View {
        if isStory { storyInner } else { squareInner }
    }

    private var storyInner: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow

            Spacer(minLength: 0)
            coverFace(width: 236)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 0) {
                if let rating, rating > 0 {
                    starRow(rating, size: 19).padding(.bottom, 14)
                }
                titleText(40)
                authorText(17).padding(.top, 10)
            }

            if let note, !note.isEmpty {
                noteText(note, size: 17)
                    .padding(.top, 16)
                    .overlay(alignment: .top) {
                        Rectangle().fill(hair).frame(height: 1)
                    }
                    .padding(.top, 16)
            }

            footer.padding(.top, 22)
        }
        .padding(44)
        .frame(width: base.width, height: base.height, alignment: .topLeading)
    }

    private var squareInner: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow

            HStack(spacing: 30) {
                coverFace(width: 180)
                VStack(alignment: .leading, spacing: 0) {
                    if let rating, rating > 0 {
                        starRow(rating, size: 18).padding(.bottom, 14)
                    }
                    titleText(34)
                    authorText(15).padding(.top, 9)
                    if let note, !note.isEmpty {
                        noteText(note, size: 16).padding(.top, 16)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)

            footer
        }
        .padding(44)
        .frame(width: base.width, height: base.height, alignment: .topLeading)
    }

    // MARK: - Pieces

    private var topRow: some View {
        HStack(alignment: .center) {
            Text("PaperBoxd")
                .font(.custom("SnellRoundhand-Bold", size: isStory ? 30 : 28))
                .foregroundStyle(txt)
            Spacer()
            statusPill
        }
    }

    private var statusPill: some View {
        HStack(spacing: 7) {
            Circle().fill(footFG).frame(width: 6, height: 6)
            Text(status.label.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(footFG)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(footBG, in: Capsule())
        .overlay(Capsule().strokeBorder(footBorder, lineWidth: 1))
    }

    private func coverFace(width: CGFloat) -> some View {
        Group {
            if let cover = coverImage {
                Image(uiImage: cover).resizable().scaledToFill()
            } else {
                ZStack {
                    accent
                    Image(systemName: "book.closed")
                        .font(.system(size: width * 0.3, weight: .light))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 30, y: 20)
    }

    private func titleText(_ size: CGFloat) -> some View {
        Text(title)
            .font(.system(size: size, weight: .semibold, design: .serif))
            .tracking(-0.025 * size)
            .lineSpacing(-2)
            .foregroundStyle(txt)
            .lineLimit(3)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func authorText(_ size: CGFloat) -> some View {
        Text(year.map { "\(author) · \($0)" } ?? author)
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(muted)
            .lineLimit(1)
    }

    private func noteText(_ note: String, size: CGFloat) -> some View {
        Text("“\(note)”")
            .font(.system(size: size, design: .serif)).italic()
            .foregroundStyle(txt)
            .lineSpacing(3)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func starRow(_ rating: Double, size: CGFloat) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: starSymbol(i, rating))
                    .font(.system(size: size))
                    .foregroundStyle(txt)
            }
        }
    }

    private func starSymbol(_ index: Int, _ rating: Double) -> String {
        let i = Double(index)
        if rating >= i + 1 { return "star.fill" }
        if rating >= i + 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("PaperBoxd")
                .font(.custom("SnellRoundhand-Bold", size: 26))
                .foregroundStyle(footFG)
            if let handle, !handle.isEmpty {
                Text(handle)
                    .font(.system(size: 12, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(footFG.opacity(0.62))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 13)
        .background(footBG, in: Capsule())
        .overlay(Capsule().strokeBorder(footBorder, lineWidth: 1))
    }
}

/// Full-bleed blurred-cover backdrop that fills the entire share canvas behind
/// the card — no black borders, the art *is* the background.
struct ShareBackdropView: View {
    let coverImage: UIImage?
    let accent: Color
    let theme: ColorScheme
    let size: CGSize

    private var light: Bool { theme == .light }

    var body: some View {
        ZStack {
            if light {
                Color(red: 0.98, green: 0.972, blue: 0.957)
                cover
                    .opacity(0.6)
                    .blur(radius: 120)
                Color.white.opacity(0.35)
            } else {
                Color(red: 0.06, green: 0.06, blue: 0.07)
                cover
                    .saturation(1.4)
                    .blur(radius: 110)
                // darken so the card reads as a distinct layer on top
                LinearGradient(
                    colors: [.black.opacity(0.35), .black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private var cover: some View {
        if let coverImage {
            Image(uiImage: coverImage)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .scaleEffect(1.4)
        } else {
            accent.scaleEffect(1.4)
        }
    }
}

/// The full shared image: blurred-cover background filling the frame, with the
/// rounded card centered on top.
struct ShareComposition: View {
    let title: String
    let author: String
    let year: String?
    let rating: Double?
    let note: String?
    let coverImage: UIImage?
    let accent: Color
    let handle: String?
    let status: ShareStatus
    let theme: ColorScheme
    let format: BookShareCardView.Format

    var body: some View {
        ZStack {
            ShareBackdropView(
                coverImage: coverImage,
                accent: accent,
                theme: theme,
                size: format.frameSize
            )
            BookShareCardView(
                title: title,
                author: author,
                year: year,
                rating: rating,
                note: note,
                coverImage: coverImage,
                accent: accent,
                handle: handle,
                status: status,
                theme: theme,
                format: format
            )
            .scaleEffect(0.88)
        }
        .frame(width: format.frameSize.width, height: format.frameSize.height)
    }
}
