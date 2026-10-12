import Combine
import SwiftUI

// MARK: - Service

/// Thought mutations. Paths address the author (`entry.username`), not the
/// profile the row happens to sit on — a repost shows someone else's thought.
enum ThoughtService {
    static func setLiked(_ on: Bool, _ entry: DiaryEntry) async throws -> Int64? {
        let resp: ThoughtCountResponse = try await APIClient.shared.request(
            path: Endpoints.thoughtLike(username: entry.username, thoughtId: entry.id),
            method: on ? .post : .delete, requiresAuth: true
        )
        return resp.likesCount
    }

    static func setReposted(_ on: Bool, _ entry: DiaryEntry) async throws -> Int64? {
        let resp: ThoughtCountResponse = try await APIClient.shared.request(
            path: Endpoints.thoughtRepost(username: entry.username, thoughtId: entry.id),
            method: on ? .post : .delete, requiresAuth: true
        )
        return resp.repostsCount
    }

    static func thread(for entry: DiaryEntry) async throws -> [DiaryEntry] {
        let resp: ThoughtThreadResponse = try await APIClient.shared.request(
            path: Endpoints.thoughtThread(username: entry.username, thoughtId: entry.id),
            method: .get, requiresAuth: true
        )
        return resp.thoughts
    }

    /// Continues `parent`'s thread. The backend takes book and privacy from the thread.
    static func continueThread(after parent: DiaryEntry, content: String) async throws -> DiaryEntry {
        struct Body: Encodable {
            let content: String
            let threadParentID: String
            enum CodingKeys: String, CodingKey {
                case content
                case threadParentID = "thread_parent_id"
            }
        }
        return try await APIClient.shared.request(
            path: Endpoints.userThoughts(username: parent.username),
            method: .post,
            body: Body(content: content, threadParentID: parent.id),
            requiresAuth: true
        )
    }
}

// MARK: - Toggle state

/// Like + repost counts for one thought, optimistic with rollback.
@MainActor
final class ThoughtToggles: ObservableObject {
    @Published private(set) var isLiked: Bool
    @Published private(set) var likesCount: Int64
    @Published private(set) var isReposted: Bool
    @Published private(set) var repostsCount: Int64
    @Published var error: String?
    private let entry: DiaryEntry
    private var busy = false

    /// The backend answers 409 "Already liked/reposted" when a double tap races
    /// the first request; the server already holds the state we asked for.
    private static func alreadyInState(_ error: Error) -> Bool {
        if case .validation(let message) = error as? APIError { return message.hasPrefix("Already") }
        return false
    }

    init(_ entry: DiaryEntry) {
        self.entry = entry
        isLiked = entry.isLiked
        likesCount = entry.likesCount
        isReposted = entry.isReposted
        repostsCount = entry.repostsCount
    }

    func toggleLike() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        let on = !isLiked
        withAnimation(.snappy(duration: 0.25)) { isLiked = on; likesCount = max(0, likesCount + (on ? 1 : -1)) }
        do {
            if let count = try await ThoughtService.setLiked(on, entry) { likesCount = count }
        } catch where Self.alreadyInState(error) {
        } catch {
            withAnimation(.snappy(duration: 0.25)) { isLiked = !on; likesCount = max(0, likesCount + (on ? -1 : 1)) }
        }
    }

    func toggleRepost() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        let on = !isReposted
        withAnimation(.snappy(duration: 0.25)) { isReposted = on; repostsCount = max(0, repostsCount + (on ? 1 : -1)) }
        do {
            if let count = try await ThoughtService.setReposted(on, entry) { repostsCount = count }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch where Self.alreadyInState(error) {
        } catch let e as APIError {
            withAnimation(.snappy(duration: 0.25)) { isReposted = !on; repostsCount = max(0, repostsCount + (on ? -1 : 1)) }
            error = e.errorDescription
        } catch {
            withAnimation(.snappy(duration: 0.25)) { isReposted = !on; repostsCount = max(0, repostsCount + (on ? -1 : 1)) }
        }
    }
}

// MARK: - Pieces

enum ThoughtFormat {
    static func relative(_ iso: String) -> String {
        guard let date = ISO8601.parse(iso) else { return "" }
        let s = max(0, Date().timeIntervalSince(date))
        if s < 60 { return "now" }
        if s < 3600 { return "\(Int(s / 60))m" }
        if s < 86400 { return "\(Int(s / 3600))h" }
        if s < 7 * 86400 { return "\(Int(s / 86400))d" }
        let out = DateFormatter()
        out.dateFormat = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) ? "MMM d" : "MMM d, yyyy"
        return out.string(from: date)
    }
}

struct ThoughtHeader: View {
    let entry: DiaryEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(entry.displayName)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(Color("TextPrimary"))
                .lineLimit(1)
                .layoutPriority(1)
            Text("@\(entry.username)")
                .font(.system(size: 13.5))
                .foregroundStyle(Color("TextSecondary"))
                .lineLimit(1)
            Text("· \(ThoughtFormat.relative(entry.createdAt))")
                .font(.system(size: 13.5))
                .foregroundStyle(Color("TextSecondary"))
                .fixedSize()
            Spacer(minLength: 4)
            if entry.isPrivate {
                Label("Private", systemImage: "lock.fill")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 11))
                    .foregroundStyle(Color("TextSecondary"))
                    .accessibilityLabel("Private")
            }
        }
    }
}

struct ThoughtBookChip: View {
    let entry: DiaryEntry

    var body: some View {
        if let book = entry.book {
            HStack(spacing: 10) {
                BookCoverView(url: book.coverURL, width: 30, cornerRadius: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(PB.serif(13.5))
                        .foregroundStyle(Color("TextPrimary"))
                        .lineLimit(1)
                    if !book.authorLine.isEmpty {
                        Text(book.authorLine)
                            .font(.system(size: 12))
                            .foregroundStyle(Color("TextSecondary"))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                if let r = entry.rating, r > 0 {
                    HStack(spacing: 1.5) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= r ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundStyle(i <= r ? Color("Accent") : Color("TextSecondary").opacity(0.4))
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(r) out of 5 stars")
                }
            }
            .padding(8)
            .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color("Border"), lineWidth: 1))
        }
    }
}

/// Reply-count-free action bar: continue (own), repost, like, share.
struct ThoughtActionBar: View {
    let entry: DiaryEntry
    let isOwn: Bool
    @ObservedObject var toggles: ThoughtToggles
    var onContinue: (() -> Void)?
    var onShare: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if isOwn, let onContinue {
                action(icon: "plus.bubble", label: "Add to thread", action: onContinue)
            } else {
                Color.clear.frame(width: 44, height: 1)
            }
            Spacer()
            action(
                icon: "arrow.2.squarepath",
                count: toggles.repostsCount,
                tint: toggles.isReposted ? Color(red: 0.13, green: 0.55, blue: 0.36) : nil,
                label: toggles.isReposted ? "Undo repost" : "Repost",
                disabled: isOwn || entry.isPrivate
            ) { Task { await toggles.toggleRepost() } }
            Spacer()
            action(
                icon: toggles.isLiked ? "heart.fill" : "heart",
                count: toggles.likesCount,
                tint: toggles.isLiked ? PB.likeRed : nil,
                label: toggles.isLiked ? "Unlike" : "Like"
            ) { Task { await toggles.toggleLike() } }
            Spacer()
            action(icon: "square.and.arrow.up", label: "Share to story", action: onShare)
        }
        .padding(.trailing, 8)
    }

    private func action(
        icon: String,
        count: Int64? = nil,
        tint: Color? = nil,
        label: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .regular))
                    .contentTransition(.symbolEffect(.replace))
                if let count {
                    Text(count > 0 ? "\(count)" : " ")
                        .font(PB.mono(12))
                        .contentTransition(.numericText())
                        .frame(minWidth: 14, alignment: .leading)
                }
            }
            .foregroundStyle(tint ?? Color("TextSecondary"))
            .frame(minWidth: 44, minHeight: 36, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel(label)
        .accessibilityValue(count.map { "\($0)" } ?? "")
    }
}

// MARK: - Row

/// One thought in a profile's Thoughts tab, Twitter-style.
struct ThoughtRow: View {
    let entry: DiaryEntry
    /// Username of the signed-in reader — decides "You reposted" and own-thought actions.
    let viewerUsername: String?
    var onContinue: () -> Void
    var onShare: () -> Void

    @StateObject private var toggles: ThoughtToggles

    init(entry: DiaryEntry, viewerUsername: String?, onContinue: @escaping () -> Void, onShare: @escaping () -> Void) {
        self.entry = entry
        self.viewerUsername = viewerUsername
        self.onContinue = onContinue
        self.onShare = onShare
        _toggles = StateObject(wrappedValue: ThoughtToggles(entry))
    }

    private var isOwn: Bool {
        viewerUsername?.lowercased() == entry.username.lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let by = entry.repostedBy {
                Label(
                    by.username.lowercased() == viewerUsername?.lowercased() ? "You reposted" : "\(by.name.isEmpty ? by.username : by.name) reposted",
                    systemImage: "arrow.2.squarepath"
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color("TextSecondary"))
                .padding(.leading, 22)
            }

            HStack(alignment: .top, spacing: 11) {
                AvatarView(url: entry.avatarURL, size: 40)

                VStack(alignment: .leading, spacing: 5) {
                    ThoughtHeader(entry: entry)

                    if entry.book == nil, let t = entry.title, !t.isEmpty {
                        Text(t)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(Color("TextPrimary"))
                    }

                    Text(entry.plainTextPreview)
                        .font(.system(size: 15.5, design: .serif))
                        .foregroundStyle(Color("TextPrimary"))
                        .lineSpacing(3)
                        .lineLimit(8)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if entry.book != nil {
                        ThoughtBookChip(entry: entry).padding(.top, 5)
                    }

                    if entry.threadCount > 0 {
                        Text("Show this thread · \(entry.threadCount) more")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color("Accent"))
                            .padding(.top, 3)
                    }

                    ThoughtActionBar(
                        entry: entry,
                        isOwn: isOwn,
                        toggles: toggles,
                        onContinue: onContinue,
                        onShare: onShare
                    )
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .alert("Couldn't repost", isPresented: Binding(get: { toggles.error != nil }, set: { if !$0 { toggles.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(toggles.error ?? "")
        }
    }
}
