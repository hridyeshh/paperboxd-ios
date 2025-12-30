import SwiftUI
import PhotosUI
import UIKit

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    let profile: UserProfile
    let onSave: () -> Void
    
    @State private var username: String
    @State private var name: String
    @State private var bio: String
    @State private var pronouns: [String]
    @State private var birthday: Date?
    @State private var gender: String
    @State private var customGender: String = "" // Store custom gender value separately
    @State private var links: String
    @State private var selectedAvatar: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var rawAvatarImage: UIImage? // Store the raw selected image before cropping
    @State private var showImageCropper = false
    @State private var imageReadyForCropper = false // Track when image is ready
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showPronounPicker = false
    @State private var showGenderPicker = false
    
    // Username availability checking
    @State private var isCheckingUsername = false
    @State private var usernameAvailable: Bool? = nil
    @State private var usernameCheckTask: Task<Void, Never>? = nil
    
    
    // Pronoun options (matching web version)
    private let pronounOptions = ["He", "Him", "His", "She", "Her", "They", "Them", "Theirs"]
    
    // Gender options (matching web version)
    private let genderOptions = ["Female", "Male", "Non-binary", "Transgender", "Intersex", "Prefer not to say", "Custom"]
    
    init(profile: UserProfile, onSave: @escaping () -> Void) {
        self.profile = profile
        self.onSave = onSave
        _username = State(initialValue: profile.username ?? "")
        _name = State(initialValue: profile.name ?? "")
        _bio = State(initialValue: profile.bio ?? "")
        _pronouns = State(initialValue: profile.pronouns ?? [])
        
        // Parse birthday
        if let birthdayString = profile.birthday {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            _birthday = State(initialValue: formatter.date(from: birthdayString))
        } else {
            _birthday = State(initialValue: nil)
        }
        
        // Handle gender - check if it's a custom value
        let profileGender = profile.gender ?? ""
        let initialGender: String
        if !profileGender.isEmpty && !genderOptions.contains(profileGender) {
            // It's a custom gender, set picker to "Custom" and store the value
            initialGender = "Custom"
            _customGender = State(initialValue: profileGender)
        } else {
            initialGender = profileGender
            _customGender = State(initialValue: "")
        }
        _gender = State(initialValue: initialGender)
        
        _links = State(initialValue: (profile.links ?? []).joined(separator: ", "))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    // Avatar picker
                    VStack(spacing: 12) {
                        HStack {
                            Spacer()
                            if let avatarImage = avatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let avatarURL = profile.avatar, let url = URL(string: avatarURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text((name.isEmpty ? username : name).prefix(1).uppercased())
                                            .font(.system(size: 40, weight: .bold))
                                    )
                            }
                            Spacer()
                        }
                        
                        // Edit picture button
                        PhotosPicker(selection: $selectedAvatar, matching: .images) {
                            Text("Edit picture")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Profile Information") {
                    // Username
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Username")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: username) { _, newValue in
                                checkUsernameAvailability(newValue)
                            }
                        
                        // Username availability indicator
                        if isCheckingUsername {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Checking availability...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 2)
                        } else if let available = usernameAvailable {
                            if username != profile.username {
                                if available {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("Username available")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                    .padding(.top, 2)
                                } else {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                        Text("Username already taken")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                        }
                    }
                    
                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Name", text: $name)
                    }
                    
                    // Bio
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Bio", text: $bio, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                
                Section("Pronouns") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pronouns")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button(action: {
                            showPronounPicker = true
                        }) {
                            HStack {
                                if pronouns.isEmpty {
                                    Text("Select pronouns")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(pronouns.joined(separator: ", "))
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                Section("Personal Information") {
                    // Birthday
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Birthday")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker("Birthday", selection: Binding(
                            get: { birthday ?? Date() },
                            set: { birthday = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden()
                    }
                    
                    // Gender
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gender")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Gender", selection: $gender) {
                            Text("Select gender").tag("")
                            ForEach(genderOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .labelsHidden()
                    }
                    
                    // Custom gender field (shown when "Custom" is selected)
                    if gender == "Custom" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom Gender")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Enter custom gender", text: $customGender)
                        }
                    }
                }
                
                Section("Links") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Links")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Links (comma-separated)", text: $links)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Button("Save") {
                            Task {
                                await saveProfile()
                            }
                        }
                    }
                }
            }
            .onChange(of: selectedAvatar) { _, newItem in
                Task {
                    guard let newItem = newItem else { return }
                    
                    print("📸 EditProfileView: Starting image load from PhotosPicker...")
                    
                    // Load the image data
                    guard let data = try? await newItem.loadTransferable(type: Data.self) else {
                        print("❌ EditProfileView: Failed to load image data")
                        return
                    }
                    
                    print("📸 EditProfileView: Image data loaded, size: \(data.count) bytes")
                    
                    // Create UIImage from data
                    guard let uiImage = UIImage(data: data) else {
                        print("❌ EditProfileView: Failed to create UIImage from data")
                        return
                    }
                    
                    print("📸 EditProfileView: Image created. Size: \(uiImage.size.width) x \(uiImage.size.height)")
                    
                    // Set the image first, then show cropper after a tiny delay to ensure state propagation
                    await MainActor.run {
                        rawAvatarImage = uiImage
                        print("✅ EditProfileView: rawAvatarImage set to image with size \(uiImage.size.width)x\(uiImage.size.height)")
                    }
                    
                    // Small delay to ensure state propagates before showing cropper
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                    
                    // Now show the cropper - rawAvatarImage should be set by now
                    await MainActor.run {
                        if rawAvatarImage != nil {
                            showImageCropper = true
                            print("✅ EditProfileView: showImageCropper set to true, image confirmed ready")
                        } else {
                            print("❌ EditProfileView: rawAvatarImage is nil! This shouldn't happen.")
                        }
                    }
                }
            }
            .sheet(isPresented: $showPronounPicker) {
                PronounPickerView(selectedPronouns: $pronouns, options: pronounOptions)
            }
            .fullScreenCover(isPresented: $showImageCropper) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    // Use a view that re-evaluates when rawAvatarImage changes
                    ImageCropperView(
                        rawAvatarImage: $rawAvatarImage,
                        onImageCropped: { croppedImage in
                            print("✅ EditProfileView: onImageCropped called with image size: \(croppedImage.size.width)x\(croppedImage.size.height)")
                            avatarImage = croppedImage
                            print("✅ EditProfileView: avatarImage set successfully")
                        },
                        onDismiss: {
                            print("✅ EditProfileView: ImageCropperView dismissed")
                            showImageCropper = false
                        }
                    )
                }
            }
        }
    }
    
    private func checkUsernameAvailability(_ newUsername: String) {
        // Cancel previous check task
        usernameCheckTask?.cancel()
        
        // Reset state
        usernameAvailable = nil
        isCheckingUsername = false
        
        // Don't check if username is empty or same as current
        if newUsername.isEmpty || newUsername == profile.username {
            return
        }
        
        // Validate format first
        let usernameRegex = try? NSRegularExpression(pattern: "^[a-zA-Z0-9_]{3,30}$", options: [])
        let range = NSRange(location: 0, length: newUsername.utf16.count)
        if let regex = usernameRegex, regex.firstMatch(in: newUsername, options: [], range: range) == nil {
            usernameAvailable = false
            return
        }
        
        // Debounce the check (wait 500ms after user stops typing)
        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            // Check if task was cancelled
            if Task.isCancelled {
                return
            }
            
            await MainActor.run {
                isCheckingUsername = true
            }
            
            do {
                let available = try await APIClient.shared.checkUsernameAvailability(newUsername)
                await MainActor.run {
                    isCheckingUsername = false
                    usernameAvailable = available
                }
            } catch {
                await MainActor.run {
                    isCheckingUsername = false
                    usernameAvailable = false
                }
            }
        }
    }
    
    private func saveProfile() async {
        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }
        
        do {
            // First, upload avatar if changed
            var avatarURL = profile.avatar
            
            // Check if avatarImage has been set (user selected and cropped a new image)
            // Also check rawAvatarImage in case it was just updated (cropped image)
            // Prioritize avatarImage as it's the final cropped version
            let imageToUpload = avatarImage ?? rawAvatarImage
            print("📸 EditProfileView: Checking for image to upload...")
            print("📸 EditProfileView: avatarImage is \(avatarImage != nil ? "set" : "nil")")
            print("📸 EditProfileView: rawAvatarImage is \(rawAvatarImage != nil ? "set" : "nil")")
            
            if let imageToUpload = imageToUpload {
                print("📸 EditProfileView: Uploading avatar image with size: \(imageToUpload.size.width)x\(imageToUpload.size.height)...")
                do {
                    avatarURL = try await APIClient.shared.uploadAvatar(image: imageToUpload)
                    print("✅ EditProfileView: Avatar uploaded successfully: \(avatarURL ?? "nil")")
                } catch {
                    print("❌ EditProfileView: Avatar upload failed: \(error.localizedDescription)")
                    throw error // Re-throw to be caught by outer catch block
                }
            } else {
                print("ℹ️ EditProfileView: No avatar image to upload")
            }
            
            // Format birthday
            var birthdayString: String? = nil
            if let birthday = birthday {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                birthdayString = formatter.string(from: birthday)
            }
            
            // Parse links
            let linksArray = links.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            // Determine final gender value
            let finalGender: String?
            if gender == "Custom" {
                finalGender = customGender.isEmpty ? nil : customGender
            } else {
                finalGender = gender.isEmpty ? nil : gender
            }
            
            // Then update profile
            let usernameToUse = username.isEmpty ? profile.username ?? "" : username
            print("📝 EditProfileView: Updating profile with username: \(usernameToUse)")
            print("📝 EditProfileView: Profile data - name: \(name), bio: \(bio.prefix(20))..., avatarURL: \(avatarURL ?? "nil")")
            
            do {
                _ = try await APIClient.shared.updateProfile(
                    username: usernameToUse,
                    name: name.isEmpty ? nil : name,
                    bio: bio.isEmpty ? nil : bio,
                    pronouns: pronouns.isEmpty ? nil : pronouns,
                    birthday: birthdayString,
                    gender: finalGender,
                    links: linksArray.isEmpty ? nil : linksArray,
                    avatar: avatarURL
                )
                print("✅ EditProfileView: Profile updated successfully")
            } catch {
                print("❌ EditProfileView: Profile update failed: \(error.localizedDescription)")
                throw error // Re-throw to be caught by outer catch block
            }
            
            await MainActor.run {
                isSaving = false
                print("✅ EditProfileView: Calling onSave() callback")
                onSave()
                print("✅ EditProfileView: Dismissing edit profile view")
                dismiss()
            }
        } catch {
            print("❌ EditProfileView: Error in saveProfile: \(error.localizedDescription)")
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

