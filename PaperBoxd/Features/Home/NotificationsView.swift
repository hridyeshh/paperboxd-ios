import SwiftUI

/// Friend-activity feed shown from the home bell. Mirrors the web ActivityPopover:
/// recent activity from people the user follows, tap-through to the book.
struct NotificationsView: View {
    let activities: [FriendActivity]
    let user: User
    var followRequests: [FollowRequestUser] = []
    var onRespondToRequest: (String, Bool) -> Void = { _, _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()

    /// This is a feed of people you follow — never surface your own actions
    /// (e.g. liking your own diary entry).
    private var visibleActivities: [FriendActivity] {
        activities.filter { $0.userID != user.id }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color("Background").ignoresSafeArea()
                if visibleActivities.isEmpty && followRequests.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            // Requests sit above the feed: they need an answer,
                            // the rest is only news.
                            if !followRequests.isEmpty {
                                HStack {
                                    Text("Follow requests")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                ForEach(followRequests) { request in
                                    requestRow(request)
                                }
                            }

                            ForEach(visibleActivities) { activity in
                                row(activity)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 24)
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
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func requestRow(_ request: FollowRequestUser) -> some View {
        HStack(spacing: 11) {
            VStack(alignment: .leading, spacing: 6) {
                (Text("@\(request.username) ").font(.subheadline.weight(.semibold))
                    + Text("wants to follow you").font(.subheadline).foregroundColor(.secondary))
                HStack(spacing: 8) {
                    Button("Confirm") { onRespondToRequest(request.username, true) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button("Decline") { onRespondToRequest(request.username, false) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func row(_ a: FriendActivity) -> some View {
        Button {
            if let bookId = a.bookID { path.append(bookId) }
        } label: {
            HStack(alignment: .top, spacing: 11) {
                AvatarView(url: a.avatarURL, size: 38)

                VStack(alignment: .leading, spacing: 6) {
                    (
                        Text("@\(a.username) ").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color("TextPrimary"))
                        + Text(a.verbPhrase).font(.system(size: 13)).foregroundStyle(Color("TextSecondary"))
                        + Text(a.objectTitle.map { " \($0)" } ?? "").font(.system(size: 13, weight: .medium)).foregroundStyle(Color("TextPrimary"))
                    )
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                    Text(a.relativeTime.uppercased())
                        .font(PB.mono(10))
                        .tracking(0.8)
                        .foregroundStyle(Color("TextSecondary"))
                }

                Spacer(minLength: 6)

                Circle()
                    .fill(Color("Accent"))
                    .frame(width: 7, height: 7)
                    .padding(.top, 5)
            }
            .padding(13)
            // Moderate brutalism: card surface, thin ink border, small hard
            // offset shadow (not the heavy 5–6px the design mockup uses).
            .background(Color("Surface"))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color("TextPrimary"), lineWidth: 1.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color("TextPrimary"))
                    .offset(x: 3, y: 3)
            )
            .padding(.trailing, 3)
            .padding(.bottom, 3)
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
