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

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            BookCoverView(url: book.coverURL, width: 68, cornerRadius: 6)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(PB.serif(18))
                    .foregroundStyle(Color("TextPrimary"))
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
                        .frame(width: geo.size.width * CGFloat(book.displayPercent) / 100)
                }
            }
            .frame(height: 3)
        }
    }

    private var progressLine: String {
        if book.totalPages > 0 {
            return "P.\(book.currentPage) / \(book.totalPages) · \(book.displayPercent)%"
        }
        return "P.\(book.currentPage)"
    }
}

/// Empty-state card shown when the user has never logged a book.
struct LastLoggedEmptyCard: View {
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
        .background(Color("Surface"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
