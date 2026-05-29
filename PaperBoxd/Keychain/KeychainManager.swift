import Foundation
import Security

/// Thin wrapper around Keychain Services for the JWT token + cached user.
/// Sync API — keychain reads are fast and getting them off-actor is more
/// trouble than it's worth in Phase 1.
final class KeychainManager: @unchecked Sendable {
    static let shared = KeychainManager()
    private init() {}

    private let service = Config.keychainService
    private let tokenKey = "auth.token"
    private let userKey = "auth.user"

    // MARK: - Token

    @discardableResult
    func saveToken(_ token: String) -> Bool {
        save(key: tokenKey, data: Data(token.utf8))
    }

    func getToken() -> String? {
        guard let data = load(key: tokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - User

    @discardableResult
    func saveUser(_ user: User) -> Bool {
        do {
            let data = try JSONEncoder().encode(user)
            return save(key: userKey, data: data)
        } catch {
            return false
        }
    }

    func getUser() -> User? {
        guard let data = load(key: userKey) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }

    // MARK: - Clear

    func clearAll() {
        delete(key: tokenKey)
        delete(key: userKey)
    }

    // MARK: - Internals

    private func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        // Delete first — SecItemAdd duplicates on existing entries.
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    @discardableResult
    private func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
