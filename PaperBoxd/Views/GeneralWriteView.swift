import SwiftUI
import UIKit

struct GeneralWriteView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var profileViewModel = ProfileViewModel.shared
    
    @State private var subject: String = ""
    @State private var htmlContent: String = ""
    @State private var isSaving: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String?
    @State private var textView: UITextView?
    
    private var username: String {
        profileViewModel.profile?.username ?? ""
    }
    
    private var canPublish: Bool {
        let textContent = htmlContent.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        return !textContent.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Subject field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Subject")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("Enter a subject for your note...", text: $subject)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    // Rich text editor
                    RichTextEditorView(
                        htmlContent: $htmlContent,
                        textView: $textView,
                        placeholder: "Start writing your thoughts..."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Write")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await publishEntry()
                        }
                    }) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Publish")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canPublish || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Failed to publish entry")
            }
            .onAppear {
                Task {
                    await profileViewModel.loadProfile()
                }
            }
        }
    }
    
    private func publishEntry() async {
        guard !isSaving else { return }
        
        let textContent = htmlContent.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textContent.isEmpty else {
            errorMessage = "Please write something before publishing"
            showError = true
            return
        }
        
        isSaving = true
        
        do {
            let subjectToSend = subject.trimmingCharacters(in: .whitespacesAndNewlines)
            let subjectValue = subjectToSend.isEmpty ? nil : subjectToSend
            
            _ = try await APIClient.shared.createDiaryEntry(
                username: username,
                subject: subjectValue,
                content: htmlContent.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            // Success - refresh profile to show new entry, then dismiss
            await MainActor.run {
                isSaving = false
                // Refresh profile to show the new diary entry
                Task {
                    await profileViewModel.refreshProfile()
                }
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Rich Text Editor View
struct RichTextEditorView: View {
    @Binding var htmlContent: String
    @Binding var textView: UITextView?
    let placeholder: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Formatting toolbar
            FormattingToolbar(textView: $textView)
            
            Divider()
            
            // Text editor
            RichTextEditorWrapper(
                htmlContent: $htmlContent,
                textView: $textView,
                placeholder: placeholder
            )
        }
    }
}

// MARK: - Rich Text Editor Wrapper (UIViewRepresentable)
struct RichTextEditorWrapper: UIViewRepresentable {
    @Binding var htmlContent: String
    @Binding var textView: UITextView?
    let placeholder: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.textColor = UIColor.label
        textView.backgroundColor = UIColor.clear
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.textContainer.lineFragmentPadding = 0
        
        // Enable rich text editing
        textView.allowsEditingTextAttributes = true
        textView.typingAttributes = [
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor.label
        ]
        
        // Set placeholder
        if htmlContent.isEmpty {
            textView.text = placeholder
            textView.textColor = UIColor.placeholderText
        } else {
            textView.attributedText = htmlToAttributedString(htmlContent)
            textView.textColor = UIColor.label
        }
        
        // Store reference in coordinator
        context.coordinator.textView = textView
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        // Update text view reference in coordinator
        context.coordinator.textView = textView
        
        // Only update if content has changed externally and text view is not first responder
        if !textView.isFirstResponder {
            if htmlContent.isEmpty {
                if textView.text != placeholder {
                    textView.text = placeholder
                    textView.textColor = UIColor.placeholderText
                }
            } else {
                let currentHTML = attributedStringToHTML(textView.attributedText)
                if currentHTML != htmlContent {
                    textView.attributedText = htmlToAttributedString(htmlContent)
                    textView.textColor = UIColor.label
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditorWrapper
        var textView: UITextView?
        
        init(parent: RichTextEditorWrapper) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // Update HTML content when text changes
            let html = attributedStringToHTML(textView.attributedText)
            parent.htmlContent = html
            // Update reference
            self.textView = textView
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.textView = textView
            }
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.text == parent.placeholder {
                textView.text = ""
                textView.textColor = UIColor.label
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = parent.placeholder
                textView.textColor = UIColor.placeholderText
            }
        }
    }
    
}

// MARK: - Helper Functions
// Helper to convert NSAttributedString to HTML
private func attributedStringToHTML(_ attributedString: NSAttributedString) -> String {
    let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [
        .documentType: NSAttributedString.DocumentType.html
    ]
    
    do {
        let htmlData = try attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: documentAttributes
        )
        if let html = String(data: htmlData, encoding: .utf8) {
            return html
        }
    } catch {
        print("Error converting to HTML: \(error)")
    }
    
    return attributedString.string
}

// Helper to convert HTML to NSAttributedString
private func htmlToAttributedString(_ html: String) -> NSAttributedString {
    guard let data = html.data(using: .utf8) else {
        return NSAttributedString(string: html)
    }
    
    do {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        return try NSAttributedString(data: data, options: options, documentAttributes: nil)
    } catch {
        print("Error converting from HTML: \(error)")
        return NSAttributedString(string: html)
    }
}

// MARK: - Formatting Toolbar
struct FormattingToolbar: View {
    @Binding var textView: UITextView?
    @State var isBold: Bool = false
    @State var isItalic: Bool = false
    @State var isUnderline: Bool = false
    @State var isBulletList: Bool = false
    @State var isNumberedList: Bool = false
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Bold
                Button(action: { toggleBold() }) {
                    Image(systemName: "bold")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isBold ? .blue : .primary)
                        .frame(width: 44, height: 44)
                        .background(isBold ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                }
                
                // Italic
                Button(action: { toggleItalic() }) {
                    Image(systemName: "italic")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isItalic ? .blue : .primary)
                        .frame(width: 44, height: 44)
                        .background(isItalic ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                }
                
                // Underline
                Button(action: { toggleUnderline() }) {
                    Image(systemName: "underline")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isUnderline ? .blue : .primary)
                        .frame(width: 44, height: 44)
                        .background(isUnderline ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                }
                
                Divider()
                    .frame(height: 32)
                
                // Bullet List
                Button(action: { toggleBulletList() }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isBulletList ? .blue : .primary)
                        .frame(width: 44, height: 44)
                        .background(isBulletList ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                }
                
                // Numbered List
                Button(action: { toggleNumberedList() }) {
                    Image(systemName: "list.number")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isNumberedList ? .blue : .primary)
                        .frame(width: 44, height: 44)
                        .background(isNumberedList ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }
    
    private func toggleBold() {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
        
        if range.length > 0 {
            let font = attributedText.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont ?? UIFont.systemFont(ofSize: 18)
            let newFont = isBold ? UIFont.systemFont(ofSize: font.pointSize) : UIFont.boldSystemFont(ofSize: font.pointSize)
            attributedText.addAttribute(.font, value: newFont, range: range)
        } else {
            let font = textView.typingAttributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 18)
            let newFont = isBold ? UIFont.systemFont(ofSize: font.pointSize) : UIFont.boldSystemFont(ofSize: font.pointSize)
            textView.typingAttributes[.font] = newFont
        }
        
        textView.attributedText = attributedText
        isBold.toggle()
    }
    
    private func toggleItalic() {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
        
        if range.length > 0 {
            let font = attributedText.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont ?? UIFont.systemFont(ofSize: 18)
            let newFont = isItalic ? UIFont.systemFont(ofSize: font.pointSize) : UIFont.italicSystemFont(ofSize: font.pointSize)
            attributedText.addAttribute(.font, value: newFont, range: range)
        } else {
            let font = textView.typingAttributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 18)
            let newFont = isItalic ? UIFont.systemFont(ofSize: font.pointSize) : UIFont.italicSystemFont(ofSize: font.pointSize)
            textView.typingAttributes[.font] = newFont
        }
        
        textView.attributedText = attributedText
        isItalic.toggle()
    }
    
    private func toggleUnderline() {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
        
        if range.length > 0 {
            if isUnderline {
                attributedText.removeAttribute(.underlineStyle, range: range)
            } else {
                attributedText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
        } else {
            if isUnderline {
                textView.typingAttributes.removeValue(forKey: .underlineStyle)
            } else {
                textView.typingAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
        }
        
        textView.attributedText = attributedText
        isUnderline.toggle()
    }
    
    private func toggleBulletList() {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        let text = textView.text as NSString
        let lineRange = text.lineRange(for: range)
        let line = text.substring(with: lineRange)
        
        if line.hasPrefix("• ") {
            let newText = text.replacingCharacters(in: lineRange, with: String(line.dropFirst(2)))
            textView.text = newText
            textView.selectedRange = NSRange(location: max(0, range.location - 2), length: 0)
            isBulletList = false
        } else {
            let newText = text.replacingCharacters(in: lineRange, with: "• \(line)")
            textView.text = newText
            textView.selectedRange = NSRange(location: range.location + 2, length: 0)
            isBulletList = true
        }
    }
    
    private func toggleNumberedList() {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        let text = textView.text as NSString
        let lineRange = text.lineRange(for: range)
        let line = text.substring(with: lineRange)
        
        let numberPattern = "^\\d+\\. "
        if let regex = try? NSRegularExpression(pattern: numberPattern, options: []) {
            let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.count))
            if !matches.isEmpty {
                let newText = text.replacingCharacters(in: lineRange, with: String(line.dropFirst(matches[0].range.length)))
                textView.text = newText
                textView.selectedRange = NSRange(location: max(0, range.location - matches[0].range.length), length: 0)
                isNumberedList = false
            } else {
                let newText = text.replacingCharacters(in: lineRange, with: "1. \(line)")
                textView.text = newText
                textView.selectedRange = NSRange(location: range.location + 3, length: 0)
                isNumberedList = true
            }
        }
    }
}
