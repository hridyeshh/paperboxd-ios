import SwiftUI

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

    private var effectiveTotal: Int { localTotal > 0 ? localTotal : (bookPageCount ?? 0) }
    private var hasChanges: Bool { localPage != savedPage }
    private var percent: Double {
        guard effectiveTotal > 0 else { return 0 }
        return min(Double(localPage) / Double(effectiveTotal), 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your progress")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color("TextPrimary"))
                Spacer()
                if effectiveTotal > 0 {
                    Text("\(Int((percent * 100).rounded()))%")
                        .font(.system(size: 13, weight: .heavy, design: .serif))
                        .foregroundStyle(PB.terracotta)
                }
            }

            progressBar

            HStack(spacing: 14) {
                stepperButton(symbol: "−", delta: -1, longDelta: -10)
                pageDisplay
                stepperButton(symbol: "+", delta: 1, longDelta: 10)
                Spacer()
                if hasChanges {
                    Button {
                        Task { await onUpdate(localPage, effectiveTotal) }
                    } label: {
                        if isSaving {
                            ProgressView().scaleEffect(0.75).tint(Color("Background"))
                                .frame(width: 64, height: 30)
                        } else {
                            Text("Update")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color("Background"))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color("TextPrimary"), in: Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .transition(.opacity)
                }
            }

            if effectiveTotal > 0, let finish = finishLine {
                Text(finish)
                    .font(PB.serifItalic(12))
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
        .padding(14)
        .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color("Border"), lineWidth: 1))
        .animation(.easeInOut(duration: 0.18), value: hasChanges)
        .onAppear { sync() }
        .onChange(of: progress?.currentPage) { sync() }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color("Border").opacity(0.6))
                RoundedRectangle(cornerRadius: 4).fill(PB.terracotta)
                    .frame(width: geo.size.width * CGFloat(percent))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: percent)
            }
        }
        .frame(height: 6)
    }

    @ViewBuilder
    private var pageDisplay: some View {
        if effectiveTotal == 0 {
            if editingTotal {
                HStack(spacing: 4) {
                    Text("p. \(localPage) /")
                        .font(.system(size: 12)).foregroundStyle(Color("TextSecondary"))
                    TextField("pages", text: $totalInput)
                        .keyboardType(.numberPad)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color("TextPrimary"))
                        .frame(width: 56)
                        .onSubmit {
                            if let n = Int(totalInput), n > 0 { localTotal = n }
                            editingTotal = false
                        }
                }
            } else {
                Button {
                    totalInput = ""; editingTotal = true
                } label: {
                    HStack(spacing: 3) {
                        Text("p. \(localPage)")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(Color("TextPrimary"))
                        Text("/ Set total")
                            .font(.system(size: 12)).foregroundStyle(Color("Accent"))
                    }
                }
                .buttonStyle(.plain)
            }
        } else {
            HStack(spacing: 3) {
                Text("p.").font(.system(size: 12)).foregroundStyle(Color("TextSecondary"))
                Text("\(localPage)").font(.system(size: 14, weight: .bold)).foregroundStyle(Color("TextPrimary"))
                Text("/").foregroundStyle(Color("TextSecondary"))
                Text("\(effectiveTotal)").font(.system(size: 12)).foregroundStyle(Color("TextSecondary"))
            }
        }
    }

    private func stepperButton(symbol: String, delta: Int, longDelta: Int) -> some View {
        Text(symbol)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color("TextPrimary"))
            .frame(width: 30, height: 30)
            .background(Color("Background"), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color("Border"), lineWidth: 1))
            .onTapGesture { step(delta) }
            .onLongPressGesture(minimumDuration: 0.4) { step(longDelta) }
    }

    private func step(_ delta: Int) {
        let maxPage = effectiveTotal > 0 ? effectiveTotal : Int.max
        localPage = Swift.max(0, Swift.min(localPage + delta, maxPage))
    }

    private var finishLine: String? {
        guard let dateStr = progress?.estimatedFinishDate else { return nil }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return nil }
        let out = DateFormatter(); out.dateFormat = "EEEE"
        return "— at this pace you'll finish by \(out.string(from: date))"
    }

    private func sync() {
        localPage = progress?.currentPage ?? 0
        savedPage = progress?.currentPage ?? 0
        localTotal = progress?.totalPages ?? bookPageCount ?? 0
    }
}
