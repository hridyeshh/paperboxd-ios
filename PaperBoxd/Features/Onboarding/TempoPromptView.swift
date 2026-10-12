import SwiftUI

/// One-shot bottom sheet shown over Home right after onboarding finishes.
/// Local-only preference (no backend field yet) — just paces recommendation
/// copy client-side, so it's a plain UserDefaults write, not a network call.
enum ReadingTempo: String, CaseIterable {
    case casual, regular, voracious

    var title: String {
        switch self {
        case .casual: return "Casual"
        case .regular: return "Regular"
        case .voracious: return "Voracious"
        }
    }

    var subtitle: String {
        switch self {
        case .casual: return "0–2 books / month"
        case .regular: return "3–4 books / month"
        case .voracious: return "5+ books / month"
        }
    }

    static let storageKey = "pb_reading_tempo"

    static var stored: ReadingTempo? {
        UserDefaults.standard.string(forKey: storageKey).flatMap(ReadingTempo.init(rawValue:))
    }
}

struct TempoPromptView: View {
    let onDismiss: () -> Void
    @State private var selected: ReadingTempo?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Capsule()
                .fill(BK.ink.opacity(0.15))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text("Set a Tempo")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(BK.ink)
                Text("What are your reading goals? This will help us pace recommendations.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(BK.muted)
                    .lineSpacing(2)
            }

            VStack(spacing: 10) {
                ForEach(ReadingTempo.allCases, id: \.self) { tempo in
                    row(tempo)
                }
            }

            Button(action: finish) {
                HStack(spacing: 6) {
                    Text("start reading")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BK.muted)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(BK.paper)
    }

    private func row(_ tempo: ReadingTempo) -> some View {
        Button {
            selected = tempo
            finish()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(tempo.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BK.ink)
                Text(tempo.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(BK.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .buttonStyle(BrutalButtonStyle(fill: BK.card, borderWidth: 2))
    }

    private func finish() {
        if let selected {
            UserDefaults.standard.set(selected.rawValue, forKey: ReadingTempo.storageKey)
        }
        onDismiss()
    }
}
