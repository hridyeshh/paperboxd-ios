import SwiftUI

struct ProfileHeaderView: View {
    let profile: UserProfile
    var booksCount: Int? = nil
    let isOwnProfile: Bool
    let isFollowLoading: Bool
    let streak: Int?
    let bannerCovers: [String]
    let onFollow: () -> Void
    let onEdit: () -> Void
    let onSettings: () -> Void
    let onFollowers: () -> Void
    let onFollowing: () -> Void
    var onShare: () -> Void = {}
    var onEditBanner: (() -> Void)? = nil
    var onReport: () -> Void = {}
    var onBlock: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                avatar

                VStack(alignment: .leading, spacing: 8) {
                    Text(profile.displayName)
                        .font(PB.serif(28))
                        .foregroundStyle(Color("TextPrimary"))
                        .fixedSize(horizontal: false, vertical: true)

                    handleRow
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8) // wordmark clearance now comes from the scroll's topInset

            VStack(alignment: .leading, spacing: 0) {
                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(PB.serifItalic(15))
                        .foregroundStyle(Color("TextPrimary").opacity(0.78))
                        .lineSpacing(2)
                        .padding(.top, 16)
                }

                statStrip.padding(.top, 20)

                actionRow.padding(.top, 16)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Avatar

    private var avatar: some View {
        ZStack {
            if let urlStr = profile.avatarURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    PB.avatarGradient
                }
            } else {
                PB.avatarGradient
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color("Background"), lineWidth: 3))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }

    // MARK: - Handle row

    private var handleRow: some View {
        HStack(spacing: 8) {
            Text("@\(profile.username)")
                .font(PB.mono(12))
                .foregroundStyle(Color("TextSecondary"))
            if !profile.pronouns.isEmpty {
                dot
                Text(profile.pronouns.joined(separator: "/"))
                    .font(.system(size: 12))
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
    }

    private var dot: some View {
        Text("·").foregroundStyle(Color("TextSecondary").opacity(0.6))
    }

    // MARK: - Stat strip

    private var statStrip: some View {
        HStack(spacing: 6) {
            statCell(value: booksCount ?? profile.booksReadCount, label: "Books", action: nil)
            statCell(value: streak ?? 0, label: "Streak", action: nil)
            statCell(value: profile.followersCount, label: "Friends", action: onFollowers)
            statCell(value: profile.diaryEntriesCount, label: "Reviews", action: nil)
        }
        .padding(.vertical, 18)
        .overlay(alignment: .top) { Rectangle().fill(Color("Border")).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color("Border")).frame(height: 1) }
    }

    private func statCell(value: Int, label: String, action: (() -> Void)?) -> some View {
        let content = VStack(spacing: 4) {
            Text(formatCount(value))
                .font(PB.serif(22))
                .foregroundStyle(Color("TextPrimary"))
            Text(label.uppercased())
                .font(PB.mono(9.5))
                .tracking(1.6)
                .foregroundStyle(Color("TextSecondary"))
        }
        .frame(maxWidth: .infinity)

        return Group {
            if let action {
                Button(action: action) { content }.buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 8) {
            if isOwnProfile {
                PillButton(title: "Edit profile", style: .brutalPrimary, action: onEdit)
                PillButton(title: "Share profile", style: .brutalGhost, action: onShare)
            } else {
                let following = profile.isFollowing ?? false
                let requested = profile.hasRequested ?? false
                PillButton(
                    title: following ? "Following" : (requested ? "Requested" : "Follow"),
                    systemImage: (following || requested) ? nil : "plus",
                    style: (following || requested) ? .ghost : .primary,
                    loading: isFollowLoading,
                    action: onFollow
                )
                Menu {
                    Button("Report user", systemImage: "flag") { onReport() }
                    Button("Block user", systemImage: "hand.raised", role: .destructive) { onBlock() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color("TextPrimary"))
                        .frame(width: 44, height: 40)
                        .overlay(Rectangle().strokeBorder(Color("TextPrimary").opacity(0.7), lineWidth: 2))
                }
            }
        }
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }
}
