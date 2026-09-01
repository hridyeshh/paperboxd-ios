import SwiftUI

/// Which bundled legal document a sheet is showing. `Identifiable` so it can
/// drive `.sheet(item:)` from the signup consent row.
enum LegalDocKind: String, Identifiable {
    case privacy, terms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return "Privacy Policy"
        case .terms:   return "Terms of Service"
        }
    }

    var text: String {
        switch self {
        case .privacy: return LegalText.privacyPolicy
        case .terms:   return LegalText.termsOfService
        }
    }
}

/// Full legal document rendered in a bottom sheet at signup. Content is bundled
/// (LegalText), so this works offline — no web dependency.
struct LegalSheetView: View {
    let kind: LegalDocKind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LegalMarkdownView(text: kind.text)
                    .padding(20)
            }
            .background(BK.paper.ignoresSafeArea())
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(BK.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BK.accent)
                }
            }
        }
        // Sheet inherits the window's forced dark appearance otherwise, which
        // would put a dark nav bar and status text over the paper document.
        .preferredColorScheme(.light)
    }
}

/// Minimal markdown renderer for the bundled legal text: headings, bullets,
/// paragraphs, and horizontal rules. Tables render as plain monospaced rows
/// (deliberate — the bundled-native path has no table layout engine).
struct LegalMarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, raw in
                lineView(raw)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func lineView(_ raw: String) -> some View {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty {
            Spacer().frame(height: 10)
        } else if line == "---" {
            Divider().overlay(BK.ink.opacity(0.18)).padding(.vertical, 8)
        } else if line.hasPrefix("### ") {
            Text(clean(String(line.dropFirst(4))))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(BK.ink)
                .padding(.top, 12).padding(.bottom, 2)
        } else if line.hasPrefix("## ") {
            Text(clean(String(line.dropFirst(3))))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(BK.ink)
                .padding(.top, 18).padding(.bottom, 4)
        } else if line.hasPrefix("# ") {
            Text(clean(String(line.dropFirst(2))))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(BK.ink)
                .padding(.bottom, 6)
        } else if line.hasPrefix("|") {
            if line.allSatisfy({ "|-: ".contains($0) }) {
                EmptyView()
            } else {
                Text(line)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(BK.muted)
                    .padding(.vertical, 1)
            }
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 8) {
                Text("•").foregroundStyle(BK.muted)
                Text(clean(String(line.dropFirst(2))))
                    .font(.system(size: 14))
                    .foregroundStyle(BK.ink)
            }
            .padding(.vertical, 2)
        } else {
            Text(clean(line))
                .font(.system(size: 14))
                .foregroundStyle(BK.ink)
                .padding(.vertical, 3)
        }
    }

    /// Strip inline markdown that the block renderer doesn't handle:
    /// `**bold**` markers and `[label](url)` → `label`.
    private func clean(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "**", with: "")
        if let re = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\([^)]+\)"#) {
            let range = NSRange(out.startIndex..., in: out)
            out = re.stringByReplacingMatches(in: out, range: range, withTemplate: "$1")
        }
        return out
    }
}
