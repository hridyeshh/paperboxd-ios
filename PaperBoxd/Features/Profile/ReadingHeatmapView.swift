import SwiftUI

/// GitHub-style reading heatmap, brutalist resolution: a hard black-bordered card
/// with an offset drop-shadow, mono eyebrow + year tabs, a big page count, a
/// month-labelled grid of pages-per-day cells, and a LESS→MORE legend with the
/// streak line. Data comes from GET /reading/activity (see `ReadingActivity`).
struct ReadingHeatmapView: View {
    let activity: ReadingActivity
    let selectedYear: Int
    let onSelectYear: (Int) -> Void

    // Cell geometry
    private let cell: CGFloat = 9
    private let gap: CGFloat = 3

    // Terracotta "red" ramp (empty → most): matches the design's default accent.
    private static let ramp: [Color] = [
        Color(red: 0.925, green: 0.906, blue: 0.882), // 0 · empty
        Color(red: 0.957, green: 0.824, blue: 0.741), // 1
        Color(red: 0.906, green: 0.659, blue: 0.490), // 2
        Color(red: 0.851, green: 0.478, blue: 0.290), // 3
        Color(red: 0.749, green: 0.333, blue: 0.149), // 4
    ]
    private var ink: Color { Color("TextPrimary") }
    private var muted: Color { Color("TextSecondary") }
    private var accent: Color { Self.ramp[4] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            countRow.padding(.top, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    monthHeader
                    grid
                }
            }
            // The server caps the current year at today, so the grid's trailing
            // edge is the current week — land there instead of on January.
            .defaultScrollAnchor(.trailing)
            .padding(.top, 14)

            legendRow.padding(.top, 14)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("Background"))
        .overlay(Rectangle().strokeBorder(ink, lineWidth: 2))
        .background(Rectangle().fill(ink).offset(x: 5, y: 5))
    }

    // MARK: - Header (eyebrow + year tabs)

    private var headerRow: some View {
        HStack(alignment: .center) {
            Text("READING ACTIVITY")
                .font(PB.mono(10, .medium))
                .tracking(2.0)
                .foregroundStyle(muted)
            Spacer(minLength: 8)
            HStack(spacing: 12) {
                ForEach(yearTabs, id: \.self) { yr in
                    let active = yr == selectedYear
                    Button { onSelectYear(yr) } label: {
                        Text("'\(String(format: "%02d", yr % 100))")
                            .font(PB.mono(11, active ? .semibold : .regular))
                            .foregroundStyle(active ? ink : muted)
                            .overlay(alignment: .bottom) {
                                if active {
                                    Rectangle().fill(accent).frame(height: 2).offset(y: 4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// The three most recent years up to the current one, ascending.
    private var yearTabs: [Int] {
        let now = Calendar(identifier: .gregorian).component(.year, from: Date())
        return [now - 2, now - 1, now]
    }

    // MARK: - Page count

    private var countRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(Self.grouped(activity.totalPages))
                .font(PB.serif(34, .bold))
                .foregroundStyle(ink)
            Text("PAGES")
                .font(PB.mono(11, .medium))
                .tracking(1.5)
                .foregroundStyle(muted)
        }
    }

    // MARK: - Month header

    private var monthHeader: some View {
        HStack(spacing: gap) {
            ForEach(Array(monthMarkers.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(PB.mono(8.5))
                    .foregroundStyle(muted)
                    .fixedSize()
                    .frame(width: cell, alignment: .leading)
            }
        }
        .frame(height: 12, alignment: .leading)
    }

    // MARK: - Grid

    private var grid: some View {
        HStack(spacing: gap) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                VStack(spacing: gap) {
                    ForEach(Array(col.enumerated()), id: \.offset) { _, lvl in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(lvl.map { Self.ramp[$0] } ?? Color.clear)
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 6) {
            Text("LESS").font(PB.mono(9)).foregroundStyle(muted)
            ForEach(0..<Self.ramp.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Self.ramp[i])
                    .frame(width: cell, height: cell)
            }
            Text("MORE").font(PB.mono(9)).foregroundStyle(muted)
            Spacer(minLength: 8)
            (
                Text("\(activity.daysRead) DAYS · ")
                    .foregroundColor(muted)
                + Text("\(activity.longestStreak)-DAY STREAK")
                    .foregroundColor(ink)
            )
            .font(PB.mono(9.5, .medium))
        }
    }

    // MARK: - Grid model

    /// Week columns of 7 day-levels (Sun→Sat). `nil` = a padding cell outside the
    /// year (before Jan 1 / after the last real day) — rendered transparent.
    private var columns: [[Int?]] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        guard let startDate = Self.parse(activity.start),
              let endDate = Self.parse(activity.end) else { return [] }

        var pagesByKey: [String: Int] = [:]
        for d in activity.days { pagesByKey[d.date] = d.pages }

        let startWeekday = cal.component(.weekday, from: startDate) // 1 = Sunday
        let gridStart = cal.date(byAdding: .day, value: -(startWeekday - 1), to: startDate)!
        let endWeekday = cal.component(.weekday, from: endDate)
        let gridEnd = cal.date(byAdding: .day, value: 7 - endWeekday, to: endDate)!

        var cols: [[Int?]] = []
        var cur = gridStart
        while cur <= gridEnd {
            var col: [Int?] = []
            for _ in 0..<7 {
                if cur >= startDate && cur <= endDate {
                    col.append(Self.level(pagesByKey[Self.key(cur)] ?? 0))
                } else {
                    col.append(nil)
                }
                cur = cal.date(byAdding: .day, value: 1, to: cur)!
            }
            cols.append(col)
        }
        return cols
    }

    /// One entry per column: the 3-letter month label at the column where a new
    /// month first appears, empty otherwise.
    private var monthMarkers: [String] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        guard let startDate = Self.parse(activity.start),
              let endDate = Self.parse(activity.end) else { return [] }

        let months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
        let startWeekday = cal.component(.weekday, from: startDate)
        let gridStart = cal.date(byAdding: .day, value: -(startWeekday - 1), to: startDate)!
        // Walk the same padded range as `columns` so the header always has
        // exactly one marker per week column.
        let endWeekday = cal.component(.weekday, from: endDate)
        let gridEnd = cal.date(byAdding: .day, value: 7 - endWeekday, to: endDate)!

        var markers: [String] = []
        var cur = gridStart
        var lastMonth = -1
        while cur <= gridEnd {
            // month of the first in-year day of this column
            var repMonth = -1
            var probe = cur
            for _ in 0..<7 {
                if probe >= startDate && probe <= endDate {
                    repMonth = cal.component(.month, from: probe) - 1
                    break
                }
                probe = cal.date(byAdding: .day, value: 1, to: probe)!
            }
            if repMonth >= 0 && repMonth != lastMonth {
                markers.append(months[repMonth])
                lastMonth = repMonth
            } else {
                markers.append("")
            }
            cur = cal.date(byAdding: .day, value: 7, to: cur)!
        }
        return markers
    }

    // MARK: - Helpers

    private static func level(_ pages: Int) -> Int {
        switch pages {
        case ..<1:   return 0
        case ...12:  return 1
        case ...30:  return 2
        case ...55:  return 3
        default:     return 4
        }
    }

    private static let parser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func parse(_ s: String) -> Date? { parser.date(from: s) }
    private static func key(_ d: Date) -> String { parser.string(from: d) }

    private static func grouped(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
