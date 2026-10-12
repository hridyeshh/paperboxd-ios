import SwiftUI

struct DiaryNavItem: Hashable, Identifiable {
    let entry: DiaryEntry
    /// Open with the "Add to thread" box focused.
    var compose = false
    var id: String { entry.rowKey }
    static func == (lhs: DiaryNavItem, rhs: DiaryNavItem) -> Bool { lhs.id == rhs.id && lhs.compose == rhs.compose }
    func hash(into hasher: inout Hasher) { hasher.combine(id); hasher.combine(compose) }
}

/// A thought and its thread: every post in writing order joined by a line,
/// with a composer under the last one for the author.
struct DiaryEntryDetailView: View {
    let entry: DiaryEntry
    let viewer: User
    var compose = false

    @State private var thread: [DiaryEntry]
    @State private var isLoading = true
    @State private var draft = ""
    @State private var isPosting = false
    @State private var postError: String?
    @State private var shareTarget: ShareTarget?
    @State private var deleteTarget: DiaryEntry?
    @State private var deleteError: String?
    @State private var reportTarget: DiaryEntry?
    /// Set after posting a follow-up — not on load, which must open at the first thought.
    @State private var scrollToComposer = false
    @FocusState private var composerFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private struct ShareTarget: Identifiable {
        let entry: DiaryEntry
        let label: String?
        var id: String { entry.id }
    }

    init(entry: DiaryEntry, viewer: User, compose: Bool = false) {
        self.entry = entry
        self.viewer = viewer
        self.compose = compose
        _thread = State(initialValue: [entry])
    }

    private var root: DiaryEntry { thread[0] }
    private var isOwnThread: Bool { viewer.username?.lowercased() == root.username.lowercased() }
    private var isThread: Bool { thread.count > 1 }

    var body: some View {
        NavigationStack {
            dialogs(chrome(threadScroll))
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // The app is light-only; sheets don't inherit the root's scheme.
        .preferredColorScheme(.light)
    }

    private var threadScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(thread.enumerated()), id: \.element.id) { idx, item in
                        threadItem(item, at: idx)
                    }
                    if isLoading && thread.count == 1 {
                        PBSpinner().frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    if isOwnThread {
                        composer.id("composer")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: scrollToComposer) { _, go in
                guard go else { return }
                withAnimation { proxy.scrollTo("composer", anchor: .bottom) }
                scrollToComposer = false
            }
        }
    }

    private func threadItem(_ item: DiaryEntry, at idx: Int) -> ThreadItem {
        let label: String? = isThread ? "\(idx + 1)/\(thread.count)" : nil
        return ThreadItem(
            entry: item,
            isFirst: idx == 0,
            joinsNext: idx < thread.count - 1 || isOwnThread,
            viewer: viewer,
            onShare: { shareTarget = ShareTarget(entry: item, label: label) },
            onDelete: { deleteTarget = item },
            onReport: { reportTarget = item }
        )
    }

    private func chrome<V: View>(_ content: V) -> some View {
        content
            .background(Color("Background").ignoresSafeArea())
            .navigationTitle(isThread ? "Thread" : "Thought")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
                    }
                    .accessibilityLabel("Close")
                    .tint(Color("TextPrimary"))
                }
            }
            .navigationDestination(for: String.self) { bookId in
                BookDetailView(bookId: bookId, user: viewer)
            }
            .navigationDestination(for: AuthorNav.self) { AuthorDetailView(nav: $0) }
            .task { await loadThread() }
            .sheet(item: $shareTarget) { target in
                ThoughtShareSheet(entry: target.entry, threadLabel: target.label)
                    .presentationDetents([.large])
            }
    }

    private var deletesWholeThread: Bool { deleteTarget?.id == root.id && isThread }

    private func dialogs<V: View>(_ content: V) -> some View {
        content
            .alert(
                deletesWholeThread ? "Delete this thread?" : "Delete this thought?",
                isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
            ) {
                Button("Delete", role: .destructive) {
                    if let t = deleteTarget { Task { await delete(t) } }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(deletesWholeThread
                     ? "The first thought takes the whole thread with it. This can't be undone."
                     : "This can't be undone.")
            }
            .alert("Couldn't delete", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
            .alert("Couldn't add to thread", isPresented: Binding(get: { postError != nil }, set: { if !$0 { postError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(postError ?? "")
            }
            .confirmationDialog(
                "Report thought",
                isPresented: Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } }),
                titleVisibility: .visible
            ) {
                ForEach(ModerationService.reportReasons, id: \.self) { reason in
                    Button(reason) {
                        guard let id = reportTarget?.id else { return }
                        Task { try? await ModerationService.report(contentType: "thought", contentID: id, reason: reason) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .top, spacing: 11) {
            AvatarView(url: root.avatarURL, size: 40)
            VStack(alignment: .leading, spacing: 8) {
                TextField("Add to this thread…", text: $draft, axis: .vertical)
                    .font(.system(size: 15.5, design: .serif))
                    .lineLimit(1...8)
                    .focused($composerFocused)
                    .padding(.top, 10)
                HStack {
                    Text(root.isPrivate ? "Private, like the rest of the thread" : "Joins the thread under the same book")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color("TextSecondary"))
                    Spacer()
                    Button {
                        Task { await post() }
                    } label: {
                        Group {
                            if isPosting { ProgressView().tint(.white) } else { Text("Post") }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color("Background"))
                        .frame(minWidth: 56, minHeight: 32)
                        .padding(.horizontal, 6)
                        .background(Capsule().fill(Color("TextPrimary")))
                    }
                    .buttonStyle(.plain)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                    .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                }
                .padding(.top, 6)
                .overlay(alignment: .top) { Rectangle().fill(Color("Border")).frame(height: 1) }
            }
        }
        .padding(.top, 4)
        .onAppear { if compose { composerFocused = true } }
    }

    // MARK: - Actions

    private func loadThread() async {
        defer { isLoading = false }
        if let full = try? await ThoughtService.thread(for: entry), !full.isEmpty {
            thread = full
        }
    }

    private func post() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let last = thread.last else { return }
        isPosting = true
        defer { isPosting = false }
        do {
            let created = try await ThoughtService.continueThread(after: last, content: text)
            draft = ""
            withAnimation(.snappy) { thread.append(created) }
            scrollToComposer = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch let e as APIError {
            postError = e.errorDescription
        } catch {
            postError = error.localizedDescription
        }
    }

    private func delete(_ target: DiaryEntry) async {
        do {
            let _: Empty = try await APIClient.shared.request(
                path: Endpoints.thought(username: target.username, thoughtId: target.id),
                method: .delete, requiresAuth: true
            )
            NotificationCenter.default.post(name: .diaryEntryDeleted, object: target.id)
            if target.id == root.id {
                dismiss()
            } else {
                withAnimation(.snappy) { thread.removeAll { $0.id == target.id } }
            }
        } catch let e as APIError {
            deleteError = e.errorDescription
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

// MARK: - Thread item

private struct ThreadItem: View {
    let entry: DiaryEntry
    let isFirst: Bool
    /// Draw the line down to the next post (or the composer).
    let joinsNext: Bool
    let viewer: User
    var onShare: () -> Void
    var onDelete: () -> Void
    var onReport: () -> Void

    @StateObject private var toggles: ThoughtToggles

    init(entry: DiaryEntry, isFirst: Bool, joinsNext: Bool, viewer: User,
         onShare: @escaping () -> Void, onDelete: @escaping () -> Void, onReport: @escaping () -> Void) {
        self.entry = entry
        self.isFirst = isFirst
        self.joinsNext = joinsNext
        self.viewer = viewer
        self.onShare = onShare
        self.onDelete = onDelete
        self.onReport = onReport
        _toggles = StateObject(wrappedValue: ThoughtToggles(entry))
    }

    private var isOwn: Bool { viewer.username?.lowercased() == entry.username.lowercased() }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            VStack(spacing: 4) {
                AvatarView(url: entry.avatarURL, size: 40)
                if joinsNext {
                    Rectangle()
                        .fill(Color("Border"))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    ThoughtHeader(entry: entry)
                    Menu {
                        if isOwn {
                            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
                        } else {
                            Button(action: onReport) { Label("Report", systemImage: "flag") }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color("TextSecondary"))
                            .frame(width: 32, height: 24)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("More")
                }

                if isFirst, entry.book == nil, let t = entry.title, !t.isEmpty {
                    Text(t)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color("TextPrimary"))
                }

                Text(entry.plainText)
                    .font(.system(size: 16.5, design: .serif))
                    .foregroundStyle(Color("TextPrimary"))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if isFirst, let book = entry.book {
                    NavigationLink(value: book.id) {
                        ThoughtBookChip(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }

                ThoughtActionBar(entry: entry, isOwn: isOwn, toggles: toggles, onContinue: nil, onShare: onShare)
                    .padding(.top, 2)
            }
            .padding(.bottom, 14)
        }
    }
}
