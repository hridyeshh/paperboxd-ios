import SwiftUI
import UniformTypeIdentifiers

/// Imports a Goodreads library export (CSV) into the reader's bookshelf.
///
/// Mirrors the web app's `/api/import/goodreads` flow, but runs natively:
/// parse the CSV → for each row search our catalogue (ISBN first, then
/// title + author) → add the match to the shelf with the mapped status.
/// Star ratings are not imported here: the mobile progress endpoint tracks
/// pages, not ratings, so shelf placement is the honest, working subset.
///
/// Export a CSV from Goodreads: goodreads.com/review/import → "Export Library".
struct GoodreadsImportView: View {
    @EnvironmentObject private var appState: AppState

    @State private var phase: Phase = .idle
    @State private var showPicker = false
    @State private var errorMessage: String?

    enum Phase: Equatable {
        case idle
        case importing(done: Int, total: Int)
        case finished(imported: Int, skipped: Int, total: Int)
    }

    var body: some View {
        VStack(spacing: 0) {
            switch phase {
            case .idle:            idleView
            case .importing(let done, let total): importingView(done: done, total: total)
            case .finished(let imported, let skipped, let total):
                finishedView(imported: imported, skipped: skipped, total: total)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background").ignoresSafeArea())
        .navigationTitle("Import from Goodreads")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.commaSeparatedText, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { Task { await runImport(url: url) } }
            case .failure(let err):
                errorMessage = "Couldn't open that file: \(err.localizedDescription)"
            }
        }
        .alert("Import failed",
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color("Accent"))

            Text("Bring your Goodreads shelf")
                .font(PB.serif(24))
                .foregroundStyle(Color("TextPrimary"))

            Text("On Goodreads, open **My Books → Import and export → Export Library**, then choose the CSV file here. We match each book to our catalogue and add it to your shelf with the right status.")
                .font(.system(size: 15))
                .foregroundStyle(Color("TextSecondary"))
                .lineSpacing(3)

            Eyebrow(text: "Read · Currently reading · To-read are all kept")
                .padding(.top, 4)

            Spacer()

            Button { showPicker = true } label: {
                Text("Choose CSV file")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(Color("Background"))
                    .background(Color("TextPrimary"))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }

    // MARK: - Importing

    private func importingView(done: Int, total: Int) -> some View {
        VStack(spacing: 18) {
            Spacer()
            PBSpinner()
                .scaleEffect(1.2)
            Text("Importing your books")
                .font(PB.serif(20))
                .foregroundStyle(Color("TextPrimary"))
            Text("\(done) / \(total)")
                .font(PB.mono(13))
                .foregroundStyle(Color("TextSecondary"))
            Text("Keep this screen open")
                .font(.system(size: 12))
                .foregroundStyle(Color("TextSecondary").opacity(0.7))
            Spacer()
        }
        .padding(24)
    }

    // MARK: - Finished

    private func finishedView(imported: Int, skipped: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 34))
                .foregroundStyle(Color("Accent"))

            Text(imported > 0 ? "Import complete" : "Nothing to add")
                .font(PB.serif(24))
                .foregroundStyle(Color("TextPrimary"))

            VStack(spacing: 0) {
                resultRow(label: "Added to shelf", value: imported)
                Divider().overlay(Color("Border"))
                resultRow(label: "Skipped (no match)", value: skipped)
                Divider().overlay(Color("Border"))
                resultRow(label: "Total in file", value: total)
            }

            if skipped > 0 {
                Text("Skipped books weren't found in our catalogue. You can add those by searching for them directly.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color("TextSecondary"))
                    .lineSpacing(2)
            }

            Spacer()

            Button { phase = .idle } label: {
                Text("Import another file")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(Color("TextPrimary"))
                    .overlay(Capsule().strokeBorder(Color("Border"), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
    }

    private func resultRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color("TextPrimary"))
            Spacer()
            Text("\(value)")
                .font(PB.serif(20))
                .foregroundStyle(Color("TextPrimary"))
        }
        .padding(.vertical, 14)
    }

    // MARK: - Import engine

    private func runImport(url: URL) async {
        guard let username = appState.currentUser?.username, !username.isEmpty else {
            errorMessage = "You need to be signed in to import."
            return
        }

        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            // Goodreads CSVs are UTF-8, but fall back to Latin-1 for odd exports.
            if let data = try? Data(contentsOf: url),
               let latin = String(data: data, encoding: .isoLatin1) {
                text = latin
            } else {
                errorMessage = "Couldn't read that file. Make sure it's the CSV exported from Goodreads."
                return
            }
        }

        let rows = Self.parseCSV(text)
        guard !rows.isEmpty else {
            errorMessage = "No books found in that CSV. Export your library from Goodreads and try again."
            return
        }

        phase = .importing(done: 0, total: rows.count)
        var imported = 0
        var skipped = 0

        // Sequential keeps the backend un-hammered and lets us show live progress.
        for (index, row) in rows.enumerated() {
            let ok = await importRow(row, username: username)
            if ok { imported += 1 } else { skipped += 1 }
            phase = .importing(done: index + 1, total: rows.count)
        }

        phase = .finished(imported: imported, skipped: skipped, total: rows.count)
    }

    /// Search for one row's book and add it to the shelf. Returns true on success.
    private func importRow(_ row: [String: String], username: String) async -> Bool {
        let title = row["Title"] ?? ""
        guard !title.isEmpty else { return false }
        let author = row["Author"] ?? row["Author l-f"] ?? ""
        let isbn13 = Self.cleanISBN(row["ISBN13"] ?? "")
        let isbn = Self.cleanISBN(row["ISBN"] ?? "")
        let status = Self.mapStatus(row["Exclusive Shelf"] ?? "to-read")

        let query = !isbn13.isEmpty ? isbn13
                  : !isbn.isEmpty ? isbn
                  : "\(title) \(author)".trimmingCharacters(in: .whitespaces)

        // Find a catalogue match (best single result).
        var comps = URLComponents(string: Endpoints.searchBooks)!
        comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page_size", value: "1"),
        ]
        guard
            let resp: BookListResponse = try? await APIClient.shared.request(
                path: comps.string ?? Endpoints.searchBooks,
                method: .get,
                requiresAuth: false
            ),
            let bookId = resp.items.first?.id
        else {
            return false
        }

        // Add to shelf (upsert — re-adding an existing book is harmless).
        do {
            let _: Empty = try await APIClient.shared.request(
                path: Endpoints.addToBookshelf(username: username),
                method: .post,
                body: ["book_id": bookId, "status": status],
                requiresAuth: true
            )
            return true
        } catch {
            // Network error, or a strict backend rejecting a duplicate: count
            // as skipped. A first-time import (the common path) adds cleanly.
            return false
        }
    }

    // MARK: - CSV parsing

    /// Goodreads maps its exclusive shelves onto our three shelf statuses.
    static func mapStatus(_ exclusive: String) -> String {
        switch exclusive {
        case "read":              return "read"
        case "currently-reading": return "reading"
        default:                  return "to-read"
        }
    }

    /// Goodreads writes ISBNs as `="0451524935"` — strip the `="` wrapper.
    static func cleanISBN(_ raw: String) -> String {
        raw.replacingOccurrences(of: "=", with: "")
           .replacingOccurrences(of: "\"", with: "")
           .trimmingCharacters(in: .whitespaces)
    }

    static func parseCSV(_ text: String) -> [[String: String]] {
        let lines = text.split(whereSeparator: { $0 == "\n" || $0 == "\r\n" })
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return [] }

        let headers = parseCSVLine(lines[0]).map { $0.trimmingCharacters(in: .whitespaces) }
        return lines.dropFirst().compactMap { line in
            let values = parseCSVLine(line)
            var obj: [String: String] = [:]
            for (i, h) in headers.enumerated() {
                obj[h] = i < values.count ? values[i].trimmingCharacters(in: .whitespaces) : ""
            }
            return (obj["Title"]?.isEmpty == false) ? obj : nil
        }
    }

    /// Split one CSV line, respecting quoted fields (which may contain commas).
    static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        result.append(current)
        return result
    }
}
