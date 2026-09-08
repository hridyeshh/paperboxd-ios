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
            .background(BK.field, in: Rectangle())
            .overlay(
                Rectangle()
                    .stroke(isFocused ? BK.ink : BK.ink.opacity(0.32), lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.18), value: isFocused)
    }
}

/// Brutalist auth-card backing: a flat, opaque card-face panel with hard 90° corners,
/// a heavy ink border, and an offset "echo" plate standing in for a drop shadow.
/// No glass, no blur, no shimmer. Sits on the paper ground.
struct BrutalCard: View {
    /// Fill of the offset plate behind the card — ochre on sign in, forest on
    /// register, so the two screens read apart at a glance.
    var echo: Color = BK.ochre

    var body: some View {
        ZStack {
            // Offset plate — the hard, blur-free brutalist shadow.
            Rectangle()
                .fill(echo)
                .overlay(Rectangle().stroke(BK.ink, lineWidth: 2))
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
        .background(BK.field, in: Rectangle())
        .overlay(
            Rectangle()
                .stroke(isFocused ? BK.ink : BK.ink.opacity(0.32), lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.18), value: isFocused)
    }
}
