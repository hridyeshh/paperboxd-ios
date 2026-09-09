import SwiftUI

// MARK: - Avatar with XP ring

/// The profile avatar wrapped in an XP arc, with the level name plated beneath.
///
/// The arc's gradient is the web profile's `xpRingGrad` verbatim so a reader
/// sees the same ring on either surface; everything around it is repainted for
/// the light brutalist profile (ink border, hard-shadowed plate) rather than
/// web's rounded pill on a dark ground.
///
/// No XP figure appears out here — the total, the remainder and the bar all
/// live in `ProfileLevelSheet`. Out here the arc is the whole story.
struct XPRingAvatar: View {
    let avatarURL: String?
    /// `nil` while the stats request is in flight, or on a profile the server
    /// won't give stats for. Then: plain avatar, no ring, no plate, no tap.
    let progress: ReaderProgress?
    var onTap: (() -> Void)?

    private let block: CGFloat = 112
    private let avatar: CGFloat = 88
    private let ringWidth: CGFloat = 5

    /// #B85C38 → #A8893F, lifted from the web profile's ring.
    private static let arcStart = Color(red: 0.722, green: 0.361, blue: 0.220)
    private static let arcEnd = Color(red: 0.659, green: 0.537, blue: 0.247)
    private static let arc = LinearGradient(
        colors: [arcStart, arcEnd], startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// Paper2 — the ring's unfilled track.
    private static let track = Color(red: 0.914, green: 0.886, blue: 0.820)

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                if let progress {
                    Circle()
                        .stroke(Self.track, lineWidth: ringWidth)
                        .frame(width: block - ringWidth, height: block - ringWidth)
                    Circle()
                        .trim(from: 0, to: progress.ringFill)
                        .stroke(Self.arc, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                        .frame(width: block - ringWidth, height: block - ringWidth)
                        .rotationEffect(.degrees(-90))
                }
                avatarImage
            }
            .frame(width: block, height: block)

            if let progress {
                levelPlate(progress).offset(y: 8)
            }
        }
        .frame(width: block, height: progress == nil ? block : block + 14)
        .contentShape(Rectangle())
        .onTapGesture { if progress != nil { onTap?() } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(progress != nil ? .isButton : [])
        .accessibilityHint(progress != nil ? "Shows level details" : "")
    }

    private var avatarImage: some View {
        ZStack {
            if let urlStr = avatarURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    PB.avatarGradient
                }
            } else {
                PB.avatarGradient
            }
        }
        .frame(width: avatar, height: avatar)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color("TextPrimary"), lineWidth: 2))
    }

    private func levelPlate(_ p: ReaderProgress) -> some View {
        HStack(spacing: 6) {
            Text("\(p.level)")
                .font(PB.mono(10, .bold))
                .foregroundStyle(Color("Background"))
                .frame(width: 18, height: 18)
                .background(Color("TextPrimary"))
            Text(p.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color("TextPrimary"))
                .fixedSize()
        }
        .padding(.leading, 5)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(Color("Surface"))
        .overlay(Rectangle().strokeBorder(Color("TextPrimary"), lineWidth: 2))
        .background(Rectangle().fill(Color("TextPrimary")).offset(x: 3, y: 3))
    }

    private var accessibilityText: String {
        guard let p = progress else { return "Profile photo" }
        return "Level \(p.level), \(p.name), \(p.totalXP.formatted()) XP, "
             + "\(p.xpToNext.formatted()) to level \(p.level + 1)"
    }
}

// MARK: - Level sheet

/// Tapping the avatar opens this. Every XP figure in the app lives here.
///
/// Web lists all 35 levels; this shows the seven named tiers with the current
/// one plated, because 35 rows is a scroll nobody finishes on a phone.
struct ProfileLevelSheet: View {
    let progress: ReaderProgress
    /// Someone else's profile: keep the tiers and their standing, drop the
    /// "to go" figures and the earn table — neither is actionable for a viewer.
    var isOwnProfile: Bool = true

    /// Sage — matches Android's `HL.Sage`; `PBStyle` carries no green.
    private static let done = Color(red: 0.184, green: 0.490, blue: 0.353)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if isOwnProfile { progressBar }
                tiers
                if isOwnProfile { earn }
            }
            .padding(.horizontal, 20)
            // 20 clears the drag indicator, which floats over the content.
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color("Background"))
        // A sheet gets its own presentation context and does NOT inherit the
        // profile tab's forced light mode, so the asset colours resolved dark
        // and snapped light on drag. Same pair every light-only screen uses.
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .presentationDetents([.height(612), .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("\(progress.level)")
                .font(PB.mono(19, .bold))
                .foregroundStyle(Color("Background"))
                .frame(width: 46, height: 46)
                .background(Color("TextPrimary"))
                .overlay(Rectangle().strokeBorder(Color("TextPrimary"), lineWidth: 2))
                .background(Rectangle().fill(PB.terracotta).offset(x: 3, y: 3))
                .padding(.trailing, 3)
                .padding(.bottom, 3)

            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(text: "Level \(progress.level) · The reading order")
                Text(progress.name)
                    .font(PB.serif(24))
                    .foregroundStyle(Color("TextPrimary"))
            }
            Spacer(minLength: 0)
        }
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(progress.totalXP.formatted()) XP")
                    .font(PB.mono(15, .bold))
                    .foregroundStyle(Color("TextPrimary"))
                Spacer()
                Text("\(progress.xpToNext.formatted()) TO LEVEL \(progress.level + 1)")
                    .font(PB.mono(10))
                    .foregroundStyle(Color("TextSecondary"))
            }
            GeometryReader { geo in
                Rectangle()
                    .fill(LinearGradient(colors: [PB.terracotta, Color(red: 0.659, green: 0.537, blue: 0.247)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * progress.ringFill)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 12)
            .background(Color("Border"))
            .overlay(Rectangle().strokeBorder(Color("TextPrimary"), lineWidth: 2))

            HStack {
                Text("\(progress.levelStart.formatted())")
                Spacer()
                Text("\(progress.levelEnd.formatted())")
            }
            .font(PB.mono(9))
            .foregroundStyle(Color("TextSecondary"))
        }
    }

    private var tiers: some View {
        VStack(alignment: .leading, spacing: 7) {
            Eyebrow(text: "The reading order")
            // 2 here, not 4: each row already carries a 3pt shadow gutter below
            // it, so the visible gap is 5.
            VStack(spacing: 2) {
                ForEach(ReaderProgress.tiers, id: \.level) { tier in
                    tierRow(level: tier.level, name: tier.name)
                }
            }
        }
    }

    @ViewBuilder
    private func tierRow(level: Int, name: String) -> some View {
        // "Current" is the tier the level falls inside, not one whose number
        // matches — level 13 is a Bibliophile though the tier starts at 11.
        let next = ReaderProgress.tiers.first { $0.level > level }?.level ?? Int.max
        let isCurrent = progress.level >= level && progress.level < next
        let isUnlocked = progress.level >= next
        let isNext = ReaderProgress.tiers.first(where: { $0.level > progress.level })?.level == level
        let need = ReaderProgress.xpAtStart(of: level)

        HStack(spacing: 10) {
            Text("\(level)")
                .font(PB.mono(10, .bold))
                .foregroundStyle(isCurrent ? Color("TextPrimary") : Color("TextPrimary").opacity(isUnlocked ? 1 : 0.7))
                .frame(width: 22, height: 22)
                .background(isCurrent ? Color("Background") : Color("TextPrimary").opacity(isUnlocked ? 0.12 : 0.06))

            Text(name)
                .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? Color("Background") : (isUnlocked ? Color("TextSecondary") : Color("TextPrimary")))

            Spacer(minLength: 6)

            Text("\(need.formatted()) XP")
                .font(PB.mono(10))
                .foregroundStyle(isCurrent ? Color("Background").opacity(0.7) : Color("TextSecondary"))

            if isCurrent {
                Text("NOW").font(PB.mono(9)).tracking(1.2)
                    .foregroundStyle(Color("Background"))
            } else if isUnlocked {
                Text("done").font(.system(size: 11)).foregroundStyle(Self.done)
            } else if isNext && isOwnProfile {
                Text("\((need - progress.totalXP).formatted()) to go")
                    .font(PB.mono(9.5))
                    .foregroundStyle(PB.likeRed)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
        .background(isCurrent ? Color("TextPrimary") : .clear)
        .overlay {
            if isCurrent {
                Rectangle().strokeBorder(Color("TextPrimary"), lineWidth: 2)
            } else if isNext {
                Rectangle().strokeBorder(Color("Border"), lineWidth: 1)
            }
        }
        .background(isCurrent ? Rectangle().fill(PB.terracotta).offset(x: 3, y: 3) : nil)
        // Every row reserves the same shadow gutter, plated or not, so their
        // edges line up down the column instead of the current one sitting 3pt
        // short of the rest.
        .padding(.trailing, 3)
        .padding(.bottom, 3)
        .opacity(isCurrent || isUnlocked || isNext ? 1 : 0.5)
    }

    private var earn: some View {
        VStack(alignment: .leading, spacing: 8) {
            // A real divider rather than a top overlay — an overlay draws inside
            // the padding, so the rule ended up touching the tiers above it.
            Rectangle()
                .fill(Color("Border"))
                .frame(height: 1)
                .padding(.bottom, 6)

            Eyebrow(text: "How to earn XP")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 20), GridItem(.flexible())], spacing: 3) {
                ForEach(XPAction.all, id: \.label) { action in
                    HStack {
                        Text(action.label)
                            .font(.system(size: 12))
                            .foregroundStyle(Color("TextSecondary"))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("+\(action.xp)")
                            .font(PB.mono(12, .bold))
                            .foregroundStyle(Color("TextPrimary"))
                    }
                }
            }
            Text("\(XPAction.dailyCap) XP a day max — streak and referral bonuses are exempt")
                .font(PB.mono(9.5))
                .foregroundStyle(Color("TextSecondary"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }
}
