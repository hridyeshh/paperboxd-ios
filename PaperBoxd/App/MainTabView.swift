import SwiftUI
import UIKit

enum DockTab: String, CaseIterable, Identifiable {
    case home, search, scan, leaderboard, you

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home:        return "Home"
        case .search:      return "Search"
        case .scan:        return "Scan"
        case .leaderboard: return "Leaderboard"
        case .you:         return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home:        return "house"
        case .search:      return "magnifyingglass"
        case .scan:        return "barcode.viewfinder"
        case .leaderboard: return "trophy"
        case .you:         return "person"
        }
    }

    var activeIcon: String {
        switch self {
        case .home:        return "house.fill"
        case .search:      return "magnifyingglass"
        case .scan:        return "barcode.viewfinder"
        case .leaderboard: return "trophy.fill"
        case .you:         return "person.fill"
        }
    }

    var isSpecial: Bool { self == .scan }
}

struct MainTabView: View {
    let user: User
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: DockTab = .home
    @State private var previousTab: DockTab = .home
    @State private var hideDock = false
    @State private var profileImage: Image?
    @State private var showScan = false

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                nativeTabView
            } else {
                dock
            }
        }
        // Scan & Know is a modal flow, not a tab destination. Intercept selection of
        // the .scan tab: present the flow and bounce the selection back so the tab
        // highlight never sticks on Scan.
        .fullScreenCover(isPresented: $showScan) {
            ScanFlowView()
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .scan {
                showScan = true
                selectedTab = previousTab
            } else {
                previousTab = newTab
            }
        }
    }

    // MARK: - iOS 26+ : native Liquid Glass tab bar (shrink on scroll + sliding indicator)

    @available(iOS 26.0, *)
    private var nativeTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(value: DockTab.home) {
                HomeView(user: user)
            } label: {
                Image(systemName: "house")
            }
            Tab(value: DockTab.search) {
                SearchView(viewer: user)
            } label: {
                Image(systemName: "magnifyingglass")
            }
            Tab(value: DockTab.scan) {
                HomeView(user: user) // placeholder — barcode scan feature TBD
            } label: {
                Image(systemName: "barcode.viewfinder")
            }
            Tab(value: DockTab.leaderboard) {
                LeaderboardView(viewer: user)
            } label: {
                Image(systemName: "trophy")
            }
            Tab(value: DockTab.you) {
                NavigationStack {
                    ProfileView(username: user.username ?? "", viewer: user)
                }
                .environment(\.colorScheme, .light)   // profile tab is light-mode only
                .preferredColorScheme(.light)
            } label: {
                profileImage ?? Image(systemName: "person")
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Color("TextPrimary"))
        .task {
            if profileImage == nil {
                profileImage = await Self.loadCircularAvatar(from: user.avatarURL)
            }
        }
        // Reload the baked dock avatar when the user changes it in Edit Profile.
        // The static `user.avatarURL` is stale by then, so rebuild from the URL
        // the edit flow broadcasts.
        .onReceive(NotificationCenter.default.publisher(for: .paperboxdAvatarUpdated)) { note in
            let url = note.userInfo?["url"] as? String
            Task { profileImage = await Self.loadCircularAvatar(from: url) }
        }
    }

    /// Downloads the user's avatar and bakes it into a circular, original-rendered
    /// image so the system tab bar shows the photo (not a tinted glyph).
    private static func loadCircularAvatar(from urlString: String?) async -> Image? {
        guard let urlString,
              let url = URL(string: urlString.replacingOccurrences(of: "http://", with: "https://")),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let ui = UIImage(data: data) else { return nil }
        let size = CGSize(width: 30, height: 30)
        let circular = UIGraphicsImageRenderer(size: size).image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
            let scale = max(size.width / ui.size.width, size.height / ui.size.height)
            let draw = CGSize(width: ui.size.width * scale, height: ui.size.height * scale)
            ui.draw(in: CGRect(x: (size.width - draw.width) / 2,
                               y: (size.height - draw.height) / 2,
                               width: draw.width, height: draw.height))
        }
        return Image(uiImage: circular.withRenderingMode(.alwaysOriginal))
    }

    // MARK: - iOS < 26 : custom glass dock (icon-only) fallback

    private var dock: some View {
        ZStack(alignment: .bottom) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomDock(selected: $selectedTab)
                .offset(y: hideDock ? 140 : 0)
                .opacity(hideDock ? 0 : 1)
                .animation(.spring(response: 0.32, dampingFraction: 0.85), value: hideDock)
        }
        .ignoresSafeArea(.keyboard)
        .onPreferenceChange(HideDockPreferenceKey.self) { hideDock = $0 }
        .onChange(of: selectedTab) { _, newTab in
            if newTab != .scan {
                previousTab = newTab
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .home:
            HomeView(user: user)
        case .search:
            SearchView(viewer: user)
        case .scan:
            HomeView(user: user) // placeholder — barcode scan feature TBD
        case .leaderboard:
            LeaderboardView(viewer: user)
        case .you:
            NavigationStack {
                ProfileView(username: user.username ?? "", viewer: user)
            }
            .environment(\.colorScheme, .light)   // profile tab is light-mode only
            .preferredColorScheme(.light)
        }
    }

}

private struct CustomDock: View {
    @Binding var selected: DockTab

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(DockTab.allCases) { tab in
                if tab.isSpecial {
                    scanButton
                } else {
                    regularButton(tab)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background {
            ZStack {
                Capsule(style: .continuous).fill(.regularMaterial)
                // heavier dark tint — far less see-through than before
                Capsule(style: .continuous).fill(Color("Background").opacity(0.78))
            }
        }
        .overlay {
            // top-lit rim highlight
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        }
        .clipShape(Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 22, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    // MARK: - Scan (center button: white circle, icon only)

    private var scanButton: some View {
        Button { selected = .scan } label: {
            ZStack {
                Circle()
                    .fill(Color("TextPrimary"))
                    .frame(width: 38, height: 38)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color("Background"))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Regular tab (icon only; active gets a soft glow halo)

    private func regularButton(_ tab: DockTab) -> some View {
        let active = selected == tab
        return Button { selected = tab } label: {
            ZStack {
                if active {
                    Circle()
                        .fill(Color("TextPrimary").opacity(0.16))
                        .frame(width: 42, height: 42)
                        .blur(radius: 9)
                }
                Image(systemName: active ? tab.activeIcon : tab.icon)
                    .font(.system(size: 22, weight: active ? .semibold : .regular))
            }
            .foregroundStyle(active ? Color("TextPrimary") : Color("TextSecondary").opacity(0.6))
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
