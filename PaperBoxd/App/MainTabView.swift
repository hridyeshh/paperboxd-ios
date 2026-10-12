import SwiftUI

enum DockTab: String, CaseIterable, Identifiable {
    case home, search, inbox, leaderboard, you

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home:        return "Home"
        case .search:      return "Search"
        case .inbox:       return "Messages"
        case .leaderboard: return "Leaderboard"
        case .you:         return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home:        return "house"
        case .search:      return "magnifyingglass"
        case .inbox:       return "paperplane"
        case .leaderboard: return "trophy"
        case .you:         return "person"
        }
    }

    var activeIcon: String {
        switch self {
        case .home:        return "house.fill"
        case .search:      return "magnifyingglass"
        case .inbox:       return "paperplane.fill"
        case .leaderboard: return "trophy.fill"
        case .you:         return "person.fill"
        }
    }
}

struct MainTabView: View {
    let user: User
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: DockTab = .home
    @State private var hideDock = false
    @State private var showScan = false
    // Messages badge on the dock. No push yet: polled while signed in.
    @StateObject private var inbox = InboxModel()

    var body: some View {
        dock
        // Pip — floating Ask Jazy entry point (vibe search + Scan & Know),
        // bottom-right above the dock.
        .overlay(alignment: .bottomTrailing) {
            PipScanButton { showScan = true }
                .padding(.trailing, 18)
                .padding(.bottom, 84)
                .offset(y: hideDock ? 200 : 0)
                .opacity(hideDock ? 0 : 1)
                .animation(.spring(response: 0.32, dampingFraction: 0.85), value: hideDock)
        }
        .onPreferenceChange(HideDockPreferenceKey.self) { hideDock = $0 }
        .fullScreenCover(isPresented: $showScan) {
            JazyView(user: user)
        }
        // Plus: renewal listener + entitlement check, once per signed-in session.
        .task { PlusStore.shared.start() }
        .task {
            while !Task.isCancelled {
                await inbox.refreshBadge()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .onChange(of: selectedTab) { Task { await inbox.refreshBadge() } }
        // Full-screen celebration takeovers (shelved / streak / level-up).
        .overlay { CelebrationOverlayView() }
        // Fusion links, notification taps and the profile list all land here.
        .fullScreenCover(item: $appState.fusionRoute) { route in
            FusionRootView(route: route, user: user)
        }
    }

    // MARK: - Dock

    private var dock: some View {
        ZStack(alignment: .bottom) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomDock(selected: $selectedTab, inboxBadge: inbox.badge.total)
                .offset(y: hideDock ? 140 : 0)
                .opacity(hideDock ? 0 : 1)
                .animation(.spring(response: 0.32, dampingFraction: 0.85), value: hideDock)
        }
        .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .home:
            HomeView(user: user)
        case .search:
            SearchView(viewer: user)
        case .inbox:
            MessagesStack(root: .inbox, viewer: user, inTab: true)
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

/// Brutal-block dock: a flat card with a 2pt ink border and a hard offset shadow,
/// matching the onboarding buttons. The active tab is an ink square that slides
/// between tabs; the unread badge is a crimson square.
private struct CustomDock: View {
    @Binding var selected: DockTab
    var inboxBadge = 0
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DockTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 56)
        .background(Color("Background"), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Color("TextPrimary"), lineWidth: 2))
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color("TextPrimary"))
                .offset(x: 4, y: 4)
        )
        .padding(.leading, 20)
        .padding(.trailing, 24)
        .padding(.bottom, 6)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func tabButton(_ tab: DockTab) -> some View {
        let active = selected == tab
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selected = tab }
        } label: {
            ZStack {
                if active {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color("TextPrimary"))
                        .frame(width: 40, height: 40)
                        .matchedGeometryEffect(id: "active", in: indicator)
                }
                Image(systemName: active ? tab.activeIcon : tab.icon)
                    .font(.system(size: 19, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? Color("Background") : Color("TextSecondary"))
                if tab == .inbox && inboxBadge > 0 {
                    Rectangle()
                        .fill(BK.crimson)
                        .frame(width: 8, height: 8)
                        .overlay(Rectangle().stroke(Color("TextPrimary"), lineWidth: 1.5))
                        .offset(x: 11, y: -10)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab == .inbox && inboxBadge > 0 ? "\(tab.label), \(inboxBadge) new" : tab.label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
