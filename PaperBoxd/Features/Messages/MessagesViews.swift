import Combine
import PhotosUI
import SwiftUI

// Messages (DMs): inbox, chat, the Shared tab, and attachment cards.
// Android twin: ui/screens/messages/*. No push yet — the chat polls every 4s
// while open and the inbox every 15s.

/// Where Messages is entered: the inbox (the dock's Messages tab) or straight
/// into a chat (a profile's Message button). Each entry gets its own stack so
/// detail pushes and the Fusion cover work the same from anywhere.
struct MessagesStack: View {
    enum Root { case inbox, chat(username: String) }

    let root: Root
    let viewer: User
    /// As a dock tab the inbox is a root screen with nothing to close.
    var inTab = false
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()
    @State private var fusionRoute: FusionRoute?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch root {
                case .inbox:
                    InboxView(onClose: inTab ? nil : { dismiss() }, onOpenChat: { path.append(MessagesNav.chat(id: $0)) })
                case .chat(let username):
                    ChatView(conversationID: nil, username: username, onBack: { dismiss() }, onOpen: open,
                             onOpenFusionLink: { fusionRoute = .link(token: $0) })
                }
            }
            .navigationDestination(for: MessagesNav.self) { nav in
                switch nav {
                case .chat(let id):
                    ChatView(conversationID: id, username: nil, onBack: { path.removeLast() }, onOpen: open,
                             onOpenFusionLink: { fusionRoute = .link(token: $0) })
                case .book(let id):
                    BookDetailView(bookId: id, user: viewer)
                case .profile(let username):
                    ProfileView(username: username, viewer: viewer).environmentObject(appState)
                case .list(let nav):
                    ListDetailView(nav: nav, viewer: viewer)
                }
            }
        }
        .fullScreenCover(item: $fusionRoute) { FusionRootView(route: $0, user: viewer) }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
    }

    private func open(_ att: MessageAttachment) {
        switch att.kind {
        case AttachKind.book: path.append(MessagesNav.book(att.refID))
        case AttachKind.profile: path.append(MessagesNav.profile(att.str("username")))
        case AttachKind.list: path.append(MessagesNav.list(ListNav(listId: att.refID, username: att.str("owner_username"))))
        // No thought screen is addressable by id on iOS; the author's profile holds it.
        case AttachKind.thought: path.append(MessagesNav.profile(att.str("author_username")))
        case AttachKind.fusion: fusionRoute = .fusion(id: att.refID, introFrom: nil)
        default: break
        }
    }
}

enum MessagesNav: Hashable {
    case chat(id: String)
    case book(String)
    case profile(String)
    case list(ListNav)
}

// MARK: - Inbox

@MainActor
final class InboxModel: ObservableObject {
    @Published var box = "accepted"
    @Published var conversations: [ConversationSummary] = []
    @Published var loading = true
    @Published var error: String?
    @Published var badge = InboxBadge()

    func select(_ b: String) async {
        guard b != box else { return }
        box = b
        conversations = []
        loading = true
        await load()
    }

    func load() async {
        let b = box
        do {
            let list = try await MessageService.conversations(box: b)
            if box == b { conversations = list.conversations; error = nil }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
        await refreshBadge()
    }

    func refreshBadge() async {
        if let b = try? await MessageService.badge() { badge = b }
    }
}

struct InboxView: View {
    let onClose: (() -> Void)?
    let onOpenChat: (String) -> Void
    @StateObject private var model = InboxModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(BK.ink)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
                Text("Messages").font(.system(size: 26, weight: .semibold, design: .serif)).foregroundStyle(BK.ink)
                    .frame(minHeight: 44)
                Spacer()
            }
            .padding(.horizontal, onClose == nil ? 20 : 12)
            .padding(.top, 8)

            HStack(spacing: 10) {
                MonoChip(label: "CHATS", on: model.box == "accepted") { Task { await model.select("accepted") } }
                MonoChip(label: model.badge.requests > 0 ? "REQUESTS · \(model.badge.requests)" : "REQUESTS",
                         on: model.box == "request") { Task { await model.select("request") } }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            if model.loading && model.conversations.isEmpty {
                PBSpinner().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.conversations.isEmpty {
                CenterNote(text: model.error ?? (model.box == "request" ? "No message requests." :
                    "No messages yet. Send a book to someone from its Share button, or tap Message on a reader's profile."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(model.conversations.enumerated()), id: \.element.id) { i, c in
                            Button { onOpenChat(c.id) } label: { ConversationRow(c: c) }.buttonStyle(.plain)
                            if i < model.conversations.count - 1 {
                                Rectangle().fill(BK.ink.opacity(0.08)).frame(height: 1).padding(.leading, 86)
                            }
                        }
                    }
                    // Clear the dock when this is a tab.
                    .padding(.bottom, onClose == nil ? 120 : 40)
                }
            }
        }
        .background(BK.paper.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            while !Task.isCancelled {
                await model.load()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }
}

private struct ConversationRow: View {
    let c: ConversationSummary
    var body: some View {
        let unread = c.unreadCount > 0
        HStack(spacing: 14) {
            AvatarView(url: c.them.avatarURL, size: 52)
                .overlay(Circle().strokeBorder(BK.ink, lineWidth: unread ? 2 : 0))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(c.them.displayName).font(.system(size: 15, weight: unread ? .bold : .semibold)).foregroundStyle(BK.ink).lineLimit(1)
                    if c.muted { Image(systemName: "bell.slash").font(.system(size: 11)).foregroundStyle(BK.muted) }
                }
                Text((c.lastMessage.fromMe ? "You: " : "") + c.lastMessage.text)
                    .font(.system(size: 13, weight: unread ? .semibold : .regular))
                    .foregroundStyle(unread ? BK.ink : BK.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 7) {
                Text(shortAgo(c.lastMessage.createdAt)).font(.system(size: 11, design: .monospaced)).foregroundStyle(unread ? BK.ink : BK.muted)
                if unread {
                    Text(c.unreadCount > 9 ? "9+" : "\(c.unreadCount)")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(BK.paper)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(BK.ink, in: Capsule())
                } else {
                    Color.clear.frame(width: 18, height: 18)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(unread ? BK.paper2.opacity(0.5) : .clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Chat

@MainActor
final class ChatModel: ObservableObject {
    @Published var conversationID: String?
    @Published var them: MessagePerson
    @Published var myState = "accepted"
    @Published var muted = false
    @Published var theirLastReadID: Int64 = 0
    @Published var messages: [ChatMessage] = []
    @Published var hasMore = false
    @Published var loading = true
    @Published var error: String?
    @Published var draft = ""
    @Published var pendingBooks: [Book] = []
    @Published var pendingMedia: [PendingMedia] = []
    @Published var sending = false
    @Published var sendError: String?
    @Published var showShared = false
    @Published var shared: SharedList?
    @Published var sharedKind: String?
    @Published var gone = false
    @Published var toast: String?
    // One client id per draft, so a retried send after a timeout is not doubled.
    private var clientID = UUID().uuidString

    init(conversationID: String?, username: String?) {
        self.conversationID = conversationID
        self.them = MessagePerson(username: username ?? "")
    }

    func start() async {
        if conversationID == nil, !them.username.isEmpty {
            do {
                let w = try await MessageService.conversationWith(username: them.username)
                them = w.them
                conversationID = w.conversationID.isEmpty ? nil : w.conversationID
            } catch {
                self.error = error.localizedDescription
                loading = false
                return
            }
        }
        guard let id = conversationID else { loading = false; return }
        do {
            let p = try await MessageService.messages(id)
            apply(p)
            messages = p.messages
            hasMore = p.hasMore
            error = nil
            await markRead()
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func apply(_ p: ConversationPage) {
        them = p.them
        myState = p.state
        muted = p.muted
        theirLastReadID = p.theirLastReadID
    }

    // A request stays unread until accepted, so the sender does not see "Seen".
    private func markRead() async {
        guard let id = conversationID, myState != "request" else { return }
        try? await MessageService.markRead(id)
    }

    /// The polling path: whatever arrived since the newest message we hold.
    func poll() async {
        guard let id = conversationID, !loading else { return }
        let after = messages.last?.id
        guard let p = try? await MessageService.messages(id, after: after) else { return }
        apply(p)
        if after == nil { messages = p.messages; hasMore = p.hasMore; return }
        let known = Set(messages.map(\.id))
        let fresh = p.messages.filter { !known.contains($0.id) }
        guard !fresh.isEmpty else { return }
        messages += fresh
        if fresh.contains(where: { !$0.fromMe }) { await markRead() }
    }

    func loadOlder() async {
        guard let id = conversationID, let first = messages.first?.id,
              let p = try? await MessageService.messages(id, before: first) else { return }
        messages = p.messages + messages
        hasMore = p.hasMore
    }

    var uploading: Bool { pendingMedia.contains { $0.upload == nil } }

    var canSend: Bool {
        (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingBooks.isEmpty || !pendingMedia.isEmpty)
            && !sending && !uploading
    }

    func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }
        let atts = pendingBooks.map { AttachmentRef(kind: AttachKind.book, refID: $0.id) }
            + pendingMedia.compactMap { m in m.upload.map { AttachmentRef(kind: $0.kind, refID: $0.refID) } }
        if await post(body: body, attachments: atts, clientID: clientID) {
            clientID = UUID().uuidString
            draft = ""
            pendingBooks = []
            pendingMedia = []
        }
    }

    /// A GIF or sticker goes out on its own, leaving the draft alone.
    func sendNow(_ ref: AttachmentRef) async {
        guard !sending else { return }
        _ = await post(body: "", attachments: [ref], clientID: UUID().uuidString)
    }

    private func post(body: String, attachments: [AttachmentRef], clientID: String) async -> Bool {
        sending = true
        sendError = nil
        defer { sending = false }
        do {
            let r = try await MessageService.send(
                conversationID: conversationID,
                to: conversationID == nil ? [them.username] : nil,
                body: body,
                attachments: attachments,
                clientID: clientID
            )
            guard let msg = r.sent.first else {
                sendError = r.failed.first?.error ?? "Couldn't send"
                return false
            }
            conversationID = msg.conversationID
            if !messages.contains(where: { $0.id == msg.id }) { messages.append(msg) }
            myState = "accepted" // replying to a request accepts it
            return true
        } catch {
            sendError = error.localizedDescription
            return false
        }
    }

    /// Picked photos and videos start uploading straight away, so Send is
    /// quick; it waits until every upload has its ref.
    func addMedia(_ items: [PhotosPickerItem]) {
        let room = 10 - pendingBooks.count - pendingMedia.count
        for item in items.prefix(max(room, 0)) {
            let pending = PendingMedia(kind: MediaPrep.isVideo(item) ? AttachKind.video : AttachKind.photo)
            pendingMedia.append(pending)
            Task { await upload(pending.id, item) }
        }
    }

    private func upload(_ id: UUID, _ item: PhotosPickerItem) async {
        do {
            let prepared = try await MediaPrep.prepare(item)
            updateMedia(id) { $0.preview = prepared.preview }
            let up = try await MessageService.uploadMedia(prepared.data, kind: prepared.kind, mimeType: prepared.mimeType)
            updateMedia(id) { $0.upload = up }
        } catch {
            pendingMedia.removeAll { $0.id == id }
            sendError = error.localizedDescription
        }
    }

    private func updateMedia(_ id: UUID, _ change: (inout PendingMedia) -> Void) {
        if let i = pendingMedia.firstIndex(where: { $0.id == id }) { change(&pendingMedia[i]) }
    }

    func unsend(_ m: ChatMessage) async {
        do {
            try await MessageService.unsend(m.id)
            if let i = messages.firstIndex(where: { $0.id == m.id }) {
                messages[i].unsent = true
                messages[i].body = ""
                messages[i].attachments = []
            }
        } catch { toast = error.localizedDescription }
    }

    func accept() async {
        guard let id = conversationID else { return }
        do { try await MessageService.accept(id); myState = "accepted"; await markRead() }
        catch { toast = error.localizedDescription }
    }

    func toggleMute() async {
        guard let id = conversationID else { return }
        do { try await MessageService.setMuted(id, !muted); muted.toggle(); toast = muted ? "Muted" : "Unmuted" }
        catch { toast = error.localizedDescription }
    }

    func clearChat() async {
        guard let id = conversationID else { return }
        do { try await MessageService.clear(id); gone = true }
        catch { toast = error.localizedDescription }
    }

    func block() async {
        do { try await ModerationService.block(username: them.username); gone = true }
        catch { toast = error.localizedDescription }
    }

    func report(contentType: String, contentID: String, reason: String) async {
        do {
            try await ModerationService.report(contentType: contentType, contentID: contentID, reason: reason)
            toast = "Reported. We review reports within 24 hours."
        } catch { toast = error.localizedDescription }
    }

    /// "Make a Fusion": drops your live Fusion link into this chat. It is the
    /// same one-time link as the profile's, so the first reader to fuse wins.
    func makeFusion() async {
        do {
            let inv: FusionInvite = try await APIClient.shared.request(
                path: Endpoints.fusionInvites, method: .post, requiresAuth: true
            )
            draft = "Fuse with me on PaperBoxd: \(inv.url)"
            await send()
        } catch {
            toast = error.localizedDescription
        }
    }

    func loadShared(_ kind: String?) async {
        guard let id = conversationID else { return }
        sharedKind = kind
        if let l = try? await MessageService.shared(id, kind: kind) { shared = l }
    }
}

struct ChatView: View {
    let onBack: () -> Void
    let onOpen: (MessageAttachment) -> Void
    let onOpenFusionLink: (String) -> Void
    @StateObject private var model: ChatModel
    @State private var confirmBlock = false
    @State private var confirmClear = false
    @State private var confirmFusion = false
    @State private var unsendTarget: ChatMessage?
    @State private var reportTarget: ReportTarget?
    @State private var pickBook = false
    @State private var pickMedia = false
    @State private var mediaItems: [PhotosPickerItem] = []
    @State private var gifType: String?
    @State private var viewing: MessageAttachment?

    private struct ReportTarget: Identifiable {
        let contentType: String
        let contentID: String
        let title: String
        var id: String { contentType + contentID }
    }

    init(conversationID: String?, username: String?, onBack: @escaping () -> Void,
         onOpen: @escaping (MessageAttachment) -> Void, onOpenFusionLink: @escaping (String) -> Void = { _ in }) {
        self.onBack = onBack
        self.onOpen = onOpen
        self.onOpenFusionLink = onOpenFusionLink
        _model = StateObject(wrappedValue: ChatModel(conversationID: conversationID, username: username))
    }

    private var firstName: String {
        let n = model.them.displayName.components(separatedBy: " ").first ?? ""
        return n.isEmpty ? "them" : n
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.myState == "request" { requestBanner }
            if model.showShared {
                SharedPane(model: model, onOpen: onOpen, onView: { viewing = $0 })
            } else {
                thread
                composer
            }
        }
        .background(BK.paper.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .hidesBottomDock()
        .task {
            await model.start()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                await model.poll()
            }
        }
        .onChange(of: model.gone) { _, gone in if gone { onBack() } }
        .alert("Make a Fusion with \(firstName)?", isPresented: $confirmFusion) {
            Button("Send link") { Task { await model.makeFusion() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Sends your Fusion link here. When they tap Fuse, your two shelves line up side by side. The link works once.") }
        .alert("Block @\(model.them.username)?", isPresented: $confirmBlock) {
            Button("Block", role: .destructive) { Task { await model.block() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("They won't be able to message you, and this chat disappears for both of you.") }
        .alert("Delete this chat?", isPresented: $confirmClear) {
            Button("Delete", role: .destructive) { Task { await model.clearChat() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("It's removed for you only. If they message again, the chat comes back from that message.") }
        .alert("Unsend message?", isPresented: Binding(get: { unsendTarget != nil }, set: { if !$0 { unsendTarget = nil } })) {
            Button("Unsend", role: .destructive) { if let m = unsendTarget { Task { await model.unsend(m) } } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("It's removed for both of you.") }
        .confirmationDialog(reportTarget?.title ?? "Report", isPresented: Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } }), titleVisibility: .visible) {
            ForEach(ModerationService.reportReasons, id: \.self) { reason in
                Button(reason) {
                    if let t = reportTarget { Task { await model.report(contentType: t.contentType, contentID: t.contentID, reason: reason) } }
                }
            }
        }
        .alert(model.toast ?? "", isPresented: Binding(get: { model.toast != nil }, set: { if !$0 { model.toast = nil } })) {
            Button("OK", role: .cancel) {}
        }
        .photosPicker(isPresented: $pickMedia, selection: $mediaItems, maxSelectionCount: 10,
                      matching: .any(of: [.images, .videos]))
        .onChange(of: mediaItems) { _, items in
            guard !items.isEmpty else { return }
            model.addMedia(items)
            mediaItems = []
        }
        .sheet(item: Binding(get: { gifType.map { GifTab(type: $0) } }, set: { gifType = $0?.type })) { tab in
            GifPickerSheet(type: tab.type) { ref in
                gifType = nil
                Task { await model.sendNow(ref) }
            }
        }
        .fullScreenCover(item: $viewing) { MediaViewer(att: $0) }
        .sheet(isPresented: $pickBook) {
            BookPickerSheet { book in
                if model.pendingBooks.count < 10, !model.pendingBooks.contains(where: { $0.id == book.id }) {
                    model.pendingBooks.append(book)
                }
                pickBook = false
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold)).foregroundStyle(BK.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                Button {
                    if !model.them.username.isEmpty {
                        onOpen(MessageAttachment(kind: AttachKind.profile, refID: model.them.userID,
                                                 snapshot: .object(["username": .string(model.them.username)])))
                    }
                } label: {
                    HStack(spacing: 11) {
                        AvatarView(url: model.them.avatarURL, size: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(model.them.displayName)
                                .font(.system(size: 18, weight: .semibold, design: .serif))
                                .foregroundStyle(BK.ink).lineLimit(1)
                            if !model.them.username.isEmpty {
                                Text("@\(model.them.username)" + (model.muted ? "  ·  muted" : ""))
                                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(BK.muted).lineLimit(1)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Menu {
                    Button("Make a Fusion", systemImage: "circle.lefthalf.filled") { confirmFusion = true }
                    if model.conversationID != nil {
                        Button(model.muted ? "Unmute" : "Mute", systemImage: model.muted ? "bell" : "bell.slash") {
                            Task { await model.toggleMute() }
                        }
                        Button("Delete chat", systemImage: "trash") { confirmClear = true }
                    }
                    Button("Report", systemImage: "flag") {
                        reportTarget = ReportTarget(contentType: "user", contentID: model.them.username, title: "Report @\(model.them.username)")
                    }
                    Button("Block", systemImage: "hand.raised", role: .destructive) { confirmBlock = true }
                } label: {
                    Image(systemName: "ellipsis").rotationEffect(.degrees(90))
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(BK.ink)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .padding(.bottom, 4)

            if model.conversationID != nil {
                HStack(spacing: 0) {
                    segment("Chat", on: !model.showShared) { model.showShared = false }
                    segment("Shared", on: model.showShared) {
                        model.showShared = true
                        Task { await model.loadShared(model.sharedKind) }
                    }
                }
            }
            Rectangle().fill(BK.ink.opacity(0.12)).frame(height: 1)
        }
        .background(BK.card)
    }

    private func segment(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: on ? .bold : .medium, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(on ? BK.ink : BK.muted)
                Rectangle().fill(on ? BK.ink : .clear).frame(width: 44, height: 2)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var requestBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            MsgEyebrow(text: "MESSAGE REQUEST")
            Text("@\(model.them.username) wants to message you. They won't see that you've read this until you accept.")
                .font(.system(size: 14)).foregroundStyle(BK.ink)
            HStack(spacing: 8) {
                PillChip(label: "ACCEPT", on: true) { Task { await model.accept() } }
                PillChip(label: "DELETE", on: false) { confirmClear = true }
                PillChip(label: "BLOCK", on: false) { confirmBlock = true }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalPlate(fill: BK.card, borderWidth: 1.5, offset: 3)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Thread

    @ViewBuilder
    private var thread: some View {
        if model.loading {
            PBSpinner().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let e = model.error, model.messages.isEmpty {
            CenterNote(text: e)
        } else if model.messages.isEmpty {
            emptyChat
        } else {
            let msgs = model.messages
            let newestMine = msgs.last.flatMap { $0.fromMe ? $0 : nil }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if model.hasMore {
                            Button("Load earlier") { Task { await model.loadOlder() } }
                                .font(.system(size: 13)).foregroundStyle(BK.muted).padding(.vertical, 6)
                        }
                        ForEach(Array(msgs.enumerated()), id: \.element.id) { i, m in
                            let older = i > 0 ? msgs[i - 1] : nil
                            let newer = i + 1 < msgs.count ? msgs[i + 1] : nil
                            let newDay = older.map { !sameDay($0.createdAt, m.createdAt) } ?? true
                            let joinsOlder = !newDay && older?.fromMe == m.fromMe && minutesApart(older!.createdAt, m.createdAt) < 5
                            let joinsNewer = newer.map { $0.fromMe == m.fromMe && sameDay(m.createdAt, $0.createdAt) && minutesApart(m.createdAt, $0.createdAt) < 5 } ?? false
                            VStack(spacing: 0) {
                                if newDay { dayDivider(dayLabel(m.createdAt)) }
                                MessageBubble(
                                    m: m,
                                    joinsOlder: joinsOlder,
                                    joinsNewer: joinsNewer,
                                    seen: m.id == newestMine?.id && model.theirLastReadID >= m.id,
                                    onOpen: onOpen,
                                    onView: { viewing = $0 },
                                    onOpenFusionLink: onOpenFusionLink,
                                    onUnsend: { unsendTarget = m },
                                    onReport: {
                                        reportTarget = ReportTarget(contentType: "message", contentID: String(m.id), title: "Report message")
                                    }
                                )
                            }
                            .id(m.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.messages.last?.id) { _, id in
                    if let id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                }
            }
        }
    }

    private func dayDivider(_ label: String) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(BK.ink.opacity(0.1)).frame(height: 1)
            Text(label.uppercased()).font(.system(size: 9.5, design: .monospaced)).tracking(1.6).foregroundStyle(BK.muted)
                .fixedSize()
            Rectangle().fill(BK.ink.opacity(0.1)).frame(height: 1)
        }
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var emptyChat: some View {
        VStack(spacing: 4) {
            AvatarView(url: model.them.avatarURL, size: 84)
            Text(model.them.displayName).font(.system(size: 22, weight: .semibold, design: .serif)).foregroundStyle(BK.ink)
                .padding(.top, 10)
            if !model.them.username.isEmpty {
                Text("@\(model.them.username)").font(.system(size: 12, design: .monospaced)).foregroundStyle(BK.muted)
            }
            Text("Say hi, or send them a book.").font(.system(size: 15, design: .serif).italic()).foregroundStyle(BK.muted)
                .padding(.top, 14)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.pendingBooks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.pendingBooks) { b in
                            HStack(spacing: 6) {
                                BookCoverView(url: b.coverURL, width: 22, cornerRadius: 2)
                                Text(b.title).font(.system(size: 12)).foregroundStyle(BK.ink).lineLimit(1).frame(maxWidth: 120)
                                Button { model.pendingBooks.removeAll { $0.id == b.id } } label: {
                                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(BK.muted)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 7).padding(.vertical, 5)
                            .background(BK.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BK.ink.opacity(0.15), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            if !model.pendingMedia.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.pendingMedia) { m in pendingThumb(m) }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                }
            }
            if let e = model.sendError { Text(e).font(.system(size: 12)).foregroundStyle(BK.accent).padding(.leading, 8) }
            let canSend = model.canSend
            HStack(alignment: .bottom, spacing: 4) {
                Menu {
                    Button("Book", systemImage: "book") { pickBook = true }
                    Button("Photo or video", systemImage: "photo.on.rectangle") { pickMedia = true }
                    Button("GIF", systemImage: "square.stack") { gifType = "gifs" }
                    Button("Sticker", systemImage: "face.smiling") { gifType = "stickers" }
                } label: {
                    Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(BK.ink)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Attach")
                TextField("Message…", text: $model.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.system(size: 15))
                    .foregroundStyle(BK.ink)
                    .padding(.vertical, 10)
                Button { Task { await model.send() } } label: {
                    Group {
                        if model.sending { ProgressView().tint(BK.paper) }
                        else { Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundStyle(canSend ? BK.paper : BK.muted) }
                    }
                    .frame(width: 40, height: 40)
                    .background(canSend ? BK.ink : BK.paper2)
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(4)
            .background(BK.card)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(BK.ink.opacity(0.18), lineWidth: 1))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(BK.paper)
    }

    /// A picked photo/video in the composer: spinner until its upload lands.
    private func pendingThumb(_ m: PendingMedia) -> some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                if let img = m.preview {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    BK.paper2
                }
                if m.upload == nil {
                    Color.black.opacity(0.25)
                    ProgressView().tint(.white)
                } else if m.kind == AttachKind.video {
                    Image(systemName: "play.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                }
            }
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            Button { model.pendingMedia.removeAll { $0.id == m.id } } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(BK.paper)
                    .frame(width: 20, height: 20).background(BK.ink, in: Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 5, y: -5)
            .accessibilityLabel("Remove")
        }
    }
}

private struct GifTab: Identifiable {
    let type: String
    var id: String { type }
}

private struct MessageBubble: View {
    let m: ChatMessage
    let joinsOlder: Bool
    let joinsNewer: Bool
    let seen: Bool
    let onOpen: (MessageAttachment) -> Void
    let onView: (MessageAttachment) -> Void
    let onOpenFusionLink: (String) -> Void
    let onUnsend: () -> Void
    let onReport: () -> Void

    var body: some View {
        VStack(alignment: m.fromMe ? .trailing : .leading, spacing: 4) {
            if m.unsent {
                Text("Message unsent")
                    .font(.system(size: 13, design: .serif).italic()).foregroundStyle(BK.muted)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(BK.ink.opacity(0.15), lineWidth: 1))
            } else {
                ForEach(Array(m.attachments.enumerated()), id: \.offset) { _, a in
                    if a.isMedia {
                        MediaAttachmentView(att: a) { onView(a) }
                            .contextMenu { menu }
                    } else {
                        Button { onOpen(a) } label: { AttachmentCardView(att: a) }
                            .buttonStyle(.plain)
                            .contextMenu { menu }
                    }
                }
                if let token = fusionToken(m.body) {
                    Button { onOpenFusionLink(token) } label: { fusionInvite }
                        .buttonStyle(.plain)
                        .contextMenu { menu }
                } else if !m.body.isEmpty {
                    Text(m.body)
                        .font(.system(size: 15))
                        .foregroundStyle(m.fromMe ? BK.paper : BK.ink)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(m.fromMe ? BK.ink : BK.card)
                        .clipShape(shape)
                        .overlay(shape.stroke(m.fromMe ? .clear : BK.ink.opacity(0.12), lineWidth: 1))
                        .frame(maxWidth: 290, alignment: m.fromMe ? .trailing : .leading)
                        .contextMenu { menu }
                }
            }
            if !joinsNewer || seen {
                Text([timeLabel(m.createdAt), seen ? "Seen" : nil].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 10.5)).foregroundStyle(BK.muted)
                    .padding(.horizontal, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: m.fromMe ? .trailing : .leading)
        .padding(.top, joinsOlder ? 2 : 8)
    }

    /// Tails: the corner on the sender's side tightens where bubbles join.
    private var shape: UnevenRoundedRectangle {
        let big: CGFloat = 20, small: CGFloat = 6
        return m.fromMe
            ? UnevenRoundedRectangle(topLeadingRadius: big, bottomLeadingRadius: big,
                                     bottomTrailingRadius: joinsNewer ? small : big, topTrailingRadius: joinsOlder ? small : big)
            : UnevenRoundedRectangle(topLeadingRadius: joinsOlder ? small : big, bottomLeadingRadius: joinsNewer ? small : big,
                                     bottomTrailingRadius: big, topTrailingRadius: big)
    }

    /// A Fusion link dropped into a chat, drawn as an invitation rather than a URL.
    private var fusionInvite: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FUSION INVITE").font(.system(size: 9.5, design: .monospaced)).tracking(1.6).foregroundStyle(BK.accent)
            Text("Two tastes. One discovery.").font(.system(size: 17, weight: .semibold, design: .serif)).foregroundStyle(BK.ink)
            Text(m.fromMe ? "Waiting for them to fuse. The link works once." : "Tap to line up your shelves side by side.")
                .font(.system(size: 12.5)).foregroundStyle(BK.muted)
            if !m.fromMe {
                Text("FUSE →").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.4)
                    .foregroundStyle(BK.paper).padding(.horizontal, 12).padding(.vertical, 7).background(BK.ink)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(width: 250, alignment: .leading)
        .brutalPlate(fill: BK.card, borderWidth: 1.5, offset: 3)
    }

    @ViewBuilder private var menu: some View {
        if m.fromMe {
            Button("Unsend", role: .destructive, action: onUnsend)
        } else {
            Button("Report", role: .destructive, action: onReport)
        }
    }
}

// MARK: - Shared tab

private struct KindTab: Hashable { let kind: String?; let label: String }

private let kindTabs: [KindTab] = [
    KindTab(kind: nil, label: "ALL"), KindTab(kind: AttachKind.book, label: "BOOKS"),
    KindTab(kind: AttachKind.list, label: "LISTS"), KindTab(kind: AttachKind.thought, label: "THOUGHTS"),
    KindTab(kind: AttachKind.profile, label: "READERS"), KindTab(kind: AttachKind.fusion, label: "FUSIONS"),
    KindTab(kind: AttachKind.photo, label: "PHOTOS"), KindTab(kind: AttachKind.video, label: "VIDEOS")
]

private struct SharedPane: View {
    @ObservedObject var model: ChatModel
    let onOpen: (MessageAttachment) -> Void
    let onView: (MessageAttachment) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(kindTabs, id: \.self) { tab in
                        let kind = tab.kind, label = tab.label
                        let n = kind == nil ? model.shared?.counts.values.reduce(0, +) : kind.flatMap { model.shared?.counts[$0] }
                        if kind == nil || (n ?? 0) > 0 {
                            MonoChip(label: (n ?? 0) > 0 ? "\(label) \(n!)" : label, on: model.sharedKind == kind) {
                                Task { await model.loadShared(kind) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            if let shared = model.shared {
                if shared.items.isEmpty {
                    CenterNote(text: "Everything you two send each other collects here.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(shared.items) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    MsgEyebrow(text: (item.fromMe ? "YOU" : "@\(model.them.username)".uppercased()) + " · " + shortAgo(item.createdAt).uppercased())
                                    if item.attachment.isMedia {
                                        MediaAttachmentView(att: item.attachment) { onView(item.attachment) }
                                    } else {
                                        Button { onOpen(item.attachment) } label: { AttachmentCardView(att: item.attachment) }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            } else {
                PBSpinner().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Attachment card

/// A Paperboxd object inside a message, drawn from its send-time snapshot so it
/// still renders after the object changes. Tapping opens the live object.
struct AttachmentCardView: View {
    let att: MessageAttachment

    var body: some View {
        if att.kind == AttachKind.book { bookCard } else { objectCard }
    }

    /// A book gets the full treatment: cover, meta line, and a short blurb so
    /// the recipient knows what it is before tapping. Older cards have no blurb.
    private var bookCard: some View {
        let blurb = att.str("description")
        let meta = [
            "BOOK",
            att.int("year").map(String.init),
            att.int("page_count").flatMap { $0 > 0 ? "\($0) PP" : nil },
        ].compactMap { $0 }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 12) {
                BookCoverView(url: att.str("cover_url"), width: 64, cornerRadius: 4)
                    .shadow(color: BK.ink.opacity(0.22), radius: 0, x: 2, y: 2)
                VStack(alignment: .leading, spacing: 4) {
                    MsgEyebrow(text: meta)
                    Text(att.str("title"))
                        .font(.system(size: 16, weight: .semibold, design: .serif)).foregroundStyle(BK.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    let authors = att.strings("authors").joined(separator: ", ")
                    if !authors.isEmpty {
                        Text("by \(authors)").font(.system(size: 12)).foregroundStyle(BK.muted).lineLimit(1)
                    }
                    if let rating = att.double("rating"), rating > 0 {
                        Text("★ \(String(format: "%.1f", rating))")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(BK.ink)
                            .padding(.top, 2)
                    }
                }
            }
            if !blurb.isEmpty {
                Rectangle().fill(BK.ink.opacity(0.12)).frame(height: 1)
                Text(blurb)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(BK.ink.opacity(0.78))
                    .lineSpacing(2)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Text("OPEN BOOK →").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(BK.ink)
            }
        }
        .padding(13)
        .frame(width: 272, alignment: .leading)
        .brutalPlate(fill: BK.card, borderWidth: 1.5, offset: 3)
    }

    private var objectCard: some View {
        HStack(spacing: 12) {
            switch att.kind {
            case AttachKind.list:
                ZStack(alignment: .leading) {
                    ForEach(Array(att.strings("covers").prefix(3).enumerated()), id: \.offset) { i, url in
                        BookCoverView(url: url, width: 36, cornerRadius: 3).offset(x: CGFloat(i) * 10)
                    }
                }
                .frame(width: 58, alignment: .leading)
                let n = att.int("book_count") ?? 0
                cardText("LIST · \(n) \(n == 1 ? "BOOK" : "BOOKS")", att.str("title"), "by @\(att.str("owner_username"))")
            case AttachKind.thought:
                if !att.str("book_cover_url").isEmpty {
                    BookCoverView(url: att.str("book_cover_url"), width: 40, cornerRadius: 3)
                }
                VStack(alignment: .leading, spacing: 4) {
                    MsgEyebrow(text: "THOUGHT · @\(att.str("author_username"))")
                    Text("“\(att.str("excerpt"))”").font(.system(size: 14, design: .serif).italic()).foregroundStyle(BK.ink).lineLimit(4)
                    if !att.str("book_title").isEmpty {
                        Text(att.str("book_title")).font(.system(size: 11)).foregroundStyle(BK.muted).lineLimit(1)
                    }
                }
            case AttachKind.profile:
                AvatarView(url: att.str("avatar_url").isEmpty ? nil : att.str("avatar_url"), size: 44)
                cardText("READER", att.str("name").isEmpty ? att.str("username") : att.str("name"), "@\(att.str("username"))")
            case AttachKind.fusion:
                let readers = att.readers
                ZStack(alignment: .leading) {
                    ForEach(Array(readers.prefix(2).enumerated()), id: \.offset) { i, r in
                        AvatarView(url: r.avatarURL, size: 36).offset(x: CGFloat(i) * 22)
                    }
                }
                .frame(width: 60, alignment: .leading)
                let score = att.int("score")
                cardText("FUSION",
                         readers.map { $0.displayName.components(separatedBy: " ").first ?? $0.displayName }.joined(separator: " + "),
                         score.map { "\($0)% taste match" } ?? "Taste Fusion")
            default:
                cardText("PAPERBOXD", "Unsupported card", "Update the app to see this")
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 260, alignment: .leading)
        .brutalPlate(fill: BK.card, borderWidth: 1.5, offset: 3)
    }

    private func cardText(_ eyebrow: String, _ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            MsgEyebrow(text: eyebrow)
            Text(title).font(.system(size: 15, weight: .semibold, design: .serif)).foregroundStyle(BK.ink).lineLimit(2)
            if !sub.isEmpty { Text(sub).font(.system(size: 12)).foregroundStyle(BK.muted).lineLimit(1) }
        }
    }
}

// MARK: - Send on Paperboxd

@MainActor
final class SendModel: ObservableObject {
    @Published var query = ""
    @Published var recents: [MessagePerson] = []
    @Published var results: [MessagePerson] = []
    @Published var selected: [MessagePerson] = []
    @Published var note = ""
    @Published var sending = false
    @Published var error: String?
    private var searchTask: Task<Void, Never>?

    func loadRecents() async {
        if let l = try? await MessageService.conversations(box: "accepted") {
            recents = Array(l.conversations.prefix(12).map(\.them))
        }
    }

    func search(_ q: String) {
        searchTask?.cancel()
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            var comps = URLComponents(string: Endpoints.searchUsers)!
            comps.queryItems = [URLQueryItem(name: "query", value: trimmed), URLQueryItem(name: "page_size", value: "15")]
            if let r: UserListResponse = try? await APIClient.shared.request(path: comps.string ?? Endpoints.searchUsers, requiresAuth: true) {
                results = r.users.map { MessagePerson(userID: $0.id, username: $0.username, name: $0.name, avatarURL: $0.avatarURL) }
            }
        }
    }

    func toggle(_ p: MessagePerson) {
        if selected.contains(where: { $0.username == p.username }) {
            selected.removeAll { $0.username == p.username }
        } else if selected.count >= 5 {
            error = "You can send to 5 readers at a time"
        } else {
            selected.append(p)
            error = nil
        }
    }

    func send(_ attachment: AttachmentRef) async -> Bool {
        guard !selected.isEmpty, !sending else { return false }
        sending = true
        defer { sending = false }
        do {
            let r = try await MessageService.send(
                conversationID: nil, to: selected.map(\.username),
                body: note.trimmingCharacters(in: .whitespacesAndNewlines), attachments: [attachment]
            )
            if r.sent.isEmpty { error = r.failed.first?.error ?? "Couldn't send"; return false }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

/// "Send on Paperboxd": pick up to five readers — recent chats first, or
/// search — add an optional note, and the object lands in each DM as a card.
struct SendSheetView: View {
    let attachment: AttachmentRef
    var onSent: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = SendModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SEND ON PAPERBOXD").font(.system(size: 15, weight: .black, design: .monospaced)).tracking(2).foregroundStyle(BK.ink)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(BK.ink)
                }
                .buttonStyle(.plain)
            }
            field("Search readers", text: $model.query)
                .onChange(of: model.query) { _, q in model.search(q) }

            let people = model.query.isEmpty ? model.recents : model.results
            if model.query.isEmpty && !people.isEmpty { MsgEyebrow(text: "RECENT") }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(people, id: \.username) { p in
                        let on = model.selected.contains { $0.username == p.username }
                        Button { model.toggle(p) } label: {
                            HStack(spacing: 12) {
                                AvatarView(url: p.avatarURL, size: 40)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(p.displayName).font(.system(size: 15, weight: .semibold)).foregroundStyle(BK.ink).lineLimit(1)
                                    Text("@\(p.username)").font(.system(size: 12)).foregroundStyle(BK.muted).lineLimit(1)
                                }
                                Spacer()
                                ZStack {
                                    Circle().fill(on ? BK.ink : BK.card)
                                    Circle().strokeBorder(BK.ink, lineWidth: 1.5)
                                    if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(BK.paper) }
                                }
                                .frame(width: 24, height: 24)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if people.isEmpty {
                        Text(model.query.isEmpty ? "Search for a reader to send this to." : "No readers found.")
                            .font(.system(size: 13)).foregroundStyle(BK.muted).padding(.vertical, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if !model.selected.isEmpty { field("Add a message (optional)", text: $model.note) }
            if let e = model.error { Text(e).font(.system(size: 13)).foregroundStyle(BK.accent) }

            let n = model.selected.count
            Button {
                Task { if await model.send(attachment) { onSent(); dismiss() } }
            } label: {
                Group {
                    if model.sending { ProgressView().tint(BK.paper) }
                    else {
                        Text(n == 0 ? "Choose readers" : n == 1 ? "Send" : "Send separately to \(n)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(n > 0 ? BK.paper : BK.muted)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .brutalPlate(fill: n > 0 ? BK.ink : BK.paper2, borderWidth: 2, offset: 3)
            }
            .buttonStyle(.plain)
            .disabled(n == 0 || model.sending)
        }
        .padding(20)
        .background(BK.paper.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .presentationDetents([.large])
        .task { await model.loadRecents() }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .lineLimit(1...4)
            .font(.system(size: 15))
            .foregroundStyle(BK.ink)
            .padding(12)
            .background(BK.card)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(BK.ink.opacity(0.4), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Book picker

private struct BookPickerSheet: View {
    let onPick: (Book) -> Void
    @State private var query = ""
    @State private var results: [Book] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SEND A BOOK").font(.system(size: 15, weight: .black, design: .monospaced)).tracking(2).foregroundStyle(BK.ink)
            TextField("Search books", text: $query)
                .font(.system(size: 15)).foregroundStyle(BK.ink)
                .padding(12).background(BK.card)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(BK.ink.opacity(0.4), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onChange(of: query) { _, q in search(q) }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { b in
                        Button { onPick(b) } label: {
                            HStack(spacing: 12) {
                                BookCoverView(url: b.coverURL, width: 40, cornerRadius: 3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(b.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(BK.ink).lineLimit(2)
                                    Text(b.authorLine).font(.system(size: 12)).foregroundStyle(BK.muted).lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .background(BK.paper.ignoresSafeArea())
        .environment(\.colorScheme, .light)
    }

    private func search(_ q: String) {
        searchTask?.cancel()
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            let resp: BookListResponse? = try? await APIClient.shared.request(path: Endpoints.searchBooks + "?q=\(encoded)&page_size=15")
            results = resp?.items ?? []
        }
    }
}

// MARK: - Small shared pieces

struct MonoChip: View {
    let label: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(on ? BK.paper : BK.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .brutalPlate(fill: on ? BK.ink : BK.card, borderWidth: 1.5, offset: 2)
        }
        .buttonStyle(.plain)
    }
}

private struct MsgEyebrow: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 9.5, design: .monospaced)).tracking(1.6).foregroundStyle(BK.muted).lineLimit(1)
    }
}

private struct CenterNote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 15, design: .serif).italic())
            .foregroundStyle(BK.muted)
            .multilineTextAlignment(.center)
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PillChip: View {
    let label: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(on ? BK.paper : BK.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? BK.ink : BK.card)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(BK.ink.opacity(on ? 1 : 0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Chat day divider: "Today", "Yesterday", "Monday", "12 Sep", "12 Sep 2025".
func dayLabel(_ iso: String) -> String {
    guard let d = ISO8601.parse(iso) else { return "" }
    let cal = Calendar.current
    if cal.isDateInToday(d) { return "Today" }
    if cal.isDateInYesterday(d) { return "Yesterday" }
    let f = DateFormatter()
    if let days = cal.dateComponents([.day], from: d, to: Date()).day, days < 7 { f.dateFormat = "EEEE" }
    else if cal.component(.year, from: d) == cal.component(.year, from: Date()) { f.dateFormat = "d MMM" }
    else { f.dateFormat = "d MMM yyyy" }
    return f.string(from: d)
}

/// "10:42" in the device's locale.
func timeLabel(_ iso: String) -> String {
    guard let d = ISO8601.parse(iso) else { return "" }
    return d.formatted(date: .omitted, time: .shortened)
}

func sameDay(_ a: String, _ b: String) -> Bool {
    guard let x = ISO8601.parse(a), let y = ISO8601.parse(b) else { return false }
    return Calendar.current.isDate(x, inSameDayAs: y)
}

func minutesApart(_ a: String, _ b: String) -> Double {
    guard let x = ISO8601.parse(a), let y = ISO8601.parse(b) else { return .infinity }
    return abs(y.timeIntervalSince(x)) / 60
}

/// The Fusion invite token in a message body, if it carries one.
func fusionToken(_ body: String) -> String? {
    guard let r = body.range(of: #"https://(www\.)?paperboxd\.in/fusion/[a-km-np-z2-9]{12}"#, options: .regularExpression) else { return nil }
    return String(body[r].suffix(12))
}

/// "now", "5m", "3h", "Yesterday", "Mon", "12 Sep".
func shortAgo(_ iso: String) -> String {
    guard let date = ISO8601.parse(iso) else { return "" }
    let secs = Date().timeIntervalSince(date)
    let cal = Calendar.current
    if secs < 60 { return "now" }
    if secs < 3600 { return "\(Int(secs / 60))m" }
    if cal.isDateInToday(date) { return "\(Int(secs / 3600))h" }
    if cal.isDateInYesterday(date) { return "Yesterday" }
    let f = DateFormatter()
    f.dateFormat = secs < 7 * 86_400 ? "EEE" : "d MMM"
    return f.string(from: date)
}
