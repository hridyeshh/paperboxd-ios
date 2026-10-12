import Foundation

/// Messages (DMs) API. Thin wrappers over APIClient, like ModerationService;
/// Android twin is MessageRepository. No push yet: screens poll.
enum MessageService {
    static func conversations(box: String) async throws -> ConversationList {
        try await APIClient.shared.request(path: Endpoints.conversations + "?box=\(box)", requiresAuth: true)
    }

    static func badge() async throws -> InboxBadge {
        try await APIClient.shared.request(path: Endpoints.inboxBadge, requiresAuth: true)
    }

    static func conversationWith(username: String) async throws -> ConversationWith {
        let u = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        return try await APIClient.shared.request(path: Endpoints.conversationWith(u), requiresAuth: true)
    }

    static func messages(_ id: String, before: Int64? = nil, after: Int64? = nil) async throws -> ConversationPage {
        var comps = URLComponents(string: Endpoints.conversation(id) + "/messages")!
        var q: [URLQueryItem] = []
        if let before { q.append(URLQueryItem(name: "before", value: String(before))) }
        if let after { q.append(URLQueryItem(name: "after", value: String(after))) }
        comps.queryItems = q.isEmpty ? nil : q
        return try await APIClient.shared.request(path: comps.string ?? Endpoints.conversation(id), requiresAuth: true)
    }

    static func shared(_ id: String, kind: String?) async throws -> SharedList {
        let path = Endpoints.conversation(id) + "/shared" + (kind.map { "?kind=\($0)" } ?? "")
        return try await APIClient.shared.request(path: path, requiresAuth: true)
    }

    /// Sends to a conversation, or to up to five usernames when `conversationID`
    /// is nil. `clientID` makes a retry return the first send instead of a twin.
    static func send(
        conversationID: String?,
        to: [String]? = nil,
        body: String,
        attachments: [AttachmentRef] = [],
        clientID: String = UUID().uuidString
    ) async throws -> SendResult {
        try await APIClient.shared.request(
            path: Endpoints.messages,
            method: .post,
            body: SendMessageBody(conversationID: conversationID, to: to, body: body, attachments: attachments, clientID: clientID),
            requiresAuth: true
        )
    }

    /// Uploads a photo (JPEG) or video (MP4); attach the result by its refID.
    static func uploadMedia(_ data: Data, kind: String, mimeType: String) async throws -> MediaUpload {
        try await APIClient.shared.upload(
            path: Endpoints.messages + "/media",
            fileData: data,
            fileName: kind == AttachKind.video ? "video.mp4" : "photo.jpg",
            mimeType: mimeType,
            fields: ["kind": kind],
            // The server relays a video to Cloudinary before it answers.
            timeout: 180
        )
    }

    /// GIPHY search (trending when `query` is empty). type is "gifs" or "stickers".
    static func gifs(type: String, query: String) async throws -> GifList {
        var comps = URLComponents(string: Endpoints.messages + "/gifs")!
        comps.queryItems = [URLQueryItem(name: "type", value: type), URLQueryItem(name: "q", value: query)]
        return try await APIClient.shared.request(path: comps.string ?? Endpoints.messages + "/gifs", requiresAuth: true)
    }

    static func unsend(_ messageID: Int64) async throws {
        let _: Empty = try await APIClient.shared.request(path: Endpoints.message(messageID), method: .delete, requiresAuth: true)
    }

    static func markRead(_ id: String) async throws {
        let _: Empty = try await APIClient.shared.request(path: Endpoints.conversation(id) + "/read", method: .post, requiresAuth: true)
    }

    static func accept(_ id: String) async throws {
        let _: Empty = try await APIClient.shared.request(path: Endpoints.conversation(id) + "/accept", method: .post, requiresAuth: true)
    }

    static func setMuted(_ id: String, _ muted: Bool) async throws {
        let _: Empty = try await APIClient.shared.request(
            path: Endpoints.conversation(id), method: .patch, body: ["muted": muted], requiresAuth: true
        )
    }

    static func clear(_ id: String) async throws {
        let _: Empty = try await APIClient.shared.request(path: Endpoints.conversation(id), method: .delete, requiresAuth: true)
    }
}
