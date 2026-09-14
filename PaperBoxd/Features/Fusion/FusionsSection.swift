import Combine
import SwiftUI

// Your side of Fusion: the profile section (waiting link + Fusions) and the
// Create sheet (landing → link). Port of fusion2/flow.jsx FLanding, FInvite
// and FList.

@MainActor
final class FusionsModel: ObservableObject {
    @Published private(set) var list = FusionList(invite: nil, fusions: [])
    @Published private(set) var loaded = false
    @Published private(set) var isCreating = false
    @Published var toast: String?

    func load() async {
        if let l: FusionList = try? await APIClient.shared.request(path: Endpoints.fusions, requiresAuth: true) {
            list = l
        }
        loaded = true
    }

    /// Returns the live link, making one if needed.
    func createInvite() async -> FusionInvite? {
        isCreating = true
        defer { isCreating = false }
        do {
            let inv: FusionInvite = try await APIClient.shared.request(
                path: Endpoints.fusionInvites, method: .post, requiresAuth: true
            )
            list = FusionList(invite: inv, fusions: list.fusions)
            return inv
        } catch {
            flash((error as? APIError)?.errorDescription ?? "Couldn't make a link. Try again.")
            return nil
        }
    }

    func cancel(_ invite: FusionInvite) async {
        do {
            let _: Empty = try await APIClient.shared.request(
                path: Endpoints.fusionInvite(invite.token), method: .delete, requiresAuth: true
            )
            list = FusionList(invite: nil, fusions: list.fusions)
            flash("Link cancelled")
        } catch {
            flash("Couldn't cancel the link")
        }
    }

    func copy(_ invite: FusionInvite) {
        UIPasteboard.general.string = invite.url
        flash("Fusion link copied")
    }

    func flash(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if toast == message { toast = nil }
        }
    }
}

// MARK: - Profile section

/// Sits on your own profile. Quiet until there is something in it.
struct FusionsSection: View {
    @StateObject private var model = FusionsModel()
    @EnvironmentObject private var appState: AppState
    @State private var showCreate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                FZLabel(text: "Fusion", size: 9.5, color: FZ.accent)
                Spacer()
                if !model.list.fusions.isEmpty {
                    FZLabel(text: "\(model.list.fusions.count) \(model.list.fusions.count == 1 ? "reader" : "readers")", size: 9)
                }
            }

            if model.list.fusions.isEmpty && model.list.invite == nil {
                Button { showCreate = true } label: {
                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            FZHeading(text: "Two tastes. One discovery.", size: 19)
                            FZBody(text: "Send one reader a link and see how your shelves line up.", size: 13)
                        }
                        Spacer(minLength: 8)
                        Text("→").font(FZ.heading(24)).foregroundStyle(FZ.accent)
                    }
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
            } else {
                if let invite = model.list.invite {
                    waiting(invite).padding(.top, 12)
                }
                ForEach(model.list.fusions) { f in
                    Rectangle().fill(FZ.line).frame(height: 1).padding(.top, 12)
                    Button {
                        appState.fusionRoute = .fusion(id: f.id, introFrom: nil)
                    } label: {
                        HStack(spacing: 12) {
                            HStack(spacing: 0) {
                                FZMonogram(initial: String((appState.currentUser?.username ?? "Y").prefix(1)).uppercased(), size: 30, accent: true)
                                FZMonogram(initial: f.them.initial, size: 30)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                FZHeading(text: f.them.name.isEmpty ? f.them.username : f.them.name, size: 17)
                                FZLabel(text: "@\(f.them.username)", size: 9)
                            }
                            Spacer(minLength: 8)
                            FZNum(text: f.score.map { "\($0)%" } ?? "New", size: 22, color: FZ.accent)
                        }
                        .padding(.top, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if model.list.invite == nil {
                    FZPill(title: "Create a Fusion", compact: true) { showCreate = true }
                        .padding(.top, 16)
                }
            }
        }
        .padding(18)
        .background(FZ.bg)
        .overlay(Rectangle().stroke(FZ.ink, lineWidth: 1))
        .overlay(alignment: .bottom) {
            if let t = model.toast { FZToast(message: t, bottom: 0).offset(y: 22) }
        }
        .task { await model.load() }
        .onChange(of: appState.fusionRoute) { _, route in
            // Back from a Fusion: scores may have been built for the first time.
            if route == nil { Task { await model.load() } }
        }
        .sheet(isPresented: $showCreate, onDismiss: { Task { await model.load() } }) {
            FusionCreateSheet(model: model)
                .presentationDetents([.large])
                .presentationBackground(FZ.bg)
        }
    }

    private func waiting(_ invite: FusionInvite) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Rectangle().fill(FZ.accent).frame(width: 7, height: 7)
                FZLabel(text: "Link waiting", size: 9, color: FZ.ink)
                Spacer()
                FZLabel(text: "\(invite.daysLeft) \(invite.daysLeft == 1 ? "day" : "days") left", size: 9)
            }
            FZNum(text: invite.url.replacingOccurrences(of: "https://", with: ""), size: 12.5, bold: false)
                .lineLimit(1)
            HStack(spacing: 8) {
                if let url = URL(string: invite.url) {
                    ShareLink(item: url) {
                        Text("SHARE").font(FZ.medium(9.5)).tracking(0.95).foregroundStyle(FZ.bg)
                            .padding(.horizontal, 12).padding(.vertical, 9).background(FZ.ink)
                    }
                }
                FZPill(title: "Copy", compact: true, fullWidth: false) { model.copy(invite) }
                FZPill(title: "Cancel", compact: true, fullWidth: false) { Task { await model.cancel(invite) } }
            }
        }
        .padding(14)
        .overlay(Rectangle().stroke(FZ.ink, lineWidth: 1))
    }
}

// MARK: - Create sheet

struct FusionCreateSheet: View {
    @ObservedObject var model: FusionsModel
    @State private var invite: FusionInvite?

    var body: some View {
        ZStack(alignment: .bottom) {
            if let invite {
                FusionInviteView(invite: invite, model: model)
                    .transition(.opacity)
            } else {
                FusionLandingView(isCreating: model.isCreating) {
                    Task {
                        if let inv = await model.createInvite() {
                            withAnimation(.easeInOut(duration: 0.3)) { invite = inv }
                        }
                    }
                }
            }
            if let t = model.toast { FZToast(message: t, bottom: 40) }
        }
        .animation(.easeInOut(duration: 0.25), value: model.toast)
        .environment(\.colorScheme, .light)
        .onAppear { invite = model.list.invite }
    }
}

struct FusionLandingView: View {
    let isCreating: Bool
    let onCreate: () -> Void

    var body: some View {
        FZScreen(top: 36, bottom: 36) {
            HStack(alignment: .firstTextBaseline) {
                Text("PaperBoxd").font(FZ.script(28)).foregroundStyle(FZ.ink)
                Spacer()
                FZLabel(text: "Fusion")
            }
            FZRule(delay: 0.2).padding(.top, 12)
            Spacer()
            FZDiscs(delay: 0.26).padding(.bottom, 34)
            FZStack(lines: ["Two tastes.", "One discovery."], size: 46, accentLast: true, delay: 0.42, step: 0.09)
            FZRule(delay: 0.72).padding(.top, 24).padding(.bottom, 18)
            PBFade(delay: 0.8) {
                FZBody(text: "Send a link to one reader. When they open it and tap Fuse, PaperBoxd puts your two shelves side by side.", size: 15)
            }
            Spacer()
            PBFade(delay: 0.96) {
                FZPill(title: isCreating ? "Making your link…" : "Create a Fusion", solid: true, action: onCreate)
                    .disabled(isCreating)
            }
            PBFade(delay: 1.04) {
                HStack { Spacer(); FZLabel(text: "A Fusion is private until you share it", size: 9); Spacer() }
            }
            .padding(.top, 14)
        }
    }
}

/// The link, and what happens to it: a ledger, like Analyzing.
struct FusionInviteView: View {
    let invite: FusionInvite
    @ObservedObject var model: FusionsModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        FZScreen(top: 36, bottom: 36) {
            HStack {
                FZLabel(text: "Create a Fusion")
                Spacer()
                FZLabel(text: "Invite")
            }
            FZRule(delay: 0.16).padding(.top, 12)
            FZStack(lines: ["Send this to", "one reader."], size: 36, accentLast: true, delay: 0.22).padding(.top, 24)
            PBFade(delay: 0.42) {
                FZBody(text: "The first person to open it and tap Fuse becomes your Fusion. It works once.", size: 14)
            }
            .padding(.top, 14)

            PBFade(delay: 0.54) {
                HStack(spacing: 0) {
                    FZNum(text: invite.url.replacingOccurrences(of: "https://", with: ""), size: 14, bold: false)
                        .lineLimit(1).truncationMode(.middle)
                        .padding(.horizontal, 14).padding(.vertical, 15)
                    Spacer(minLength: 0)
                    Button { model.copy(invite) } label: {
                        FZLabel(text: "Copy", size: 10, color: FZ.ink)
                            .padding(.horizontal, 16).frame(maxHeight: .infinity)
                            .overlay(alignment: .leading) { Rectangle().fill(FZ.ink).frame(width: 1) }
                    }
                    .buttonStyle(.plain)
                }
                .fixedSize(horizontal: false, vertical: true)
                .overlay(Rectangle().stroke(FZ.ink, lineWidth: 1))
            }
            .padding(.top, 26)

            if let url = URL(string: invite.url) {
                PBFade(delay: 0.62) {
                    ShareLink(item: url, message: Text("Fuse with me on PaperBoxd")) {
                        Text("SHARE LINK").font(FZ.medium(11)).tracking(1.1).foregroundStyle(FZ.bg)
                            .frame(maxWidth: .infinity).padding(.vertical, 15).background(FZ.ink)
                    }
                }
                .padding(.top, 10)
            }

            VStack(spacing: 0) {
                ledgerRow(0, "Link made", done: true, trailing: "Ready")
                ledgerRow(1, "Waiting for them to open it", done: false, pulse: true)
                ledgerRow(2, "Your Fusion builds", done: false)
                FZRule(delay: 1.1)
            }
            .padding(.top, 30)

            Spacer()
            PBFade(delay: 1.18) {
                HStack(alignment: .firstTextBaseline) {
                    FZLabel(text: "Single use · expires in \(invite.daysLeft) \(invite.daysLeft == 1 ? "day" : "days")", size: 9)
                    Spacer()
                    Button {
                        Task { await model.cancel(invite); dismiss() }
                    } label: { FZLabel(text: "Cancel link", size: 9, color: FZ.ink) }
                }
            }
        }
    }

    private func ledgerRow(_ i: Int, _ text: String, done: Bool, trailing: String? = nil, pulse: Bool = false) -> some View {
        VStack(spacing: 0) {
            FZRule(delay: 0.76 + Double(i) * 0.11)
            PBSlide(delay: 0.8 + Double(i) * 0.11, distance: 14) {
                HStack(spacing: 12) {
                    FZNum(text: .fzIndex(i + 1), size: 10, color: done ? FZ.accent : FZ.grey).frame(width: 18, alignment: .leading)
                    FZBody(text: text, size: 13.5, opacity: done || pulse ? 0.86 : 0.45)
                    Spacer(minLength: 0)
                    if let trailing { FZLabel(text: trailing, size: 9) }
                    if pulse { PulseDot() }
                }
                .padding(.vertical, 13)
            }
        }
    }
}

private struct PulseDot: View {
    @State private var on = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Rectangle().fill(FZ.accent).frame(width: 7, height: 7)
            .opacity(on ? 1 : 0)
            .task {
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(550))
                    on.toggle()
                }
            }
    }
}

#if DEBUG
#Preview("Fusion — landing") {
    FusionLandingView(isCreating: false, onCreate: {})
}

#Preview("Fusion — invite") {
    FusionInviteView(invite: FusionInvite(token: "k7q2xmabcdef", url: "https://paperboxd.in/fusion/k7q2xmabcdef", expiresAt: "2026-09-20T10:00:00Z"), model: FusionsModel())
}
#endif
