import SwiftUI

/// Scan & Know flow coordinator. Presented modally from the dock's Scan button.
///
/// Stages: Scan → Analyzing (the breakout game fills the wait while the backend scores
/// the scanned ISBN) → Reveal (count-up) → Breakdown. The book + score + breakdown are
/// real — fetched from `POST /api/v1/scan/analyze`, not hardcoded.
struct ScanFlowView: View {
    @Environment(\.dismiss) private var dismiss

    enum Stage { case scan, analyzing, reveal, breakdown }
    @State private var stage: Stage = .scan
    @State private var isbn = ""
    @State private var pendingTitle: String?
    @State private var result: ScanResult?
    @State private var loadError: String?

    var body: some View {
        ZStack {
            (stage == .scan ? Color.black : SK.bg).ignoresSafeArea()

            switch stage {
            case .scan:
                ScanScreen(onScanIt: { startScan($0, title: $1) }, onClose: { dismiss() })
                    .transition(.opacity)
            case .analyzing:
                AnalyzingScreen(book: result, pendingTitle: pendingTitle, error: loadError,
                                onReveal: { go(.reveal) },
                                onRetry: { startScan(isbn, title: pendingTitle) },
                                onClose: { dismiss() })
                    .transition(.opacity)
            case .reveal:
                if let result {
                    RevealScreen(result: result,
                                 onBreakdown: { go(.breakdown) }, onClose: { dismiss() })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            case .breakdown:
                if let result {
                    BreakdownScreen(result: result, onClose: { dismiss() })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .preferredColorScheme(stage == .scan ? .dark : .light)
    }

    private func startScan(_ code: String, title: String?) {
        isbn = code
        pendingTitle = title
        result = nil
        loadError = nil
        go(.analyzing)
        Task {
            do {
                let r = try await ScanService.analyze(isbn: code)
                await MainActor.run { withAnimation { result = r } }
            } catch {
                await MainActor.run { loadError = friendlyMessage(error) }
            }
        }
    }

    private func friendlyMessage(_ error: Error) -> String {
        if case .decoding = error as? APIError { return "Couldn't read the score. Try again." }
        if case .transport = error as? APIError { return "Network hiccup. Check your connection." }
        return (error as? APIError)?.errorDescription ?? "Something went wrong. Try again."
    }

    private func go(_ next: Stage) {
        withAnimation(.easeInOut(duration: 0.45)) { stage = next }
    }
}

#Preview {
    ScanFlowView()
}
