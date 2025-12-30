import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var profileViewModel = ProfileViewModel.shared
    @State private var showLikes = false
    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccount = false
    var onDismiss: (() -> Void)?
    
    init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    dismiss()
                    onDismiss?()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Invisible button to center the title
                Button(action: {}) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.clear)
                        .padding(8)
                }
                .disabled(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Settings Options
            ScrollView {
                VStack(spacing: 0) {
                        // Likes option
                        SettingsRow(
                            icon: "heart.fill",
                            title: "Likes",
                            action: {
                                showLikes = true
                            }
                        )
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Log out option
                        SettingsRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            title: "Log out",
                            action: {
                                showLogoutConfirmation = true
                            }
                        )
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Delete account option (in red)
                        SettingsRow(
                            icon: "trash",
                            title: "Delete account",
                            titleColor: .red,
                            action: {
                                showDeleteAccount = true
                            }
                        )
                }
            }
        }
        .fullScreenCover(isPresented: $showLikes) {
            LikesView()
        }
        .alert("Log out", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Log out", role: .destructive) {
                logout()
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
        .fullScreenCover(isPresented: $showDeleteAccount) {
            DeleteAccountView()
        }
    }
    
    private func logout() {
        // Clear token
        APIClient.shared.logout()
        
        // Clear profile data
        ProfileViewModel.shared.clearProfile()
        
        // Sign out from Google
        GoogleSignInService.shared.signOut()
        
        // Update app state
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        
        // Dismiss settings
        dismiss()
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var titleColor: Color = .primary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(titleColor)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(titleColor)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(uiColor: .systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
