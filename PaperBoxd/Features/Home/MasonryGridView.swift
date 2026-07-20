import SwiftUI

/// 2-column masonry (Pinterest-style) layout using the Layout protocol.
/// Items fill the shorter column so covers of varying heights leave no gaps.
struct MasonryGridView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    @ViewBuilder let content: (Item) -> Content

    init(items: [Item], spacing: CGFloat = 12, @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        MasonryLayout(columns: 2, spacing: spacing) {
            ForEach(items) { item in
                content(item)
            }
        }
        .drawingGroup()
    }
}

// MARK: - Layout Engine

private struct MasonryLayout: Layout {
    let columns: Int
    let spacing: CGFloat

    struct CacheData {
        var heights: [CGFloat] = []
    }

    func makeCache(subviews: Subviews) -> CacheData { CacheData() }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let totalWidth = proposal.width ?? 0
        let colWidth = (totalWidth - spacing * CGFloat(columns + 1)) / CGFloat(columns)
        var colHeights = Array(repeating: CGFloat(0), count: columns)

        for subview in subviews {
            let col = colHeights.indices.min(by: { colHeights[$0] < colHeights[$1] })!
            let size = subview.sizeThatFits(ProposedViewSize(width: colWidth, height: nil))
            colHeights[col] += size.height + spacing
        }

        cache.heights = colHeights
        return CGSize(width: totalWidth, height: (colHeights.max() ?? 0) + spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        let colWidth = (bounds.width - spacing * CGFloat(columns + 1)) / CGFloat(columns)
        var colHeights = Array(repeating: bounds.minY + spacing, count: columns)

        for subview in subviews {
            let col = colHeights.indices.min(by: { colHeights[$0] < colHeights[$1] })!
            let x = bounds.minX + spacing + CGFloat(col) * (colWidth + spacing)
            let size = subview.sizeThatFits(ProposedViewSize(width: colWidth, height: nil))
            subview.place(at: CGPoint(x: x, y: colHeights[col]),
                         proposal: ProposedViewSize(width: colWidth, height: size.height))
            colHeights[col] += size.height + spacing
        }
    }
}
