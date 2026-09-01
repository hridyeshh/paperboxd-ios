import Foundation

/// Store-compliance moderation (Apple 1.2 / Play UGC): report content and
/// block users. Thin wrappers over APIClient; Android twin lives in
/// UserRepository.block/unblock/report.
enum ModerationService {
    static let reportReasons = [
        "Spam",
        "Harassment or hate",
        "Inappropriate content",
        "Misinformation",
        "Something else"
    ]

    private struct ReportBody: Encodable {
        let contentType: String
        let contentID: String
        let reason: String

        enum CodingKeys: String, CodingKey {
            case contentType = "content_type"
            case contentID = "content_id"
            case reason
        }
    }

    static func report(contentType: String, contentID: String, reason: String) async throws {
        let _: Empty = try await APIClient.shared.request(
            path: Endpoints.reports,
            method: .post,
            body: ReportBody(contentType: contentType, contentID: contentID, reason: reason),
            requiresAuth: true
        )
    }

    static func block(username: String) async throws {
        let _: Empty = try await APIClient.shared.request(
            path: Endpoints.block(username: username),
            method: .post,
            requiresAuth: true
        )
    }

    static func unblock(username: String) async throws {
        let _: Empty = try await APIClient.shared.request(
            path: Endpoints.block(username: username),
            method: .delete,
            requiresAuth: true
        )
    }
}
