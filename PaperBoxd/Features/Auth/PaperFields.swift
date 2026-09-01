import SwiftUI

struct PaperTextField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autocapitalisation: TextInputAutocapitalization = .never
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text(title).foregroundColor(BK.muted.opacity(0.7)))
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(autocapitalisation)
            .autocorrectionDisabled(true)
            .foregroundStyle(BK.ink)
            .focused($isFocused)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(isFocused ? BK.paper2 : BK.paper2.opacity(0.55), in: Rectangle())
            .overlay(
                Rectangle()
                    .stroke(isFocused ? BK.ink : BK.ink.opacity(0.28), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.18), value: isFocused)
    }
}

/// Brutalist auth-card backing: a flat, opaque card-face panel with hard 90° corners,
/// a heavy ink border, and an offset "echo" frame standing in for a drop shadow.
/// No glass, no blur, no shimmer. Sits on the paper ground.
struct BrutalCard: View {
    var body: some View {
        ZStack {
            // Offset echo — the hard, blur-free brutalist shadow.
            Rectangle()
                .stroke(BK.ink.opacity(0.25), lineWidth: 2)
                .offset(x: 7, y: 7)
            // Opaque panel: fully hides the background behind the card (readable, raw).
            Rectangle()
                .fill(BK.card)
            // Heavy structural border.
            Rectangle()
                .stroke(BK.ink, lineWidth: 2)
        }
    }
}

struct PaperSecureField: View {
    let title: String
    @Binding var text: String
    var showText: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if showText {
                TextField("", text: $text, prompt: Text(title).foregroundColor(BK.muted.opacity(0.7)))
                    .textContentType(.password)
            } else {
                SecureField("", text: $text, prompt: Text(title).foregroundColor(BK.muted.opacity(0.7)))
                    .textContentType(.password)
            }
        }
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
        .foregroundStyle(BK.ink)
        .focused($isFocused)
        .padding(.horizontal, 14)
        .padding(.trailing, 40)
        .frame(height: 52)
        .background(isFocused ? BK.paper2 : BK.paper2.opacity(0.55), in: Rectangle())
        .overlay(
            Rectangle()
                .stroke(isFocused ? BK.ink : BK.ink.opacity(0.28), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.18), value: isFocused)
    }
}
