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
            .background(.white.opacity(isFocused ? 0.09 : 0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(isFocused ? 0.48 : 0.11), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.18), value: isFocused)
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
        .background(.white.opacity(isFocused ? 0.09 : 0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(isFocused ? 0.48 : 0.11), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.18), value: isFocused)
    }
}
