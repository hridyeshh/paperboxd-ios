import SwiftUI

struct UserSearchResultRow: View {
    let user: UserProfile

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(url: user.avatarURL, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName)
                    .font(PB.serif(14.5))
                    .foregroundStyle(Color("TextPrimary"))
                    .lineLimit(1)
                Text("@\(user.username)")
                    .font(PB.mono(11))
                    .foregroundStyle(Color("TextSecondary"))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(user.booksReadCount)")
                    .font(PB.mono(12, .medium))
                    .foregroundStyle(Color("TextPrimary"))
                Text("BOOKS")
                    .font(PB.mono(8.5))
                    .tracking(1.6)
                    .foregroundStyle(Color("TextSecondary"))
            }
            .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}
