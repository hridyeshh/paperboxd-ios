import SwiftUI
import Combine

struct EditProfileView: View {
    @StateObject private var vm: EditProfileViewModel
    @Environment(\.dismiss) private var dismiss

    /// Called after a successful save so the profile screen can refresh.
    let onSaved: () -> Void

    @State private var showPicker = false
    @State private var pickedAvatar: Image?
    @State private var customGender = false

    private static let genderOptions = [
        "Female", "Male", "Non-binary", "Transgender", "Intersex", "Prefer not to say", "Custom",
    ]
    static let pronounOptions = ["He", "Him", "His", "She", "Her", "They", "Them", "Theirs"]

    init(profile: UserProfile, onSaved: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: EditProfileViewModel(profile: profile))
        self.onSaved = onSaved
        _customGender = State(initialValue: {
            let g = profile.gender ?? ""
            return !g.isEmpty && !EditProfileView.genderOptions.contains(g)
        }())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 30) {
                        avatarHeader

                        section("Identity") {
                            stackedRow("Username") { usernameControl }
                            rowDivider
                            stackedRow("Name") {
                                TextField("Your name", text: $vm.name)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color("TextPrimary"))
                            }
                            rowDivider
                            stackedRow("Bio") { bioControl }
                        }

                        section("Personal") {
                            birthdayRow
                            rowDivider
                            stackedRow("Pronouns") { pronounChips }
                            rowDivider
                            stackedRow("Gender") { genderControl }
                        }

                        section("Online") {
                            stackedRow("Link") {
                                TextField("https://…", text: $vm.links)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color("TextPrimary"))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.URL)
                            }
                        }

                        if let err = vm.errorMessage {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(PB.likeRed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color("TextSecondary"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await vm.save() { onSaved(); dismiss() }
                        }
                    } label: {
                        if vm.isSaving {
                            ProgressView().tint(Color("Accent"))
                        } else {
                            Text("Save").fontWeight(.semibold).foregroundStyle(Color("Accent"))
                        }
                    }
                    .disabled(vm.isSaving)
                }
            }
            .sheet(isPresented: $showPicker) {
                ImagePicker(source: .photoLibrary) { image in
                    guard let data = image.avatarJPEGData() else { return }
                    pickedAvatar = Image(uiImage: image)
                    Task { await vm.uploadAvatar(data) }
                }
            }
        }
    }

    // MARK: - Avatar header (focal)

    private var previewName: String {
        let n = vm.name.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? vm.username : n
    }

    private var avatarHeader: some View {
        VStack(spacing: 14) {
            Button { showPicker = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let pickedAvatar {
                            pickedAvatar.resizable().scaledToFill()
                        } else if let url = vm.avatarURL, let u = URL(string: url) {
                            AsyncImage(url: u) { img in
                                img.resizable().scaledToFill()
                            } placeholder: { PB.avatarGradient }
                        } else {
                            PB.avatarGradient
                        }
                    }
                    .frame(width: 104, height: 104)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color("Border"), lineWidth: 1))
                    .shadow(color: .black.opacity(0.14), radius: 16, y: 7)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color("Background"))
                        .frame(width: 30, height: 30)
                        .background(Color("TextPrimary"), in: Circle())
                        .overlay(Circle().strokeBorder(Color("Background"), lineWidth: 2.5))
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 3) {
                Text(previewName)
                    .font(PB.serif(23))
                    .foregroundStyle(Color("TextPrimary"))
                Text("@\(vm.username)")
                    .font(PB.mono(12))
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 2)
    }

    // MARK: - Section scaffolding

    @ViewBuilder
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
    private func stackedRow<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased())
                .font(PB.mono(9.5)).tracking(1.5)
                .foregroundStyle(Color("TextSecondary"))
            control()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 13)
    }

    // MARK: - Username (with live availability)

    private var usernameControl: some View {
        HStack(spacing: 10) {
            TextField("Unique handle", text: $vm.username)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundStyle(Color("TextPrimary"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: vm.username) { _, _ in vm.onUsernameChange() }

            if vm.checkingUsername {
                ProgressView().controlSize(.small)
            } else if vm.usernameAvailable == true {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if vm.usernameAvailable == false {
                Image(systemName: "xmark.circle.fill").foregroundStyle(PB.likeRed)
            }
        }
    }

    // MARK: - Bio (with counter)

    private var bioControl: some View {
        VStack(alignment: .trailing, spacing: 4) {
            TextEditor(text: $vm.bio)
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 78, alignment: .topLeading)
                .padding(.horizontal, -5)
            Text("\(vm.bio.count)/160")
                .font(PB.mono(9.5))
                .foregroundStyle(vm.bio.count > 160 ? PB.likeRed : Color("TextSecondary").opacity(0.55))
        }
    }

    // MARK: - Birthday

    private var birthdayBinding: Binding<Date> {
        Binding(
            get: { vm.birthdayDate ?? (Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()) },
            set: { vm.birthdayDate = $0 }
        )
    }

    private var birthdayRow: some View {
        HStack {
            Text("BIRTHDAY")
                .font(PB.mono(9.5)).tracking(1.5)
                .foregroundStyle(Color("TextSecondary"))
            Spacer()
            if vm.birthdayDate != nil {
                DatePicker("", selection: birthdayBinding, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                Button {
                    vm.birthdayDate = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color("TextSecondary").opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            } else {
                Button {
                    vm.birthdayDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1))
                } label: {
                    Text("Add")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color("Accent"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }

    // MARK: - Pronouns (chip multi-select, max 2)

    private var pronounChips: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 62), spacing: 8, alignment: .leading)],
            alignment: .leading, spacing: 8
        ) {
            ForEach(Self.pronounOptions, id: \.self) { opt in
                let selected = vm.pronouns.contains(opt)
                let atMax = vm.pronouns.count >= 2 && !selected
                Button { togglePronoun(opt) } label: {
                    Text(opt)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(selected ? Color("TextPrimary") : Color("Background"), in: Capsule())
                        .foregroundStyle(selected ? Color("Background") : Color("TextPrimary"))
                        .overlay(Capsule().strokeBorder(Color("Border"), lineWidth: selected ? 0 : 1))
                        .opacity(atMax ? 0.35 : 1)
                }
                .buttonStyle(.plain)
                .disabled(atMax)
                .animation(.easeOut(duration: 0.15), value: selected)
            }
        }
    }

    private func togglePronoun(_ opt: String) {
        if let i = vm.pronouns.firstIndex(of: opt) {
            vm.pronouns.remove(at: i)
        } else if vm.pronouns.count < 2 {
            vm.pronouns.append(opt)
        }
    }

    // MARK: - Gender

    private var genderControl: some View {
        VStack(spacing: 10) {
            Menu {
                ForEach(Self.genderOptions, id: \.self) { opt in
                    Button(opt) { selectGender(opt) }
                }
            } label: {
                HStack {
                    Text(genderDisplay)
                        .font(.system(size: 16))
                        .foregroundStyle(vm.gender.isEmpty && !customGender ? Color("TextSecondary") : Color("TextPrimary"))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color("TextSecondary"))
                }
            }

            if customGender {
                TextField("Enter gender", text: $vm.gender)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(Color("TextPrimary"))
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color("Background"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color("Border"), lineWidth: 1))
            }
        }
    }

    private var genderDisplay: String {
        if customGender { return vm.gender.isEmpty ? "Custom" : vm.gender }
        return vm.gender.isEmpty ? "Select gender" : vm.gender
    }

    private func selectGender(_ option: String) {
        if option == "Custom" {
            customGender = true
            if Self.genderOptions.contains(vm.gender) { vm.gender = "" }
        } else {
            customGender = false
            vm.gender = option
        }
    }
}

@MainActor
final class EditProfileViewModel: ObservableObject {
    @Published var name: String
    @Published var bio: String
    @Published var pronouns: [String]   // selected pronoun chips (max 2)
    @Published var avatarURL: String?
    @Published var username: String
    @Published var birthdayDate: Date?
    @Published var gender: String
    @Published var links: String      // single URL in the UI; sent as [String]
    @Published var usernameAvailable: Bool?
    @Published var checkingUsername = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    let originalUsername: String
    private var usernameCheckTask: Task<Void, Never>?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(profile: UserProfile) {
        originalUsername = profile.username
        username = profile.username
        name = profile.name
        bio = profile.bio ?? ""
        // Normalize stored pronouns (possibly lowercased) to the canonical chip
        // labels so the matching chips highlight on open.
        pronouns = profile.pronouns.map { p in
            EditProfileView.pronounOptions.first { $0.lowercased() == p.lowercased() } ?? p
        }
        avatarURL = profile.avatarURL
        gender = profile.gender ?? ""
        links = profile.links.first ?? ""
        if let b = profile.birthday {
            birthdayDate = Self.dateFormatter.date(from: b)
        }
    }

    /// Debounced username availability check against the backend.
    func onUsernameChange() {
        usernameCheckTask?.cancel()
        let candidate = username.lowercased().trimmingCharacters(in: .whitespaces)
        guard candidate != originalUsername.lowercased() else {
            usernameAvailable = nil
            checkingUsername = false
            return
        }
        guard candidate.range(of: "^[a-z0-9_]{3,30}$", options: .regularExpression) != nil else {
            usernameAvailable = false
            checkingUsername = false
            return
        }
        usernameCheckTask = Task { @MainActor in
            checkingUsername = true
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            let resp: CheckUsernameResponse? = try? await APIClient.shared.request(
                path: Endpoints.checkUsername(candidate),
                method: .get,
                requiresAuth: false
            )
            if Task.isCancelled { return }
            usernameAvailable = resp?.available
            checkingUsername = false
        }
    }

    @discardableResult
    func uploadAvatar(_ data: Data) async -> Bool {
        do {
            let updated: UserProfile = try await APIClient.shared.upload(
                path: Endpoints.avatarUpload,
                fileData: data, fileName: "avatar.jpg", mimeType: "image/jpeg",
                requiresAuth: true
            )
            avatarURL = updated.avatarURL
            // Tell the dock + AppState to refresh; their copy of the URL is now stale.
            NotificationCenter.default.post(
                name: .paperboxdAvatarUpdated,
                object: nil,
                userInfo: updated.avatarURL.map { ["url": $0] }
            )
            return true
        } catch let e as APIError {
            errorMessage = e.errorDescription; return false
        } catch {
            errorMessage = error.localizedDescription; return false
        }
    }

    func save() async -> Bool {
        isSaving = true; defer { isSaving = false }
        errorMessage = nil

        let trimmedUsername = username.lowercased().trimmingCharacters(in: .whitespaces)
        let usernameChanged = trimmedUsername != originalUsername.lowercased()
        if usernameChanged && usernameAvailable == false {
            errorMessage = "That username is taken or invalid."
            return false
        }

        let pronounList = pronouns
        let trimmedLink = links.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGender = gender.trimmingCharacters(in: .whitespaces)

        let body = ProfileUpdateBody(
            username: usernameChanged ? trimmedUsername : nil,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            pronouns: pronounList,
            birthday: birthdayDate.map { Self.dateFormatter.string(from: $0) },
            gender: trimmedGender.isEmpty ? nil : trimmedGender,
            links: trimmedLink.isEmpty ? nil : [trimmedLink]
        )
        do {
            let _: UserProfile = try await APIClient.shared.request(
                path: Endpoints.profile(username: originalUsername),
                method: .put, body: body, requiresAuth: true
            )
            return true
        } catch let e as APIError {
            errorMessage = e.errorDescription; return false
        } catch {
            errorMessage = error.localizedDescription; return false
        }
    }
}

private struct ProfileUpdateBody: Encodable {
    let username: String?
    let name: String?
    let bio: String?
    let pronouns: [String]?
    let birthday: String?
    let gender: String?
    let links: [String]?
}
