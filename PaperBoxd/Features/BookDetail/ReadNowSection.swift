import SwiftUI

/// "Read now" — store links out of the app. Rendered inside BookDetailView
/// under the same brutalist section header as its siblings. Hidden when the
/// book has no links (uncached external result).
struct ReadNowSection: View {
    let links: BookReadLinks
    let header: AnyView
    /// Opens the in-app reader; only wired when the book is public domain.
    var onReadFree: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            VStack(spacing: 10) {
                if let onReadFree, links.isPublicDomain, links.gutenbergHtmlUrl != nil {
                    Button(action: onReadFree) {
                        HStack(spacing: 10) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("READ FREE")
                                .font(.system(size: 13, weight: .black)).tracking(0.5)
                            Spacer()
                            Text("PUBLIC DOMAIN")
                                .font(PB.mono(9, .semibold)).tracking(1)
                                .opacity(0.8)
                        }
                        .foregroundStyle(BK.paper)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity).frame(height: 46)
                    }
                    .buttonStyle(BrutalButtonStyle(fill: BK.accent, shadowColor: BK.ink, offset: 3))
                }
                ForEach(links.stores, id: \.label) { store in
                    Button {
                        UIApplication.shared.open(store.url)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "book")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(BK.accent)
                            Text(store.label.uppercased())
                                .font(.system(size: 13, weight: .black)).tracking(0.5)
                                .foregroundStyle(BK.ink)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(BK.muted)
                        }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity).frame(height: 46)
                    }
                    .buttonStyle(BrutalButtonStyle(fill: BK.paper, shadowColor: BK.ink, offset: 3))
                }
            }
            .padding(.trailing, 3) // room for the offset shadow
        }
    }
}
