import SwiftUI

/// Coloured recommendation reason pill. Colour determined by reasonType.
struct SignalPillView: View {
    let reason: String
    let reasonType: String?

    var body: some View {
        Text(reason)
            .font(.system(size: 10, weight: .medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(pillColor.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(pillColor.opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(pillColor.opacity(0.25), lineWidth: 0.5))
    }

    private var pillColor: Color {
        switch reasonType?.uppercased() {
        case "VECTOR_SIMILAR":        return Color(red: 0.95, green: 0.70, blue: 0.30) // amber
        case "SOCIAL_FRIEND":         return Color(red: 0.40, green: 0.65, blue: 0.95) // blue
        case "GENRE_MATCH":           return Color(red: 0.40, green: 0.78, blue: 0.55) // green
        case "AUTHOR_MATCH":          return Color(red: 0.72, green: 0.52, blue: 0.95) // purple
        case "TRENDING":              return Color(red: 0.95, green: 0.50, blue: 0.38) // coral
        default:                      return Color(red: 0.95, green: 0.70, blue: 0.30) // amber fallback
        }
    }
}
