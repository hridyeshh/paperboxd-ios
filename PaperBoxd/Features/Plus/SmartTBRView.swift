import SwiftUI

/// Smart TBR — "what should I read next?", answered from the reader's own
/// TBR. Plus feature, in the Jazy kit. Mirrors `service.SmartTBR`.
struct SmartTBRItem: Decodable, Identifiable {
    let id: String
    let title: String
    let authors: [String]
    let coverURL: String?
    let reason: String?
    let confidence: String?
    let bucket: String
    let daysOnShelf: Int
    let pageCount: Int?
    let lines: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, authors, reason, confidence, bucket, lines
        case coverURL = "cover_url"
        case daysOnShelf = "days_on_shelf"
        case pageCount = "page_count"
    }
}

struct SmartTBRResponse: Decodable {
    let next: SmartTBRItem?
    let queue: [SmartTBRItem]
    let buckets: [String: [SmartTBRItem]]
    let total: Int
}

enum SmartTBRService {
    static func load() async throws -> SmartTBRResponse {
        try await APIClient.shared.request(path: "/api/v1/users/me/tbr/smart", method: .get, requiresAuth: true)
    }
    static func keep(bookID: String) async {
        let _: Empty? = try? await APIClient.shared.request(
            path: "/api/v1/users/me/tbr/smart/\(bookID)/keep", method: .post, requiresAuth: true)
    }
    static func remove(username: String, bookID: String) async {
        let _: Empty? = try? await APIClient.shared.request(
            path: Endpoints.removeFromBookshelf(username: username, bookId: bookID), method: .delete, requiresAuth: true)
    }
    static func startReading(username: String, bookID: String) async {
        let _: Empty? = try? await APIClient.shared.request(
            path: Endpoints.addToBookshelf(username: username), method: .post,
            body: ["book_id": bookID, "status": "reading"], requiresAuth: true)
    }
}

struct SmartTBRView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss

    @State private var data: SmartTBRResponse?
    @State private var errorMessage: String?
    @State private var showPaywall = false
    @State private var openBook: OpenBook?
    /// Books answered on the stale list this session, so the row reads as done.
    @State private var settled: [String: String] = [:]

    var body: some View {
        ZStack {
            SK.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if let data {
                        if data.total == 0 {
                            empty("Nothing on your TBR yet. Add a few books and Jazy will order them.")
                        } else {
                            content(data)
                        }
                    } else if let errorMessage {
                        empty(errorMessage)
                    } else {
                        HStack { ProgressView().tint(SK.ink); MonoLabel(text: "Reading your shelf", size: 10, tracking: 1.6, color: SK.faint) }
                            .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.light)
        .overlay {
            if showPaywall {
                PlusPaywallView(feature: .taste, onUnlocked: { showPaywall = false; Task { await load() } },
                                onDismiss: { showPaywall = false; dismiss() })
                    .transition(.opacity)
            }
        }
        .fullScreenCover(item: $openBook) { open in
            NavigationStack {
                BookDetailView(bookId: open.id, user: user)
                    .navigationDestination(for: String.self) { BookDetailView(bookId: $0, user: user) }
                    .navigationDestination(for: AuthorNav.self) { AuthorDetailView(nav: $0) }
            }
            // Covers sit above MainTabView's overlay; celebrations need their own.
            .overlay { CelebrationOverlayView() }
        }
        .task {
            Analytics.track("premium_feature_viewed", metadata: ["feature": "smart_tbr"])
            await load()
        }
    }

    private func load() async {
        do {
            data = try await SmartTBRService.load()
        } catch {
            if case .subscriptionRequired = error as? APIError {
                withAnimation(.easeInOut(duration: 0.2)) { showPaywall = true }
            } else {
                errorMessage = (error as? APIError)?.errorDescription ?? "Shelf jammed — try again"
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                MonoLabel(text: "Smart TBR · Plus", size: 9.5, tracking: 2.2, color: SK.faint)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(SK.ink)
                        .frame(width: 32, height: 32)
                        .overlay(Rectangle().strokeBorder(SK.ink, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            Text("Read this next.")
                .font(PB.serif(30, .semibold))
                .foregroundStyle(SK.ink)
        }
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    @ViewBuilder private func content(_ data: SmartTBRResponse) -> some View {
        if let next = data.next {
            nextCard(next)
        }
        if data.queue.count > 1 {
            section("My next 5") {
                ForEach(Array(data.queue.enumerated()), id: \.element.id) { i, item in
                    row(item, index: i + 1)
                }
            }
        }
        if let soon = data.buckets["read_soon"], !soon.isEmpty {
            section("Read soon") { ForEach(soon) { row($0) } }
        }
        if let maybe = data.buckets["maybe"], !maybe.isEmpty {
            section("Maybe") { ForEach(maybe) { row($0) } }
        }
        if let stale = data.buckets["stale"], !stale.isEmpty {
            section("Still want these?", note: "Untouched for a year. Keep, or let them go.") {
                ForEach(stale) { staleRow($0) }
            }
        }
    }

    private func nextCard(_ item: SmartTBRItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                cover(item, width: 84)
                VStack(alignment: .leading, spacing: 6) {
                    MonoLabel(text: item.confidence ?? "Top of your shelf", size: 9, tracking: 1.6, color: SK.accent)
                    Text(item.title).font(PB.serif(21, .semibold)).foregroundStyle(SK.ink).lineLimit(3)
                    Text(item.authors.joined(separator: ", ")).font(.system(size: 12.5)).foregroundStyle(SK.sub)
                }
            }
            if let reason = item.reason, !reason.isEmpty {
                Text(reason).font(PB.serifItalic(15)).foregroundStyle(SK.ink).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 14)
            }
            ForEach(item.lines, id: \.self) { line in
                MonoLabel(text: line, size: 9.5, tracking: 1.2, color: SK.sub).padding(.top, 6)
            }
            HStack(spacing: 10) {
                Button {
                    Task { await SmartTBRService.startReading(username: user.username ?? "", bookID: item.id); await load() }
                } label: {
                    MonoLabel(text: "Start reading", size: 11, tracking: 1.4, color: SK.panel, weight: .semibold)
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(BrutalButtonStyle(fill: SK.ink, shadowColor: SK.ink.opacity(0.78), border: SK.ink, borderWidth: 2, offset: 4))
                Button { openBook = OpenBook(id: item.id) } label: {
                    MonoLabel(text: "Open", size: 11, tracking: 1.4, color: SK.ink, weight: .semibold)
                        .frame(minWidth: 90, minHeight: 46)
                }
                .buttonStyle(BrutalButtonStyle(fill: SK.panel, shadowColor: SK.ink.opacity(0.78), border: SK.ink, borderWidth: 2, offset: 4))
            }
            .padding(.top, 18)
            .padding(.trailing, 4)
            .padding(.bottom, 4)
        }
        .padding(18)
        .background(SK.panel)
        .overlay(Rectangle().strokeBorder(SK.ink, lineWidth: 2))
        .background(Rectangle().fill(SK.ink).offset(x: 5, y: 5))
        .padding(.trailing, 5)
        .padding(.bottom, 24)
    }

    private func section<Content: View>(_ title: String, note: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoLabel(text: title, size: 10, tracking: 2, color: SK.ink, weight: .semibold)
            if let note {
                Text(note).font(.system(size: 12.5)).foregroundStyle(SK.sub).padding(.top, 4)
            }
            Rectangle().fill(SK.ink).frame(height: 2).padding(.top, 8)
            content()
        }
        .padding(.bottom, 24)
    }

    private func row(_ item: SmartTBRItem, index: Int? = nil) -> some View {
        Button { openBook = OpenBook(id: item.id) } label: {
            HStack(spacing: 12) {
                if let index {
                    MonoLabel(text: String(format: "%02d", index), size: 10, tracking: 1, color: SK.faint)
                }
                cover(item, width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(PB.serif(15, .semibold)).foregroundStyle(SK.ink).lineLimit(1)
                    Text((item.lines.first ?? item.authors.joined(separator: ", ")))
                        .font(.system(size: 11.5)).foregroundStyle(SK.sub).lineLimit(1)
                }
                Spacer()
                if let c = item.confidence { MonoLabel(text: c, size: 8.5, tracking: 1.2, color: SK.faint) }
            }
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(SK.ink.opacity(0.12)).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }

    private func staleRow(_ item: SmartTBRItem) -> some View {
        HStack(spacing: 12) {
            cover(item, width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(PB.serif(15, .semibold)).foregroundStyle(SK.ink).lineLimit(1)
                Text(item.lines.first ?? "").font(.system(size: 11.5)).foregroundStyle(SK.sub).lineLimit(1)
            }
            Spacer()
            if let answer = settled[item.id] {
                MonoLabel(text: answer, size: 9, tracking: 1.4, color: SK.faint)
            } else {
                Button("Keep") {
                    settled[item.id] = "Kept"
                    Task { await SmartTBRService.keep(bookID: item.id) }
                }
                Button("Remove") {
                    settled[item.id] = "Removed"
                    Task { await SmartTBRService.remove(username: user.username ?? "", bookID: item.id) }
                }
                .foregroundStyle(SK.accent)
            }
        }
        .font(PB.mono(10, .semibold))
        .foregroundStyle(SK.ink)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(SK.ink.opacity(0.12)).frame(height: 1) }
    }

    @ViewBuilder private func cover(_ item: SmartTBRItem, width: CGFloat) -> some View {
        Group {
            if let raw = item.coverURL, let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { SK.coverGradient }
                }
            } else {
                SK.coverGradient
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipped()
        .overlay(Rectangle().strokeBorder(SK.ink, lineWidth: 1.5))
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).foregroundStyle(SK.sub)
            .frame(maxWidth: .infinity, minHeight: 200)
            .multilineTextAlignment(.center)
    }
}

/// fullScreenCover(item:) needs Identifiable; a bare String is not.
private struct OpenBook: Identifiable { let id: String }
