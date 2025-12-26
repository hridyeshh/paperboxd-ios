import Foundation
import Security

/// Secure Keychain helper for storing sensitive authentication tokens
/// Uses iOS Keychain - the most secure storage on the device
class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    /// Save data to Keychain
    /// - Parameters:
    ///   - data: The data to store
    ///   - service: Service identifier (e.g., "paperboxd-jwt")
    ///   - account: Account identifier (e.g., "user-auth")
    func save(_ data: Data, service: String, account: String) {
        let query: [String: Any] = [
            kSecValueData as String: data,
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ KeychainHelper: Failed to save data - status: \(status)")
        } else {
            print("✅ KeychainHelper: Successfully saved data for \(service)/\(account)")
        }
    }
    
    /// Read data from Keychain
    /// - Parameters:
    ///   - service: Service identifier
    ///   - account: Account identifier
    /// - Returns: The stored data, or nil if not found
    func read(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        } else if status == errSecItemNotFound {
            print("ℹ️ KeychainHelper: No data found for \(service)/\(account)")
            return nil
        } else {
            print("⚠️ KeychainHelper: Failed to read data - status: \(status)")
            return nil
        }
    }
    
    /// Delete data from Keychain
    /// - Parameters:
    ///   - service: Service identifier
    ///   - account: Account identifier
    func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            print("✅ KeychainHelper: Successfully deleted data for \(service)/\(account)")
        } else if status == errSecItemNotFound {
            print("ℹ️ KeychainHelper: No data to delete for \(service)/\(account)")
        } else {
            print("⚠️ KeychainHelper: Failed to delete data - status: \(status)")
        }
    }
    
    /// Convenience method to save a string (JWT token)
    func saveToken(_ token: String, service: String = "paperboxd-jwt", account: String = "user-auth") {
        let trimmedToken = token.trimmingCharacters(in: .whitespaces)
        guard !trimmedToken.isEmpty else {
            print("❌ KeychainHelper: Attempted to save empty token - rejecting")
            return
        }
        if let data = trimmedToken.data(using: .utf8) {
            save(data, service: service, account: account)
        } else {
            print("❌ KeychainHelper: Failed to convert token to data")
        }
    }
    
    /// Convenience method to read a string (JWT token)
    func readToken(service: String = "paperboxd-jwt", account: String = "user-auth") -> String? {
        guard let data = read(service: service, account: account) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    /// Convenience method to delete a token
    func deleteToken(service: String = "paperboxd-jwt", account: String = "user-auth") {
        delete(service: service, account: account)
    }
}

