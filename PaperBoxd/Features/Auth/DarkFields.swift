import SwiftUI

struct DarkTextField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autocapitalisation: TextInputAutocapitalization = .never
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text(title).foregroundColor(.white.opacity(0.32)))
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(autocapitalisation)
            .autocorrectionDisabled(true)
            .foregroundStyle(.white)
            .focused($isFocused)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(.white.opacity(isFocused ? 0.09 : 0.055), in: Rectangle())
            .overlay(
                Rectangle()
                    .stroke(.white.opacity(isFocused ? 0.48 : 0.11), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.18), value: isFocused)
    }
}

/// Brutalist auth-card backing: a flat, opaque near-black panel with hard 90° corners,
/// a heavy off-white border, and an offset "echo" frame standing in for a drop shadow.
/// No glass, no blur, no shimmer. Sits over the existing dark book-cover background.
struct BrutalCard: View {
    var body: some View {
        ZStack {
            // Offset echo — the hard, blur-free brutalist shadow.
            Rectangle()
                .stroke(.white.opacity(0.16), lineWidth: 2)
                .offset(x: 7, y: 7)
            // Opaque panel: fully hides the background behind the card (readable, raw).
            Rectangle()
                .fill(Color(red: 0.07, green: 0.07, blue: 0.078))
            // Heavy structural border.
            Rectangle()
                .stroke(Color(red: 0.93, green: 0.92, blue: 0.90), lineWidth: 2)
        }
    }
}

struct DarkSecureField: View {
    let title: String
    @Binding var text: String
    var showText: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if showText {
                TextField("", text: $text, prompt: Text(title).foregroundColor(.white.opacity(0.35)))
                    .textContentType(.password)
            } else {
                SecureField("", text: $text, prompt: Text(title).foregroundColor(.white.opacity(0.35)))
                    .textContentType(.password)
            }
        }
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
        .foregroundStyle(.white)
        .focused($isFocused)
        .padding(.horizontal, 14)
        .padding(.trailing, 40)
        .frame(height: 52)
        .background(.white.opacity(isFocused ? 0.09 : 0.055), in: Rectangle())
        .overlay(
            Rectangle()
                .stroke(.white.opacity(isFocused ? 0.48 : 0.11), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.18), value: isFocused)
    }
}
