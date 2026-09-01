import SwiftUI

/// The way into Monthly Wrapped from your own profile. Deliberately quiet —
/// the story behind it is not.
struct WrappedEntryCard: View {
    let monthName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MONTHLY WRAPPED")
                        .font(PBW.mono(9.5)).tracking(1.6)
                        .foregroundStyle(PBW.terra)
                    Text("Your \(monthName), in fourteen chapters.")
                        .font(PBW.display(19))
                        .foregroundStyle(PBW.cream)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text("→")
                    .font(PBW.poster(24))
                    .foregroundStyle(PBW.terra)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(PBW.ink)
            .overlay(Rectangle().stroke(PBW.terra.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open your \(monthName) Wrapped")
    }
}
