import SwiftUI

struct UpdatesView: View {
    @Environment(\.dismiss) var dismiss
    @State private var activities: [ActivityEntry] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else if activities.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No updates yet")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Follow some users to see their reading updates here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(activities) { activity in
                                ActivityCard(activity: activity)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Updates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadActivities()
            }
        }
    }
    
    func loadActivities() async {
        isLoading = true
        // TODO: Fetch activities from API
        // For now, show empty state
        try? await Task.sleep(nanoseconds: 500_000_000) // Simulate loading
        isLoading = false
    }
}

struct ActivityEntry: Identifiable {
    let id: String
    let userName: String
    let username: String?
    let userAvatar: String?
    let action: String
    let detail: String
    let timeAgo: String
    let cover: String?
    let bookTitle: String?
}

struct ActivityCard: View {
    let activity: ActivityEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User Avatar
            if let avatarURL = activity.userAvatar, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(activity.userName.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.primary)
                    )
            }
            
            // Activity Content
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.timeAgo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Text("@\(activity.username ?? activity.userName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(activity.action)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    if let bookTitle = activity.bookTitle {
                        Text(bookTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    } else {
                        Text(activity.detail)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Book Cover (if available)
            if let coverURL = activity.cover, let url = URL(string: coverURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                }
                .frame(width: 48, height: 64)
                .cornerRadius(8)
                .clipped()
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    UpdatesView()
}

