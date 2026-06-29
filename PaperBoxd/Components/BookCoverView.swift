import SwiftUI

/// Async book cover image with three states: loading shimmer, success, failure.
/// Safe with nil URL. Forces reload when URL changes via .id(url).
/// Never pass `.infinity` as width — use GridCoverCell or GeometryReader at the call site.
struct BookCoverView: View {
    let url: String?
    let width: CGFloat
    let cornerRadius: CGFloat

    @State private var shimmer: Double = 0.4

    var body: some View {
        Group {
            if let urlStr = url,
               let imageURL = URL(string: urlStr.replacingOccurrences(of: "http://", with: "https://")) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        failurePlaceholder
                    default:
                        loadingPlaceholder
                    }
                }
            } else {
                failurePlaceholder
            }
        }
        .frame(width: max(0, width.isFinite ? width : 0), 
               height: max(0, width.isFinite ? width * 1.5 : 0))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .id(url)
    }

    private var loadingPlaceholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color("Surface"))
            .opacity(shimmer)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    shimmer = 0.75
                }
            }
    }

    private var failurePlaceholder: some View {
        ZStack {
            Color("Surface")
            Image(systemName: "book.closed")
                .font(.system(size: width * 0.22, weight: .light))
                .foregroundStyle(Color("TextSecondary"))
        }
    }
}
