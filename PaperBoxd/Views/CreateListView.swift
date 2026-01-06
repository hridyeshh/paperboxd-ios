import SwiftUI

struct CreateListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var profileViewModel = ProfileViewModel.shared
    
    let onListCreated: (ReadingList) -> Void
    
    @State private var listName: String = ""
    @State private var isSecret: Bool = false
    @State private var isCreating: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String?
    
    private var username: String {
        profileViewModel.profile?.username ?? ""
    }
    
    private var canCreate: Bool {
        !listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // List Image Placeholder (matching web design)
                        VStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(uiColor: .secondarySystemBackground))
                                .frame(height: 200)
                                .overlay(
                                    VStack(spacing: 8) {
                                        HStack(spacing: 8) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(uiColor: .tertiarySystemBackground))
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(uiColor: .tertiarySystemBackground))
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        }
                                        HStack(spacing: 8) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(uiColor: .tertiarySystemBackground))
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(uiColor: .tertiarySystemBackground))
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        }
                                    }
                                    .padding(12)
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // List Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("List name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            TextField("Name your list", text: $listName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                                .padding(12)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(8)
                                .onSubmit {
                                    if canCreate && !isCreating {
                                        Task {
                                            await createList()
                                        }
                                    }
                                }
                        }
                        .padding(.horizontal, 20)
                        
                        // Make this list secret toggle
                        VStack(spacing: 0) {
                            Button(action: {
                                withAnimation {
                                    isSecret.toggle()
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Make this list secret")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Text("Only people you share the link with can see this list")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $isSecret)
                                        .labelsHidden()
                                }
                                .padding(16)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 20)
                        
                        // Create Button
                        Button(action: {
                            Task {
                                await createList()
                            }
                        }) {
                            HStack {
                                if isCreating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Create")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(canCreate ? Color.primary : Color(uiColor: .secondarySystemBackground))
                            .foregroundColor(canCreate ? Color(uiColor: .systemBackground) : Color.secondary)
                            .cornerRadius(12)
                        }
                        .disabled(!canCreate || isCreating)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Create a list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Failed to create list")
            }
            .onAppear {
                Task {
                    await profileViewModel.loadProfile()
                }
            }
        }
    }
    
    private func createList() async {
        print("📝 CreateListView: createList() called")
        guard !isCreating else {
            print("⚠️ CreateListView: Already creating, ignoring duplicate call")
            return
        }
        
        let trimmedName = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            print("❌ CreateListView: List name is empty")
            errorMessage = "Please enter a list name"
            showError = true
            return
        }
        
        print("📝 CreateListView: Starting list creation with name: '\(trimmedName)', isPublic: \(!isSecret), username: '\(username)'")
        isCreating = true
        
        do {
            print("📝 CreateListView: Calling APIClient.createList...")
            let newList = try await APIClient.shared.createList(
                username: username,
                title: trimmedName,
                description: "",
                isPublic: !isSecret
            )
            
            print("✅ CreateListView: List created successfully!")
            print("📝 CreateListView: Created list details - title: '\(newList.title)', id: '\(newList._id ?? "nil")'")
            
            // Success - refresh profile, then call callback to open the list detail view
            await MainActor.run {
                print("📝 CreateListView: On MainActor, setting up navigation...")
                isCreating = false
                print("📝 CreateListView: List created successfully - title: '\(newList.title)', id: '\(newList._id ?? "nil")'")
                
                // Refresh profile to show the new list
                Task {
                    print("📝 CreateListView: Starting profile refresh...")
                    await profileViewModel.refreshProfile()
                    print("✅ CreateListView: Profile refresh completed")
                }
                
                // Call the callback to notify parent view
                print("📝 CreateListView: Calling onListCreated callback...")
                onListCreated(newList)
                print("📝 CreateListView: onListCreated callback called")
                
                // Dismiss create view
                print("📝 CreateListView: Calling dismiss()...")
                dismiss()
                print("📝 CreateListView: dismiss() called")
            }
        } catch {
            print("❌ CreateListView: Error creating list: \(error.localizedDescription)")
            await MainActor.run {
                isCreating = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
