import SwiftUI

struct LeaderboardView: View {
    @StateObject private var vm: LeaderboardViewModel
    @State private var path = NavigationPath()

    // Leaderboard is light-mode only (app window is globally forced dark and the
    // asset colors are single-appearance dark). Fixed light values — same approach
    // as home / search / book page. Mirrors "Leaderboard - Brutalist Mobile.html".
    private let lbBg     = Color(red: 0.949, green: 0.929, blue: 0.882) // paper  #f2ede1
    private let lbCard   = Color(red: 0.992, green: 0.984, blue: 0.965) // card   #fdfbf6
    private let lbSoft   = Color(red: 0.914, green: 0.886, blue: 0.820) // soft   #e9e2d1
    private let lbInk    = Color(red: 0.082, green: 0.082, blue: 0.075) // ink    #151513
    private let lbMuted  = Color(red: 0.416, green: 0.392, blue: 0.337) // muted  #6a6456
    private let lbFaint  = Color(red: 0.702, green: 0.671, blue: 0.600) // faint  #b3ab99
    private let lbLine   = Color(red: 0.902, green: 0.874, blue: 0.816) // line   #e6dfd0
    private let lbAccent = Color(red: 0.824, green: 0.231, blue: 0.149) // accent #d23b26

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
                lbBg.ignoresSafeArea()

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
        .environment(\.colorScheme, .light)   // leaderboard is light-mode only
        .preferredColorScheme(.light)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Eyebrow(text: "Ranked by devotion")
            Text("The Reading Order")
                .font(PB.serif(30, .bold))
                .foregroundStyle(lbInk)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(LeaderboardTab.allCases) { t in
                let on = vm.tab == t
                Button { vm.tab = t } label: {
                    Text(t.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(on ? lbInk : lbMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(on ? lbCard : Color.clear)
                                .shadow(color: on ? .black.opacity(0.10) : .clear, radius: 3, y: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Capsule().fill(lbSoft))
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 16)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.entries.isEmpty {
            PBSpinner().frame(maxHeight: .infinity)
        } else if let err = vm.errorMessage, vm.entries.isEmpty {
            errorView(err)
        } else if vm.entries.isEmpty {
            emptyView
        } else {
            BrutalistRefreshable(onRefresh: { await vm.refresh() }) {
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
        let isFirst = rank == 1
        let shadowColor = isFirst ? lbAccent : lbInk
        let shadowOffset: CGFloat = isFirst ? 6 : 5
        return Button {
            path.append(LBUserDestination(username: entry.username))
        } label: {
            VStack(spacing: 0) {
                // hard square medal — ink (accent for #1)
                Text("\(rank)")
                    .font(.system(size: isFirst ? 14 : 12, weight: .heavy))
                    .foregroundStyle(lbCard)
                    .frame(width: isFirst ? 26 : 22, height: isFirst ? 26 : 22)
                    .background(isFirst ? lbAccent : lbInk)
                    .padding(.bottom, 10)

                LBAvatar(username: entry.username, size: isFirst ? 50 : 40)

                Text(entry.username.split(separator: " ").first.map(String.init) ?? entry.username)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(lbInk)
                    .lineLimit(1)
                    .padding(.top, 8)

                Text(formatValue(vm.tab.value(entry)))
                    .font(PB.mono(15, .bold))
                    .foregroundStyle(lbInk)
                    .padding(.top, 3)

                Text(vm.tab.unit.uppercased())
                    .font(PB.mono(8))
                    .tracking(0.8)
                    .foregroundStyle(lbMuted)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, isFirst ? 18 : 12)
            .padding(.bottom, 11)
            .padding(.horizontal, 8)
            .background(lbCard)
            .overlay(Rectangle().strokeBorder(lbInk, lineWidth: 1.5))
            .background(alignment: .topLeading) {
                Rectangle().fill(shadowColor).offset(x: shadowOffset, y: shadowOffset)
            }
            .padding(.trailing, shadowOffset).padding(.bottom, shadowOffset)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ranked list

    private var rankedList: some View {
        VStack(spacing: 0) {
            ForEach(Array(rest.enumerated()), id: \.element.id) { idx, entry in
                let isMe = entry.userID == vm.myStats?.userID
                let nextIsMe = idx + 1 < rest.count && rest[idx + 1].userID == vm.myStats?.userID
                rankRow(entry, rank: idx + 4)
                // hairline between plain rows; skip around the bordered "me" card
                if entry.id != rest.last?.id && !isMe && !nextIsMe {
                    Rectangle().fill(lbLine).frame(height: 1)
                        .padding(.leading, 59)
                }
            }
        }
    }

    private func rankRow(_ entry: LeaderboardEntry, rank: Int) -> some View {
        let isMe = entry.userID == vm.myStats?.userID
        return Button {
            path.append(LBUserDestination(username: entry.username))
        } label: {
            HStack(spacing: 11) {
                Text("\(rank)")
                    .font(PB.mono(14, .semibold))
                    .foregroundStyle(lbMuted)
                    .frame(width: 26)

                LBAvatar(username: entry.username, size: 38)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(entry.username)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(lbInk)
                            .lineLimit(1)
                        if isMe {
                            Text("YOU")
                                .font(PB.mono(8, .semibold))
                                .tracking(0.6)
                                .foregroundStyle(lbCard)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(lbAccent)
                        }
                    }
                    HStack(spacing: 5) {
                        Text(entry.levelName)
                            .font(.system(size: 11))
                            .foregroundStyle(lbMuted)
                        Text("·").foregroundStyle(lbMuted.opacity(0.5))
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
                        .font(PB.mono(14, .semibold)).foregroundStyle(lbInk)
                    + Text(vm.tab == .global ? " xp" : "")
                        .font(PB.mono(9)).foregroundStyle(lbMuted)
                )
            }
            .padding(.horizontal, isMe ? 12 : 14)
            .padding(.vertical, 11)
            .background(isMe ? lbCard : Color.clear)
            .overlay {
                if isMe {
                    Rectangle().strokeBorder(lbInk, lineWidth: 1.5)
                }
            }
            // brutalist offset shadow only on the "you" row
            .background(alignment: .topLeading) {
                if isMe {
                    Rectangle().fill(lbInk).offset(x: 4, y: 4)
                }
            }
            .padding(isMe ? 6 : 0)
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
                            .foregroundStyle(lbBg.opacity(0.6))
                        Text(vm.myRank.map { "\($0)" } ?? "—")
                            .font(PB.serif(24, .bold))
                            .foregroundStyle(lbBg)
                    }
                    .frame(minWidth: 38)

                    Rectangle().fill(lbBg.opacity(0.18)).frame(width: 1, height: 32)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(me.username)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(lbBg)
                            .lineLimit(1)
                        Text("\(me.levelName) · \(formatValue(me.totalXP)) XP")
                            .font(.system(size: 11))
                            .foregroundStyle(lbBg.opacity(0.62))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)

                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill").font(.system(size: 11))
                        Text("Profile").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(lbBg)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(lbBg.opacity(0.14), in: Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(lbInk)
                .overlay(Rectangle().strokeBorder(lbInk, lineWidth: 1.5))
                // hard offset accent shadow — brutalist signature
                .background(alignment: .topLeading) {
                    Rectangle().fill(lbAccent).offset(x: 5, y: 5)
                }
                .padding(.trailing, 5).padding(.bottom, 5)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - States

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(lbMuted.opacity(0.5))
            Text(vm.tab == .friends ? "No friends on the board yet" : "No data yet")
                .font(PB.serif(17)).foregroundStyle(lbInk)
            Text(vm.tab == .friends ? "Follow some readers to see how you stack up." : "Start reading to claim your spot.")
                .font(.system(size: 13)).foregroundStyle(lbMuted)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 14) {
            Text(msg)
                .font(PB.serifItalic(14)).foregroundStyle(lbMuted)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Retry") { Task { await vm.loadEntries() } }
                .foregroundStyle(lbAccent)
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
        .overlay(Circle().strokeBorder(Color(red: 0.902, green: 0.874, blue: 0.816), lineWidth: 1))
    }
}
