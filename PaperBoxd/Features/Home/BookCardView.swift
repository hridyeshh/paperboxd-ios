import SwiftUI

/// Single card in the masonry home feed. Cover-first, title + author below.
/// Tapping pushes BookDetailView via NavigationLink value.
/// Appearing fires impression tracking via onImpression callback.
struct BookCardView: View {
    let item: RecommendationItem
    var onImpression: ((String) -> Void)?

    var body: some View {
        NavigationLink(value: item.id) {
            VStack(alignment: .leading, spacing: 6) {
                coverImage
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color("TextPrimary"))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !item.authorLine.isEmpty {
                    Text(item.authorLine)
                        .font(.system(size: 11))
                        .foregroundStyle(Color("TextSecondary"))
                        .lineLimit(1)
                }

                if let reason = item.reason, !reason.isEmpty {
                    SignalPillView(reason: reason, reasonType: item.reasonType)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            onImpression?(item.id)
        }
    }

    private var coverImage: some View {
        GeometryReader { geo in
            AsyncImage(url: URL(string: item.coverURL ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width * 1.5)
                        .clipped()
                case .failure:
                    coverPlaceholder(width: geo.size.width)
                default:
                    shimmerPlaceholder(width: geo.size.width)
                }
            }
            .frame(width: geo.size.width, height: geo.size.width * 1.5)
        }
        .frame(height: 0)  // height set by aspect ratio below
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
    }

    private func shimmerPlaceholder(width: CGFloat) -> some View {
        ShimmerRect(cornerRadius: 8, width: width, height: width * 1.5)
    }

    private func coverPlaceholder(width: CGFloat) -> some View {
        ZStack {
            Color("Surface")
            Image(systemName: "book.closed")
                .font(.system(size: width * 0.22, weight: .light))
                .foregroundStyle(Color("TextSecondary"))
        }
        .frame(width: width, height: width * 1.5)
    }
}

// MARK: - Shimmer placeholder

struct ShimmerRect: View {
    let cornerRadius: CGFloat
    let width: CGFloat
    let height: CGFloat
    @State private var opacity: Double = 0.3

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color("Surface"))
            .frame(width: width, height: height)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    opacity = 0.75
                }
            }
    }
}
