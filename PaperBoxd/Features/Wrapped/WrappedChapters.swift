import SwiftUI

// The chapters of Monthly Wrapped. Port of the design prototype's
// wrapped/screens-a.jsx and wrapped/screens-b.jsx, laid out against the 402pt
// design grid that WrappedView scales to the device.

struct WrappedChapter: Identifiable {
    let id: String
    let label: String
    /// Light chapters are dark-on-light: the progress bar and share pill flip.
    let isLight: Bool
    let content: (Wrapped) -> AnyView

    /// The story skips chapters the month cannot fill — a reader who finished
    /// nothing gets no five-star page rather than an empty one.
    static func all(for w: Wrapped) -> [WrappedChapter] {
        var chapters: [WrappedChapter] = [
            WrappedChapter(id: "cover", label: "Cover", isLight: false) { AnyView(CoverChapter(w: $0)) },
            WrappedChapter(id: "pages", label: "Pages", isLight: false) { AnyView(PagesChapter(w: $0)) },
        ]
        if !w.books.isEmpty {
            chapters.append(WrappedChapter(id: "books", label: "Top books", isLight: true) { AnyView(BooksChapter(w: $0)) })
        }
        if !w.authors.isEmpty {
            chapters.append(WrappedChapter(id: "authors", label: "Authors", isLight: false) { AnyView(AuthorsChapter(w: $0)) })
        }
        if !w.genres.isEmpty {
            chapters.append(WrappedChapter(id: "genres", label: "Genres", isLight: true) { AnyView(GenresChapter(w: $0)) })
        }
        chapters.append(WrappedChapter(id: "rhythm", label: "Rhythm", isLight: false) { AnyView(RhythmChapter(w: $0)) })
        if w.streak.days > 0 {
            chapters.append(WrappedChapter(id: "streak", label: "Streak", isLight: false) { AnyView(StreakChapter(w: $0)) })
        }
        if w.topRated != nil {
            chapters.append(WrappedChapter(id: "top-rated", label: "Best book", isLight: true) { AnyView(TopRatedChapter(w: $0)) })
        }
        if w.abandoned != nil {
            chapters.append(WrappedChapter(id: "abandoned", label: "Abandoned", isLight: false) { AnyView(AbandonedChapter(w: $0)) })
        }
        chapters.append(contentsOf: [
            WrappedChapter(id: "rank", label: "Rank", isLight: true) { AnyView(RankChapter(w: $0)) },
            WrappedChapter(id: "type", label: "Your type", isLight: false) { AnyView(ArchetypeChapter(w: $0)) },
            WrappedChapter(id: "dare", label: "The dare", isLight: true) { AnyView(DareChapter(w: $0)) },
            WrappedChapter(id: "card", label: "The card", isLight: false) { AnyView(CardChapter(w: $0)) },
            WrappedChapter(id: "outro", label: "Outro", isLight: false) { AnyView(OutroChapter(w: $0)) },
        ])
        return chapters
    }
}

// MARK: - 01 Cover

private struct CoverChapter: View {
    let w: Wrapped

    var body: some View {
        ZStack(alignment: .topLeading) {
            PBW.ink.ignoresSafeArea()
            PBStamp(delay: 0.08, duration: 0.62) {
                Circle().fill(PBW.terra).frame(width: 268, height: 268)
            }
            .offset(x: -70, y: 168)
            PBStamp(delay: 0.24, duration: 0.62) {
                Circle().fill(PBW.amber).frame(width: 152, height: 152)
            }
            .offset(x: 284, y: 372)

            VStack(alignment: .leading, spacing: 0) {
                PBFade {
                    Text("PaperBoxd").font(PBW.script(34)).foregroundStyle(PBW.cream)
                }
                PBKicker(text: "Monthly Wrapped", delay: 0.16).padding(.top, 6)
                Spacer()
                PBRise(delay: 0.42) {
                    Text(w.month.uppercased())
                        .font(PBW.poster(72))
                        .kerning(-2)
                        .foregroundStyle(PBW.cream)
                }
                PBFade(delay: 0.62) {
                    Text(w.year).font(PBW.mono(15)).tracking(6.3).foregroundStyle(PBW.amber)
                }
                .padding(.top, 14)
                PBRule(delay: 0.76, color: PBW.cream.opacity(0.35), height: 1.5).padding(.top, 22)
                PBFade(delay: 0.86) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(coverLine)
                            .font(PBW.displayItalic(19))
                            .foregroundStyle(PBW.cream)
                        Text(w.reader.handle.uppercased())
                            .font(PBW.mono(11)).tracking(1.5)
                            .foregroundStyle(PBW.muted)
                    }
                }
                .padding(.top, 16)
            }
            .padding(.top, 76).padding(.horizontal, 30).padding(.bottom, 112)
        }
        .clipped()
    }

    private var coverLine: String {
        w.totals.books > 0
            ? "\(w.totals.books) books. One very specific mood."
            : "\(w.totals.pages.formatted()) pages. One very specific mood."
    }
}

// MARK: - 02 Pages

private struct PagesChapter: View {
    let w: Wrapped

    var body: some View {
        WrappedScreen {
            PBKicker(text: "You turned")
            PBRise(delay: 0.18) {
                PBCount(value: w.totals.pages, delay: 0.26, duration: 1.6, font: PBW.poster(92), color: PBW.amber)
            }
            .padding(.top, 14)
            PBRise(delay: 0.32) {
                Text("pages").font(PBW.poster(44)).foregroundStyle(PBW.cream)
            }

            // The stack of set lines — a page of type, abstracted.
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<26, id: \.self) { i in
                    PBGrow(delay: 0.52 + Double(i) * 0.034, duration: 0.62) {
                        Rectangle()
                            .fill(i % 5 == 4 ? PBW.terra : PBW.cream.opacity(0.3))
                            .frame(height: 3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .scaleEffect(x: lineWidth(i), anchor: .leading)
                    }
                }
            }
            .padding(.top, 34)

            Spacer()
            PBRule(delay: 1.5, color: PBW.cream.opacity(0.28), height: 1).padding(.bottom, 18)
            HStack(alignment: .top, spacing: 30) {
                stat("Hours", "\(w.totals.estimatedHours)h \(w.totals.estimatedMinutes)m", delay: 1.56)
                stat("Sittings", "\(w.totals.sessions)", delay: 1.67)
                stat("Biggest day", "\(w.totals.biggestDayPages)p", delay: 1.78)
            }
        }
    }

    private func lineWidth(_ i: Int) -> CGFloat {
        CGFloat(34 + ((i * 37) % 66)) / 100
    }

    private func stat(_ label: String, _ value: String, delay: Double) -> some View {
        PBFade(delay: delay) {
            VStack(alignment: .leading, spacing: 5) {
                Text(label.uppercased()).font(PBW.mono(9.5)).tracking(1.5).foregroundStyle(PBW.muted)
                Text(value).font(PBW.display(24)).foregroundStyle(PBW.cream)
            }
        }
    }
}

// MARK: - 03 Top books

private struct BooksChapter: View {
    let w: Wrapped

    var body: some View {
        WrappedScreen(background: PBW.cream, foreground: PBW.ink) {
            PBKicker(text: w.books.count >= 5 ? "Your top five" : "What you read", color: PBW.terraDeep)
            PBRise(delay: 0.14) {
                Text("The books").font(PBW.display(40)).kerning(-1).foregroundStyle(PBW.ink)
            }
            .padding(.top, 10)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(w.books.enumerated()), id: \.element.id) { i, book in
                    PBSlide(delay: 0.34 + Double(i) * 0.13, from: .leading, distance: 26) {
                        HStack(alignment: .center, spacing: 14) {
                            Text(String(format: "%02d", i + 1))
                                .font(PBW.mono(11))
                                .foregroundStyle(i == 0 ? PBW.terra : PBW.ink.opacity(0.4))
                                .frame(width: 20, alignment: .leading)
                            ZStack(alignment: .leading) {
                                Rectangle().fill(PBWPalette.spine(i))
                                Rectangle().fill(.black.opacity(0.25)).frame(width: 1).offset(x: 2)
                            }
                            .frame(width: 26, height: 39)
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 3)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(book.title)
                                    .font(PBW.display(i == 0 ? 21 : 17))
                                    .foregroundStyle(PBW.ink)
                                    .lineLimit(2)
                                Text(book.author)
                                    .font(PBW.sans(12))
                                    .foregroundStyle(PBW.ink.opacity(0.52))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(book.pages)p").font(PBW.mono(10.5)).foregroundStyle(PBW.ink.opacity(0.45))
                                Text("\(book.days)d").font(PBW.mono(10.5)).foregroundStyle(PBW.ink.opacity(0.3))
                            }
                        }
                        .padding(.vertical, 13)
                    }
                    if i < w.books.count - 1 {
                        PBGrow(delay: 0.42 + Double(i) * 0.13, duration: 0.5) {
                            Rectangle().fill(PBW.ink.opacity(0.12)).frame(height: 1)
                        }
                    }
                }
            }
            .padding(.top, 26)

            Spacer()
            if let top = w.books.first {
                PBFade(delay: 1.1) {
                    Text("You spent the most of the month with \(top.title) — \(top.pages) pages across \(top.days) \(top.days == 1 ? "day" : "days").")
                        .font(PBW.displayItalic(15.5))
                        .foregroundStyle(PBW.ink.opacity(0.62))
                }
            }
        }
    }
}

// MARK: - 04 Authors

private struct AuthorsChapter: View {
    let w: Wrapped

    var body: some View {
        WrappedScreen {
            PBKicker(text: "Most read author")
            if let top = w.authors.first {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(top.name.split(separator: " ").enumerated()), id: \.offset) { i, word in
                        PBRise(delay: 0.2 + Double(i) * 0.11) {
                            Text(String(word))
                                .font(PBW.display(46))
                                .kerning(-1.3)
                                .foregroundStyle(PBW.amber)
                        }
                    }
                }
                .padding(.top, 16)

                PBFade(delay: 0.52) {
                    HStack(alignment: .firstTextBaseline, spacing: 22) {
                        countPair(top.books, "BOOKS")
                        countPair(top.pages, "PAGES")
                    }
                }
                .padding(.top, 16)

                if let note = top.note {
                    PBFade(delay: 0.66) {
                        Text(note.uppercased())
                            .font(PBW.mono(10)).tracking(1.2)
                            .foregroundStyle(PBW.terra)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .overlay(Rectangle().stroke(PBW.terra, lineWidth: 1))
                    }
                    .padding(.top, 14)
                }
            }

            PBRule(delay: 0.8, color: PBW.cream.opacity(0.25), height: 1)
                .padding(.top, 30).padding(.bottom, 4)

            ForEach(Array(w.authors.dropFirst().enumerated()), id: \.element.id) { i, author in
                PBSlide(delay: 0.88 + Double(i) * 0.11, from: .trailing, distance: 22) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(String(format: "%02d", i + 2))
                            .font(PBW.mono(10)).foregroundStyle(PBW.muted).frame(width: 18, alignment: .leading)
                        Text(author.name).font(PBW.display(19)).foregroundStyle(PBW.cream).lineLimit(1)
                        Spacer(minLength: 6)
                        Text("\(author.pages)p").font(PBW.mono(10.5)).foregroundStyle(PBW.muted)
                    }
                    .padding(.vertical, 11)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(PBW.cream.opacity(0.1)).frame(height: 1)
                    }
                }
            }
            Spacer()
        }
    }

    private func countPair(_ n: Int, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text("\(n)").font(PBW.poster(32)).foregroundStyle(PBW.cream)
            Text(label).font(PBW.mono(10)).tracking(1.4).foregroundStyle(PBW.muted)
        }
    }
}

// MARK: - 05 Genres

private struct GenresChapter: View {
    let w: Wrapped

    var body: some View {
        WrappedScreen(background: PBW.terra, foreground: PBW.ink) {
            PBKicker(text: "What you reached for", color: PBW.ink.opacity(0.6))
            PBRise(delay: 0.14) {
                Text("Your genres").font(PBW.display(40)).kerning(-1).foregroundStyle(PBW.ink)
            }
            .padding(.top, 10)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(w.genres.enumerated()), id: \.element.id) { i, genre in
                    HStack(spacing: 0) {
                        PBGrow(delay: 0.38 + Double(i) * 0.14, duration: 0.76) {
                            Rectangle()
                                .fill(PBWPalette.genre(i))
                                .frame(width: max(80, CGFloat(genre.pct) * 1.34 / 100 * 342))
                        }
                        PBFade(delay: 0.62 + Double(i) * 0.14) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(genre.name)
                                    .font(PBW.sans(13.5, .semibold))
                                    .foregroundStyle(PBW.ink)
                                    .lineLimit(2)
                                Text("\(genre.pct)%")
                                    .font(PBW.mono(10.5))
                                    .foregroundStyle(PBW.ink.opacity(0.6))
                            }
                            .padding(.leading, 12)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(height: max(44, CGFloat(genre.pct + 13) * 2.4))
                }
            }
            .padding(.vertical, 24)

            Spacer()
            if let top = w.genres.first {
                PBFade(delay: 1.24) {
                    Text("\(top.pct)% of everything you read this month was \(top.name.lowercased()).")
                        .font(PBW.displayItalic(16))
                        .foregroundStyle(PBW.ink.opacity(0.78))
                }
            }
        }
    }
}

// MARK: - 06 Rhythm

private struct RhythmChapter: View {
    let w: Wrapped

    var body: some View {
        WrappedScreen {
            PBKicker(text: "Your reading rhythm")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(w.rhythm.label.split(separator: " ").enumerated()), id: \.offset) { i, word in
                    PBRise(delay: 0.18 + Double(i) * 0.11) {
                        Text(String(word).uppercased())
                            .font(PBW.poster(60))
                            .kerning(-1.8)
                            .foregroundStyle(i == 0 ? PBW.cream : PBW.amber)
                    }
                }
            }
            .padding(.top, 12)

            PBFade(delay: 0.52) {
                Text(w.rhythm.line)
                    .font(PBW.displayItalic(17))
                    .foregroundStyle(PBW.cream.opacity(0.8))
            }
            .padding(.top, 16)

            Spacer()
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(Array(w.rhythm.hours.enumerated()), id: \.offset) { hour, value in
                    PBGrow(delay: 0.7 + Double(hour) * 0.032, duration: 0.64, vertical: true) {
                        Rectangle()
                            .fill(hour >= 22 || hour <= 1 ? PBW.amber : PBW.cream.opacity(0.34))
                            .frame(height: max(3, CGFloat(value) / 100 * 168))
                    }
                }
            }
            .frame(height: 168, alignment: .bottom)
            .padding(.bottom, 10)

            PBFade(delay: 1.56) {
                HStack {
                    ForEach(["12A", "6A", "12P", "6P", "11P"], id: \.self) { label in
                        Text(label).font(PBW.mono(9)).tracking(0.9).foregroundStyle(PBW.muted)
                        if label != "11P" { Spacer() }
                    }
                }
                .padding(.top, 7)
                .overlay(alignment: .top) {
                    Rectangle().fill(PBW.cream.opacity(0.16)).frame(height: 1)
                }
            }

            PBFade(delay: 1.68) {
                HStack(alignment: .top, spacing: 26) {
                    labelled("PEAK", w.rhythm.peak, color: PBW.amber)
                    labelled("AFTER MIDNIGHT", "\(w.rhythm.pctAfterMidnight)%", color: PBW.cream)
                }
            }
            .padding(.top, 18)
        }
    }

    private func labelled(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(PBW.mono(9.5)).tracking(1.5).foregroundStyle(PBW.muted)
            Text(value).font(PBW.display(20)).foregroundStyle(color)
        }
    }
}

// MARK: - 07 Streak

private struct StreakChapter: View {
    let w: Wrapped

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        WrappedScreen {
            PBKicker(text: "Longest streak")
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                PBRise(delay: 0.18) {
                    PBCount(value: w.streak.days, delay: 0.24, duration: 1.1, font: PBW.poster(96), color: PBW.amber)
                }
                PBRise(delay: 0.34) {
                    Text("days").font(PBW.poster(34)).foregroundStyle(PBW.cream)
                }
            }
            .padding(.top, 12)

            PBFade(delay: 0.56) {
                Text("\(w.streak.start) to \(w.streak.end).\(w.streak.broke.isEmpty ? "" : " Then \(w.streak.broke) happened.")")
                    .font(PBW.displayItalic(16.5))
                    .foregroundStyle(PBW.cream.opacity(0.78))
            }
            .padding(.top, 12)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(w.streak.calendar.enumerated()), id: \.offset) { i, pages in
                    PBStamp(delay: 0.82 + Double(i) * 0.026, duration: 0.34) {
                        dayCell(index: i, pages: pages)
                    }
                }
            }
            .padding(.top, 30)

            Spacer()
            PBFade(delay: 1.7) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOUR RECORD").font(PBW.mono(9.5)).tracking(1.5).foregroundStyle(PBW.muted)
                        Text("\(w.streak.longestEver) days").font(PBW.display(21)).foregroundStyle(PBW.cream)
                    }
                    Spacer()
                    Text(recordGap).font(PBW.mono(10)).tracking(1).foregroundStyle(PBW.terra)
                }
                .padding(.top, 14)
                .overlay(alignment: .top) {
                    Rectangle().fill(PBW.cream.opacity(0.16)).frame(height: 1)
                }
            }
        }
    }

    private var recordGap: String {
        let gap = w.streak.longestEver - w.streak.days
        return gap > 0 ? "\(gap) SHORT" : "YOUR BEST YET"
    }

    @ViewBuilder
    private func dayCell(index: Int, pages: Int) -> some View {
        let broke = index == w.streak.brokeIndex
        let inStreak = w.streak.isInStreak(index)
        let peak = max(w.streak.calendar.max() ?? 1, 1)

        ZStack {
            if broke {
                Rectangle().stroke(PBW.terra, lineWidth: 1.5)
                Text("×").font(PBW.mono(13)).foregroundStyle(PBW.terra)
            } else {
                Rectangle()
                    .fill(inStreak ? PBW.amber : PBW.cream.opacity(0.13))
                    .opacity(inStreak ? max(0.42, Double(pages) / Double(peak)) : 1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - 08 The month's best book

private struct TopRatedChapter: View {
    let w: Wrapped

    var body: some View {
        WrappedScreen(background: PBW.cream, foreground: PBW.ink) {
            if let f = w.topRated {
                PBKicker(text: f.rating >= 5 ? "The only five star" : "The best of the month", color: PBW.terraDeep)
                HStack(alignment: .top, spacing: 18) {
                    PBBookBlock(
                        title: f.title, author: f.author,
                        spine: PBWPalette.spine(1), accent: Color(hex: "e9e2cf"),
                        width: 104, delay: 0.26, rotation: -3
                    )
                    VStack(alignment: .leading, spacing: 0) {
                        PBRise(delay: 0.42) {
                            Text(f.title).font(PBW.display(27)).kerning(-0.5).foregroundStyle(PBW.ink)
                        }
                        PBFade(delay: 0.54) {
                            Text(f.author).font(PBW.sans(13)).foregroundStyle(PBW.ink.opacity(0.55))
                        }
                        .padding(.top, 6)
                        HStack(spacing: 4) {
                            ForEach(0..<Int(f.rating.rounded()), id: \.self) { i in
                                PBStamp(delay: 0.7 + Double(i) * 0.09, duration: 0.3) {
                                    Text("★").font(.system(size: 17)).foregroundStyle(PBW.terra)
                                }
                            }
                        }
                        .padding(.top, 12)
                        PBFade(delay: 1.18) {
                            Text(f.date.uppercased())
                                .font(PBW.mono(10)).tracking(1.2)
                                .foregroundStyle(PBW.ink.opacity(0.45))
                        }
                        .padding(.top, 12)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 20)

                Spacer()
                PBRule(delay: 1.28, color: PBW.ink.opacity(0.2), height: 1).padding(.bottom, 20)
                PBFade(delay: 1.36) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(f.review.isEmpty ? "No review — some books do not need one." : "“\(f.review)”")
                            .font(PBW.displayItalic(20))
                            .foregroundStyle(PBW.ink)
                        Text("YOUR REVIEW · \(w.reader.handle.uppercased())")
                            .font(PBW.mono(10)).tracking(1.4)
                            .foregroundStyle(PBW.ink.opacity(0.45))
                    }
                }
                Spacer().frame(height: 24)
            }
        }
    }
}

// MARK: - 09 The one left unfinished

private struct AbandonedChapter: View {
    let w: Wrapped

    var body: some View {
        WrappedScreen {
            if let a = w.abandoned {
                PBKicker(text: "Left unfinished", color: PBW.terra)
                HStack {
                    Spacer()
                    ZStack(alignment: .topTrailing) {
                        PBBookBlock(
                            title: a.title, author: a.author,
                            spine: PBWPalette.spine(5), accent: Color(hex: "efe6f2"),
                            width: 128, delay: 0.24, rotation: 4
                        )
                        // The bookmark still sitting in it.
                        PBSlide(delay: 0.72, duration: 0.62, from: .top, distance: 40) {
                            Rectangle()
                                .fill(PBW.terra)
                                .frame(width: 16, height: 74)
                                .rotationEffect(.degrees(4))
                                .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                        }
                        .offset(x: -20, y: -18)
                    }
                    Spacer()
                }
                .padding(.top, 24)

                PBFade(delay: 0.9) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("PAGE \(a.page)").font(PBW.mono(10)).tracking(1.2).foregroundStyle(PBW.muted)
                            Spacer()
                            Text("\(a.of) TOTAL").font(PBW.mono(10)).tracking(1.2).foregroundStyle(PBW.muted)
                        }
                        ZStack(alignment: .leading) {
                            Rectangle().fill(PBW.cream.opacity(0.16)).frame(height: 5)
                            PBGrow(delay: 1.02, duration: 0.9) {
                                Rectangle()
                                    .fill(PBW.terra)
                                    .frame(width: 342 * CGFloat(a.pctRead) / 100, height: 5)
                            }
                        }
                        Text("\(a.pctRead)% IN").font(PBW.mono(10)).tracking(1.2).foregroundStyle(PBW.terra)
                    }
                }
                .padding(.top, 26)

                PBFade(delay: 1.3) {
                    Text(a.roast).font(PBW.displayItalic(21)).foregroundStyle(PBW.cream)
                }
                .padding(.top, 28)

                Spacer()
                PBFade(delay: 1.56) {
                    Text("STARTED \(a.started.uppercased()) · LAST OPENED \(a.lastOpened.uppercased())")
                        .font(PBW.mono(10)).tracking(1.2)
                        .foregroundStyle(PBW.muted)
                        .padding(.top, 13)
                        .overlay(alignment: .top) {
                            Rectangle().fill(PBW.cream.opacity(0.16)).frame(height: 1)
                        }
                }
            }
        }
    }
}

// MARK: - 10 Rank

private struct RankChapter: View {
    let w: Wrapped

    /// A reader distribution: most people finish a little, a few finish a lot.
    private var curve: [Double] {
        (0..<30).map { i in exp(-pow((Double(i) - 9) / 6.4, 2)) * 100 }
    }

    private var youAt: Int {
        // Position on the curve from the percentile: top 1% sits at the tail.
        let fromRight = Int((Double(w.rank.percentile) / 100 * 30).rounded())
        return max(0, min(29, 29 - fromRight))
    }

    var body: some View {
        WrappedScreen(background: PBW.amber, foreground: PBW.ink) {
            PBKicker(text: "Against everybody else", color: PBW.ink.opacity(0.6))
            PBRise(delay: 0.18) {
                Text("TOP \(w.rank.percentile)%")
                    .font(PBW.poster(88))
                    .kerning(-3)
                    .foregroundStyle(PBW.ink)
            }
            .padding(.top, 14)
            PBFade(delay: 0.52) {
                Text(w.rank.line).font(PBW.displayItalic(18)).foregroundStyle(PBW.ink.opacity(0.8))
            }
            .padding(.top, 16)

            Spacer()
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(curve.enumerated()), id: \.offset) { i, value in
                        PBGrow(delay: 0.76 + Double(i) * 0.026, duration: 0.6, vertical: true) {
                            Rectangle()
                                .fill(i >= youAt ? PBW.ink : PBW.ink.opacity(0.26))
                                .frame(height: max(4, value / 100 * 150))
                        }
                    }
                }
                .frame(height: 150, alignment: .bottom)

                PBFade(delay: 1.62) {
                    HStack(alignment: .top, spacing: 12) {
                        Text("YOU\nARE\nHERE")
                            .font(PBW.mono(10)).tracking(1)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(PBW.ink)
                        Rectangle().fill(PBW.ink).frame(width: 1.5, height: 150)
                    }
                }
                .offset(x: -8)
            }

            PBFade(delay: 1.74) {
                HStack {
                    Text("0 PAGES").font(PBW.mono(9.5)).tracking(1).foregroundStyle(PBW.ink.opacity(0.6))
                    Spacer()
                    Text("OF \(w.rank.readers.formatted()) READERS").font(PBW.mono(9.5)).tracking(1).foregroundStyle(PBW.ink.opacity(0.6))
                }
                .padding(.top, 9)
                .overlay(alignment: .top) {
                    Rectangle().fill(PBW.ink.opacity(0.3)).frame(height: 1)
                }
            }
            .padding(.top, 6)
        }
    }
}

// MARK: - 11 Reading personality

private struct ArchetypeChapter: View {
    let w: Wrapped

    var body: some View {
        ZStack(alignment: .topLeading) {
            PBW.ink.ignoresSafeArea()
            PBStamp(delay: 0.3, duration: 0.9) {
                Circle()
                    .stroke(PBW.terra.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 300, height: 300)
            }
            .offset(x: 198, y: 430)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        PBKicker(text: w.archetype.kicker, color: PBW.terra)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(w.archetype.name.split(separator: " ").enumerated()), id: \.offset) { i, word in
                                PBRise(delay: 0.22 + Double(i) * 0.13) {
                                    Text(String(word))
                                        .font(i == 0 ? PBW.displayItalic(34) : PBW.display(48))
                                        .kerning(-1.5)
                                        .foregroundStyle(i == 1 ? PBW.amber : PBW.cream)
                                }
                            }
                        }
                        .padding(.top, 16)
                    }
                    Spacer(minLength: 8)
                    PBStamp(delay: 0.76, rotation: -7) {
                        VStack(spacing: 2) {
                            Text(w.archetype.statLabel.uppercased())
                                .font(PBW.mono(7.5)).tracking(1)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            Text(w.archetype.statValue).font(PBW.poster(20))
                        }
                        .foregroundStyle(PBW.terra)
                        .padding(6)
                        .frame(width: 78, height: 78)
                        .overlay(Circle().stroke(PBW.terra, lineWidth: 1.5))
                    }
                    .padding(.top, 8)
                }

                PBRule(delay: 0.9, color: PBW.terra, height: 1.5)
                    .padding(.top, 26).padding(.bottom, 20)

                PBFade(delay: 0.98) {
                    Text(w.archetype.definition)
                        .font(PBW.displayItalic(18.5))
                        .foregroundStyle(PBW.cream.opacity(0.88))
                }

                WrappedFlowRow(spacing: 7) {
                    ForEach(Array(w.archetype.traits.enumerated()), id: \.element) { i, trait in
                        PBFade(delay: 1.22 + Double(i) * 0.11) {
                            Text(trait.uppercased())
                                .font(PBW.mono(9)).tracking(0.6)
                                .foregroundStyle(PBW.cream)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .overlay(Rectangle().stroke(PBW.cream.opacity(0.28), lineWidth: 1))
                        }
                    }
                }
                .padding(.top, 24)

                Spacer()
                PBFade(delay: 1.7) {
                    HStack(spacing: 5) {
                        Text("PAIRS WELL WITH").font(PBW.mono(10)).tracking(1.4).foregroundStyle(PBW.muted)
                        Text(w.archetype.pairs.uppercased()).font(PBW.mono(10)).tracking(1.4).foregroundStyle(PBW.amber)
                    }
                    .padding(.top, 13)
                    .overlay(alignment: .top) {
                        Rectangle().fill(PBW.cream.opacity(0.16)).frame(height: 1)
                    }
                }
            }
            .padding(.top, 76).padding(.horizontal, 30).padding(.bottom, 112)
        }
        .clipped()
    }
}

// MARK: - 12 The dare

private struct DareChapter: View {
    let w: Wrapped

    var body: some View {
        WrappedScreen(background: PBW.cream, foreground: PBW.ink) {
            PBFade(delay: 0.08) {
                Text(w.dare.tag)
                    .font(PBW.mono(10)).tracking(1.6)
                    .foregroundStyle(PBW.cream)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(PBW.ink)
            }

            VStack(alignment: .leading, spacing: 0) {
                let words = w.dare.title.split(separator: " ")
                ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                    PBRise(delay: 0.28 + Double(i) * 0.11) {
                        Text(String(word))
                            .font(i == words.count - 1 ? PBW.displayItalic(42) : PBW.display(42))
                            .kerning(-1.3)
                            .foregroundStyle(i == words.count - 1 ? PBW.terra : PBW.ink)
                    }
                }
            }
            .padding(.top, 28)

            PBRule(delay: 0.86, color: PBW.ink.opacity(0.25), height: 1)
                .padding(.top, 30).padding(.bottom, 22)

            PBFade(delay: 0.94) {
                Text(w.dare.body).font(PBW.sans(15.5)).foregroundStyle(PBW.ink.opacity(0.72)).lineSpacing(6)
            }

            Spacer()
            PBFade(delay: 1.2) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(w.nextMonth.uppercased()) TARGET")
                            .font(PBW.mono(9.5)).tracking(1.5)
                            .foregroundStyle(PBW.ink.opacity(0.5))
                        Text(w.dare.target).font(PBW.display(23)).kerning(-0.5).foregroundStyle(PBW.ink)
                    }
                    Spacer()
                    Text("→").font(PBW.poster(30)).foregroundStyle(PBW.terra)
                }
                .padding(.horizontal, 20).padding(.vertical, 18)
                .overlay(Rectangle().stroke(PBW.ink, lineWidth: 1.5))
            }
        }
    }
}

// MARK: - 13 The card

private struct CardChapter: View {
    let w: Wrapped

    var body: some View {
        WrappedScreen(topPadding: 72) {
            PBKicker(text: "Your \(w.month), in one card")
            HStack {
                Spacer()
                PBStamp(delay: 0.22, duration: 0.64) {
                    WrappedRecapCard(w: w)
                        .shadow(color: .black.opacity(0.5), radius: 30, y: 26)
                }
                Spacer()
            }
            .padding(.top, 16)
            Spacer()
        }
    }
}

// MARK: - 14 Outro

private struct OutroChapter: View {
    let w: Wrapped

    var body: some View {
        ZStack {
            PBW.ink.ignoresSafeArea()
            PBStamp(delay: 0.12, duration: 0.7) {
                Circle().fill(PBW.brown).frame(width: 216, height: 216)
            }
            .offset(y: -80)

            VStack(spacing: 0) {
                PBFade(delay: 0.34) {
                    Text("PaperBoxd").font(PBW.script(58)).foregroundStyle(PBW.cream)
                }
                PBRise(delay: 0.56) {
                    Text("See you in \(w.nextMonth),")
                        .font(PBW.displayItalic(25))
                        .foregroundStyle(PBW.cream)
                }
                .padding(.top, 22)
                PBRise(delay: 0.68) {
                    Text("\(w.reader.first).")
                        .font(PBW.display(25))
                        .foregroundStyle(PBW.amber)
                }
                PBFade(delay: 0.96) {
                    Text("\(w.totals.books) BOOKS · \(w.totals.pages.formatted()) PAGES · \(w.totals.estimatedHours)H")
                        .font(PBW.mono(10)).tracking(1.8)
                        .foregroundStyle(PBW.muted)
                }
                .padding(.top, 30)
            }
            .multilineTextAlignment(.center)
        }
        .clipped()
    }
}

// MARK: - The 9:16 object that actually gets shared

struct WrappedRecapCard: View {
    let w: Wrapped
    var width: CGFloat = 300

    private var height: CGFloat { width * 16 / 9 }
    private var scale: CGFloat { width / 300 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PBW.ink
            Circle()
                .fill(PBW.terra)
                .frame(width: 168 * scale, height: 168 * scale)
                .offset(x: width - 110 * scale, y: 264 * scale)

            VStack(alignment: .leading, spacing: 0) {
                Text("PaperBoxd").font(PBW.script(26 * scale))
                Text("MONTHLY WRAPPED")
                    .font(PBW.mono(8 * scale)).tracking(1.4 * scale).foregroundStyle(PBW.muted)
                    .padding(.top, 4 * scale)
                Text(w.month.uppercased())
                    .font(PBW.poster(44 * scale)).kerning(-1.5 * scale)
                    .padding(.top, 22 * scale)
                Text(w.year)
                    .font(PBW.mono(11 * scale)).tracking(4.6 * scale).foregroundStyle(PBW.amber)
                    .padding(.top, 9 * scale)

                Rectangle().fill(PBW.cream.opacity(0.3)).frame(height: 1)
                    .padding(.top, 20 * scale).padding(.bottom, 16 * scale)

                HStack(alignment: .top, spacing: 20 * scale) {
                    stat("BOOKS", "\(w.totals.books)")
                    stat("PAGES", w.totals.pages.formatted())
                    stat("HOURS", "\(w.totals.estimatedHours)")
                }

                if !w.books.isEmpty {
                    Text("TOP BOOKS")
                        .font(PBW.mono(7.5 * scale)).tracking(1.4 * scale).foregroundStyle(PBW.muted)
                        .padding(.top, 20 * scale).padding(.bottom, 8 * scale)
                    ForEach(Array(w.books.prefix(4).enumerated()), id: \.element.id) { i, book in
                        HStack(alignment: .firstTextBaseline, spacing: 8 * scale) {
                            Text(String(format: "%02d", i + 1))
                                .font(PBW.mono(8 * scale)).foregroundStyle(PBW.terra)
                            Text(book.title).font(PBW.display(13.5 * scale)).lineLimit(1)
                        }
                        .padding(.vertical, 4 * scale)
                    }
                }

                HStack(alignment: .top, spacing: 20 * scale) {
                    if let author = w.authors.first {
                        smallStat("TOP AUTHOR", author.name)
                    }
                    if let genre = w.genres.first {
                        smallStat("TOP GENRE", genre.name)
                    }
                }
                .padding(.top, 16 * scale)

                Spacer(minLength: 8 * scale)

                VStack(alignment: .leading, spacing: 3 * scale) {
                    Text("READING TYPE")
                        .font(PBW.mono(7.5 * scale)).tracking(1.4 * scale).foregroundStyle(PBW.terra)
                    Text(w.archetype.name).font(PBW.display(19 * scale)).kerning(-0.4 * scale)
                }
                .padding(.horizontal, 13 * scale).padding(.vertical, 11 * scale)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(Rectangle().stroke(PBW.terra, lineWidth: 1))

                HStack {
                    Text(w.reader.handle.uppercased())
                    Spacer()
                    Text("PAPERBOXD.IN")
                }
                .font(PBW.mono(8 * scale)).tracking(1.4 * scale).foregroundStyle(PBW.muted)
                .padding(.top, 14 * scale)
            }
            .padding(.horizontal, 26 * scale)
            .padding(.vertical, 30 * scale)
            .foregroundStyle(PBW.cream)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2 * scale) {
            Text(label).font(PBW.mono(7.5 * scale)).tracking(1.4 * scale).foregroundStyle(PBW.muted)
            Text(value).font(PBW.poster(26 * scale))
        }
    }

    private func smallStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3 * scale) {
            Text(label).font(PBW.mono(7.5 * scale)).tracking(1.4 * scale).foregroundStyle(PBW.muted)
            Text(value).font(PBW.display(14 * scale)).lineLimit(1)
        }
    }
}

// MARK: - Flow layout for the trait chips

/// Wraps its children onto as many rows as they need. Used for the archetype
/// traits, which are as long as the archetype makes them.
struct WrappedFlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#if DEBUG
/// Every chapter side by side, at the size they are actually laid out for.
#Preview("Wrapped — all chapters") {
    let wrapped = PreviewData.wrapped
    return ScrollView(.horizontal) {
        HStack(spacing: 20) {
            ForEach(WrappedChapter.all(for: wrapped)) { chapter in
                VStack(spacing: 8) {
                    chapter.content(wrapped)
                        .frame(width: PBW.designWidth, height: 874)
                        .clipped()
                        .scaleEffect(0.42, anchor: .top)
                        .frame(width: PBW.designWidth * 0.42, height: 874 * 0.42)
                    Text(chapter.label).font(PBW.mono(9)).foregroundStyle(PBW.muted)
                }
            }
        }
        .padding(30)
    }
    .background(PBW.inkDeep)
}

#Preview("Wrapped — recap card") {
    ZStack {
        PBW.inkDeep.ignoresSafeArea()
        WrappedRecapCard(w: PreviewData.wrapped)
            .environment(\.wrappedStill, true)
    }
}
#endif
