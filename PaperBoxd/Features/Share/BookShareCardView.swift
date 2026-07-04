import SwiftUI

/// Reading status for the share flow. Kept for BookDetailView's status mapping;
/// the web-style card doesn't render it, but the label seeds future variants.
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

/// The shareable book card, matching the web share card exactly
/// (app/api/og/share/route.tsx): pure black canvas, a white rounded card with
/// @username top-left, bold title + uppercase author on the left, the cover on
/// the right, and a hairline "paperboxd.in" footer. Drawn at base point sizes
/// (540×960 story, 540×540 square) so ImageRenderer rasterises at scale 2 → 1080px.
struct BookShareCardView: View {
    enum Format {
        case story, square

        /// Full share canvas in points (9:16 story for Instagram, 1:1 square).
        var baseSize: CGSize {
            switch self {
            case .story:  return CGSize(width: 540, height: 960)
            case .square: return CGSize(width: 540, height: 540)
            }
        }

        /// scale → 1080px on the short edge.
        var renderScale: CGFloat { 1080.0 / baseSize.width }
    }

    let title: String
    let author: String
    let coverImage: UIImage?
    let handle: String?     // rendered as-is, e.g. "@anais"
    let rating: Int?        // viewer's own rating; web card shows none
    let format: Format

    // Web design tokens (px values from the OG route, halved to points)
    private let cardPadding: CGFloat = 24        // p-48px
    private let cardCorner: CGFloat = 25         // rounded-50px
    private let cardHeight: CGFloat = 325        // 650px
    private let coverSize = CGSize(width: 140, height: 210) // 280×420px
    private let authorGray = Color(red: 0.42, green: 0.447, blue: 0.502)  // #6b7280
    private let footerGray = Color(red: 0.82, green: 0.835, blue: 0.859)  // #d1d5db
    private let hairline   = Color(red: 0.953, green: 0.957, blue: 0.965) // #f3f4f6

    var body: some View {
        ZStack {
            Color.black
            card
                .padding(.horizontal, 32) // p-64px canvas margin
        }
        .frame(width: format.baseSize.width, height: format.baseSize.height)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: @username
            if let handle, !handle.isEmpty {
                Text(handle)
                    .font(.system(size: 18, weight: .black))
                    .tracking(-0.36)
                    .foregroundStyle(.black.opacity(0.5))
            }

            // Middle: title/author left, cover right
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 30, weight: .black))
                        .tracking(-0.6)
                        .lineSpacing(1)
                        .foregroundStyle(.black)
                        .lineLimit(4)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(author.uppercased())
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(0.9)
                        .foregroundStyle(authorGray)
                        .lineLimit(2)
                        .padding(.top, 12)
                    if let rating, rating > 0 {
                        starRow(rating)
                            .padding(.top, 12)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                coverFace
            }
            .frame(maxHeight: .infinity)
            .padding(.vertical, 16)

            // Footer: paperboxd.in over a hairline
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(hairline).frame(height: 1)
                Text("paperboxd.in")
                    .font(.system(size: 15, weight: .black))
                    .tracking(3.75) // 0.25em
                    .foregroundStyle(footerGray)
                    .padding(.top, 16)
            }
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .fill(.white)
                .shadow(color: .white.opacity(0.10), radius: 40)
        )
    }

    private var coverFace: some View {
        Group {
            if let coverImage {
                Image(uiImage: coverImage).resizable().scaledToFill()
            } else {
                ZStack {
                    Color(red: 0.953, green: 0.957, blue: 0.965) // #f3f4f6
                    Text("NO COVER")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(footerGray)
                }
            }
        }
        .frame(width: coverSize.width, height: coverSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.black.opacity(0.05), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 5)
    }

    private func starRow(_ rating: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < rating ? "star.fill" : "star")
                    .font(.system(size: 15))
                    .foregroundStyle(i < rating ? .black : Color(red: 0.82, green: 0.835, blue: 0.859))
            }
        }
    }
}

/// The full shared image — for the web-style card the canvas *is* the design
/// (black background, white card), so this is a thin alias kept for the sheet's
/// render call.
struct ShareComposition: View {
    let title: String
    let author: String
    let coverImage: UIImage?
    let handle: String?
    let rating: Int?
    let format: BookShareCardView.Format

    var body: some View {
        BookShareCardView(
            title: title,
            author: author,
            coverImage: coverImage,
            handle: handle,
            rating: rating,
            format: format
        )
    }
}
