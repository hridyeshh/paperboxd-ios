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

    // Eyebrow over serif title over serif-italic body — the same voice the
    // profile header and section headers use. The eyebrow carries the private
    // state, so the lock glyph that used to sit by the count is gone.
    private func header(_ d: ListDetailResponse) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: d.isPrivate ? "Private list" : "List")

            Text(d.title)
                .font(PB.serif(26))
                .foregroundStyle(Color("TextPrimary"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            if let desc = d.description, !desc.isEmpty {
                Text(desc)
                    .font(PB.serifItalic(15))
                    .foregroundStyle(Color("TextPrimary").opacity(0.78))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }

            Text("\(d.bookCount) \(d.bookCount == 1 ? "book" : "books")")
                .font(PB.mono(10))
                .tracking(1.6)
                .foregroundStyle(Color("TextSecondary"))
                .padding(.top, 14)

            Rectangle()
                .fill(Color("Border"))
                .frame(height: 1)
                .padding(.top, 16)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 3) {
                    Eyebrow(text: "New list")
                    Text("What are you collecting?")
                        .font(PB.serif(24))
                        .foregroundStyle(Color("TextPrimary"))
                        .fixedSize(horizontal: false, vertical: true)
                }

                section("The list") {
                    stackedRow("Name", counter: "\(title.count)/50", over: title.count > 50) {
                        TextField("Books that ruined me", text: $title)
                            .textFieldStyle(.plain)
                            .font(PB.serif(16))
                            .foregroundStyle(Color("TextPrimary"))
                    }
                    rowDivider
                    stackedRow("Description", counter: "\(description.count)/200", over: description.count > 200) {
                        TextField("Optional", text: $description, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(2...4)
                            .font(PB.serifItalic(15))
                            .foregroundStyle(Color("TextPrimary"))
                    }
                }

                section("Who can see it") {
                    // The whole row is the target, not just the switch.
                    Button { isPrivate.toggle() } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Private")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color("TextPrimary"))
                                Text(isPrivate
                                     ? "Only you, and anyone you grant access."
                                     : "Anyone can see this list on your profile.")
                                    .font(PB.mono(10))
                                    .foregroundStyle(Color("TextSecondary"))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 8)
                            Toggle("", isOn: $isPrivate)
                                .labelsHidden()
                                .tint(Color("TextPrimary"))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(PB.mono(11))
                        .foregroundStyle(PB.likeRed)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    PillButton(title: "Cancel", style: .brutalGhost) { dismiss() }
                    PillButton(
                        title: isSaving ? "Creating…" : "Create list",
                        style: .brutalPrimary,
                        loading: isSaving
                    ) {
                        Task { await save() }
                    }
                    .opacity(canSave ? 1 : 0.45)
                    .disabled(!canSave || isSaving)
                }
            }
            .padding(.horizontal, 20)
            // 20 clears the drag indicator, which floats over the content.
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color("Background"))
        // A sheet gets its own presentation context and does NOT inherit the
        // profile tab's forced light mode, so the asset colours resolve dark
        // and snap light on drag. Same pair every light-only screen uses.
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .presentationDetents([.height(560), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Form chrome
    //
    // Same anatomy as EditProfileView's sections — mono eyebrow over a Surface
    // card, stacked rows with a mono field label — so the two forms read as one
    // app rather than one bespoke sheet and one stock iOS Form.

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(PB.mono(10.5)).tracking(2)
                .foregroundStyle(Color("TextSecondary").opacity(0.7))
                .padding(.leading, 6)
            VStack(spacing: 0) { content() }
                .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color("Border").opacity(0.55), lineWidth: 1))
        }
    }

    private var rowDivider: some View {
        Rectangle().fill(Color("Border").opacity(0.45)).frame(height: 1).padding(.leading, 16)
    }

    @ViewBuilder
    private func stackedRow<Control: View>(
        _ label: String,
        counter: String,
        over: Bool,
        @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(label.uppercased())
                    .font(PB.mono(9.5)).tracking(1.5)
                    .foregroundStyle(Color("TextSecondary"))
                Spacer()
                Text(counter)
                    .font(PB.mono(9.5))
                    .foregroundStyle(over ? PB.likeRed : Color("TextSecondary").opacity(0.7))
            }
            control()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 13)
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
