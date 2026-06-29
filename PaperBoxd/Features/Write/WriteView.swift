import SwiftUI

struct WriteView: View {
    @StateObject private var vm: WriteViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDiscard = false
    @State private var showBookSearch = false
    @State private var showDatePicker = false
    @State private var showRating = false

    init(username: String, preselectedBook: Book? = nil) {
        _vm = StateObject(wrappedValue: WriteViewModel(preselectedBook: preselectedBook, username: username))
    }

    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                Rectangle().fill(Color("Border")).frame(height: 1)
                bookRow
                if showBookSearch { bookSearchPanel }
                if showRating {
                    HStack {
                        RatingPickerView(rating: $vm.rating)
                        Spacer()
                        Button("Done") { withAnimation(.easeInOut(duration: 0.18)) { showRating = false } }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color("Accent"))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color("Surface"))
                    .overlay(alignment: .top) { Rectangle().fill(Color("Border")).frame(height: 1) }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                editorArea
            }
            .safeAreaInset(edge: .bottom) { bottomToolbar }
        }
        .onChange(of: vm.didSubmit) { _, submitted in
            if submitted { dismiss() }
        }
        .alert("Discard entry?", isPresented: $showDiscard) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("Your entry will not be saved.")
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button("Cancel") { handleCancel() }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color("TextSecondary"))

            Spacer()

            Text("PaperBoxd")
                .font(PB.wordmark(20))
                .foregroundStyle(Color("Accent"))

            Spacer()

            Button {
                Task { await vm.submit() }
            } label: {
                if vm.isLoading {
                    ProgressView().tint(Color("Background")).scaleEffect(0.8)
                        .frame(width: 52, height: 30)
                } else {
                    Text("Post")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(vm.canSubmit ? Color("Background") : Color("TextSecondary"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            vm.canSubmit ? Color("TextPrimary") : Color("TextSecondary").opacity(0.2),
                            in: Capsule()
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(!vm.canSubmit)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Book attachment

    private var bookRow: some View {
        Group {
            if let book = vm.selectedBook {
                HStack(spacing: 10) {
                    BookCoverView(url: book.coverURL, width: 32, cornerRadius: 3)
                    Text(book.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color("TextPrimary"))
                        .lineLimit(1)
                    Spacer()
                    Button {
                        vm.selectedBook = nil
                        vm.bookSearchQuery = ""
                        vm.bookSearchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color("TextSecondary").opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color("Surface"))
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { showBookSearch.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                        Text("Attach a book")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(Color("TextSecondary"))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color("Surface"))
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Color("Border")).frame(height: 1) }
    }

    // MARK: - Book search panel

    @ViewBuilder
    private var bookSearchPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(Color("TextSecondary"))
                TextField("Search books...", text: $vm.bookSearchQuery)
                    .font(.system(size: 14))
                    .foregroundStyle(Color("TextPrimary"))
                    .autocorrectionDisabled()
                    .onChange(of: vm.bookSearchQuery) { vm.onSearchChange() }
                if vm.isSearchingBooks {
                    ProgressView().scaleEffect(0.7).tint(Color("TextSecondary"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color("Background"))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color("Border"), lineWidth: 1))
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if !vm.bookSearchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.bookSearchResults) { book in
                            Button {
                                vm.selectedBook = book
                                vm.bookSearchQuery = ""
                                vm.bookSearchResults = []
                                withAnimation(.easeInOut(duration: 0.18)) { showBookSearch = false }
                            } label: {
                                HStack(spacing: 10) {
                                    BookCoverView(url: book.coverURL, width: 28, cornerRadius: 3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(book.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color("TextPrimary"))
                                            .lineLimit(1)
                                        if !book.authorLine.isEmpty {
                                            Text(book.authorLine)
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color("TextSecondary"))
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Rectangle().fill(Color("Border")).frame(height: 1).padding(.leading, 56)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .background(Color("Background"))
        .overlay(alignment: .bottom) { Rectangle().fill(Color("Border")).frame(height: 1) }
        .transition(.opacity)
    }

    // MARK: - Editor

    private var editorArea: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $vm.content)
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(Color("TextPrimary"))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 220)
                    .padding(.horizontal, 14)
                    .padding(.top, 14)

                if vm.content.isEmpty {
                    Text("What are you reading?")
                        .font(PB.serifItalic(16))
                        .foregroundStyle(Color("TextSecondary").opacity(0.6))
                        .padding(.horizontal, 18)
                        .padding(.top, 22)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Bottom toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 18) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showDatePicker.toggle()
                    showRating = false
                }
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundStyle(showDatePicker ? Color("Accent") : Color("TextSecondary"))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDatePicker) {
                DatePicker("Reading date", selection: $vm.readingDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showRating.toggle()
                    showDatePicker = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: vm.rating != nil ? "star.fill" : "star")
                        .font(.system(size: 18))
                        .foregroundStyle(vm.rating != nil ? Color("Accent") : Color("TextSecondary"))
                    if let r = vm.rating {
                        Text("\(r)")
                            .font(PB.mono(12, .semibold))
                            .foregroundStyle(Color("Accent"))
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(vm.charCount) chars")
                .font(PB.mono(11))
                .foregroundStyle(vm.charCount >= 10 ? Color("Accent") : Color("TextSecondary").opacity(0.5))
                .animation(.none, value: vm.charCount)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color("Background").opacity(0.97))
        .overlay(alignment: .top) { Rectangle().fill(Color("Border")).frame(height: 1) }
    }

    // MARK: - Helpers

    private func handleCancel() {
        if vm.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dismiss()
        } else {
            showDiscard = true
        }
    }
}
