import SwiftUI

/// Friend-activity feed shown from the home bell. Mirrors the web ActivityPopover:
/// recent activity from people the user follows, tap-through to the book.
struct NotificationsView: View {
    let activities: [FriendActivity]
    let user: User

    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color("Background").ignoresSafeArea()
                if activities.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(activities) { activity in
                                row(activity)
                                Rectangle().fill(Color("Border").opacity(0.5)).frame(height: 1)
                                    .padding(.leading, 64)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("Updates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color("Accent"))
                }
            }
            .navigationDestination(for: String.self) { bookId in
                BookDetailView(bookId: bookId, user: user)
            }
        }
    }

    @ViewBuilder
    private func row(_ a: FriendActivity) -> some View {
        Button {
            if let bookId = a.bookID { path.append(bookId) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                AvatarView(url: a.avatarURL, size: 38)

                VStack(alignment: .leading, spacing: 3) {
                    (
                        Text("@\(a.username) ").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color("TextPrimary"))
                        + Text(a.verbPhrase).font(.system(size: 13)).foregroundStyle(Color("TextSecondary"))
                        + Text(a.objectTitle.map { " \($0)" } ?? "").font(.system(size: 13, weight: .medium)).foregroundStyle(Color("TextPrimary"))
                    )
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                    Text(a.relativeTime)
                        .font(PB.mono(10))
                        .foregroundStyle(Color("TextSecondary"))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(a.bookID == nil)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.slash")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color("TextSecondary").opacity(0.6))
            Text("No updates yet")
                .font(PB.serif(17))
                .foregroundStyle(Color("TextPrimary"))
            Text("Follow people to see their reading activity here.")
                .font(.system(size: 13))
                .foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
