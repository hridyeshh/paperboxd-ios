import SwiftUI

struct AvatarView: View {
    let url: String?
    let size: CGFloat
    var ringColor: Color = .clear
    var ringWidth: CGFloat = 0

    var body: some View {
        ZStack {
            if let urlStr = url, let imageURL = URL(string: urlStr) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        Color("Surface")
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(ringColor, lineWidth: ringWidth))
    }

    private var placeholder: some View {
        ZStack {
            Color("Surface")
            Image(systemName: "person.fill")
                .foregroundStyle(Color("TextSecondary"))
                .font(.system(size: size * 0.45))
        }
    }
}
