import SwiftUI

/// 04 — Breakdown · MINIMALIST resolution. Everything exhales: no boxes, no shadows
/// — whitespace, hairline splits, a serif headline, a thin radar, and plain-English
/// reasons built from books you finish vs abandon.
struct BreakdownScreen: View {
    let result: ScanResult
    let onClose: () -> Void

    @EnvironmentObject private var appState: AppState

    private enum TBRState: Equatable { case idle, loading, added, failed }
    @State private var tbrState: TBRState = .idle
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                header
                compareRow
                breaksDown
                whySection
                sourcesCaption
                actions
                notForMe
                ScansRemainingFooter()
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 26)
            .padding(.top, 16)
            .padding(.bottom, 44)
        }
        .background(SK.bgSofter.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(SK.sub)
                    .frame(width: 34, height: 34)
            }
            .padding(.horizontal, 16).padding(.top, 6)
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SK.bg)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(SK.ink).clipShape(Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        withAnimation { self.toast = nil }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 18) {
            ScanCover(result: result, width: 62)
            VStack(alignment: .leading, spacing: 5) {
                Text(result.title).font(PB.serif(21, .medium)).foregroundStyle(SK.ink).lineLimit(2)
                Text(result.author).font(.system(size: 12.5)).foregroundStyle(SK.sub)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(result.matchScore)").font(PB.mono(34)).foregroundStyle(SK.ink)
                MonoLabel(text: "match", size: 10.5, tracking: 1.0, color: SK.faint)
            }
        }
    }

    // MARK: - Internet vs you (hairline split)

    private var compareRow: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(text: "The internet", size: 11, tracking: 0.8, color: SK.faint)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(result.internetRating.map { String(format: "%.2f", $0) } ?? "—")
                        .font(PB.mono(22)).foregroundStyle(SK.ink)
                    Text("★ avg").font(.system(size: 12)).foregroundStyle(SK.sub)
                }
                Text("\(result.ratingsCount ?? "—") ratings").font(.system(size: 11)).foregroundStyle(SK.faint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)

            Rectangle().fill(SK.border).frame(width: 1)

            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(text: "For you", size: 11, tracking: 0.8, color: SK.faint)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(result.matchScore)").font(PB.mono(22)).foregroundStyle(SK.ink)
                    Text("/100").font(.system(size: 12)).foregroundStyle(SK.sub)
                }
                Text(result.verdict.lowercased()).font(.system(size: 11)).foregroundStyle(SK.faint).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18).padding(.leading, 20)
        }
        .overlay(alignment: .top) { Rectangle().fill(SK.border).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(SK.border).frame(height: 1) }
    }

    // MARK: - Radar

    private var breaksDown: some View {
        VStack(alignment: .leading, spacing: 22) {
            MonoLabel(text: "How it breaks down", size: 11, tracking: 0.8, color: SK.faint)
            RadarChart(dimensions: result.dimensions)
        }
    }

    // MARK: - Why for you

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            MonoLabel(text: "Why this score, for you", size: 11, tracking: 0.8, color: SK.faint)
            VStack(alignment: .leading, spacing: 16) {
                ForEach(result.reasons.indices, id: \.self) { i in
                    let r = result.reasons[i]
                    HStack(alignment: .top, spacing: 13) {
                        Image(systemName: r.ok ? "checkmark" : "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(r.ok ? SK.ink : SK.faint)
                            .frame(width: 16)
                        Text(r.text)
                            .font(.system(size: 13.5)).lineSpacing(2)
                            .foregroundStyle(r.ok ? SK.ink : SK.sub)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var sourcesCaption: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 12)).foregroundStyle(SK.faint)
            MonoLabel(text: "reddit · web reviews · your shelf of \(result.shelfCount) books", size: 9.5, tracking: 0.6, color: SK.faint)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                Task { await addToTBR() }
            } label: {
                HStack(spacing: 7) {
                    switch tbrState {
                    case .loading:
                        ProgressView().tint(SK.bg)
                    case .added:
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .bold))
                        Text("Added to TBR").font(.system(size: 14, weight: .semibold))
                    default:
                        Image(systemName: "plus").font(.system(size: 15, weight: .bold))
                        Text("Add to TBR").font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundStyle(SK.bg)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(tbrState == .added ? SK.sub : SK.ink).clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(tbrState == .loading || tbrState == .added)

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 16)).foregroundStyle(SK.ink)
                    .frame(width: 50, height: 48)
                    .overlay(Capsule().strokeBorder(SK.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    /// Ghost dismiss — closes the result and returns to the scan entry state.
    /// No negative signal logged, no API call (same dismiss path as the ✕ button).
    private var notForMe: some View {
        Button {
            onClose()
        } label: {
            Text("Not for me")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    /// Text shared from the breakdown — book, personal match, and app attribution.
    private var shareText: String {
        "\(result.title) by \(result.author) — scored \(result.matchScore)/100 for me on PaperBoxd. \(result.oneLine)"
    }

    /// Adds the scanned book to the reader's TBR. The backend resolves the book by
    /// ISBN and auto-creates it from ISBNdb if it isn't cached yet.
    private func addToTBR() async {
        guard tbrState != .loading, tbrState != .added else { return }
        guard let username = appState.currentUser?.username, !result.isbn.isEmpty else {
            toast = "Sign in to save books"
            return
        }
        tbrState = .loading
        do {
            let _: Empty = try await APIClient.shared.request(
                path: Endpoints.addToBookshelf(username: username),
                method: .post,
                body: ["isbn": result.isbn, "status": "to-read"],
                requiresAuth: true
            )
            tbrState = .added
            toast = "Added to your TBR"
        } catch let e as APIError {
            tbrState = .failed
            toast = e.errorDescription
        } catch {
            tbrState = .failed
            toast = "Couldn't add — try again"
        }
    }
}

// MARK: - Radar chart (light brutalist palette)

struct RadarChart: View {
    let dimensions: [ScanResult.Dimension]

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 * 0.7
            ZStack {
                ForEach(1...4, id: \.self) { ring in
                    RadarPolygon(sides: dimensions.count, scale: CGFloat(ring) / 4)
                        .stroke(SK.border, lineWidth: 1)
                }
                RadarDataPolygon(values: dimensions.map { $0.value })
                    .fill(SK.ink.opacity(0.08))
                RadarDataPolygon(values: dimensions.map { $0.value })
                    .stroke(SK.ink, lineWidth: 2)

                ForEach(dimensions.indices, id: \.self) { i in
                    let a = RadarChart.angle(i, dimensions.count)
                    Text(dimensions[i].name)
                        .font(PB.mono(9.5))
                        .foregroundStyle(SK.sub)
                        .position(x: center.x + cos(a) * (radius + 24),
                                  y: center.y + sin(a) * (radius + 18))
                }
            }
        }
        .frame(height: 240)
    }

    static func angle(_ i: Int, _ n: Int) -> CGFloat {
        -.pi / 2 + 2 * .pi * CGFloat(i) / CGFloat(n)
    }
}

private struct RadarPolygon: Shape {
    let sides: Int
    var scale: CGFloat = 1
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 * 0.7 * scale
        var p = Path()
        for i in 0..<sides {
            let a = RadarChart.angle(i, sides)
            let pt = CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

private struct RadarDataPolygon: Shape {
    let values: [Double]
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxR = min(rect.width, rect.height) / 2 * 0.7
        var p = Path()
        for (i, v) in values.enumerated() {
            let a = RadarChart.angle(i, values.count)
            let r = maxR * CGFloat(v)
            let pt = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
