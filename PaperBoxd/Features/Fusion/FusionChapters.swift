import SwiftUI

// The Fusion story. Port of the design prototype's fusion2/stories-a.jsx and
// stories-b.jsx, laid out against the 402pt grid the player scales. Pages the
// two shelves cannot fill honestly are skipped, not shown empty.

struct FusionActions {
    var toast: (String) -> Void = { _ in }
    var share: () -> Void = {}
    var explore: () -> Void = {}
    var next: () -> Void = {}
    var addToTBR: ([FusionBook]) -> Void = { _ in }
}

struct FusionChapter: Identifiable {
    let id: String
    let isDark: Bool
    let content: (FusionStory, _ number: Int, _ total: Int, FusionActions) -> AnyView

    static func all(for s: FusionStory) -> [FusionChapter] {
        var c: [FusionChapter] = [
            .init(id: "score", isDark: false) { s, n, of, _ in AnyView(ScorePage(s: s, n: n, of: of)) },
            .init(id: "numbers", isDark: false) { s, n, of, _ in AnyView(NumbersPage(s: s, n: n, of: of)) },
        ]
        if !s.sharedLoved.isEmpty {
            c.append(.init(id: "loved", isDark: false) { s, n, of, _ in AnyView(LovedPage(s: s, n: n, of: of)) })
        }
        if !s.agree.isEmpty {
            c.append(.init(id: "agree", isDark: false) { s, n, of, _ in AnyView(AgreePage(s: s, n: n, of: of)) })
        }
        if !s.splits.isEmpty || s.disagreement != nil {
            c.append(.init(id: "split", isDark: false) { s, n, of, _ in AnyView(SplitPage(s: s, n: n, of: of)) })
        }
        if !s.forYou.isEmpty {
            c.append(.init(id: "their-shelf", isDark: false) { AnyView(TheirShelfPage(s: $0, n: $1, of: $2, act: $3)) })
        }
        if !s.forThem.isEmpty {
            c.append(.init(id: "your-shelf", isDark: false) { s, n, of, _ in AnyView(YourShelfPage(s: s, n: n, of: of)) })
        }
        if s.pick != nil {
            c.append(.init(id: "pick", isDark: true) { AnyView(PickPage(s: $0, n: $1, of: $2, act: $3)) })
        }
        if s.wildcard != nil {
            c.append(.init(id: "wildcard", isDark: true) { AnyView(WildcardPage(s: $0, n: $1, of: $2, act: $3)) })
        }
        c.append(.init(id: "verdict", isDark: false) { AnyView(VerdictPage(s: $0, n: $1, of: $2, act: $3)) })
        return c
    }
}

private struct RunHead: View {
    let n: Int
    let of: Int
    var dark = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                FZLabel(text: "PaperBoxd Fusion", color: dark ? FZ.muteOnDark : FZ.grey)
                Spacer()
                FZNum(text: "\(String.fzIndex(n)) / \(String.fzIndex(of))", size: 10, color: dark ? FZ.muteOnDark : FZ.grey, bold: false)
            }
            FZRule(delay: 0.2, dark: dark)
        }
    }
}

// MARK: - 01 Score

private struct ScorePage: View {
    let s: FusionStory
    let n: Int, of: Int

    var body: some View {
        FZScreen {
            RunHead(n: n, of: of)
            Spacer()
            PBRise(delay: 0.3) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    PBCount(value: s.score, delay: 0.38, duration: 1.1, font: FZ.heading(176), color: FZ.ink)
                        .tracking(FZ.tracking(176))
                    Text("%").font(FZ.heading(56)).foregroundStyle(FZ.accent)
                }
            }
            PBFade(delay: 0.76) { FZLabel(text: "Taste Fusion", size: 12) }.padding(.top, 18)
            FZOverprint(a: s.me.first.uppercased(), b: s.them.first.uppercased(), size: 44, delay: 0.9)
                .padding(.top, 34)
            Spacer()
            FZRule(delay: 1.2)
            PBFade(delay: 1.28) { FZBody(text: s.scoreLine, size: 17, opacity: 1) }.padding(.top, 16)
            HStack(alignment: .top, spacing: 8) {
                stat("\(s.sharedCount)", "Shared", 1.38)
                stat("\(s.agreement)%", "Agree", 1.47)
                stat("\(s.sharedAuthors.count)", "Authors", 1.56)
            }
            .padding(.top, 20)
        }
    }

    private func stat(_ v: String, _ l: String, _ d: Double) -> some View {
        PBFade(delay: d) {
            VStack(alignment: .leading, spacing: 5) {
                FZNum(text: v, size: 22)
                FZLabel(text: l, size: 9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 02 Numbers

private struct NumbersPage: View {
    let s: FusionStory
    let n: Int, of: Int

    private var rest: [(Int, String)] {
        [
            (s.sharedAuthors.count, "Authors in common"),
            (s.sharedGenres.count, "Genres you both obsess over"),
            (s.waitingCount, "Books waiting for both of you"),
        ].filter { $0.0 > 0 }
    }

    var body: some View {
        FZScreen {
            RunHead(n: n, of: of)
            PBFade(delay: 0.26) { FZLabel(text: "What you share") }.padding(.top, 26)
            PBRise(delay: 0.36) {
                PBCount(value: s.lovedCount, delay: 0.44, duration: 1.2, font: FZ.heading(128), color: FZ.accent)
                    .tracking(FZ.tracking(128))
            }
            .padding(.top, 12)
            FZStack(lines: [s.lovedCount == 1 ? "book you" : "books you", "both loved"], size: 30, delay: 0.52)
                .padding(.top, 8)
            Spacer()
            ForEach(Array(rest.enumerated()), id: \.offset) { i, row in
                FZRule(delay: 0.76 + Double(i) * 0.12)
                PBSlide(delay: 0.82 + Double(i) * 0.12, distance: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        PBCount(value: row.0, delay: 0.88 + Double(i) * 0.12, duration: 0.9, font: FZ.heading(40), color: FZ.ink)
                            .frame(width: 74, alignment: .leading)
                        FZBody(text: row.1, size: 14)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 15)
                }
            }
            if !rest.isEmpty { FZRule(delay: 1.14) }
            if s.sharedCount > 0 {
                PBFade(delay: 1.22) {
                    FZBody(text: "You have both read \(s.sharedCount) of the same books, and agreed about \(s.agreement)% of them.", size: 13.5)
                }
                .padding(.top, 18)
            }
        }
    }
}

// MARK: - 03 Both loved

private struct LovedPage: View {
    let s: FusionStory
    let n: Int, of: Int

    private let columns = Array(repeating: GridItem(.fixed(100), spacing: 11, alignment: .topLeading), count: 3)

    var body: some View {
        FZScreen {
            RunHead(n: n, of: of)
            PBRise(delay: 0.28) {
                (Text("\(s.lovedCount)").foregroundColor(FZ.accent) + Text(s.lovedCount == 1 ? " book you" : " books you"))
                    .font(FZ.heading(38)).tracking(FZ.tracking(38)).foregroundStyle(FZ.ink)
            }
            .padding(.top, 24)
            PBRise(delay: 0.36) { FZHeading(text: "both loved", size: 38) }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(Array(s.sharedLoved.enumerated()), id: \.element.id) { i, b in
                    VStack(alignment: .leading, spacing: 7) {
                        FZCover(book: b, width: 100, owner: .both, delay: 0.48 + Double(i) * 0.085)
                        PBFade(delay: 0.76 + Double(i) * 0.085) {
                            HStack(spacing: 7) {
                                FZNum(text: "\(b.you ?? 0)", size: 12, color: FZ.accent)
                                FZNum(text: "/", size: 12, color: FZ.grey, bold: false)
                                FZNum(text: "\(b.them ?? 0)", size: 12)
                            }
                        }
                    }
                }
            }
            .padding(.top, 26)
            Spacer()
            FZRule(delay: 1.2)
            PBFade(delay: 1.26) {
                HStack(alignment: .bottom, spacing: 14) {
                    FZBody(text: footnote, size: 13.5)
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        FZLabel(text: "You", size: 9, color: FZ.accent)
                        FZLabel(text: s.them.first, size: 9)
                    }
                }
            }
            .padding(.top, 14)
        }
    }

    private var footnote: String {
        guard let top = s.sharedLoved.first, let y = top.you, let t = top.them else { return "" }
        if y == 5 && t == 5 { return "Both of you gave \(top.title) five stars." }
        return "You gave \(top.title) \(y). \(s.them.first) gave it \(t)."
    }
}

// MARK: - 04 Agree

private struct AgreePage: View {
    let s: FusionStory
    let n: Int, of: Int
    private let sizes: [CGFloat] = [34, 28, 23, 19]

    private var isAxes: Bool { s.agree.first?.kind == "axis" }

    var body: some View {
        FZScreen {
            RunHead(n: n, of: of)
            PBFade(delay: 0.26) { FZLabel(text: "Where you agree") }.padding(.top, 26)
            FZStack(lines: isAxes ? ["You want the same", "shape of book"] : ["You read the same", "kinds of book"], size: 34, delay: 0.34)
                .padding(.top, 12)
            VStack(spacing: 0) {
                ForEach(Array(s.agree.enumerated()), id: \.offset) { i, a in
                    FZRule(delay: 0.52 + Double(i) * 0.15)
                    PBSlide(delay: 0.58 + Double(i) * 0.15, distance: 20) {
                        HStack(alignment: .bottom, spacing: 12) {
                            FZHeading(text: a.phrase, size: sizes[min(i, sizes.count - 1)])
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 8) {
                                FZNum(text: "\(a.you)", size: 13, color: FZ.accent)
                                FZNum(text: "/", size: 13, color: FZ.grey, bold: false)
                                FZNum(text: "\(a.them)", size: 13)
                            }
                            .padding(.bottom, 3)
                        }
                        .padding(.vertical, 16)
                    }
                }
                FZRule(delay: 1.12)
            }
            .padding(.top, 30)
            Spacer()
            PBFade(delay: 1.2) {
                FZLabel(text: isAxes ? "\(s.agree.count) of nine taste axes · both confident" : "Share of each shelf, you / \(s.them.first)", size: 9)
            }
        }
    }
}

// MARK: - 05 Split

private struct SplitPage: View {
    let s: FusionStory
    let n: Int, of: Int

    var body: some View {
        FZScreen {
            RunHead(n: n, of: of)
            FZStack(lines: ["But you're not", "the same reader"], size: 36, delay: 0.28).padding(.top, 24)
            if !s.splits.isEmpty {
                HStack(spacing: 0) {
                    PBFade(delay: 0.5) { FZLabel(text: s.me.first, size: 9.5, color: FZ.accent) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PBFade(delay: 0.54) { FZLabel(text: s.them.first, size: 9.5) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                }
                .padding(.top, 26)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(s.splits.enumerated()), id: \.offset) { i, sp in
                        FZRule(delay: 0.6 + Double(i) * 0.15)
                        HStack(alignment: .top, spacing: 0) {
                            PBSlide(delay: 0.66 + Double(i) * 0.15, distance: 16) {
                                FZHeading(text: sp.you, size: 19, color: FZ.accent)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, 14)
                            Rectangle().fill(FZ.line).frame(width: 1)
                            PBSlide(delay: 0.66 + Double(i) * 0.15, from: .trailing, distance: 16) {
                                FZHeading(text: sp.them, size: 19)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 16)
                        }
                        .padding(.vertical, 14)
                        PBFade(delay: 0.76 + Double(i) * 0.15) { FZLabel(text: sp.label, size: 9) }
                            .padding(.bottom, 14)
                    }
                    FZRule(delay: 1.08, color: FZ.ink, height: 1.5)
                }
                .padding(.top, 10)
            }
            Spacer()
            if let d = s.disagreement, let y = d.you, let t = d.them {
                PBFade(delay: 1.16) {
                    VStack(alignment: .leading, spacing: 12) {
                        FZLabel(text: "Your biggest disagreement", size: 9)
                        FZHeading(text: d.title, size: 24)
                        HStack(spacing: 16) {
                            FZRate(who: s.me.first, n: y, color: FZ.accent, size: 15)
                            FZRate(who: s.them.first, n: t, size: 15)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 06 Their shelf

private struct TheirShelfPage: View {
    let s: FusionStory
    let n: Int, of: Int
    let act: FusionActions

    var body: some View {
        FZScreen {
            RunHead(n: n, of: of)
            PBRise(delay: 0.28) { FZHeading(text: "Books \(s.them.first) loves", size: 34) }.padding(.top, 24)
            PBRise(delay: 0.35) { FZHeading(text: "that you haven't read", size: 34, color: FZ.grey) }
            VStack(spacing: 0) {
                ForEach(Array(s.forYou.enumerated()), id: \.element.id) { i, b in
                    FZRule(delay: 0.48 + Double(i) * 0.17)
                    PBSlide(delay: 0.54 + Double(i) * 0.17, distance: 20) {
                        HStack(alignment: .top, spacing: 14) {
                            FZNum(text: .fzIndex(i + 1), size: 30, color: FZ.grey).frame(width: 34, alignment: .leading)
                            VStack(alignment: .leading, spacing: 0) {
                                FZHeading(text: b.title, size: 22)
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    FZLabel(text: b.author, size: 9)
                                    if let t = b.them { FZRate(who: s.them.first, n: t) }
                                }
                                .padding(.top, 8)
                                if let r = b.reason { FZBody(text: r, size: 13).padding(.top, 9) }
                                HStack(spacing: 12) {
                                    FZPill(title: "Add to TBR", compact: true, fullWidth: false) { act.addToTBR([b]) }
                                    if let m = b.match { FZLabel(text: m, size: 9, color: FZ.accent) }
                                }
                                .padding(.top, 11)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 16)
                    }
                }
                FZRule(delay: 1.02)
            }
            .padding(.top, 26)
            Spacer()
            PBFade(delay: 1.1) { FZLabel(text: "From \(s.them.first)'s shelf", size: 9) }
        }
    }
}

// MARK: - 07 Your shelf

private struct YourShelfPage: View {
    let s: FusionStory
    let n: Int, of: Int

    var body: some View {
        FZScreen {
            RunHead(n: n, of: of)
            PBRise(delay: 0.28) { FZHeading(text: "Books you should", size: 34) }.padding(.top, 24)
            PBRise(delay: 0.35) { FZHeading(text: "give \(s.them.first)", size: 34, color: FZ.accent) }
            HStack(spacing: 11) {
                ForEach(Array(s.forThem.enumerated()), id: \.element.id) { i, b in
                    FZCover(book: b, width: 100, owner: .you, delay: 0.48 + Double(i) * 0.11, rotation: i == 1 ? 0 : (i == 0 ? -1.5 : 1.5))
                }
            }
            .padding(.top, 28)
            VStack(spacing: 0) {
                ForEach(Array(s.forThem.enumerated()), id: \.element.id) { i, b in
                    FZRule(delay: 0.76 + Double(i) * 0.14)
                    PBSlide(delay: 0.82 + Double(i) * 0.14, distance: 16) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            FZNum(text: .fzIndex(i + 1), size: 11, color: FZ.accent).frame(width: 20, alignment: .leading)
                            VStack(alignment: .leading, spacing: 6) {
                                FZHeading(text: b.title, size: 17)
                                if let r = b.reason { FZBody(text: r, size: 12.5) }
                            }
                            Spacer(minLength: 0)
                            if let y = b.you { FZRate(who: "You", n: y, color: FZ.accent) }
                        }
                        .padding(.vertical, 13)
                    }
                }
                FZRule(delay: 1.22)
            }
            .padding(.top, 26)
            Spacer()
            PBFade(delay: 1.3) { FZLabel(text: "\(s.them.first) sees these in their Fusion too", size: 9) }
        }
    }
}

// MARK: - 08 The pick

private struct PickPage: View {
    let s: FusionStory
    let n: Int, of: Int
    let act: FusionActions

    var body: some View {
        if let p = s.pick {
            FZScreen(dark: true) {
                RunHead(n: n, of: of, dark: true)
                PBFade(delay: 0.26) { FZLabel(text: "Your Fusion found these", color: FZ.accent) }.padding(.top, 24)
                FZStack(lines: ["Neither of you", "has read this"], size: 32, color: FZ.bg, delay: 0.34).padding(.top, 12)
                HStack(alignment: .bottom, spacing: 18) {
                    FZCover(book: p.book, width: 116, owner: .both, dark: true, delay: 0.48)
                    VStack(alignment: .leading, spacing: 0) {
                        PBRise(delay: 0.62) { FZHeading(text: p.book.title, size: 34, color: FZ.bg) }
                        PBFade(delay: 0.72) { FZLabel(text: p.book.author, size: 9, color: FZ.bg.opacity(0.6)) }.padding(.top, 10)
                        PBFade(delay: 0.82) {
                            FZLabel(text: p.label, size: 9.5, color: FZ.accent)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .overlay(Rectangle().stroke(FZ.accent, lineWidth: 1))
                        }
                        .padding(.top, 14)
                    }
                    .padding(.bottom, 4)
                    Spacer(minLength: 0)
                }
                .padding(.top, 28)
                VStack(spacing: 0) {
                    ForEach(Array(p.reasons.enumerated()), id: \.offset) { i, r in
                        PBSlide(delay: 0.94 + Double(i) * 0.13, distance: 16) {
                            VStack(spacing: 0) {
                                Rectangle().fill(FZ.lineOnDark).frame(height: 1)
                                HStack(alignment: .top, spacing: 13) {
                                    FZNum(text: .fzIndex(i + 1), size: 10, color: r.who == "you" ? FZ.accent : FZ.bg.opacity(0.5))
                                        .frame(width: 18, alignment: .leading).padding(.top, 3)
                                    FZBody(text: r.text, size: 13, color: FZ.bg, opacity: 0.86)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 11)
                            }
                        }
                    }
                }
                .padding(.top, 28)
                Spacer()
                PBFade(delay: 1.5) {
                    HStack(spacing: 10) {
                        FZPill(title: s.also.isEmpty ? "Add to TBR" : "Add all \(1 + s.also.count)", solid: true, light: true) {
                            act.addToTBR([p.book] + s.also)
                        }
                        if !s.also.isEmpty {
                            VStack(alignment: .trailing, spacing: 4) {
                                ForEach(s.also) { FZLabel(text: $0.title, size: 9, color: FZ.muteOnDark).lineLimit(1) }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 09 Wildcard

private struct WildcardPage: View {
    let s: FusionStory
    let n: Int, of: Int
    let act: FusionActions

    var body: some View {
        if let w = s.wildcard {
            FZScreen(dark: true) {
                RunHead(n: n, of: of, dark: true)
                PBFade(delay: 0.26) { FZLabel(text: "One wildcard", color: FZ.accent) }.padding(.top, 26)
                Spacer()
                FZStack(lines: titleLines(w.book.title), size: 62, color: FZ.bg, delay: 0.38, step: 0.09)
                PBFade(delay: 0.64) {
                    HStack(alignment: .bottom, spacing: 20) {
                        VStack(alignment: .leading, spacing: 0) {
                            FZLabel(text: w.book.author, size: 9, color: FZ.bg.opacity(0.6))
                            ForEach(Array(w.reasons.enumerated()), id: \.offset) { i, r in
                                VStack(alignment: .leading, spacing: 11) {
                                    Rectangle().fill(FZ.lineOnDark).frame(height: 1)
                                    FZBody(text: r.text, size: 14, color: FZ.bg, opacity: 0.84)
                                }
                                .padding(.top, i == 0 ? 20 : 11)
                            }
                        }
                        Spacer(minLength: 0)
                        FZCover(book: w.book, width: 74, owner: .both, dark: true, delay: 0.9, rotation: -3)
                    }
                }
                .padding(.top, 16)
                Spacer()
                PBFade(delay: 1.2) {
                    HStack(spacing: 10) {
                        FZPill(title: "Take the risk", light: true) { act.addToTBR([w.book]) }
                        FZPill(title: "Not this time", light: true) { act.next() }
                    }
                }
            }
        }
    }

    /// Titles set as the image: two or three short lines, uppercase.
    private func titleLines(_ title: String) -> [String] {
        let words = title.uppercased().split(separator: " ").map(String.init)
        var lines: [String] = []
        var current = ""
        for word in words {
            if !current.isEmpty && current.count + word.count + 1 > 10 {
                lines.append(current)
                current = word
            } else {
                current = current.isEmpty ? word : current + " " + word
            }
        }
        if !current.isEmpty { lines.append(current) }
        return Array(lines.prefix(4))
    }
}

// MARK: - 10 Verdict

private struct VerdictPage: View {
    let s: FusionStory
    let n: Int, of: Int
    let act: FusionActions

    var body: some View {
        FZScreen {
            RunHead(n: n, of: of)
            Spacer()
            PBRise(delay: 0.3) {
                verdictText
                    .font(FZ.heading(44))
                    .tracking(FZ.tracking(44))
                    .foregroundStyle(FZ.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            FZRule(delay: 0.76).padding(.top, 26)
            PBFade(delay: 0.84) { FZBody(text: s.verdictSub, size: 15) }.padding(.top, 18)
            Spacer()
            PBFade(delay: 0.98) {
                HStack(spacing: 9) {
                    FZPill(title: "Explore your Fusion", solid: true) { act.explore() }
                    FZPill(title: "Share", fullWidth: false) { act.share() }
                }
            }
        }
    }

    /// The last word lands in the accent.
    private var verdictText: Text {
        let words = s.verdict.split(separator: " ").map(String.init)
        guard let last = words.last else { return Text("") }
        let head = words.dropLast().joined(separator: " ")
        return Text(head.isEmpty ? "" : head + " ") + Text(last).foregroundColor(FZ.accent)
    }
}
