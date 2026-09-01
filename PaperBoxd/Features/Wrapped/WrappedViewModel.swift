import Combine
import Foundation

@MainActor
final class WrappedViewModel: ObservableObject {
    @Published private(set) var wrapped: Wrapped?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    /// nil asks the backend for the current month.
    private let month: String?

    init(month: String? = nil) {
        self.month = month
    }

    var hasStory: Bool { wrapped?.hasData == true }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            wrapped = try await APIClient.shared.request(
                path: Endpoints.wrapped(month: month, timeZone: TimeZone.current.identifier),
                requiresAuth: true
            )
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Could not load your Wrapped."
        }
    }
}
