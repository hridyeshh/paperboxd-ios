import SwiftUI

struct LeaderboardView: View {
    @StateObject private var vm: LeaderboardViewModel
    @State private var path = NavigationPath()

    init(viewer: User) {
        _vm = StateObject(wrappedValue: LeaderboardViewModel(viewer: viewer))
    }

    #if DEBUG
    init(preview viewModel: LeaderboardViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }
    #endif

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .top) {
                Color("Background").ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    tabBar
                    content
                }

                if vm.myStats != nil {
                    yourRankBar
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 96)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: LBUserDestination.self) { dest in
                ProfileView(username: dest.username, viewer: vm.viewer)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Eyebrow(text: "Ranked by devotion")
            Text("The Reading Order")
                .font(PB.serif(30, .bold))
                .foregroundStyle(Color("TextPrimary"))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(LeaderboardTab.allCases) { t in
                    Button { vm.tab = t } label: {
                        Text(t.label)
                            .font(.system(size: 13, weight: vm.tab == t ? .semibold : .medium))
                            .foregroundStyle(vm.tab == t ? Color("Background") : Color("TextSecondary"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(vm.tab == t ? Color("TextPrimary") : Color("Surface"))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.entries.isEmpty {
            ProgressView().tint(Color("Accent")).frame(maxHeight: .infinity)
        } else if let err = vm.errorMessage, vm.entries.isEmpty {
            errorView(err)
        } else if vm.entries.isEmpty {
            emptyView
        } else {
            ScrollView {
                VStack(spacing: 18) {
                    if top3.count == 3 {
                        podium
                    }
                    rankedList
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 180)
            }
            .refreshable { await vm.refresh() }
        }
    }

    private var top3: [LeaderboardEntry] { Array(vm.entries.prefix(3)) }
    private var rest: [LeaderboardEntry] {
        vm.entries.count > 3 ? Array(vm.entries.dropFirst(3)) : []
    }

    // MARK: - Podium

    private var podium: some View {
        // order: 2nd, 1st, 3rd
        HStack(alignment: .bottom, spacing: 9) {
            podiumCard(top3[1], rank: 2)
            podiumCard(top3[0], rank: 1)
            podiumCard(top3[2], rank: 3)
        }
    }

    private func podiumCard(_ entry: LeaderboardEntry, rank: Int) -> some View {
        let medal = LBMedal.color(rank)
        return Button {
            path.append(LBUserDestination(username: entry.username))
        } label: {
            VStack(spacing: 0) {
                Text("\(rank)")
                    .font(PB.serif(13, .bold))
                    .foregroundStyle(medal)
                    .frame(width: rank == 1 ? 28 : 24, height: rank == 1 ? 28 : 24)
                    .overlay(Circle().strokeBorder(medal, lineWidth: 2))
                    .padding(.bottom, 9)

                LBAvatar(username: entry.username, size: rank == 1 ? 52 : 42)

                Text(entry.username.split(separator: " ").first.map(String.init) ?? entry.username)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Color("TextPrimary"))
                    .lineLimit(1)
                    .padding(.top, 8)

                Text(formatValue(vm.tab.value(entry)))
                    .font(PB.mono(14, .semibold))
                    .foregroundStyle(Color("TextPrimary"))
                    .padding(.top, 4)

                Text(vm.tab.unit.uppercased())
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Color("TextSecondary"))
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, rank == 1 ? 16 : 14)
            .padding(.bottom, 13)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(rank == 1 ? medal.opacity(0.10) : Color("Surface"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(rank == 1 ? medal.opacity(0.35) : Color("Border"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ranked list

    private var rankedList: some View {
        VStack(spacing: 0) {
            ForEach(Array(rest.enumerated()), id: \.element.id) { idx, entry in
                rankRow(entry, rank: idx + 4)
                if entry.id != rest.last?.id {
                    Rectangle().fill(Color("Border")).frame(height: 1)
                        .padding(.leading, 59)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color("Surface"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color("Border"), lineWidth: 1)
        )
    }

    private func rankRow(_ entry: LeaderboardEntry, rank: Int) -> some View {
        let isMe = entry.userID == vm.myStats?.userID
        return Button {
            path.append(LBUserDestination(username: entry.username))
        } label: {
            HStack(spacing: 11) {
                Text("\(rank)")
                    .font(PB.mono(14, .semibold))
                    .foregroundStyle(Color("TextSecondary"))
                    .frame(width: 26)

                LBAvatar(username: entry.username, size: 38)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(entry.username)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Color("TextPrimary"))
                            .lineLimit(1)
                        if isMe {
                            Text("YOU")
                                .font(.system(size: 8.5, weight: .bold))
                                .tracking(0.6)
                                .foregroundStyle(Color("Background"))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Color("TextPrimary"), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    HStack(spacing: 5) {
                        Text(entry.levelName)
                            .font(.system(size: 11))
                            .foregroundStyle(Color("TextSecondary"))
                        Text("·").foregroundStyle(Color("TextSecondary").opacity(0.5))
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill").font(.system(size: 9))
                            Text("\(entry.currentStreak)d").font(PB.mono(11, .semibold))
                        }
                        .foregroundStyle(PB.terracotta)
                    }
                }

                Spacer(minLength: 4)

                (
                    Text(formatValue(vm.tab.value(entry)))
                        .font(PB.mono(14, .semibold)).foregroundStyle(Color("TextPrimary"))
                    + Text(vm.tab == .global ? " xp" : "")
                        .font(PB.mono(9)).foregroundStyle(Color("TextSecondary"))
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(isMe ? PB.terracotta.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Your rank bar

    @ViewBuilder
    private var yourRankBar: some View {
        if let me = vm.myStats {
            Button {
                path.append(LBUserDestination(username: me.username))
            } label: {
                HStack(spacing: 12) {
                    VStack(spacing: 1) {
                        Text("RANK")
                            .font(.system(size: 8.5, weight: .semibold)).tracking(1)
                            .foregroundStyle(Color("Background").opacity(0.6))
                        Text(vm.myRank.map { "\($0)" } ?? "—")
                            .font(PB.serif(24, .bold))
                            .foregroundStyle(Color("Background"))
                    }
                    .frame(minWidth: 38)

                    Rectangle().fill(Color("Background").opacity(0.18)).frame(width: 1, height: 32)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(me.username)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color("Background"))
                            .lineLimit(1)
                        Text("\(me.levelName) · \(formatValue(me.totalXP)) XP")
                            .font(.system(size: 11))
                            .foregroundStyle(Color("Background").opacity(0.62))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)

                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill").font(.system(size: 11))
                        Text("Profile").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color("Background"))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color("Background").opacity(0.14), in: Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color("TextPrimary"))
                )
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - States

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color("TextSecondary").opacity(0.5))
            Text(vm.tab == .friends ? "No friends on the board yet" : "No data yet")
                .font(PB.serif(17)).foregroundStyle(Color("TextPrimary"))
            Text(vm.tab == .friends ? "Follow some readers to see how you stack up." : "Start reading to claim your spot.")
                .font(.system(size: 13)).foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 14) {
            Text(msg)
                .font(PB.serifItalic(14)).foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Retry") { Task { await vm.loadEntries() } }
                .foregroundStyle(Color("Accent"))
        }
        .frame(maxHeight: .infinity)
    }

    private func formatValue(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Navigation destination

struct LBUserDestination: Hashable {
    let username: String
}

// MARK: - Medal colors

private enum LBMedal {
    static func color(_ rank: Int) -> Color {
        switch rank {
        case 1:  return Color(red: 0.83, green: 0.69, blue: 0.42) // gold
        case 2:  return Color(red: 0.72, green: 0.70, blue: 0.68) // silver
        default: return Color(red: 0.75, green: 0.52, blue: 0.38) // bronze
        }
    }
}

// MARK: - Initials avatar (gradient by username hash)

struct LBAvatar: View {
    let username: String
    let size: CGFloat

    private static let gradients: [[Color]] = [
        [Color(red: 0.23, green: 0.48, blue: 0.84), Color(red: 0.10, green: 0.10, blue: 0.37)],
        [Color(red: 0.72, green: 0.36, blue: 0.22), Color(red: 0.48, green: 0.22, blue: 0.13)],
        [Color(red: 0.35, green: 0.50, blue: 0.31), Color(red: 0.18, green: 0.29, blue: 0.15)],
        [Color(red: 0.66, green: 0.54, blue: 0.25), Color(red: 0.36, green: 0.29, blue: 0.10)],
        [Color(red: 0.42, green: 0.30, blue: 0.60), Color(red: 0.23, green: 0.13, blue: 0.38)],
        [Color(red: 0.16, green: 0.49, blue: 0.54), Color(red: 0.08, green: 0.23, blue: 0.26)],
        [Color(red: 0.75, green: 0.22, blue: 0.17), Color(red: 0.48, green: 0.10, blue: 0.08)],
        [Color(red: 0.09, green: 0.63, blue: 0.52), Color(red: 0.05, green: 0.35, blue: 0.29)],
    ]

    private var gradient: LinearGradient {
        var hash = 0
        for c in username.unicodeScalars { hash = (hash &* 31 &+ Int(c.value)) & 0x7fffffff }
        let pair = Self.gradients[hash % Self.gradients.count]
        return LinearGradient(colors: pair, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var initials: String {
        String(username.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            gradient
            Text(initials)
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color("Border"), lineWidth: 1))
    }
}
