import SwiftUI

struct DiaryNavItem: Hashable, Identifiable {
    let entry: DiaryEntry
    var id: String { entry.id }
    static func == (lhs: DiaryNavItem, rhs: DiaryNavItem) -> Bool { lhs.entry.id == rhs.entry.id }
    func hash(into hasher: inout Hasher) { hasher.combine(entry.id) }
}

struct DiaryEntryDetailView: View {
    let entry: DiaryEntry
    let viewer: User

    @State private var isLiked: Bool
    @State private var likesCount: Int64
    @State private var isLiking = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showReportEntry = false
    @Environment(\.dismiss) private var dismiss

    var isOwnEntry: Bool {
        viewer.username?.lowercased() == entry.username.lowercased()
    }

    init(entry: DiaryEntry, viewer: User) {
        self.entry = entry
        self.viewer = viewer
        _isLiked = State(initialValue: entry.isLiked)
        _likesCount = State(initialValue: entry.likesCount)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background").ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let book = entry.book { bookHeader(book) }
                        entryBody
                        Spacer(minLength: 100)
                    }
                }
                VStack { Spacer(); bottomBar }
            }
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) { closeButton }
            .navigationDestination(for: String.self) { bookId in
                BookDetailView(bookId: bookId, user: viewer)
            }
            .alert("Delete entry?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { Task { await deleteEntry() } }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This cannot be undone.")
            }
            .alert("Couldn't delete entry", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteError ?? "")
            }
            .confirmationDialog("Report entry", isPresented: $showReportEntry, titleVisibility: .visible) {
                ForEach(ModerationService.reportReasons, id: \.self) { reason in
                    Button(reason) {
                        Task {
                            try? await ModerationService.report(
                                contentType: "diary_entry",
                                contentID: entry.id,
                                reason: reason
                            )
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color("TextPrimary"))
                .frame(width: 34, height: 34)
                .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color("Border"), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16).padding(.top, 10)
    }

    private func bookHeader(_ book: Book) -> some View {
        NavigationLink(value: book.id) {
            HStack(spacing: 12) {
                BookCoverView(url: book.coverURL, width: 52, cornerRadius: 5)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title).font(PB.serif(16)).foregroundStyle(Color("TextPrimary")).lineLimit(2)
                    if !book.authorLine.isEmpty {
                        Text(book.authorLine).font(.system(size: 12)).foregroundStyle(Color("TextSecondary")).lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color("TextSecondary").opacity(0.5))
            }
            .padding(14)
            .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color("Border"), lineWidth: 1))
            .padding(.horizontal, 18).padding(.top, 52).padding(.bottom, 16)
        }
        .buttonStyle(.plain)
    }

    private var entryBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            if entry.book == nil { Spacer().frame(height: 44) }

            HStack(spacing: 10) {
                AvatarView(url: entry.avatarURL, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.name.isEmpty ? entry.username : entry.name)
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color("TextPrimary"))
                    Text(formattedDate(entry.createdAt))
                        .font(PB.mono(9.5)).tracking(0.8).foregroundStyle(Color("TextSecondary"))
                }
                Spacer()
                if let r = entry.rating, r > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= r ? "star.fill" : "star")
                                .font(.system(size: 11))
                                .foregroundStyle(i <= r ? Color("Accent") : Color("TextSecondary").opacity(0.3))
                        }
                    }
                }
            }

            Text(plainText(entry.content))
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(Color("TextPrimary").opacity(0.9))
                .lineSpacing(5)
        }
        .padding(.horizontal, 18).padding(.bottom, 24)
    }

    private var bottomBar: some View {
        HStack(spacing: 20) {
            Button {
                guard !isLiking else { return }
                Task { await toggleLike() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundStyle(isLiked ? PB.terracotta : Color("TextSecondary"))
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: isLiked)
                    if likesCount > 0 {
                        Text("\(likesCount)").font(PB.mono(12))
                            .foregroundStyle(Color("TextSecondary"))
                            .contentTransition(.numericText())
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            if isOwnEntry {
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    if isDeleting {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "trash").font(.system(size: 17)).foregroundStyle(Color("TextSecondary"))
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button { showReportEntry = true } label: {
                    Image(systemName: "flag").font(.system(size: 15)).foregroundStyle(Color("TextSecondary"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Color("Background").opacity(0.97))
        .overlay(alignment: .top) { Rectangle().fill(Color("Border")).frame(height: 1) }
    }

    private func toggleLike() async {
        let prev = isLiked
        withAnimation(.snappy(duration: 0.25)) { isLiked = !prev; likesCount += prev ? -1 : 1 }
        isLiking = true; defer { isLiking = false }
        do {
            let _: Empty = try await APIClient.shared.request(
                path: Endpoints.diaryEntryLike(username: entry.username, entryId: entry.id),
                method: prev ? .delete : .post, requiresAuth: true
            )
        } catch { withAnimation(.snappy(duration: 0.25)) { isLiked = prev; likesCount += prev ? 1 : -1 } }
    }

    private func deleteEntry() async {
        isDeleting = true
        do {
            let _: Empty = try await APIClient.shared.request(
                path: Endpoints.diaryEntry(username: entry.username, entryId: entry.id),
                method: .delete, requiresAuth: true
            )
            NotificationCenter.default.post(name: .diaryEntryDeleted, object: entry.id)
            dismiss()
        } catch let e as APIError {
            isDeleting = false
            deleteError = e.errorDescription
        } catch {
            isDeleting = false
            deleteError = error.localizedDescription
        }
    }

    private func plainText(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formattedDate(_ iso: String) -> String {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = df.date(from: iso) ?? { df.formatOptions = [.withInternetDateTime]; return df.date(from: iso) }()
        guard let d = date else { return "" }
        let out = DateFormatter(); out.dateFormat = "MMM d, yyyy"
        return out.string(from: d).uppercased()
    }
}
