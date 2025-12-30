import SwiftUI
import Kingfisher

struct WriteAboutBookView: View {
    @Environment(\.dismiss) var dismiss
    let book: Book
    let existingEntry: DiaryEntry?
    let onSave: () -> Void
    
    @State private var entryContent: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @FocusState private var isEditorFocused: Bool
    @State private var isPreWarming: Bool = true // Pre-warming state
    
    private let maxWords = 200
    
    // Computed property for word count
    private var wordCount: Int {
        entryContent.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    // Check if content is valid (not empty and within word limit)
    private var isValidContent: Bool {
        let trimmed = entryContent.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && wordCount <= maxWords
    }
    
    // Helper function to strip HTML tags from content
    private func stripHtmlTags(_ html: String) -> String {
        // Remove HTML tags
        var text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decode common HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&apos;", with: "'")
        
        // Clean up multiple spaces and newlines
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n\\s*\n", with: "\n\n", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Get current username from profile
    @ObservedObject private var viewModel = ProfileViewModel.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. SOLID "INK" BACKGROUND
                Color.black.ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Tap on background to unfocus editor (only if not pre-warming)
                        if !isPreWarming && isEditorFocused {
                            isEditorFocused = false
                        }
                    }
                
                // Pre-warming loader overlay
                if isPreWarming {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Preparing writing area...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.9))
                }
                
                VStack(spacing: 24) {
                    // 2. MINI BOOK CARD (Context for writing) - Optimized smooth animation
                    HStack {
                        if isEditorFocused { Spacer() }
                        
                        HStack(spacing: isEditorFocused ? 0 : 16) {
                            if let coverURL = book.secureCoverURL {
                                KFImage(coverURL)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: isEditorFocused ? 35 : 60, height: isEditorFocused ? 50 : 90)
                                    .cornerRadius(8)
                                    .clipped()
                            } else {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(width: isEditorFocused ? 35 : 60, height: isEditorFocused ? 50 : 90)
                                    .cornerRadius(8)
                            }
                            
                            if !isEditorFocused {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title)
                                        .font(.system(size: 18, weight: .black))
                                        .foregroundColor(.black)
                                        .lineLimit(2)
                                    Text(book.authorString)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.black.opacity(0.7))
                                        .lineLimit(1)
                                }
                                .transition(.opacity) // Simplified transition
                            }
                            
                            if !isEditorFocused { Spacer() }
                        }
                        .padding(isEditorFocused ? 0 : 16)
                        .background(Color(red: 0.96, green: 0.93, blue: 0.88)) // "Paper" Cream
                        .cornerRadius(isEditorFocused ? 8 : 16)
                        .frame(width: isEditorFocused ? 35 : nil, height: isEditorFocused ? 50 : nil)
                        // Implicit animation for smooth transitions
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isEditorFocused)
                        
                        if isEditorFocused { Spacer() }
                    }
                    .padding(.horizontal)
                    
                    // 3. THE WRITING CANVAS with off-white boundary - Simplified layout
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $entryContent)
                            .scrollContentBackground(.hidden) // Remove default background
                            .background(
                                // Simplified boundary logic to avoid layout ambiguity
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                                    .background(Color.black)
                            )
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundColor(.white)
                            .frame(maxHeight: .infinity)
                            .focused($isEditorFocused)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            // Prevent keyboard from fighting bottom constraint
                            .ignoresSafeArea(.keyboard, edges: .bottom)
                            .onChange(of: entryContent) { oldValue, newValue in
                                // Enforce 200 word limit
                                let words = newValue.components(separatedBy: .whitespacesAndNewlines)
                                    .filter { !$0.isEmpty }
                                
                                if words.count > maxWords {
                                    // Truncate to the last valid word
                                    let validWords = words.prefix(maxWords)
                                    entryContent = validWords.joined(separator: " ")
                                }
                            }
                        
                        // Word count indicator
                        HStack {
                            Spacer()
                            Text("\(wordCount)/\(maxWords) words")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(wordCount > maxWords ? .red : .white.opacity(0.6))
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if showError, let errorMessage = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    // 4. BOLD ACTION BUTTON
                    Button(action: saveEntry) {
                        ZStack {
                            // Solid white background layer
                            Color.white
                                .cornerRadius(12)
                            
                            // Content layer
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            } else {
                                Text("PUBLISH")
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        // Solid background to prevent text showing through
                        (isSaving || entryContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.5) : Color.white)
                            .cornerRadius(12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.clear, lineWidth: 0)
                    )
                    .shadow(color: .white.opacity(0.2), radius: 0, x: 5, y: 5)
                    .disabled(!isValidContent || isSaving)
                    .opacity(isValidContent ? 1.0 : 0.5)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                // Add tap gesture to the entire ZStack, but with lower priority
                // This allows TextEditor to handle its own taps first
                .contentShape(Rectangle())
                .onTapGesture {
                    // Only unfocus if tapping outside interactive elements and not pre-warming
                    // TextEditor will handle its own taps and prevent this from firing
                    if !isPreWarming && isEditorFocused {
                        isEditorFocused = false
                    }
                }
                .allowsHitTesting(!isPreWarming) // Disable interaction during pre-warming
            }
            .navigationTitle(existingEntry != nil ? "Edit" : "Write")
            .onChange(of: isEditorFocused) { oldValue, newValue in
                // Staggered animation logic to prevent fighting with keyboard initialization
                if newValue {
                    // Use a slight delay for the card animation so it doesn't
                    // fight the keyboard's heavy initialization
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        // Animation is driven by the value change, no explicit state needed
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        // Revert layout smoothly
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Pre-populate with existing entry content if available (strip HTML tags)
                if let existing = existingEntry {
                    entryContent = stripHtmlTags(existing.content)
                }
                
                // Pre-warming phase: Show loader for 2-3 seconds to prepare everything
                Task { @MainActor in
                    // Pre-warming phase: 2.5 seconds
                    // This allows the view hierarchy to settle, keyboard system to initialize,
                    // and image cache to be ready
                    try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
                    
                    // Hide pre-warming loader
                    isPreWarming = false
                    
                    // Small delay before focusing to ensure smooth transition
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                    
                    // Focus the editor directly - this pre-warms the keyboard and keeps card shrunk
                    isEditorFocused = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
                }
            }
        }
    }
    
    private func saveEntry() {
        // Haptic feedback when button is tapped
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        guard let username = viewModel.profile?.username else {
            errorMessage = "Unable to get your username. Please try again."
            showError = true
            return
        }
        
        let trimmedContent = entryContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            errorMessage = "Please write something about this book."
            showError = true
            return
        }
        
        guard wordCount <= maxWords else {
            errorMessage = "Please keep your entry under \(maxWords) words."
            showError = true
            return
        }
        
        isSaving = true
        showError = false
        errorMessage = nil
        
        Task {
            do {
                // Get book cover URL
                let coverURL = book.secureCoverURL?.absoluteString ?? book.cover ?? book.imageURL
                
                // Create diary entry
                _ = try await APIClient.shared.createDiaryEntry(
                    username: username,
                    bookId: book.id,
                    bookTitle: book.title,
                    bookAuthor: book.author ?? book.authors?.first,
                    bookCover: coverURL,
                    subject: nil,
                    content: trimmedContent
                )
                
                await MainActor.run {
                    isSaving = false
                    // Haptic feedback for successful publish
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    onSave()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
                print("❌ WriteAboutBookView: Failed to save diary entry: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    WriteAboutBookView(
        book: Book(
            id: "1",
            bookId: "1",
            title: "Sample Book",
            author: "Author Name",
            authors: ["Author Name"],
            src: nil,
            cover: nil,
            alt: nil,
            description: nil,
            publishedDate: nil,
            isbn: nil,
            isbn13: nil,
            averageRating: nil,
            ratingsCount: nil,
            pageCount: nil,
            categories: nil,
            publisher: nil,
            userInteraction: nil
        ),
        existingEntry: nil,
        onSave: {}
    )
}


