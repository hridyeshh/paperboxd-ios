import SwiftUI

struct DiaryView: View {
    @StateObject private var vm: DiaryViewModel

    init(user: User) {
        _vm = StateObject(wrappedValue: DiaryViewModel(user: user))
    }

    #if DEBUG
    init(preview viewModel: DiaryViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background").ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    content
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: DiaryNavItem.self) { nav in
                DiaryEntryDetailView(entry: nav.entry, viewer: vm.user)
            }
            .navigationDestination(for: String.self) { bookId in
                BookDetailView(bookId: bookId, user: vm.user)
            }
        }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .onReceive(NotificationCenter.default.publisher(for: .diaryEntryCreated)) { note in
            if let entry = note.object as? DiaryEntry {
                vm.handleNewEntry(entry)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryEntryDeleted)) { note in
            if let id = note.object as? String {
                vm.handleDeletedEntry(id)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Eyebrow(text: "Your reading log")
            Text("The Diary.")
                .font(PB.serif(30, .bold))
                .foregroundStyle(Color("TextPrimary"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.entries.isEmpty {
            shimmer
        } else if let err = vm.errorMessage, vm.entries.isEmpty {
            errorView(err)
        } else if vm.entries.isEmpty {
            emptyView
        } else {
            entryList
        }
    }

    // MARK: - List

    private var entryList: some View {
        BrutalistRefreshable(onRefresh: { await vm.refresh() }) {
            LazyVStack(spacing: 0) {
                ForEach(Array(vm.entries.enumerated()), id: \.element.id) { idx, entry in
                    entryRow(entry, isFirst: idx == 0)
                        .onAppear { Task { await vm.loadMoreIfNeeded(item: entry) } }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 100)
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: DiaryEntry, isFirst: Bool) -> some View {
        NavigationLink(value: DiaryNavItem(entry: entry)) {
            DiaryEntryRow(entry: entry)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if !isFirst {
                Rectangle().fill(Color("Border")).frame(height: 1)
            }
        }
    }

    // MARK: - States

    private var shimmer: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { i in
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color("Surface"))
                            .frame(width: 44, height: 66)
                            .pbShimmer()
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color("Surface"))
                                .frame(height: 14)
                                .pbShimmer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color("Surface"))
                                .frame(height: 12)
                                .pbShimmer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color("Surface"))
                                .frame(width: 80, height: 12)
                                .pbShimmer()
                        }
                    }
                    .padding(.vertical, 14)
                    .overlay(alignment: .top) {
                        if i > 0 { Rectangle().fill(Color("Border")).frame(height: 1) }
                    }
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color("TextSecondary").opacity(0.7))
            Text("No diary entries yet.")
                .font(PB.serif(17))
                .foregroundStyle(Color("TextPrimary"))
            Text("Mark a book as read to write your first entry.")
                .font(PB.serifItalic(13))
                .foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 14) {
            Text(msg)
                .font(PB.serifItalic(14))
                .foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Retry") { Task { await vm.refresh() } }
                .foregroundStyle(Color("Accent"))
        }
        .frame(maxHeight: .infinity)
    }
}
