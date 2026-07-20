import SwiftUI

/// Brutalist reading-progress card — hard 2.5px border, offset shadow, a
/// segmented lit-cell bar and ± steppers that log pages. Mirrors the
/// "Reading Progress" block in "Book Page - Brutalist Mobile.html".
struct PageProgressView: View {
    let progress: ReadingProgress?
    let bookPageCount: Int?
    let isSaving: Bool
    let onUpdate: (Int, Int) async -> Void

    @State private var localPage: Int = 0
    @State private var localTotal: Int = 0
    @State private var savedPage: Int = 0
    @State private var totalInput: String = ""
    @State private var editingTotal = false
    @State private var editingPage = false
    @State private var pageInput: String = ""
    @FocusState private var pageFieldFocused: Bool

    private let line = BK.ink
    private let cellCount = 12

    private var effectiveTotal: Int { localTotal > 0 ? localTotal : (bookPageCount ?? 0) }
    private var hasChanges: Bool { localPage != savedPage }
    private var percent: Double {
        guard effectiveTotal > 0 else { return 0 }
        return min(Double(localPage) / Double(effectiveTotal), 1.0)
    }
    private var litCells: Int { Int((Double(cellCount) * percent).rounded()) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(line).offset(x: 6, y: 6)

            VStack(spacing: 0) {
                header
                Rectangle().fill(line).frame(height: 2)
                segments
                Rectangle().fill(line).frame(height: 2)
                controlRow
                if effectiveTotal > 0, let finish = finishLine {
                    Rectangle().fill(line).frame(height: 2)
                    footer(finish)
                }
            }
            .background(BK.paper2)
            .overlay(Rectangle().strokeBorder(line, lineWidth: 2.5))
        }
        .padding(.trailing, 6).padding(.bottom, 6) // room for offset shadow
        .animation(.easeInOut(duration: 0.18), value: hasChanges)
        .onAppear { sync() }
        .onChange(of: progress?.currentPage) { sync() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("READING PROGRESS")
                .font(PB.mono(10, .medium))
                .tracking(2)
                .foregroundStyle(BK.muted)
            Spacer()
            Text("\(Int((percent * 100).rounded()))%")
                .font(.system(size: 20, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(BK.ink)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    // MARK: - Segmented bar

    private var segments: some View {
        HStack(spacing: 3) {
            ForEach(0..<cellCount, id: \.self) { i in
                Rectangle()
                    .fill(i < litCells ? BK.accent : Color.clear)
                    .frame(height: 16)
                    .overlay(Rectangle().strokeBorder(line, lineWidth: 2))
                    .animation(.easeOut(duration: 0.15), value: litCells)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: - Control row (− page +)

    private var controlRow: some View {
        HStack(spacing: 0) {
            stepButton(symbol: "−", delta: -1, longDelta: -10)
            Rectangle().fill(line).frame(width: 2)

            VStack(spacing: 2) {
                pageDisplay
                if hasChanges {
                    Button { Task { await onUpdate(localPage, effectiveTotal) } } label: {
                        if isSaving {
                            ProgressView().scaleEffect(0.7).tint(BK.paper)
                                .frame(height: 18)
                        } else {
                            Text("TAP TO SAVE")
                                .font(PB.mono(8, .semibold)).tracking(1.5)
                                .foregroundStyle(BK.paper)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(BK.ink)
                        }
                    }
                    .buttonStyle(.plain).disabled(isSaving)
                } else {
                    Text("TAP ± TO LOG PAGES")
                        .font(PB.mono(8)).tracking(1.2)
                        .foregroundStyle(BK.muted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)

            Rectangle().fill(line).frame(width: 2)
            stepButton(symbol: "+", delta: 1, longDelta: 10)
        }
    }

    @ViewBuilder
    private var pageDisplay: some View {
        if effectiveTotal == 0 {
            if editingTotal {
                HStack(spacing: 4) {
                    Text("p. \(localPage) /").font(PB.mono(12)).foregroundStyle(BK.muted)
                    TextField("pages", text: $totalInput)
                        .keyboardType(.numberPad)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(BK.ink)
                        .frame(width: 52)
                        .onSubmit {
                            if let n = Int(totalInput), n > 0 { localTotal = n }
                            editingTotal = false
                        }
                }
            } else {
                Button { totalInput = ""; editingTotal = true } label: {
                    HStack(spacing: 4) {
                        Text("p. \(localPage)").font(PB.mono(15, .semibold)).foregroundStyle(BK.ink)
                        Text("/ SET TOTAL").font(PB.mono(9, .semibold)).foregroundStyle(BK.accent)
                    }
                }
                .buttonStyle(.plain)
            }
        } else if editingPage {
            HStack(spacing: 4) {
                Text("p.").font(PB.mono(12)).foregroundStyle(BK.muted)
                TextField("", text: $pageInput)
                    .keyboardType(.numberPad)
                    .font(PB.mono(15, .semibold))
                    .foregroundStyle(BK.ink)
                    .frame(width: 52)
                    .multilineTextAlignment(.center)
                    .focused($pageFieldFocused)
                    .overlay(alignment: .bottom) { Rectangle().fill(BK.accent).frame(height: 2) }
                    .onSubmit(commitPage)
                Text("/ \(effectiveTotal)").font(PB.mono(11)).foregroundStyle(BK.muted)
                Button("DONE") { commitPage() }
                    .font(PB.mono(9, .semibold)).foregroundStyle(BK.accent)
            }
        } else {
            Button {
                pageInput = "\(localPage)"
                editingPage = true
                pageFieldFocused = true
            } label: {
                HStack(spacing: 4) {
                    Text("p. \(localPage)").font(PB.mono(15, .semibold)).foregroundStyle(BK.ink)
                    Text("/ \(effectiveTotal)").font(PB.mono(11)).foregroundStyle(BK.muted)
                    Image(systemName: "pencil").font(.system(size: 10)).foregroundStyle(BK.muted)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func commitPage() {
        if let n = Int(pageInput) {
            localPage = Swift.max(0, Swift.min(n, effectiveTotal))
        }
        editingPage = false
        pageFieldFocused = false
    }

    private func stepButton(symbol: String, delta: Int, longDelta: Int) -> some View {
        Text(symbol)
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(BK.ink)
            .frame(width: 52)
            .frame(maxHeight: .infinity)
            .background(BK.paper)
            .contentShape(Rectangle())
            .onTapGesture { step(delta) }
            .onLongPressGesture(minimumDuration: 0.4) { step(longDelta) }
    }

    private func step(_ delta: Int) {
        let maxPage = effectiveTotal > 0 ? effectiveTotal : Int.max
        localPage = Swift.max(0, Swift.min(localPage + delta, maxPage))
    }

    // MARK: - Footer

    private func footer(_ text: String) -> some View {
        Text(text.uppercased())
            .font(PB.mono(9)).tracking(1)
            .foregroundStyle(BK.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9).padding(.horizontal, 14)
    }

    private var finishLine: String? {
        guard let dateStr = progress?.estimatedFinishDate else { return nil }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return nil }
        let out = DateFormatter(); out.dateFormat = "EEEE"
        return "at this pace, finished by \(out.string(from: date))"
    }

    private func sync() {
        localPage = progress?.currentPage ?? 0
        savedPage = progress?.currentPage ?? 0
        localTotal = progress?.totalPages ?? bookPageCount ?? 0
    }
}
