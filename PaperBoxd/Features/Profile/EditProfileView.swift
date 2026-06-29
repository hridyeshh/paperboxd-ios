import SwiftUI
import Combine

struct EditProfileView: View {
    @StateObject private var vm: EditProfileViewModel
    @Environment(\.dismiss) private var dismiss

    /// Called after a successful save so the profile screen can refresh.
    let onSaved: () -> Void

    @State private var showPicker = false
    @State private var pickedAvatar: Image?

    init(profile: UserProfile, onSaved: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: EditProfileViewModel(profile: profile))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("Background").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        avatarPicker
                        field(label: "Name", text: $vm.name, placeholder: "Your name")
                        bioField
                        field(label: "Pronouns", text: $vm.pronouns, placeholder: "she/her")

                        if let err = vm.errorMessage {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(PB.likeRed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                }
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

    // MARK: - Avatar

    private var avatarPicker: some View {
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
                .frame(width: 92, height: 92)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color("Border"), lineWidth: 1))

                Image(systemName: "camera.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color("Background"))
                    .frame(width: 28, height: 28)
                    .background(Color("TextPrimary"), in: Circle())
                    .overlay(Circle().strokeBorder(Color("Background"), lineWidth: 2))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fields

    private func field(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(PB.mono(10)).tracking(1.4)
                .foregroundStyle(Color("TextSecondary"))
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .foregroundStyle(Color("TextPrimary"))
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color("Border"), lineWidth: 1))
        }
    }

    private var bioField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BIO")
                .font(PB.mono(10)).tracking(1.4)
                .foregroundStyle(Color("TextSecondary"))
            TextEditor(text: $vm.bio)
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(Color("TextPrimary"))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 96, alignment: .topLeading)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color("Border"), lineWidth: 1))
        }
    }
}

@MainActor
final class EditProfileViewModel: ObservableObject {
    @Published var name: String
    @Published var bio: String
    @Published var pronouns: String   // shown as "she/her", split on / or ,
    @Published var avatarURL: String?
    @Published var isSaving = false
    @Published var errorMessage: String?

    let username: String

    init(profile: UserProfile) {
        username = profile.username
        name = profile.name
        bio = profile.bio ?? ""
        pronouns = profile.pronouns.joined(separator: "/")
        avatarURL = profile.avatarURL
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
        let pronounList = pronouns
            .split(whereSeparator: { $0 == "/" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let body = ProfileUpdateBody(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            pronouns: pronounList
        )
        do {
            let _: UserProfile = try await APIClient.shared.request(
                path: Endpoints.profile(username: username),
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
    let name: String
    let bio: String
    let pronouns: [String]
}
