import SwiftUI

/// Generic horizontal scroll carousel with a title header.
struct HorizontalCarouselView<Item: Identifiable, Content: View>: View {
    let title: String
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("TextPrimary"))
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                // Top-aligned: cards of different heights (two-line vs
                // one-line titles, an optional reason) otherwise centre and
                // the covers drift along the rail.
                HStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in
                        content(item)
                    }
                }
                .padding(.leading, 20)
                .padding(.trailing, 20)
            }
        }
    }
}
