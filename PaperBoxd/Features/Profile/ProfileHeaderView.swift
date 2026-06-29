import SwiftUI

struct ProfileHeaderView: View {
    let profile: UserProfile
    let isOwnProfile: Bool
    let isFollowLoading: Bool
    let streak: Int?
    let bannerCovers: [String]
    let onFollow: () -> Void
    let onMessage: () -> Void
    let onEdit: () -> Void
    let onShare: () -> Void
    let onFollowers: () -> Void
    let onFollowing: () -> Void
    var onEditBanner: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            banner
                .overlay(alignment: .bottomLeading) { avatar.padding(.leading, 20).offset(y: 44) }

            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 52) // clears the overlapping avatar

                Text(profile.displayName)
                    .font(PB.serif(30))
                    .foregroundStyle(Color("TextPrimary"))

                handleRow.padding(.top, 8)

                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(PB.serifItalic(15))
                        .foregroundStyle(Color("TextPrimary").opacity(0.78))
                        .lineSpacing(2)
                        .padding(.top, 12)
                }

                statStrip.padding(.top, 20)

                actionRow.padding(.top, 16)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Banner

    private var banner: some View {
        ZStack {
            if let urlStr = profile.bannerURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: { spineStrip }
            } else {
                spineStrip
            }

            LinearGradient(
                stops: [
                    .init(color: Color("Background").opacity(0.05), location: 0),
                    .init(color: Color("Background").opacity(0.65), location: 0.6),
                    .init(color: Color("Background"), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
        .frame(height: 168)
        .clipped()
        .overlay(alignment: .topTrailing) {
            if let onEditBanner {
                Button(action: onEditBanner) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 52)
                .padding(.trailing, 14)
            }
        }
    }

    private var spineStrip: some View {
        HStack(spacing: 3) {
            ForEach(0..<12, id: \.self) { i in
                spineColor(i)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(2)
            }
        }
        .blur(radius: 1.2)
        .saturation(0.7)
        .opacity(0.85)
        .scaleEffect(1.08)
    }

    private func spineColor(_ i: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.42, green: 0.16, blue: 0.22),
            Color(red: 0.22, green: 0.29, blue: 0.16),
            Color(red: 0.35, green: 0.22, blue: 0.42),
            Color(red: 0.16, green: 0.42, blue: 0.35),
            Color(red: 0.23, green: 0.29, blue: 0.42),
            Color(red: 0.42, green: 0.35, blue: 0.16),
            Color(red: 0.16, green: 0.35, blue: 0.42),
            Color(red: 0.42, green: 0.22, blue: 0.30),
        ]
        return palette[i % palette.count]
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
            if let since = readingSince {
                dot
                Text(since)
                    .font(PB.mono(10))
                    .tracking(1)
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
    }

    private var dot: some View {
        Text("·").foregroundStyle(Color("TextSecondary").opacity(0.6))
    }

    private var readingSince: String? {
        let year = String(profile.createdAt.prefix(4))
        guard year.count == 4, Int(year) != nil else { return nil }
        return "Reading since \(year)"
    }

    // MARK: - Stat strip

    private var statStrip: some View {
        HStack(spacing: 6) {
            statCell(value: profile.booksReadCount, label: "Books", action: nil)
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
                PillButton(title: "Edit profile", style: .primary, action: onEdit)
                PillButton(title: "Share profile", style: .ghost, action: onShare)
            } else {
                let following = profile.isFollowing ?? false
                PillButton(
                    title: following ? "Following" : "Follow",
                    systemImage: following ? nil : "plus",
                    style: following ? .ghost : .primary,
                    loading: isFollowLoading,
                    action: onFollow
                )
                PillButton(title: "Message", style: .ghost, action: onMessage)
            }
        }
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }
}
