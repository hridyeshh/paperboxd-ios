import Foundation

// Messages (DMs). Shapes mirror internal/service/messages.go in the backend
// (MOBILE_API.md §3.13) and domain/model/Message.kt on Android.

enum AttachKind {
    static let book = "book"
    static let list = "list"
    static let thought = "thought"
    static let profile = "profile"
    static let fusion = "fusion"
    // ref_id is a MediaUpload id.
    static let photo = "photo"
    static let video = "video"
    // ref_id is a GIPHY id.
    static let gif = "gif"
    static let sticker = "sticker"

    static let media: Set<String> = [photo, video, gif, sticker]
}

/// Loose JSON for attachment snapshots, whose fields differ per kind.
enum JSONValue: Codable, Hashable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    var string: String { if case .string(let s) = self { return s }; return "" }
    var int: Int? { if case .number(let d) = self { return Int(d) }; return nil }
    var double: Double? { if case .number(let d) = self { return d }; return nil }
    var array: [JSONValue] { if case .array(let a) = self { return a }; return [] }
}

struct MessagePerson: Codable, Hashable {
    var userID: String = ""
    var username: String = ""
    var name: String = ""
    var avatarURL: String? = nil

    var displayName: String { name.isEmpty ? username : name }

    enum CodingKeys: String, CodingKey {
        case username, name
        case userID = "user_id"
        case avatarURL = "avatar_url"
    }
}

/// What a client sends: the object's kind and id. The server builds the card.
struct AttachmentRef: Codable, Hashable {
    let kind: String
    let refID: String
    enum CodingKeys: String, CodingKey { case kind; case refID = "ref_id" }
}

extension AttachmentRef: Identifiable {
    var id: String { "\(kind)-\(refID)" }
}

/// An attachment as stored: `snapshot` is the card as it looked when sent.
struct MessageAttachment: Codable, Hashable {
    let kind: String
    let refID: String
    let snapshot: JSONValue

    enum CodingKeys: String, CodingKey { case kind, snapshot; case refID = "ref_id" }

    func str(_ key: String) -> String { snapshot[key]?.string ?? "" }
    func int(_ key: String) -> Int? { snapshot[key]?.int }
    func double(_ key: String) -> Double? { snapshot[key]?.double }
    var isMedia: Bool { AttachKind.media.contains(kind) }
    func strings(_ key: String) -> [String] { snapshot[key]?.array.map(\.string).filter { !$0.isEmpty } ?? [] }

    /// Fusion snapshot: the two readers.
    var readers: [MessagePerson] {
        (snapshot["readers"]?.array ?? []).map {
            MessagePerson(username: $0["username"]?.string ?? "", name: $0["name"]?.string ?? "",
                          avatarURL: ($0["avatar_url"]?.string).flatMap { $0.isEmpty ? nil : $0 })
        }
    }
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: Int64
    let conversationID: String
    let senderID: String
    let fromMe: Bool
    var body: String
    let createdAt: String
    var unsent: Bool
    var attachments: [MessageAttachment]

    enum CodingKeys: String, CodingKey {
        case id, body, unsent, attachments
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case fromMe = "from_me"
        case createdAt = "created_at"
    }
}

struct MessagePreview: Codable, Hashable {
    let text: String
    let fromMe: Bool
    let createdAt: String
    enum CodingKeys: String, CodingKey { case text; case fromMe = "from_me"; case createdAt = "created_at" }
}

struct ConversationSummary: Codable, Identifiable, Hashable {
    let id: String
    /// accepted | request — the viewer's side.
    let state: String
    let muted: Bool
    let them: MessagePerson
    let lastMessage: MessagePreview
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case id, state, muted, them
        case lastMessage = "last_message"
        case unreadCount = "unread_count"
    }
}

struct ConversationList: Codable {
    let conversations: [ConversationSummary]
    let nextCursor: String
    enum CodingKeys: String, CodingKey { case conversations; case nextCursor = "next_cursor" }
}

struct ConversationPage: Codable {
    let id: String
    let state: String
    let muted: Bool
    let them: MessagePerson
    let theirLastReadID: Int64
    /// Oldest first.
    let messages: [ChatMessage]
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case id, state, muted, them, messages
        case theirLastReadID = "their_last_read_id"
        case hasMore = "has_more"
    }
}

struct ConversationWith: Codable {
    /// Empty when no conversation exists yet — the first send creates it.
    let conversationID: String
    let them: MessagePerson
    enum CodingKeys: String, CodingKey { case them; case conversationID = "conversation_id" }
}

struct SendMessageBody: Encodable {
    let conversationID: String?
    let to: [String]?
    let body: String
    let attachments: [AttachmentRef]
    let clientID: String

    enum CodingKeys: String, CodingKey {
        case to, body, attachments
        case conversationID = "conversation_id"
        case clientID = "client_id"
    }

    // Omit nil keys rather than sending null.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(conversationID, forKey: .conversationID)
        try c.encodeIfPresent(to, forKey: .to)
        try c.encode(body, forKey: .body)
        try c.encode(attachments, forKey: .attachments)
        try c.encode(clientID, forKey: .clientID)
    }
}

struct SendFailure: Codable, Hashable { let username: String; let error: String }

struct SendResult: Codable {
    let sent: [ChatMessage]
    let failed: [SendFailure]
}

struct SharedItem: Codable, Hashable, Identifiable {
    let messageID: Int64
    let kind: String
    let refID: String
    let snapshot: JSONValue
    let fromMe: Bool
    let createdAt: String

    var id: String { "\(messageID)-\(kind)-\(refID)" }
    var attachment: MessageAttachment { MessageAttachment(kind: kind, refID: refID, snapshot: snapshot) }

    enum CodingKeys: String, CodingKey {
        case kind, snapshot
        case messageID = "message_id"
        case refID = "ref_id"
        case fromMe = "from_me"
        case createdAt = "created_at"
    }
}

struct SharedList: Codable {
    let counts: [String: Int]
    let items: [SharedItem]
    let nextCursor: String
    enum CodingKeys: String, CodingKey { case counts, items; case nextCursor = "next_cursor" }
}

struct InboxBadge: Codable, Equatable {
    var unread = 0
    var requests = 0
    var total: Int { unread + requests }
}

/// POST /messages/media → attach as AttachmentRef(kind, refID).
struct MediaUpload: Codable, Hashable {
    let refID: String
    let kind: String
    let url: String
    let posterURL: String
    let width: Int
    let height: Int
    let durationMs: Int

    enum CodingKeys: String, CodingKey {
        case kind, url, width, height
        case refID = "ref_id"
        case posterURL = "poster_url"
        case durationMs = "duration_ms"
    }
}

/// A GIPHY GIF or sticker from GET /messages/gifs.
struct GifItem: Codable, Hashable, Identifiable {
    let id: String
    let url: String
    let previewURL: String
    let width: Int
    let height: Int

    enum CodingKeys: String, CodingKey {
        case id, url, width, height
        case previewURL = "preview_url"
    }
}

struct GifList: Codable { let items: [GifItem] }
