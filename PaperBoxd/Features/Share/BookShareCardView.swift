import SwiftUI

/// Reading status for the share flow — drives the little pill badge at the top
/// of the card ("JUST FINISHED", etc.).
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

/// The shareable book card, matching the PaperBoxd "Share Card" design system:
/// a moody blurred-cover dark finish (the cover blown up + darkened) with the
/// script wordmark and a status pill up top, the sharp cover centred, a star
/// rating, a big serif title, author · year, a hairline, an italic note, and a
/// signature footer pill (wordmark + @handle + an audio-waveform motif).
/// A clean warm-paper light finish inverts the palette.
///
/// Drawn at base points (540×960 story, 540×540 square) so ImageRenderer
/// rasterises at scale 2 → 1080px.
struct BookShareCardView: View {
    enum Format {
        case story, square

        var baseSize: CGSize {
            switch self {
            case .story:  return CGSize(width: 540, height: 960)
            case .square: return CGSize(width: 540, height: 540)
            }
        }

        /// scale → 1080px on the short edge.
        var renderScale: CGFloat { 1080.0 / baseSize.width }
    }

    enum Theme { case dark, light }

    let title: String
    let author: String
    let year: String?
    let coverImage: UIImage?
    let handle: String?          // rendered as-is, e.g. "@hridyesh"
    let rating: Int?             // 0–5 whole stars
    let note: String?            // the reader's line, shown in italics
    let statusLabel: String      // e.g. "Just finished"
    let theme: Theme
    let format: Format

    // MARK: Palette
    private let cream = Color(red: 0.949, green: 0.929, blue: 0.882)   // #f2ede1
    private let darkBackdrop = Color(red: 0.078, green: 0.063, blue: 0.043) // #141008
    private let paperTop = Color(red: 0.949, green: 0.933, blue: 0.906) // #f2eee7
    private let paperBottom = Color(red: 0.851, green: 0.788, blue: 0.678) // #d9c9ad

    private var ink: Color { theme == .dark ? cream : Color(red: 0.10, green: 0.08, blue: 0.05) }
    private var inkSoft: Color { ink.opacity(0.62) }
    private var hairlineColor: Color { ink.opacity(0.18) }

    var body: some View {
        ZStack {
            canvasBackdrop
            ZStack {
                background
                content
                    .padding(format == .story ? 36 : 28)
            }
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .padding(.horizontal, format == .story ? 76 : 80)
            .padding(.vertical, format == .story ? 210 : 80)
            .shadow(color: .black.opacity(0.18), radius: 36, x: 0, y: 16)
        }
        .frame(width: format.baseSize.width, height: format.baseSize.height)
        .clipped()
    }

    /// The area behind the floating card — always plain white (X-style share
    /// image), so the card reads as a small object on a clean page.
    private var canvasBackdrop: some View {
        Color.white
    }

    // MARK: - Background

    @ViewBuilder
    private var background: some View {
        if theme == .dark {
            ZStack {
                darkBackdrop
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: format.baseSize.width, height: format.baseSize.height)
                        .blur(radius: 60)
                        .opacity(0.55)
                }
                LinearGradient(
                    colors: [.black.opacity(0.15), .black.opacity(0.35), .black.opacity(0.85)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        } else {
            LinearGradient(colors: [paperTop, paperBottom], startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch format {
        case .story:  storyContent
        case .square: squareContent
        }
    }

    private var storyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            Spacer(minLength: 18)
            cover(width: 176)   // sized so the shorter story card still fits title + note
                .frame(maxWidth: .infinity)
            Spacer(minLength: 18)
            details(alignment: .leading)
            Spacer(minLength: 18)
            footer
        }
    }

    private var squareContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            Spacer(minLength: 14)
            HStack(alignment: .center, spacing: 22) {
                cover(width: 150)
                details(alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 14)
            footer
        }
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack(alignment: .center) {
            Text("PaperBoxd")
                .font(.custom("SnellRoundhand-Black", size: 26))
                .foregroundStyle(ink)
            Spacer()
            if !statusLabel.isEmpty { statusBadge }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(cream)
                .frame(width: 5, height: 5)
            Text(statusLabel.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(cream)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(theme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.88))
        )
    }

    private func cover(width: CGFloat) -> some View {
        let height = width * 1.5
        return Group {
            if let coverImage {
                Image(uiImage: coverImage).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.66, green: 0.53, blue: 0.37),
                                 Color(red: 0.45, green: 0.34, blue: 0.22)],
                        startPoint: .top, endPoint: .bottom
                    )
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(cream)
                        .multilineTextAlignment(.center)
                        .padding(14)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 36, x: 0, y: 10)
    }

    private func details(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            if let rating, rating > 0 {
                starRow(rating).padding(.bottom, 12)
            }
            Text(title)
                .font(PB.serif(34, .black))
                .foregroundStyle(ink)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            Text(authorLine)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(inkSoft)
                .padding(.top, 8)

            if let note, !note.isEmpty {
                Rectangle().fill(hairlineColor)
                    .frame(height: 1)
                    .padding(.vertical, 16)
                Text("“\(note)”")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(inkSoft)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var authorLine: String {
        if let year, !year.isEmpty { return "\(author) · \(year)" }
        return author
    }

    private func starRow(_ rating: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < rating ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundStyle(i < rating ? ink : ink.opacity(0.3))
            }
        }
    }

    // MARK: - Footer pill (@handle) — hugs its content, sits bottom-left

    @ViewBuilder
    private var footer: some View {
        if let handle, !handle.isEmpty {
            Text(handle)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(cream)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(theme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.9))
                )
                .overlay(
                    Capsule().strokeBorder(cream.opacity(theme == .dark ? 0.12 : 0), lineWidth: 1)
                )
        }
    }
}

/// The full shared image — for this design the card *is* the canvas, so this is
/// a thin alias kept for the sheet's render call.
struct ShareComposition: View {
    let title: String
    let author: String
    let year: String?
    let coverImage: UIImage?
    let handle: String?
    let rating: Int?
    let note: String?
    let statusLabel: String
    let theme: BookShareCardView.Theme
    let format: BookShareCardView.Format

    var body: some View {
        BookShareCardView(
            title: title,
            author: author,
            year: year,
            coverImage: coverImage,
            handle: handle,
            rating: rating,
            note: note,
            statusLabel: statusLabel,
            theme: theme,
            format: format
        )
    }
}
