import Combine
import SwiftUI

/// How a Fusion gets opened: an invite link (universal link or
/// paperboxd://fusion/<token>), or an existing Fusion from the profile list or
/// the "fused with you" notification.
enum FusionRoute: Identifiable, Equatable {
    case link(token: String)
    case fusion(id: String, introFrom: String?)

    var id: String {
        switch self {
        case .link(let token): return "link-\(token)"
        case .fusion(let id, _): return "fusion-\(id)"
        }
    }

    /// Accepts https://paperboxd.in/fusion/<token> (and www.) or
    /// paperboxd://fusion/<token>.
    static func from(url: URL) -> FusionRoute? {
        let parts: [String]
        if url.scheme == "paperboxd" {
            guard url.host == "fusion" else { return nil }
            parts = url.pathComponents.filter { $0 != "/" }
        } else if ["paperboxd.in", "www.paperboxd.in"].contains(url.host ?? "") {
            let p = url.pathComponents.filter { $0 != "/" }
            guard p.first == "fusion" else { return nil }
            parts = Array(p.dropFirst())
        } else {
            return nil
        }
        guard let token = parts.first, token.count == 12, token.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return .link(token: token.lowercased())
    }
}

// MARK: - Model

@MainActor
final class FusionFlowModel: ObservableObject {
    enum Step {
        case loading
        case join(inviter: FusionPerson)
        case analyzing(them: String?)
        case joined(id: String, them: String)
        case story(FusionStory)
        case explore(FusionStory)
        case lowData
        case own(token: String)
        case used(inviter: String)
        case expired(inviter: String)
        case unavailable
        case gone
        case failed
    }

    @Published var step: Step = .loading
    @Published var isFusing = false
    @Published var toast: String?

    let route: FusionRoute
    let user: User

    init(route: FusionRoute, user: User) {
        self.route = route
        self.user = user
    }

    func start() async {
        switch route {
        case .link(let token):
            await preview(token)
        case .fusion(let id, let intro):
            if let intro {
                step = .joined(id: id, them: intro)
            } else {
                await build(id, them: nil)
            }
        }
    }

    func retry() async {
        step = .loading
        await start()
    }

    func preview(_ token: String) async {
        do {
            let p: FusionInvitePreview = try await APIClient.shared.request(
                path: Endpoints.fusionInvite(token), requiresAuth: true
            )
            let name = p.inviter?.first ?? "your friend"
            switch p.status {
            case .valid:
                if let inviter = p.inviter { step = .join(inviter: inviter) } else { step = .unavailable }
            case .joined:
                if let id = p.fusionID { await build(id, them: p.inviter?.first) } else { step = .unavailable }
            case .own: step = .own(token: token)
            case .used: step = .used(inviter: name)
            case .expired: step = .expired(inviter: name)
            case .unavailable: step = .unavailable
            }
        } catch is CancellationError {
        } catch {
            step = .failed
        }
    }

    func fuse(token: String, inviter: FusionPerson) async {
        guard !isFusing else { return }
        isFusing = true
        defer { isFusing = false }
        do {
            let r: FusionAcceptResponse = try await APIClient.shared.request(
                path: Endpoints.acceptFusionInvite(token), method: .post, requiresAuth: true
            )
            await build(r.fusionID, them: inviter.first)
        } catch APIError.transport {
            show("Couldn't reach PaperBoxd. Try again.")
        } catch {
            // The 409 carries the link's state; the preview names it the same way.
            await preview(token)
        }
    }

    /// Shows the Analyzing page while the story is fetched (the first open
    /// builds it server-side), and holds it long enough to read.
    func build(_ id: String, them: String?) async {
        step = .analyzing(them: them)
        let started = Date()
        let result: Result<FusionStory, Error>
        do {
            result = .success(try await APIClient.shared.request(path: Endpoints.fusion(id), requiresAuth: true))
        } catch {
            result = .failure(error)
        }
        let wait = 2.6 - Date().timeIntervalSince(started)
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }

        switch result {
        case .success(let s):
            step = s.lowData ? .lowData : .story(s)
        case .failure(APIError.notFound):
            step = .gone
        case .failure:
            step = .failed
        }
    }

    func addToTBR(_ books: [FusionBook]) {
        guard let username = user.username, !books.isEmpty else { return }
        Task {
            var added = 0
            for b in books {
                let ok = (try? await APIClient.shared.request(
                    path: Endpoints.addToBookshelf(username: username),
                    method: .post,
                    body: ["book_id": b.id, "status": "to-read"],
                    requiresAuth: true
                ) as Empty) != nil
                if ok { added += 1 }
            }
            switch added {
            case 0: show("Couldn't add. Try again.")
            case 1: show(books.count == 1 ? "\(books[0].title) added to your TBR" : "1 book added to your TBR")
            default: show("\(added) books added to your TBR")
            }
        }
    }

    func show(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if toast == message { toast = nil }
        }
    }
}

// MARK: - Root

struct FusionRootView: View {
    @StateObject private var model: FusionFlowModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    init(route: FusionRoute, user: User) {
        _model = StateObject(wrappedValue: FusionFlowModel(route: route, user: user))
    }

    private var actions: FusionActions {
        FusionActions(
            toast: { model.show($0) },
            explore: {
                if case .story(let s) = model.step { withAnimation(.easeInOut(duration: 0.3)) { model.step = .explore(s) } }
            },
            addToTBR: { model.addToTBR($0) }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .transition(.opacity)
            if let t = model.toast {
                FZToast(message: t)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.toast)
        .task { await model.start() }
        .statusBarHidden()
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .loading:
            ZStack { FZ.bg.ignoresSafeArea(); PBSpinner() }
        case .join(let inviter):
            if case .link(let token) = model.route {
                FusionJoinView(inviter: inviter, viewer: model.user, isFusing: model.isFusing,
                               onFuse: { Task { await model.fuse(token: token, inviter: inviter) } },
                               onNotNow: close)
            }
        case .analyzing(let them):
            FusionAnalyzingView(me: model.user.username.map { "@\($0)" } ?? "", them: them)
        case .joined(let id, let them):
            FusionJoinedView(me: model.user.username ?? "", them: them) { Task { await model.build(id, them: them) } }
        case .story(let s):
            FusionStoryPlayer(story: s, actions: actions, onClose: close)
        case .explore(let s):
            FusionExploreView(story: s, actions: actions, onClose: close)
        case .lowData:
            FusionStateView(label: "Not enough yet",
                            head: ["We need a little", "more reading history."],
                            message: "Once you have both rated a few books, Fusion can compare your tastes properly. Anything less would be a guess with a number on it.",
                            cta: "Close", action: close)
        case .own(let token):
            FusionStateView(label: "Your link", head: ["This is your", "own invite."],
                            message: "A Fusion needs two readers. Send this link to someone else.",
                            cta: "Close", action: close,
                            share: URL(string: "https://paperboxd.in/fusion/\(token)"))
        case .used(let inviter):
            FusionStateView(label: "Used", head: ["Someone already", "used this invite."],
                            message: "Each link makes one Fusion with one reader. Ask \(inviter) for a link of your own.",
                            cta: "Close", action: close)
        case .expired(let inviter):
            FusionStateView(label: "Expired", head: ["This invite", "has expired."],
                            message: "Fusion links last seven days. Ask \(inviter) to send a new one.",
                            cta: "Close", action: close)
        case .unavailable:
            FusionStateView(label: "Unavailable", head: ["This invite isn't", "available."],
                            message: "It may have been cancelled. Nothing was shared.",
                            cta: "Close", action: close)
        case .gone:
            FusionStateView(label: "Unavailable", head: ["This Fusion is", "no longer available."],
                            message: "One of you removed it, or this reader's account is no longer visible to you.",
                            cta: "Close", action: close)
        case .failed:
            FusionStateView(label: "Failed", head: ["We couldn't build", "this Fusion right now."],
                            message: "Both taste profiles are intact. We just couldn't put them together. Nothing was lost.",
                            cta: "Try again", action: { Task { await model.retry() } })
        }
    }

    private func close() {
        appState.fusionRoute = nil
        dismiss()
    }
}

// MARK: - Their side of the link

struct FusionJoinView: View {
    let inviter: FusionPerson
    let viewer: User
    let isFusing: Bool
    let onFuse: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        FZScreen(top: 64, bottom: 36) {
            HStack(alignment: .firstTextBaseline) {
                FZLabel(text: "Fusion invite")
                Spacer()
                if let u = viewer.username { FZLabel(text: "@\(u)") }
            }
            FZRule(delay: 0.2).padding(.top, 12)
            HStack(spacing: 16) {
                FZDiscs(delay: 0.26)
                PBFade(delay: 0.42) {
                    VStack(alignment: .leading, spacing: 5) {
                        FZLabel(text: "From", size: 9)
                        FZHeading(text: inviter.name.isEmpty ? inviter.username : inviter.name, size: 20)
                        FZLabel(text: "@\(inviter.username)", size: 9)
                    }
                }
            }
            .padding(.top, 34)
            FZStack(lines: ["\(inviter.first) invited you", "to a Fusion."], size: 42, accentLast: true, delay: 0.52)
                .padding(.top, 30)
            PBFade(delay: 0.78) { FZLabel(text: "\(inviter.first) will see", size: 9) }.padding(.top, 26)
            VStack(spacing: 0) {
                ForEach(Array(consent.enumerated()), id: \.offset) { i, line in
                    FZRule(delay: 0.84 + Double(i) * 0.09)
                    PBSlide(delay: 0.87 + Double(i) * 0.09, distance: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            FZNum(text: .fzIndex(i + 1), size: 10, color: FZ.accent).frame(width: 18, alignment: .leading).padding(.top, 2)
                            FZBody(text: line, size: 13.5, opacity: 0.86)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 11)
                    }
                }
                FZRule(delay: 1.12)
            }
            .padding(.top, 8)
            PBFade(delay: 1.18) { FZBody(text: "Your diary entries and notes are never included.", size: 12.5) }.padding(.top, 12)
            Spacer()
            PBFade(delay: 1.26) {
                FZPill(title: isFusing ? "Fusing…" : "Fuse with \(inviter.first)", solid: true, action: onFuse)
                    .disabled(isFusing)
            }
            PBFade(delay: 1.32) {
                HStack {
                    Spacer()
                    Button(action: onNotNow) { FZLabel(text: "Not now", size: 9, color: FZ.ink) }
                    Spacer()
                }
            }
            .padding(.top, 14)
        }
    }

    private var consent: [String] {
        [
            "Your ratings on books you have both read",
            "Books you loved that \(inviter.first) has not read",
            "Where your tastes agree, and where they split",
        ]
    }
}

/// The work named as a ledger, not a spinner.
struct FusionAnalyzingView: View {
    let me: String
    let them: String?

    @State private var percent = 0
    private let ledger = [
        "Reading two shelves",
        "Comparing the books you have both read",
        "Weighing how you rated them",
        "Measuring nine taste axes",
        "Finding books neither of you has read",
    ]

    var body: some View {
        FZScreen(dark: true, top: 72, bottom: 48) {
            HStack(alignment: .firstTextBaseline) {
                FZLabel(text: "Building your Fusion", color: FZ.muteOnDark)
                Spacer()
                if let them { FZNum(text: "\(me) × \(them)", size: 11, color: FZ.muteOnDark, bold: false) }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(FZ.bg.opacity(0.2))
                    Rectangle().fill(FZ.accent).frame(width: g.size.width * CGFloat(percent) / 100)
                }
            }
            .frame(height: 2)
            .padding(.top, 14)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(percent)").font(FZ.heading(132)).tracking(FZ.tracking(132)).monospacedDigit().foregroundStyle(FZ.bg)
                Text("%").font(FZ.heading(44)).foregroundStyle(FZ.accent)
            }
            Spacer()
            VStack(spacing: 0) {
                ForEach(Array(ledger.enumerated()), id: \.offset) { i, line in
                    PBFade(delay: Double(i) * 0.5, duration: 0.46) {
                        VStack(spacing: 0) {
                            Rectangle().fill(FZ.bg.opacity(0.18)).frame(height: 1)
                            HStack(spacing: 12) {
                                FZNum(text: .fzIndex(i + 1), size: 10, color: FZ.accent).frame(width: 18, alignment: .leading)
                                FZBody(text: line, size: 13, color: FZ.bg, opacity: 0.8)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 11)
                        }
                    }
                }
            }
        }
        .task {
            // Eases toward 96 and waits there: the real finish is the story.
            while percent < 96 {
                try? await Task.sleep(for: .milliseconds(90))
                percent = min(96, percent + max(1, (100 - percent) / 12))
            }
        }
    }
}

/// The inviter's side, once someone has tapped Fuse. The number is held back
/// for the story.
struct FusionJoinedView: View {
    let me: String
    let them: String
    let onPlay: () -> Void

    var body: some View {
        FZScreen(dark: true, top: 72, bottom: 48) {
            FZLabel(text: "Fusion", color: FZ.muteOnDark)
            FZRule(delay: 0.2, dark: true).padding(.top, 12)
            Spacer()
            PBStamp(delay: 0.26) {
                HStack(spacing: 0) {
                    FZMonogram(initial: String(me.prefix(1)).uppercased(), size: 56, accent: true)
                    FZMonogram(initial: String(them.prefix(1)).uppercased(), size: 56, onDark: true)
                }
            }
            FZStack(lines: ["\(them) fused", "with you."], size: 46, color: FZ.bg, accentLast: true, delay: 0.42)
                .padding(.top, 30)
            FZRule(delay: 0.7, dark: true).padding(.vertical, 20)
            PBFade(delay: 0.78) {
                FZBody(text: "Your Fusion is built. One number, where you agree and split, and a book neither of you has read.", size: 15, color: FZ.bg, opacity: 0.8)
            }
            Spacer()
            PBFade(delay: 0.92) { FZPill(title: "Play your Fusion", solid: true, light: true, action: onPlay) }
        }
    }
}

struct FusionStateView: View {
    let label: String
    let head: [String]
    let message: String
    let cta: String
    let action: () -> Void
    var share: URL? = nil

    var body: some View {
        FZScreen(top: 64, bottom: 36) {
            HStack {
                FZLabel(text: "Fusion")
                Spacer()
                FZLabel(text: label)
            }
            FZRule(delay: 0.2).padding(.top, 12)
            Spacer()
            FZStack(lines: head, size: 34, delay: 0.3)
            FZRule(delay: 0.56).padding(.vertical, 18)
            PBFade(delay: 0.64) { FZBody(text: message, size: 14.5) }
            Spacer()
            PBFade(delay: 0.78) {
                VStack(spacing: 9) {
                    if let share {
                        ShareLink(item: share) {
                            Text("SHARE LINK").font(FZ.medium(11)).tracking(1.1).foregroundStyle(FZ.bg)
                                .frame(maxWidth: .infinity).padding(.vertical, 15).background(FZ.ink)
                        }
                        FZPill(title: cta, action: action)
                    } else {
                        FZPill(title: cta, solid: true, action: action)
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Fusion — join") {
    FusionJoinView(inviter: PreviewData.fusionStory.them, viewer: PreviewData.user, isFusing: false, onFuse: {}, onNotNow: {})
}

#Preview("Fusion — analyzing") {
    FusionAnalyzingView(me: "@hridyesh", them: "Alex")
}

#Preview("Fusion — joined") {
    FusionJoinedView(me: "hridyesh", them: "Alex", onPlay: {})
}
#endif
