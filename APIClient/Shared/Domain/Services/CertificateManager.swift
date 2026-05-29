import Foundation
import Security
import CryptoKit

// MARK: - Certificate Manager

public final class CertificateManager {

    public static let shared = CertificateManager()
    private init() {}

    // MARK: - Client Certificates

    /// Import a .p12 certificate into the Keychain
    public func importP12(data: Data, passphrase: String, label: String) throws -> SecIdentity {
        var importItems: CFArray?
        let options: [String: Any] = [kSecImportExportPassphrase as String: passphrase]
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &importItems)
        guard status == errSecSuccess,
              let items = importItems as? [[String: Any]],
              let first = items.first,
              let identity = first[kSecImportItemIdentity as String] else {
            throw CertificateError.importFailed(status)
        }
        // Store in Keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecValueRef as String: identity,
            kSecAttrLabel as String: label
        ]
        SecItemDelete(addQuery as CFDictionary) // remove old if exists
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
            throw CertificateError.keychainStoreFailed(addStatus)
        }
        return identity as! SecIdentity
    }

    /// Retrieve all stored client identities
    public func allClientIdentities() -> [(label: String, identity: SecIdentity)] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else { return [] }
        return items.compactMap { dict in
            guard let identity = dict[kSecValueRef as String] else { return nil }
            let label = dict[kSecAttrLabel as String] as? String ?? "Unknown"
            return (label, identity as! SecIdentity)
        }
    }

    /// Delete a stored identity by label
    public func deleteIdentity(label: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: label
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Certificate Pinning

    public struct PinnedHost: Codable, Identifiable {
        public var id = UUID()
        public var hostPattern: String
        public var sha256PublicKeyHash: String

        public init(hostPattern: String, sha256PublicKeyHash: String) {
            self.hostPattern = hostPattern
            self.sha256PublicKeyHash = sha256PublicKeyHash
        }
    }

    @UserDefault("cert.pins", defaultValue: [])
    public var pinnedHosts: [PinnedHost]

    public func addPin(hostPattern: String, hash: String) {
        pinnedHosts.append(PinnedHost(hostPattern: hostPattern, sha256PublicKeyHash: hash))
    }

    public func removePin(id: UUID) {
        pinnedHosts.removeAll { $0.id == id }
    }

    /// Validate a server certificate against pins
    public func validatePin(for host: String, certificate: SecCertificate) -> Bool {
        let matching = pinnedHosts.filter { pin in
            fnmatch(pin.hostPattern, host, 0) == 0 ||
            pin.hostPattern == host ||
            pin.hostPattern == "*"
        }
        guard !matching.isEmpty else { return true } // no pin = pass
        let hash = publicKeyHash(for: certificate)
        return matching.contains { $0.sha256PublicKeyHash == hash }
    }

    private func publicKeyHash(for certificate: SecCertificate) -> String {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let keyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return ""
        }
        return keyData.sha256HexString
    }

    // MARK: - Custom CA Certificates

    public func importCustomCA(data: Data) throws -> SecCertificate {
        guard let cert = SecCertificateCreateWithData(nil, data as CFData) else {
            throw CertificateError.invalidCertificate
        }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: cert,
            kSecAttrLabel as String: "Custom CA"
        ]
        SecItemDelete(addQuery as CFDictionary)
        SecItemAdd(addQuery as CFDictionary, nil)
        return cert
    }

    // MARK: - Server Certificate Inspector

    public struct CertificateInfo: Identifiable {
        public let id = UUID()
        public let subject: String
        public let issuer: String
        public let serialNumber: String
        public let validFrom: Date?
        public let validTo: Date?
        public let san: [String]
        public let sha256Fingerprint: String
    }

    public func inspect(certificate: SecCertificate) -> CertificateInfo {
        let subject = SecCertificateCopySubjectSummary(certificate) as String? ?? "Unknown"
        // For a complete implementation, parse the ASN.1 DER directly.
        // Here we provide a reasonable subset via public API.
        let certData = SecCertificateCopyData(certificate) as Data
        return CertificateInfo(
            subject: subject,
            issuer: "See certificate data",
            serialNumber: "",
            validFrom: nil,
            validTo: nil,
            san: [],
            sha256Fingerprint: certData.sha256HexString
        )
    }
}

// MARK: - Errors

public enum CertificateError: LocalizedError {
    case importFailed(OSStatus)
    case keychainStoreFailed(OSStatus)
    case invalidCertificate

    public var errorDescription: String? {
        switch self {
        case .importFailed(let s): return "Certificate import failed (OSStatus \(s))"
        case .keychainStoreFailed(let s): return "Keychain storage failed (OSStatus \(s))"
        case .invalidCertificate: return "Invalid certificate data"
        }
    }
}

// MARK: - UserDefault Property Wrapper

@propertyWrapper
public struct UserDefault<T: Codable> {
    let key: String
    let defaultValue: T

    public init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    public var wrappedValue: T {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(T.self, from: data) else {
                return defaultValue
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }
    }
}

// MARK: - Data extensions

extension Data {
    var sha256HexString: String {
        let hash = SHA256.hash(data: self)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
