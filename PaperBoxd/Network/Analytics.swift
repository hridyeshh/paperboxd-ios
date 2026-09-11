import Foundation

/// Product analytics. One call → one row in the backend `events` table.
///
/// Fire and forget: never awaits, never throws, never blocks a user action.
/// Requires a signed-in session (events.user_id is NOT NULL); calls made while
/// logged out fail silently with a 401 we ignore.
///
/// Naming is snake_case `<object>_<verb>` (`onboarding_started`), the same
/// convention the web client uses in lib/analytics.ts.
enum Analytics {
    static func track(_ eventType: String, bookID: String? = nil, metadata: [String: String] = [:]) {
        let body = Event(eventType: eventType, bookID: bookID, metadata: metadata)
        Task.detached(priority: .utility) {
            _ = try? await APIClient.shared.request(
                path: Endpoints.events,
                method: .post,
                body: body,
                requiresAuth: true
            ) as Empty
        }
    }

    private struct Event: Encodable {
        let eventType: String
        let bookID: String?
        let source = "mobile"
        let metadata: [String: String]

        enum CodingKeys: String, CodingKey {
            case eventType = "event_type"
            case bookID = "book_id"
            case source, metadata
        }
    }
}
