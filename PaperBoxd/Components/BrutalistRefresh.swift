import SwiftUI

/// Pull-to-refresh with a brutalist indicator instead of the system spinner.
/// Owns its own ScrollView, so use it in place of
/// `ScrollView { ... }.refreshable { ... }`.
///
/// Uses the system `.refreshable` for the (rock-solid) pull gesture + trigger,
/// hides the system spinner with a clear tint, and draws our own brutalist
/// square as a top overlay while the refresh runs — guaranteed visible.
struct BrutalistRefreshable<Content: View>: View {
    let onRefresh: () async -> Void
    /// Distance from the scroll's top edge to the spinner. Raise it on screens
    /// with a floating header (e.g. the profile wordmark bar) so the spinner
    /// clears the header instead of overlapping it.
    var topInset: CGFloat = 12
    @ViewBuilder var content: () -> Content

    @State private var isRefreshing = false

    var body: some View {
        ScrollView {
            // Reserve space so the overlay spinner never sits on top of content.
            Color.clear
                .frame(height: isRefreshing ? topInset + 44 : 0)

            content()
                .tint(Color("Accent"))   // restore tint for content subtree
        }
        .tint(.clear)                    // hide the system refresh spinner
        .refreshable {
            withAnimation(.easeInOut(duration: 0.2)) { isRefreshing = true }
            await onRefresh()
            withAnimation(.easeInOut(duration: 0.2)) { isRefreshing = false }
        }
        .overlay(alignment: .top) {
            if isRefreshing {
                BrutalistSpinner()
                    .padding(.top, topInset)
                    .transition(.opacity)
            }
        }
    }
}

/// A hard-edged square with an ink border and offset shadow that spins.
struct BrutalistSpinner: View {
    @State private var angle: Double = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color("TextPrimary"))
                .frame(width: 28, height: 28)
                .offset(x: 3, y: 3)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color("Surface"))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color("TextPrimary"), lineWidth: 2.5)
                )
                .frame(width: 28, height: 28)
                .rotationEffect(.degrees(angle))
        }
        .onAppear {
            angle = 0
            withAnimation(.linear(duration: 0.7).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
    }
}
