import SwiftUI

/// Editorial currently-reading card: cover + title/author + progress bar + percent ring.
/// Mirrors the .pbp-cr / .pbh-prompt-pulse blocks in the design mocks.
struct CurrentlyReadingCard: View {
    let reading: CurrentlyReading
    var showLogButton: Bool = false
    var onLogPages: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                BookCoverView(url: reading.book.coverURL, width: 68, cornerRadius: 6)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(reading.book.title)
                        .font(PB.serif(18))
                        .foregroundStyle(Color("TextPrimary"))
                        .lineLimit(2)
                    Text(reading.book.authorLine)
                        .font(.system(size: 12))
                        .foregroundStyle(Color("TextSecondary"))
                        .lineLimit(1)

                    progressBlock.padding(.top, 10)
                }

                Spacer(minLength: 0)

                ProgressRing(percent: reading.displayPercent, size: 52)
            }

            if showLogButton {
                Button(action: { onLogPages?() }) {
                    HStack(spacing: 6) {
                        Text("Log today's pages")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .foregroundStyle(Color("Background"))
                    .background(Color("TextPrimary"))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color("Surface"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(progressLine)
                .font(PB.mono(10))
                .tracking(1)
                .foregroundStyle(Color("TextSecondary"))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color("Border"))
                    Capsule().fill(Color("TextPrimary"))
                        .frame(width: geo.size.width * CGFloat(reading.progressPercentage / 100))
                }
            }
            .frame(height: 3)
        }
    }

    private var progressLine: String {
        let current = reading.currentPage ?? 0
        if let total = reading.totalPages, total > 0 {
            return "P.\(current) / \(total) · \(reading.displayPercent)%"
        }
        return "P.\(current) · \(reading.displayPercent)%"
    }
}

// MARK: - Last logged book card (profile "currently reading")

/// Profile card showing the user's most-recently logged book (GET /reading/last).
struct LastLoggedBookCard: View {
    let book: LastLoggedBook

    private var ink: Color { Color("TextPrimary") }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            BookCoverView(url: book.coverURL, width: 68, cornerRadius: 3)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(PB.serif(18))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.system(size: 12))
                        .foregroundStyle(Color("TextSecondary"))
                        .lineLimit(1)
                }
                progressBlock.padding(.top, 10)
            }

            Spacer(minLength: 0)

            ProgressRing(percent: book.displayPercent, size: 52)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("Background"))
        .overlay(Rectangle().strokeBorder(ink, lineWidth: 2))
        .background(Rectangle().fill(ink).offset(x: 5, y: 5))
    }

    @ViewBuilder
    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(progressLine)
                .font(PB.mono(10))
                .tracking(1)
                .foregroundStyle(Color("TextSecondary"))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color("Border"))
                    Rectangle().fill(ink)
                        .frame(width: geo.size.width * CGFloat(book.displayPercent) / 100)
                }
            }
            .frame(height: 4)
            .overlay(Rectangle().strokeBorder(ink, lineWidth: 1))
        }
    }

    private var progressLine: String {
        if book.totalPages > 0 {
            return "P.\(book.currentPage) / \(book.totalPages) · \(book.displayPercent)%"
        }
        return "P.\(book.currentPage)"
    }
}

// MARK: - Brutalist reading hero (home page)

/// Home-page currently-reading hero. Always light mode, hard-edged, offset ink
/// shadow — mirrors the `.pbhm-hero` block in "Home - Brutalist Mobile.html".
/// The whole card is tappable (navigates to the book, where pages are logged).
struct BrutalReadingHero: View {
    let book: LastLoggedBook

    // card fill (#fdfbf6) — slightly lighter than BK.paper so the ink border reads.
    private let card = Color(red: 0.992, green: 0.984, blue: 0.965)

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 13) {
                BookCoverView(url: book.coverURL, width: 56, cornerRadius: 3)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 5)

                VStack(alignment: .leading, spacing: 3) {
                    Text("CURRENTLY READING")
                        .font(PB.mono(9)).tracking(1.8)
                        .foregroundStyle(BK.muted)
                    Text(book.title)
                        .font(PB.serif(19)).foregroundStyle(BK.ink)
                        .lineLimit(2)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.system(size: 12)).foregroundStyle(BK.muted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                HStack(alignment: .top, spacing: 1) {
                    Text("\(book.displayPercent)")
                        .font(.system(size: 27, weight: .black, design: .default))
                        .foregroundStyle(BK.ink)
                    Text("%")
                        .font(PB.mono(10, .medium)).foregroundStyle(BK.muted)
                        .padding(.top, 3)
                }
            }

            // progress bar — hard-edged, ink border, red fill
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(BK.paper2)
                    Rectangle().fill(BK.accent)
                        .frame(width: geo.size.width * CGFloat(book.displayPercent) / 100)
                }
            }
            .frame(height: 6)
            .overlay(Rectangle().strokeBorder(BK.ink, lineWidth: 1))

            HStack {
                Text(pagesLine)
                    .font(PB.mono(10)).tracking(1)
                    .foregroundStyle(BK.muted)

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Text("Log today's pages")
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(card)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(BK.ink)
                .overlay(Rectangle().strokeBorder(BK.ink, lineWidth: 1))
            }
        }
        .padding(16)
        .background(card)
        .overlay(Rectangle().strokeBorder(BK.ink, lineWidth: 1.5))
        // hard offset shadow behind the face
        .background(alignment: .topLeading) {
            Rectangle().fill(BK.ink).offset(x: 6, y: 6)
        }
        .padding(.trailing, 6).padding(.bottom, 6) // reserve room for the shadow
    }

    private var pagesLine: String {
        book.totalPages > 0 ? "P.\(book.currentPage) / \(book.totalPages)" : "P.\(book.currentPage)"
    }
}

/// Empty-state card shown when the user has never logged a book.
struct LastLoggedEmptyCard: View {
    private var ink: Color { Color("TextPrimary") }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Color("TextSecondary"))
            Text("No reading logged yet")
                .font(PB.serifItalic(14))
                .foregroundStyle(Color("TextSecondary"))
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color("Background"))
        .overlay(Rectangle().strokeBorder(ink, lineWidth: 2))
        .background(Rectangle().fill(ink).offset(x: 5, y: 5))
    }
}

// MARK: - Progress ring (vinyl percent indicator)

struct ProgressRing: View {
    let percent: Int
    var size: CGFloat = 52
    var color: Color = Color("TextPrimary")

    var body: some View {
        let p = max(0, min(percent, 100))
        ZStack {
            Circle().stroke(Color("Border"), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(p) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(p)%")
                .font(PB.mono(11, .medium))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}
