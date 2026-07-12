import SwiftUI

/// The single app-wide loading spinner. Normal system spinner in the paper/accent
/// tint. Use for screen and content loading states so every screen matches.
/// Override `tint` only for contrast on filled/colored surfaces (e.g. buttons).
struct PBSpinner: View {
    var tint: Color = Color("Accent")

    var body: some View {
        ProgressView().tint(tint)
    }
}
