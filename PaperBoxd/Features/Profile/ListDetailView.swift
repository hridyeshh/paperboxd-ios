import SwiftUI

// MARK: - Navigation

/// Value pushed onto the profile NavigationStack to open a list. Distinct type
/// so it doesn't collide with the `String` bookId destination.
struct ListNav: Hashable {
    let listId: String
    let username: String
}

// MARK: - Detail response

struct ListDetailResponse: Decodable {
    let id: String
    let username: String
    let title: String
    let description: String?
    let isPrivate: Bool
    let bookCount: Int64
    let saveCount: Int64
    let canEdit: Bool
    let books: [Book]

    enum CodingKeys: String, CodingKey {
        case id, username, title, description, books
        case isPrivate = "is_private"
        case bookCount = "book_count"
        case saveCount = "save_count"
        case canEdit = "can_edit"
    }
}

// MARK: - Detail view

struct ListDetailView: View {
    let nav: ListNav
    let viewer: User

    @State private var detail: ListDetailResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ScrollView {
            if isLoading && detail == nil {
                PBSpinner().padding(.top, 80)
            } else if let detail {
                VStack(alignment: .leading, spacing: 16) {
                    header(detail)
                    if detail.books.isEmpty {
                        EmptyTabState(icon: "books.vertical", message: "No books in this list yet")
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(detail.books) { book in
                                NavigationLink(value: book.id) {
                                    GridCoverCell(url: book.coverURL)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 8)
            } else if let errorMessage {
                EmptyTabState(icon: "exclamationmark.triangle", message: errorMessage)
                    .padding(.top, 60)
            }
        }
        .background(Color("Background").ignoresSafeArea())
        .navigationTitle(detail?.title ?? "List")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func header(_ d: ListDetailResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(d.title)
                .font(PB.serif(24))
                .foregroundStyle(Color("TextPrimary"))
            if let desc = d.description, !desc.isEmpty {
                Text(desc)
                    .font(PB.serif(14))
                    .foregroundStyle(Color("TextSecondary"))
            }
            HStack(spacing: 6) {
                if d.isPrivate {
                    Image(systemName: "lock.fill").font(.system(size: 9))
                        .foregroundStyle(Color("TextSecondary"))
                }
                Text("\(d.bookCount) books")
                    .font(PB.mono(10))
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private func load() async {
        do {
            let resp: ListDetailResponse = try await APIClient.shared.request(
                path: Endpoints.listDetail(username: nav.username, listId: nav.listId),
                requiresAuth: true
            )
            detail = resp
        } catch {
            errorMessage = "Couldn't load this list"
        }
        isLoading = false
    }
}

// MARK: - Create list sheet

struct CreateListSheet: View {
    /// Returns true on success so the sheet can dismiss; caller refreshes the tab.
    let onCreate: (_ title: String, _ description: String?, _ isPrivate: Bool) async -> Bool
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var isPrivate = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("List name", text: $title)
                        .font(PB.serif(16))
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                        .font(PB.serif(14))
                } footer: {
                    Text("\(title.count)/50")
                        .font(PB.mono(10))
                        .foregroundStyle(title.count > 50 ? .red : Color("TextSecondary"))
                }
                Section {
                    Toggle(isOn: $isPrivate) {
                        Label("Private", systemImage: isPrivate ? "lock.fill" : "lock.open")
                    }
                } footer: {
                    Text(isPrivate
                         ? "Only you (and people you grant access) can see this list."
                         : "Anyone can see this list on your profile.")
                        .font(PB.mono(10))
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(PB.serif(13))
                }
            }
            .navigationTitle("New list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await save() } }
                        .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private var canSave: Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && t.count <= 50 && description.count <= 200
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let d = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let ok = await onCreate(t, d.isEmpty ? nil : d, isPrivate)
        isSaving = false
        if ok { dismiss() } else { errorMessage = "Couldn't create the list. Try again." }
    }
}
