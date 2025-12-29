import SwiftUI
import Kingfisher
import UIKit

struct BookDetailView: View {
    let initialBook: Book // The simple version from the grid
    var namespace: Namespace.ID
    @Binding var isShowing: Bool
    
    // GESTURE STATE
    @State private var dragOffset: CGSize = .zero
    @State private var animateContent = false
    
    // FULL BOOK DATA (from API)
    @State private var fullBook: Book? // The full version from the API
    @State private var isLoadingFullDetails = true
    
    // USER STATES (Synced with PaperBoxd DB)
    @State private var isLiked: Bool = false
    @State private var isInBookshelf: Bool = false
    @State private var isDNF: Bool = false
    @State private var showLogSheet = false
    @State private var currentShelfStatus: String? = nil // Local state for immediate UI updates
    @State private var showShareSheet = false
    @State private var showDescriptionDialog = false
    @State private var isSavingStatus = false
    
    // Get current shelf status (prioritize local state for immediate updates)
    private var effectiveShelfStatus: String {
        if let currentStatus = currentShelfStatus {
            return currentStatus
        }
        return displayBook.userInteraction?.shelfStatus ?? "None"
    }
    
    // Computed property for button text
    private var logButtonText: String {
        let shelfStatus = effectiveShelfStatus
        if shelfStatus == "DNF" {
            return "DNF"
        } else if shelfStatus == "Read" || shelfStatus == "Reading" || shelfStatus == "Want to Read" {
            return "Bookshelf"
        } else {
            return "Log"
        }
    }
    
    // Computed property for the Log button icon
    @ViewBuilder
    private var logButtonIcon: some View {
        let shelfStatus = effectiveShelfStatus
        
        if shelfStatus == "DNF" {
            // DNF icon: book with cross
            ZStack {
                Image(systemName: "book.closed")
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
        } else if shelfStatus == "Read" || shelfStatus == "Reading" || shelfStatus == "Want to Read" {
            // Bookshelf icon
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 14, weight: .semibold))
        } else {
            // Default: circle with plus sign (no gray fill, just outline)
            ZStack {
                Circle()
                    .stroke(Color(uiColor: .systemBackground), lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Color(uiColor: .systemBackground))
            }
        }
    }
    
    // Use fullBook if available, otherwise fall back to initialBook
    private var displayBook: Book {
        return fullBook ?? initialBook
    }
    
    // Helper to strip HTML tags from description (matching web version)
    private func stripHtmlTags(_ html: String?) -> String {
        guard let html = html else { return "" }
        
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
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 1. HERO COVER (Matched Geometry - Premium transition)
                    ZStack(alignment: .topLeading) {
                        if let secureCoverURL = displayBook.secureCoverURL {
                            KFImage(secureCoverURL)
                                .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 600, height: 900)))
                                .forceRefresh(false)
                                .cacheMemoryOnly(false)
                                .fade(duration: 0.3)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .matchedGeometryEffect(id: initialBook.id, in: namespace)
                                .frame(width: geometry.size.width, height: 500)
                                .clipped()
                        } else {
                            // Fallback placeholder
                            Rectangle()
                                .fill(Color(uiColor: .secondarySystemBackground))
                                .matchedGeometryEffect(id: initialBook.id, in: namespace)
                                .frame(width: geometry.size.width, height: 500)
                        }
                    
                    // Back Arrow (Pinterest-style)
                    Button(action: {
                        dismissAction()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 20)
                    }
                    
                    if isLoadingFullDetails {
                        ProgressView().padding(50)
                    } else {
                    // 2. HEADER INFO
                    VStack(alignment: .leading, spacing: 8) {
                            Text(displayBook.title)
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundColor(.primary)
                        
                            Text(displayBook.authorString)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // 3. THE "PAPERBOXD" ACTION DOCK
                    HStack(spacing: 12) {
                        // LIKE BUTTON (Haptic Pulse Heart)
                        ActionButton(
                            icon: isLiked ? "heart.fill" : "heart",
                            color: isLiked ? .red : .primary,
                            active: isLiked
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                isLiked.toggle()
                            }
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }
                        
                            // LOG BUTTON (opens bottom sheet with options)
                        Button(action: {
                                showLogSheet = true
                        }) {
                            HStack(spacing: 8) {
                                    // Dynamic icon based on book status
                                    logButtonIcon
                                    
                                    Text(logButtonText)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 14)
                                .padding(.horizontal, 20)
                            .background(Color.primary)
                            .foregroundColor(Color(uiColor: .systemBackground))
                            .cornerRadius(14)
                        }
                            .disabled(isSavingStatus)
                        
                        // SHARE BUTTON
                        ActionButton(
                            icon: "square.and.arrow.up",
                            color: .primary,
                            active: false
                        ) {
                            showShareSheet = true
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                        
                            Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 25)
                    
                    // 4. SYNOPSIS & STATS
                    VStack(alignment: .leading, spacing: 15) {
                        Text("About this book")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        descriptionView
                    }
                    .padding(24)
                    .padding(.bottom, 100)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    }
                }
            }
            .ignoresSafeArea()
            .background(Color(uiColor: .systemBackground))
            // DRAG GESTURE FOR MINIMIZING
            .offset(y: dragOffset.height > 0 ? dragOffset.height : 0)
            .scaleEffect(calculateScale())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 150 {
                            dismissAction()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
        }
        .sheet(isPresented: $showLogSheet) {
            LogBookSheet(
                isDNF: isDNF,
                isInBookshelf: isInBookshelf,
                onDNFSelected: {
                    // Update local state immediately for instant UI feedback
                    currentShelfStatus = "DNF"
                    showLogSheet = false
                    Task {
                        await saveBookStatus("DNF")
                    }
                },
                onBookshelfSelected: {
                    // Update local state immediately for instant UI feedback
                    currentShelfStatus = "Read"
                    showLogSheet = false
                    Task {
                        await saveBookStatus("Read")
                    }
                }
            )
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .sheet(isPresented: $showDescriptionDialog) {
            DescriptionDialogView(
                description: stripHtmlTags(displayBook.description),
                bookTitle: displayBook.title
            )
            .presentationDetents([.medium, .large]) // The "Read More" drawer
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            loadFullDetails()
        }
    }
    
    private func dismissAction() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            animateContent = false
            isShowing = false
            dragOffset = .zero
        }
    }
    
    private func calculateScale() -> CGFloat {
        let progress = dragOffset.height / 1000
        return max(0.5, 1.0 - (progress * 0.5)) // Shrinks as you drag down, min 0.5
    }
    
    // Share items for share sheet
    private var shareItems: [Any] {
        var items: [Any] = []
        let shareText = "Check out \(displayBook.title) by \(displayBook.authorString) on PaperBoxd!"
        items.append(shareText)
        if let secureCoverURL = displayBook.secureCoverURL {
            items.append(secureCoverURL)
        }
        return items
    }
    
    // Load full book details from API
    private func loadFullDetails() {
        Task {
            do {
                print("📖 BookDetailView: Fetching full details for book ID: \(initialBook.id)")
                let detailed: Book = try await APIClient.shared.fetchBookDetails(bookId: initialBook.id)
                await MainActor.run {
                    self.fullBook = detailed
                    self.isLoadingFullDetails = false
                    
                    // Update user interaction state from API response
                    if let userInteraction = detailed.userInteraction {
                        self.isLiked = userInteraction.isLiked ?? false
                        
                        // Update bookshelf and DNF states based on shelfStatus
                        if let shelfStatus = userInteraction.shelfStatus {
                            // Update local shelf status to match API response
                            self.currentShelfStatus = shelfStatus
                            
                            if shelfStatus == "DNF" {
                                self.isDNF = true
                                self.isInBookshelf = false
                            } else if shelfStatus == "Read" || shelfStatus == "Reading" || shelfStatus == "Want to Read" {
                                self.isInBookshelf = true
                                self.isDNF = false
                            } else {
                                self.isDNF = false
                                self.isInBookshelf = false
                            }
                        }
                    }
                    
                    withAnimation(.easeOut(duration: 0.2).delay(0.2)) {
                        self.animateContent = true
                    }
                }
                print("✅ BookDetailView: Full details loaded successfully")
            } catch {
                print("❌ BookDetailView: Failed to load full details: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingFullDetails = false
                    // Still show the initial book data
                    withAnimation(.easeOut(duration: 0.2).delay(0.2)) {
                        self.animateContent = true
                    }
                }
            }
        }
    }
    
    // Save book status to backend
    private func saveBookStatus(_ status: String) async {
        await MainActor.run {
            isSavingStatus = true
        }
        
        do {
            // Get the cover URL from the display book (use secureCoverURL if available, otherwise fallback to cover/src)
            let coverURL = displayBook.secureCoverURL?.absoluteString ?? displayBook.cover ?? displayBook.imageURL
            
            let response = try await APIClient.shared.logBook(
                bookId: initialBook.id,
                status: status,
                rating: nil,
                thoughts: status == "DNF" ? "DNF" : nil,
                format: nil,
                cover: coverURL
            )
            
            await MainActor.run {
                // Update local state based on status
                self.currentShelfStatus = status // Keep local state in sync
                if status == "DNF" {
                    self.isDNF = true
                    self.isInBookshelf = false // DNF removes from bookshelf
                } else if status == "Read" {
                    self.isInBookshelf = true
                    self.isDNF = false // Bookshelf removes from DNF
                }
                self.isSavingStatus = false
                
                // Refresh full book details to sync with API
                loadFullDetails()
            }
            
            print("✅ BookDetailView: Book status saved: \(response.message)")
            
            // Refresh profile data since bookshelf/DNF/TBR lists may have changed
            Task {
                await ProfileViewModel.shared.refreshProfile()
            }
        } catch {
            print("❌ BookDetailView: Failed to save book status: \(error.localizedDescription)")
            await MainActor.run {
                self.isSavingStatus = false
            }
        }
    }
    
    // Check if description needs "Read more" (approximate check for 5+ lines)
    private func needsReadMore(_ text: String) -> Bool {
        // More lenient check: if text has more than ~100 characters, it's likely to exceed 5 lines
        // Average line on mobile is ~40-50 characters, so 100+ chars = ~2-3 lines minimum
        // With line spacing and wrapping, this will easily exceed 5 lines
        return text.count > 100
    }
    
    // Description view with "Read more" functionality
    @ViewBuilder
    private var descriptionView: some View {
        let cleanDescription = stripHtmlTags(displayBook.description)
        if !cleanDescription.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Truncated description preview (5 lines max)
                Text(cleanDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(6)
                    .lineLimit(5)
                
                // "Read more" button - opens bottom drawer with full description
                Button(action: {
                    showDescriptionDialog = true
                }) {
                    Text("Read more")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .underline()
                }
                .padding(.top, 4)
            }
        } else {
            Text("This is where your book description from the PaperBoxd API will go. It captures the essence of the narrative and invites the reader into the world of \(displayBook.title).")
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(6)
        }
    }
}

// MARK: - Log Book Sheet
struct LogBookSheet: View {
    let isDNF: Bool
    let isInBookshelf: Bool
    let onDNFSelected: () -> Void
    let onBookshelfSelected: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Log Book")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 20)
            
            Divider()
            
            // Options
            VStack(spacing: 0) {
                // Add to DNF option
                Button(action: onDNFSelected) {
                    HStack {
                        Image(systemName: isDNF ? "xmark.circle.fill" : "xmark.circle")
                            .foregroundColor(isDNF ? .red : .primary)
                        Text("Add to DNF")
                            .foregroundColor(.primary)
                        Spacer()
                        if isDNF {
                            Image(systemName: "checkmark")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                }
                
                Divider()
                
                // Add to Bookshelf option
                Button(action: onBookshelfSelected) {
                    HStack {
                        Image(systemName: isInBookshelf ? "books.vertical.fill" : "books.vertical")
                            .foregroundColor(isInBookshelf ? .green : .primary)
                        Text("Add to Bookshelf")
                            .foregroundColor(.primary)
                        Spacer()
                        if isInBookshelf {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                }
            }
            
            Spacer()
        }
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Description Dialog View
struct DescriptionDialogView: View {
    @Environment(\.dismiss) var dismiss
    let description: String
    let bookTitle: String
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Full description
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineSpacing(6)
                        .padding(24)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Description")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Action Button Component
struct ActionButton: View {
    let icon: String
    let color: Color
    let active: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(active ? color : .primary)
                .frame(width: 55, height: 55)
                .background(active ? color.opacity(0.1) : Color.secondary.opacity(0.1))
                .cornerRadius(14)
        }
    }
}


#Preview {
    struct PreviewWrapper: View {
        @Namespace var namespace
        
        var body: some View {
            // Create a sample book using JSON decoder for preview
            let sampleJSON = """
            {
                "id": "1",
                "title": "Sample Book Title",
                "author": "Author Name",
                "cover": "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=600&q=80",
                "description": "This is a sample book description for preview purposes. It demonstrates how the description text will appear in the detail view."
            }
            """.data(using: .utf8)!
            
            let decoder = JSONDecoder()
            if let book = try? decoder.decode(Book.self, from: sampleJSON) {
            BookDetailView(
                    initialBook: book,
                namespace: namespace,
                isShowing: .constant(true)
            )
            } else {
                Text("Preview Error")
            }
        }
    }
    
    return PreviewWrapper()
}
