import SwiftUI

struct RatingPickerView: View {
    @Binding var rating: Int?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    rating = (rating == star) ? nil : star
                } label: {
                    Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                        .font(.system(size: 22))
                        .foregroundStyle(star <= (rating ?? 0) ? Color("Accent") : Color("TextSecondary").opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
