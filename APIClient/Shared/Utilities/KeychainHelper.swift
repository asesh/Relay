import Foundation
import Security

// MARK: - KeychainHelper

/// Thread-safe Keychain wrapper using the Security framework directly.
public final class KeychainHelper: Sendable {

    public static let shared = KeychainHelper(service: Constants.keychainService)

    private let service: String

    public init(service: String = Constants.keychainService) {
        self.service = service
    }

    // MARK: - Save

    @discardableResult
    public func save(_ data: Data, forKey key: String, accessGroup: String? = nil) -> Bool {
        delete(forKey: key, accessGroup: accessGroup)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    @discardableResult
    public func save(_ string: String, forKey key: String, accessGroup: String? = nil) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(data, forKey: key, accessGroup: accessGroup)
    }

    // MARK: - Load

    public func load(forKey key: String, accessGroup: String? = nil) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    public func loadString(forKey key: String, accessGroup: String? = nil) -> String? {
        guard let data = load(forKey: key, accessGroup: accessGroup) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    @discardableResult
    public func delete(forKey key: String, accessGroup: String? = nil) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - OAuth Token helpers

    public func saveOAuthToken(_ token: StoredOAuthToken, forID id: String) {
        guard let data = try? JSONEncoder().encode(token) else { return }
        save(data, forKey: "oauth_token_\(id)")
    }

    public func loadOAuthToken(forID id: String) -> StoredOAuthToken? {
        guard let data = load(forKey: "oauth_token_\(id)") else { return nil }
        return try? JSONDecoder().decode(StoredOAuthToken.self, from: data)
    }

    public func deleteOAuthToken(forID id: String) {
        delete(forKey: "oauth_token_\(id)")
    }

    // MARK: - Certificate helpers

    public func saveCertificateData(_ data: Data, forHostPattern pattern: String) {
        save(data, forKey: "cert_\(pattern)")
    }

    public func loadCertificateData(forHostPattern pattern: String) -> Data? {
        load(forKey: "cert_\(pattern)")
    }
}
