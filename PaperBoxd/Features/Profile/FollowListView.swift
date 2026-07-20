import Combine
import SwiftUI

enum FollowListMode {
    case followers, following
}

@MainActor
final class FollowListViewModel: ObservableObject {
    @Published var users: [UserProfile] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    private var page = 1
    private var hasMore = true

    let username: String
    let mode: FollowListMode

    init(username: String, mode: FollowListMode) {
        self.username = username
        self.mode = mode
        Task { await fetch() }
    }

    func fetch() async {
        guard hasMore, !isLoading || users.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        let path = mode == .followers
            ? Endpoints.followers(username: username) + "?page=\(page)&page_size=30"
            : Endpoints.following(username: username) + "?page=\(page)&page_size=30"
        do {
            let resp: UserListResponse = try await APIClient.shared.request(
                path: path, method: .get, requiresAuth: true
            )
            users += resp.users
            page += 1
            hasMore = resp.users.count == 30
        } catch let e as APIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct FollowListView: View {
    @StateObject private var vm: FollowListViewModel
    let onTapUser: (String) -> Void

    init(username: String, mode: FollowListMode, onTapUser: @escaping (String) -> Void) {
        _vm = StateObject(wrappedValue: FollowListViewModel(username: username, mode: mode))
        self.onTapUser = onTapUser
    }

    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()
            if vm.isLoading && vm.users.isEmpty {
                PBSpinner()
            } else if let err = vm.errorMessage, vm.users.isEmpty {
                Text(err)
                    .foregroundStyle(Color("TextSecondary"))
                    .font(.system(size: 14))
            } else {
                List(vm.users) { user in
                    UserRowView(user: user) { onTapUser(user.username) }
                        .listRowBackground(Color("Background"))
                        .listRowSeparatorTint(Color("Surface"))
                        .onAppear {
                            if user.id == vm.users.last?.id {
                                Task { await vm.fetch() }
                            }
                        }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(vm.mode == .followers ? "Followers" : "Following")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UserRowView: View {
    let user: UserProfile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AvatarView(url: user.avatarURL, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color("TextPrimary"))
                    Text("@\(user.username)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("TextSecondary"))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("TextSecondary"))
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
