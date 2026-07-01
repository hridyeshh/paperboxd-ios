import SwiftUI

/// "Type the title instead" — searches `/books/search` and, on tap, feeds the
/// chosen book's ISBN into the scan analysis (the backend scores by ISBN).
struct ManualSearchSheet: View {
    /// Called with the chosen book's ISBN and title.
    let onPick: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var hits: [ScanSearchHit] = []
    @State private var loading = false
    @State private var searched = false
    @State private var noISBNNote = false

    var body: some View {
        VStack(spacing: 0) {
            header
            field
            content
        }
        .background(SK.bg.ignoresSafeArea())
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack {
            Text("Find your book").font(PB.serif(20, .semibold)).foregroundStyle(SK.ink)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(SK.sub)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(SK.sub)
            TextField("Title, author or ISBN", text: $query)
                .font(.system(size: 15))
                .foregroundStyle(SK.ink)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(run)
            if loading { ProgressView().scaleEffect(0.8) }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(SK.panel)
        .overlay(Rectangle().strokeBorder(SK.line, lineWidth: 1.5))
        .padding(.horizontal, 20)
    }

    @ViewBuilder private var content: some View {
        if noISBNNote {
            note("No ISBN for that edition — try another result.")
        }
        if searched && hits.isEmpty && !loading {
            note("Nothing found. Try a different search.")
        }
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(hits) { hit in
                    Button { pick(hit) } label: { row(hit) }
                        .buttonStyle(.plain)
                    Rectangle().fill(SK.border).frame(height: 1).padding(.leading, 20)
                }
            }
        }
    }

    private func row(_ hit: ScanSearchHit) -> some View {
        HStack(spacing: 12) {
            coverThumb(hit)
            VStack(alignment: .leading, spacing: 3) {
                Text(hit.title).font(PB.serif(15)).foregroundStyle(SK.ink).lineLimit(2)
                Text(hit.author).font(.system(size: 12)).foregroundStyle(SK.sub).lineLimit(1)
            }
            Spacer()
            Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                .foregroundStyle(hit.isbn == nil ? SK.faint : SK.ink)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .contentShape(Rectangle())
        .opacity(hit.isbn == nil ? 0.55 : 1)
    }

    private func coverThumb(_ hit: ScanSearchHit) -> some View {
        Group {
            if let raw = hit.coverURL, let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image { img.resizable().scaledToFill() }
                    else { SK.coverGradient }
                }
            } else { SK.coverGradient }
        }
        .frame(width: 34, height: 51)
        .clipped()
        .overlay(Rectangle().strokeBorder(SK.line, lineWidth: 1))
    }

    private func note(_ t: String) -> some View {
        Text(t).font(PB.mono(11)).foregroundStyle(SK.sub)
            .padding(.horizontal, 20).padding(.top, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func run() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        loading = true; noISBNNote = false
        Task {
            let results = (try? await ScanService.search(query: q)) ?? []
            await MainActor.run { hits = results; loading = false; searched = true }
        }
    }

    private func pick(_ hit: ScanSearchHit) {
        guard let isbn = hit.isbn else {
            withAnimation { noISBNNote = true }
            return
        }
        onPick(isbn, hit.title)
    }
}
