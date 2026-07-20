import SwiftUI

/// PreferenceKey that lets any descendant view request the bottom dock be hidden.
/// MainTabView reads this via .onPreferenceChange and animates the dock off-screen.
/// True wins — any child saying "hide me" hides the dock.
struct HideDockPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    /// Call from a leaf view (e.g. BookDetailView) to hide the dock while it's on screen.
    func hidesBottomDock(_ hide: Bool = true) -> some View {
        preference(key: HideDockPreferenceKey.self, value: hide)
    }
}
