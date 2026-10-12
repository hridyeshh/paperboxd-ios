import SwiftUI

/// Reading status for the share flow — drives the running head at the top of
/// the card ("JUST FINISHED", etc.).
enum ShareStatus: String, CaseIterable {
    case finished, reading, want, favourite

    var label: String {
        switch self {
        case .finished:  return "Just finished"
        case .reading:   return "Now reading"
        case .want:      return "Want to read"
        case .favourite: return "Favourite of 2026"
        }
    }
}

/// The shareable book card — port of the design prototype's share2/cards.jsx,
/// set in the Monthly Wrapped print kit: one ground colour, a running head,
/// hairline rules, the cover as a hard-edged printed board (typographic when
/// there is no image), a rating as a tabular number, and a footer of wordmark +
/// handle + scan code.
///
/// Laid out in the prototype's own units (450×800 story, 600×600 square, see
/// `canvas`) so every number below is copied straight from the JSX.
struct BookShareCardView: View {
    enum Format {
        case story, square

        /// Canvas for the thought card, which still draws at 540pt wide.
        var baseSize: CGSize {
            switch self {
            case .story:  return CGSize(width: 540, height: 960)
            case .square: return CGSize(width: 540, height: 540)
            }
        }

        /// scale → 1080px on the short edge.
        var renderScale: CGFloat { 1080.0 / baseSize.width }
    }

    /// The palette is a ground colour, not a filter.
    enum Ground: String, CaseIterable { case ink, paper, terra }

    /// Story emphases: the board as object, the reader's line set large, or stripped back.
    enum Layout: String, CaseIterable { case cover, quote, minimal }

    /// The prototype's artboard for a format; render at `1080 / width`.
    static func canvas(_ format: Format) -> CGSize {
        format == .story ? CGSize(width: 450, height: 800) : CGSize(width: 600, height: 600)
    }

    let title: String
    let author: String
    let year: String?
    var coverImage: UIImage? = nil
    let handle: String?          // rendered as-is, e.g. "@hridyesh"
    let rating: Int?             // 0–5; nil or 0 hides the number
    let note: String?            // the reader's line
    let statusLabel: String      // e.g. "Just finished"; empty hides it
    var ground: Ground = .ink
    var layout: Layout = .cover
    var showRating = true
    var showNote = true
    let format: Format

    // MARK: Palette

    private struct Palette {
        let bg, fg, dim, line, accent, board, boardFg, boardDim, boardBar: Color
    }

    private var p: Palette {
        switch ground {
        case .ink:
            return Palette(bg: PBW.inkDeep, fg: PBW.cream, dim: PBW.cream.opacity(0.58), line: PBW.cream.opacity(0.2),
                           accent: PBW.terra, board: Color(hex: "efe4d2"), boardFg: PBW.ink, boardDim: PBW.muted, boardBar: PBW.terra)
        case .paper:
            return Palette(bg: PBW.cream, fg: PBW.ink, dim: PBW.muted, line: PBW.ink.opacity(0.18),
                           accent: PBW.terraDeep, board: PBW.ink, boardFg: PBW.cream, boardDim: PBW.cream.opacity(0.6), boardBar: PBW.terra)
        case .terra:
            return Palette(bg: PBW.terraDeep, fg: PBW.cream, dim: PBW.cream.opacity(0.66), line: PBW.cream.opacity(0.28),
                           accent: PBW.amber, board: PBW.cream, boardFg: PBW.ink, boardDim: PBW.muted, boardBar: PBW.amber)
        }
    }

    // MARK: Content fitting

    private var noteText: String? {
        guard let t = note?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t.count > 600 ? String(t.prefix(599)) + "…" : t
    }

    /// A thought shared on its own has no book; the board row then stays out.
    private var hasBook: Bool { !title.isEmpty }

    private var ratingValue: Int? {
        guard showRating, let rating, rating > 0 else { return nil }
        return min(rating, 5)
    }

    /// Quote needs a line to set; without one the card falls back to cover.
    private var activeLayout: Layout {
        layout == .quote && noteText == nil ? .cover : layout
    }

    /// Long titles and long words step the display type down so nothing clips.
    private var titleScale: CGFloat {
        let n = title.count
        let longest = title.split(separator: " ").map(\.count).max() ?? n
        let byLength: CGFloat = n > 40 ? 0.62 : n > 26 ? 0.76 : n > 16 ? 0.88 : 1
        return max(0.5, min(byLength, 11 / CGFloat(max(longest, 1))))
    }

    /// Long lines step the display type down so the card never clips.
    private var quoteSize: CGFloat {
        let n = noteText?.count ?? 0
        let base: CGFloat = n > 420 ? 15 : n > 300 ? 17 : n > 220 ? 19 : n > 140 ? 22 : n > 80 ? 26 : 31
        return format == .square ? base * 0.86 : base
    }

    private var meta: String {
        guard let year, !year.isEmpty else { return author }
        return author.isEmpty ? year : "\(author) · \(year)"
    }

    // MARK: Body

    var body: some View {
        let size = Self.canvas(format)
        Group {
            if format == .square {
                if activeLayout == .quote { squareQuote } else { square }
            } else {
                switch activeLayout {
                case .cover:   storyCover
                case .quote:   storyQuote
                case .minimal: storyMinimal
                }
            }
        }
        .padding(format == .story ? 34 : 40)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(p.bg)
        .clipped()
    }

    // MARK: Story · cover

    private var storyCover: some View {
        VStack(alignment: .leading, spacing: 0) {
            head(brand: 30, mono: 9.5)
            rule.padding(.top, 18)
            board(width: 200)
                .padding(.leading, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            rule
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    titleText(42, lines: 3)
                    monoText(author, 10, tracking: 0.14).padding(.top, 12)
                    if let year, !year.isEmpty {
                        monoText("First published \(year)", 10, tracking: 0.14).padding(.top, 6)
                    }
                }
                Spacer(minLength: 0)
                if let ratingValue { rate(ratingValue, size: 38) }
            }
            .padding(.top, 20)
            if showNote, let noteText {
                bodyNote(noteText, lines: 3).padding(.top, 20)
            }
            foot(brand: 22, mono: 9.5, scan: 26).padding(.top, 26)
        }
    }

    // MARK: Story · quote

    private var storyQuote: some View {
        VStack(alignment: .leading, spacing: 0) {
            head(brand: 30, mono: 9.5)
            rule.padding(.top, 18)
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(p.accent).frame(width: 46, height: 4).padding(.bottom, 26)
                Text(noteText ?? "")
                    .font(PBW.display(quoteSize, .regular))
                    .lineSpacing(quoteSize * 0.16)
                    .foregroundStyle(p.fg)
                    .minimumScaleFactor(0.7)
                if let ratingValue { rate(ratingValue, size: 40).padding(.top, 30) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            rule
            if hasBook {
                HStack(alignment: .bottom, spacing: 18) {
                    board(width: 78)
                    VStack(alignment: .leading, spacing: 0) {
                        titleText(26, lines: 2)
                        monoText(meta, 9.5, tracking: 0.14).padding(.top, 10)
                    }
                    .padding(.bottom, 2)
                }
                .padding(.top, 20)
            }
            foot(brand: 22, mono: 9.5, scan: 26).padding(.top, 26)
        }
    }

    // MARK: Square · quote

    private var squareQuote: some View {
        VStack(alignment: .leading, spacing: 0) {
            head(brand: 28, mono: 10)
            rule.padding(.top, 16)
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(p.accent).frame(width: 46, height: 4).padding(.bottom, 20)
                Text(noteText ?? "")
                    .font(PBW.display(quoteSize, .regular))
                    .lineSpacing(quoteSize * 0.16)
                    .foregroundStyle(p.fg)
                    .minimumScaleFactor(0.7)
                if let ratingValue { rate(ratingValue, size: 34).padding(.top, 22) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            rule
            if hasBook {
                HStack(alignment: .bottom, spacing: 16) {
                    board(width: 60)
                    VStack(alignment: .leading, spacing: 0) {
                        titleText(22, lines: 2)
                        monoText(meta, 9.5, tracking: 0.14).padding(.top, 8)
                    }
                    .padding(.bottom, 2)
                }
                .padding(.top, 18)
            }
            foot(brand: 24, mono: 10, scan: 24).padding(.top, 22)
        }
    }

    // MARK: Story · minimal

    private var storyMinimal: some View {
        VStack(alignment: .leading, spacing: 0) {
            head(brand: 30, mono: 9.5)
            rule.padding(.top, 18)
            board(width: 222)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            rule
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    titleText(40, lines: 3)
                    monoText(meta, 10, tracking: 0.14).padding(.top, 12)
                }
                Spacer(minLength: 0)
                if let ratingValue { rate(ratingValue, size: 36) }
            }
            .padding(.top, 20)
            .padding(.bottom, 26)
            foot(brand: 22, mono: 9.5, scan: 26)
        }
    }

    // MARK: Square

    private var square: some View {
        VStack(alignment: .leading, spacing: 0) {
            head(brand: 28, mono: 10)
            rule.padding(.top, 16)
            HStack(alignment: .center, spacing: 34) {
                board(width: 168)
                VStack(alignment: .leading, spacing: 0) {
                    titleText(36, lines: 3)
                    monoText(meta, 10, tracking: 0.14).padding(.top, 12)
                    if let ratingValue { rate(ratingValue, size: 34).padding(.top, 20) }
                    if showNote, let noteText {
                        bodyNote(noteText, lines: 4).padding(.top, 20)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            foot(brand: 24, mono: 10, scan: 24)
        }
    }

    // MARK: - Pieces

    private var rule: some View {
        Rectangle().fill(p.line).frame(height: 1)
    }

    private func head(brand: CGFloat, mono: CGFloat) -> some View {
        HStack(spacing: 12) {
            Text("PaperBoxd")
                .font(PBW.script(brand))
                .foregroundStyle(p.fg)
            Spacer(minLength: 0)
            if !statusLabel.isEmpty {
                HStack(spacing: 8) {
                    Rectangle().fill(p.accent).frame(width: 7, height: 7)
                    Text(statusLabel.uppercased())
                        .font(PBW.mono(mono))
                        .tracking(mono * 0.16)
                        .foregroundStyle(p.fg)
                }
            }
        }
    }

    private func foot(brand: CGFloat, mono: CGFloat, scan: CGFloat) -> some View {
        VStack(spacing: 0) {
            rule
            HStack(spacing: 14) {
                Text("PaperBoxd")
                    .font(PBW.script(brand))
                    .foregroundStyle(p.fg)
                if let handle, !handle.isEmpty {
                    monoText(handle, mono, tracking: 0.14).lineLimit(1)
                }
                Spacer(minLength: 0)
                scanCode(height: scan)
            }
            .padding(.top, 15)
        }
    }

    private func titleText(_ size: CGFloat, lines: Int) -> some View {
        let s = size * titleScale
        return Text(title)
            .font(PBW.display(s, .semibold))
            .tracking(-0.025 * s)
            .foregroundStyle(p.fg)
            .lineLimit(lines)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func monoText(_ text: String, _ size: CGFloat, tracking: CGFloat) -> some View {
        Text(text.uppercased())
            .font(PBW.mono(size))
            .tracking(size * tracking)
            .foregroundStyle(p.dim)
    }

    private func bodyNote(_ text: String, lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            rule
            Text("“\(text)”")
                .font(PBW.sans(15.5))
                .lineSpacing(15.5 * 0.3)
                .foregroundStyle(p.fg)
                .lineLimit(lines)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)
        }
    }

    private func rate(_ r: Int, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(String(format: "%.1f", Double(r)))
                .font(PBW.sans(size, .bold))
                .tracking(-0.03 * size)
                .monospacedDigit()
                .foregroundStyle(p.accent)
            Text("/ 5")
                .font(PBW.mono(size * 0.3))
                .tracking(size * 0.03)
                .foregroundStyle(p.dim)
        }
        .fixedSize()
    }

    /// The cover as a printed board: the real cover, hard edges, an offset solid
    /// shadow. Without an image it is a uniform typographic board — accent rule
    /// on the spine, display title, mono author.
    private func board(width w: CGFloat) -> some View {
        let shadow = (w * 0.045).rounded()
        return Group {
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
            } else {
                typographicBoard(width: w)
            }
        }
        .frame(width: w, height: w * 1.5)
        .clipped()
        .background(Rectangle().fill(Color(hex: "120e0b").opacity(0.32)).offset(x: shadow, y: shadow))
    }

    private func typographicBoard(width w: CGFloat) -> some View {
        let t = w * 0.132 * titleScale
        let a = max(6.5, w * 0.052)
        return VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(PBW.display(t, .semibold))
                .tracking(-0.02 * t)
                .foregroundStyle(p.boardFg)
                .minimumScaleFactor(0.6)
            Text(author.uppercased())
                .font(PBW.mono(a))
                .tracking(a * 0.12)
                .foregroundStyle(p.boardDim)
                .lineLimit(2)
                .padding(.top, w * 0.055)
        }
        .padding(.leading, w * 0.05)
        .padding(w * 0.085)
        .frame(width: w, height: w * 1.5, alignment: .bottomLeading)
        .background(p.board)
        .overlay(alignment: .leading) {
            Rectangle().fill(p.boardBar).frame(width: max(3, w * 0.05))
        }
    }

    /// Deterministic scan-code bar heights (0…1), set in solid bars.
    private static let scanSeq: [CGFloat] = [0.5, 0.95, 0.35, 0.7, 1, 0.45, 0.8, 0.6, 0.3, 0.9, 0.5, 0.75, 0.4, 1, 0.55, 0.85, 0.35, 0.65, 0.95, 0.45, 0.7, 0.55, 0.9, 0.4, 0.8, 0.6]

    private func scanCode(height h: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 2.5) {
            ForEach(Self.scanSeq.indices, id: \.self) { i in
                Rectangle().fill(p.fg).frame(width: 3, height: max(4, (Self.scanSeq[i] * h).rounded()))
            }
        }
        .frame(height: h, alignment: .bottom)
    }
}
