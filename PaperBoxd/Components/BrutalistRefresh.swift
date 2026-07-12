import SwiftUI
import UIKit

// Tint the system pull-to-refresh spinner with the app accent so it's the same
// normal spinner used everywhere else, and visible during the pull gesture.
private let styleRefreshSpinner: Void = {
    UIRefreshControl.appearance().tintColor = UIColor(named: "Accent")
}()

/// Pull-to-refresh wrapper. Owns its own ScrollView, so use it in place of
/// `ScrollView { ... }.refreshable { ... }`. Shows the normal system spinner
/// (accent-tinted) during the pull.
struct BrutalistRefreshable<Content: View>: View {
    let onRefresh: () async -> Void
    /// Top inset for the scroll content. Raise it on screens with a floating
    /// header (e.g. the profile wordmark bar) so the refresh spinner drops
    /// below the header instead of overlapping it.
    var topInset: CGFloat = 0
    @ViewBuilder var content: () -> Content

    var body: some View {
        let _ = styleRefreshSpinner
        ScrollView {
            content()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: topInset)
        }
        .refreshable {
            await onRefresh()
        }
        .tint(Color("Accent"))
    }
}
