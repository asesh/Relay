import Foundation
import CryptoKit
import AuthenticationServices

// MARK: - Auth Handler

/// Injects authentication headers/params into an HTTPRequest based on AuthConfig.
public final class AuthHandler: Sendable {

    public init() {}

    /// Inject auth into the request. Returns a modified URLRequest.
    public func inject(auth: AuthConfig, into urlRequest: inout URLRequest, for request: HTTPRequest) async throws {
        switch auth.type {
        case .none, .inherit:
            break
        case .apiKey:
            guard let cfg = auth.apiKeyConfig else { return }
            if cfg.addTo == .header {
                urlRequest.setValue(cfg.value, forHTTPHeaderField: cfg.key)
            } else {
                // Add to query params — URL mutation happens in resolver
                appendQueryParam(key: cfg.key, value: cfg.value, to: &urlRequest)
            }
        case .bearer:
            guard let cfg = auth.bearerConfig else { return }
            urlRequest.setValue("\(cfg.prefix) \(cfg.token)", forHTTPHeaderField: "Authorization")
        case .basic:
            guard let cfg = auth.basicConfig else { return }
            urlRequest.setValue("Basic \(cfg.encoded)", forHTTPHeaderField: "Authorization")
        case .digest:
            guard let cfg = auth.digestConfig else { return }
            let header = buildDigestHeader(cfg: cfg, method: urlRequest.httpMethod ?? "GET",
                                            uri: urlRequest.url?.path ?? "/")
            urlRequest.setValue(header, forHTTPHeaderField: "Authorization")
        case .oauth1:
            guard let cfg = auth.oauth1Config else { return }
            let header = try buildOAuth1Header(cfg: cfg, urlRequest: urlRequest)
            urlRequest.setValue(header, forHTTPHeaderField: "Authorization")
        case .oauth2:
            guard let cfg = auth.oauth2Config else { return }
            try await injectOAuth2(cfg: cfg, into: &urlRequest)
        case .awsV4:
            guard let cfg = auth.awsV4Config else { return }
            try injectAWSV4(cfg: cfg, into: &urlRequest)
        case .ntlm:
            // NTLM handled via URLSessionDelegate challenge
            break
        case .hawk:
            guard let cfg = auth.hawkConfig else { return }
            let header = buildHawkHeader(cfg: cfg, urlRequest: urlRequest)
            urlRequest.setValue(header, forHTTPHeaderField: "Authorization")
        case .jwt:
            guard let cfg = auth.jwtConfig else { return }
            let token = try buildJWT(cfg: cfg)
            if cfg.addTo == .header {
                urlRequest.setValue("\(cfg.headerPrefix) \(token)", forHTTPHeaderField: "Authorization")
            } else {
                appendQueryParam(key: cfg.queryParamKey, value: token, to: &urlRequest)
            }
        }
    }

    // MARK: - Digest Auth

    private func buildDigestHeader(cfg: DigestAuthConfig, method: String, uri: String) -> String {
        let ha1 = md5("\(cfg.username):\(cfg.realm):\(cfg.password)")
        let ha2 = md5("\(method):\(uri)")
        let response: String
        if cfg.qop.isEmpty {
            response = md5("\(ha1):\(cfg.nonce):\(ha2)")
        } else {
            response = md5("\(ha1):\(cfg.nonce):\(cfg.nonceCount):\(cfg.clientNonce):\(cfg.qop):\(ha2)")
        }
        var parts = [
            "username=\"\(cfg.username)\"",
            "realm=\"\(cfg.realm)\"",
            "nonce=\"\(cfg.nonce)\"",
            "uri=\"\(uri)\"",
            "response=\"\(response)\""
        ]
        if !cfg.qop.isEmpty {
            parts += ["qop=\(cfg.qop)", "nc=\(cfg.nonceCount)", "cnonce=\"\(cfg.clientNonce)\""]
        }
        if !cfg.opaque.isEmpty { parts.append("opaque=\"\(cfg.opaque)\"") }
        return "Digest " + parts.joined(separator: ", ")
    }

    // MARK: - OAuth 1.0

    private func buildOAuth1Header(cfg: OAuth1Config, urlRequest: URLRequest) throws -> String {
        guard let url = urlRequest.url else { throw AuthError.missingURL }

        let timestamp = String(Int(Date().timeIntervalSince1970))
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var oauthParams: [(String, String)] = [
            ("oauth_consumer_key", cfg.consumerKey),
            ("oauth_nonce", nonce),
            ("oauth_signature_method", cfg.signatureMethod.rawValue),
            ("oauth_timestamp", timestamp),
            ("oauth_token", cfg.token),
            ("oauth_version", cfg.version),
        ]

        // Build signature base string
        let method = urlRequest.httpMethod ?? "GET"
        let baseURL = "\(url.scheme ?? "https")://\(url.host ?? "")\(url.path)"

        var allParams = oauthParams
        // Include query params
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.forEach { allParams.append(($0.name, $0.value ?? "")) }

        let paramString = allParams
            .map { (percentEncode($0.0), percentEncode($0.1)) }
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")

        let signatureBase = [percentEncode(method), percentEncode(baseURL), percentEncode(paramString)]
            .joined(separator: "&")

        let signingKey = "\(percentEncode(cfg.consumerSecret))&\(percentEncode(cfg.tokenSecret))"

        let signature: String
        switch cfg.signatureMethod {
        case .hmacSHA1:
            signature = hmacSHA1(key: signingKey, message: signatureBase)
        case .plaintext:
            signature = signingKey
        case .rsaSHA1:
            throw AuthError.unsupportedAlgorithm("RSA-SHA1 requires private key material")
        }

        oauthParams.append(("oauth_signature", signature))
        let headerValue = oauthParams
            .map { "\(percentEncode($0.0))=\"\(percentEncode($0.1))\"" }
            .joined(separator: ", ")

        let realmPrefix = cfg.realm.isEmpty ? "" : "realm=\"\(cfg.realm)\", "
        return "OAuth \(realmPrefix)\(headerValue)"
    }

    // MARK: - OAuth 2.0

    private func injectOAuth2(cfg: OAuth2Config, into urlRequest: inout URLRequest) async throws {
        var token: StoredOAuthToken?

        // Check keychain cache
        if let stored = KeychainHelper.shared.loadOAuthToken(forID: cfg.clientID) {
            if !stored.isExpired {
                token = stored
            } else if let refreshToken = stored.refreshToken, !refreshToken.isEmpty, cfg.autoRefresh {
                token = try await refreshOAuth2Token(cfg: cfg, refreshToken: refreshToken)
            }
        }

        if token == nil {
            switch cfg.grantType {
            case .clientCredentials:
                token = try await fetchClientCredentialsToken(cfg: cfg)
            case .passwordCredentials:
                token = try await fetchPasswordToken(cfg: cfg)
            default:
                throw AuthError.tokenRequired
            }
        }

        guard let accessToken = token?.accessToken else { throw AuthError.tokenRequired }

        if cfg.tokenPlacement == .header {
            urlRequest.setValue("\(cfg.headerPrefix) \(accessToken)",
                                forHTTPHeaderField: cfg.customHeaderName)
        } else {
            appendQueryParam(key: "access_token", value: accessToken, to: &urlRequest)
        }
    }

    private func fetchClientCredentialsToken(cfg: OAuth2Config) async throws -> StoredOAuthToken {
        guard let url = URL(string: cfg.accessTokenURL) else { throw AuthError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let credentials = "\(cfg.clientID):\(cfg.clientSecret)"
        let encoded = Data(credentials.utf8).base64EncodedString()
        req.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        let body = "grant_type=client_credentials&scope=\(cfg.scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        req.httpBody = body.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try parseTokenResponse(data: data, cfg: cfg)
    }

    private func fetchPasswordToken(cfg: OAuth2Config) async throws -> StoredOAuthToken {
        guard let url = URL(string: cfg.accessTokenURL) else { throw AuthError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=password&username=\(cfg.username.urlEncoded)&password=\(cfg.password.urlEncoded)&client_id=\(cfg.clientID.urlEncoded)&client_secret=\(cfg.clientSecret.urlEncoded)"
        req.httpBody = body.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try parseTokenResponse(data: data, cfg: cfg)
    }

    private func refreshOAuth2Token(cfg: OAuth2Config, refreshToken: String) async throws -> StoredOAuthToken {
        guard let url = URL(string: cfg.accessTokenURL) else { throw AuthError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=refresh_token&refresh_token=\(refreshToken.urlEncoded)&client_id=\(cfg.clientID.urlEncoded)&client_secret=\(cfg.clientSecret.urlEncoded)"
        req.httpBody = body.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try parseTokenResponse(data: data, cfg: cfg)
    }

    private func parseTokenResponse(data: Data, cfg: OAuth2Config) throws -> StoredOAuthToken {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.invalidTokenResponse
        }
        guard let accessToken = json["access_token"] as? String else {
            throw AuthError.invalidTokenResponse
        }
        let tokenType = json["token_type"] as? String ?? "Bearer"
        let expiresIn = json["expires_in"] as? TimeInterval
        let expiresAt = expiresIn.map { Date().addingTimeInterval($0) }
        let refreshToken = json["refresh_token"] as? String
        let scope = json["scope"] as? String
        let token = StoredOAuthToken(
            accessToken: accessToken, tokenType: tokenType,
            expiresAt: expiresAt, refreshToken: refreshToken, scope: scope
        )
        KeychainHelper.shared.saveOAuthToken(token, forID: cfg.clientID)
        return token
    }

    // MARK: - AWS Signature V4

    private func injectAWSV4(cfg: AWSV4Config, into urlRequest: inout URLRequest) throws {
        guard let url = urlRequest.url else { throw AuthError.missingURL }
        let now = Date()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime,
                                        .withTimeZone, .withDashSeparatorInDate,
                                        .withColonSeparatorInTime]
        let amzDate = iso8601Basic(date: now)
        let dateStamp = amzDateStamp(date: now)

        urlRequest.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        if !cfg.sessionToken.isEmpty {
            urlRequest.setValue(cfg.sessionToken, forHTTPHeaderField: "x-amz-security-token")
        }

        let method = urlRequest.httpMethod ?? "GET"
        let canonicalURI = url.path.isEmpty ? "/" : url.path
        let canonicalQuery = canonicalQueryString(url: url)
        let payloadHash = sha256Hash(urlRequest.httpBody ?? Data())

        var headers = urlRequest.allHTTPHeaderFields ?? [:]
        headers["host"] = url.host ?? ""
        headers["x-amz-date"] = amzDate
        if !cfg.sessionToken.isEmpty { headers["x-amz-security-token"] = cfg.sessionToken }

        let sortedHeaderNames = headers.keys.sorted().map { $0.lowercased() }
        let canonicalHeaders = sortedHeaderNames
            .compactMap { key -> String? in
                guard let val = headers.first(where: { $0.key.lowercased() == key })?.value else { return nil }
                return "\(key):\(val.trimmingCharacters(in: .whitespaces))"
            }
            .joined(separator: "\n") + "\n"
        let signedHeaders = sortedHeaderNames.joined(separator: ";")

        let canonicalRequest = [method, canonicalURI, canonicalQuery,
                                 canonicalHeaders, signedHeaders, payloadHash]
            .joined(separator: "\n")

        let algorithm = "AWS4-HMAC-SHA256"
        let credentialScope = "\(dateStamp)/\(cfg.region)/\(cfg.serviceName)/aws4_request"
        let stringToSign = [algorithm, amzDate, credentialScope, sha256Hash(Data(canonicalRequest.utf8))]
            .joined(separator: "\n")

        let signingKey = getAWSSigningKey(secret: cfg.secretKey, date: dateStamp,
                                          region: cfg.region, service: cfg.serviceName)
        let signature = hmacSHA256Hex(key: signingKey, message: Data(stringToSign.utf8))

        let authHeader = "\(algorithm) Credential=\(cfg.accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        urlRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
    }

    // MARK: - Hawk Auth

    private func buildHawkHeader(cfg: HawkConfig, urlRequest: URLRequest) -> String {
        let ts = String(Int(Date().timeIntervalSince1970))
        let nonce = cfg.nonce.isEmpty ? String(UUID().uuidString.prefix(8)) : cfg.nonce
        let method = urlRequest.httpMethod ?? "GET"
        let uri = urlRequest.url?.path ?? "/"
        let host = urlRequest.url?.host ?? ""
        let port = urlRequest.url?.port ?? (urlRequest.url?.scheme == "https" ? 443 : 80)

        var normalized = "hawk.1.header\n\(ts)\n\(nonce)\n\(method)\n\(uri)\n\(host)\n\(port)\n\n\n"
        if !cfg.extraData.isEmpty { normalized = "hawk.1.header\n\(ts)\n\(nonce)\n\(method)\n\(uri)\n\(host)\n\(port)\n\n\(cfg.extraData)\n" }

        let mac: String
        switch cfg.algorithm {
        case .sha256: mac = hmacSHA256Base64(key: cfg.authKey, message: normalized)
        case .sha1: mac = hmacSHA1(key: cfg.authKey, message: normalized)
        }

        var parts = [
            "id=\"\(cfg.authID)\"", "ts=\"\(ts)\"",
            "nonce=\"\(nonce)\"", "mac=\"\(mac)\""
        ]
        if !cfg.extraData.isEmpty { parts.insert("ext=\"\(cfg.extraData)\"", at: parts.count - 1) }
        return "Hawk " + parts.joined(separator: ", ")
    }

    // MARK: - JWT

    private func buildJWT(cfg: JWTConfig) throws -> String {
        let header = ["alg": cfg.algorithm.rawValue, "typ": "JWT"]
        let headerData = try JSONSerialization.data(withJSONObject: header)
        let headerEncoded = base64URLEncode(headerData)

        guard let payloadData = cfg.payload.data(using: .utf8),
              let payloadObj = try? JSONSerialization.jsonObject(with: payloadData),
              let normalizedPayload = try? JSONSerialization.data(withJSONObject: payloadObj) else {
            throw AuthError.invalidJWTPayload
        }
        let payloadEncoded = base64URLEncode(normalizedPayload)

        let signingInput = "\(headerEncoded).\(payloadEncoded)"
        let secretData = cfg.isBase64Encoded
            ? Data(base64Encoded: cfg.secret) ?? Data(cfg.secret.utf8)
            : Data(cfg.secret.utf8)

        let signature: String
        switch cfg.algorithm {
        case .hs256:
            let key = SymmetricKey(data: secretData)
            let mac = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: key)
            signature = base64URLEncode(Data(mac))
        case .hs384:
            let key = SymmetricKey(data: secretData)
            let mac = HMAC<SHA384>.authenticationCode(for: Data(signingInput.utf8), using: key)
            signature = base64URLEncode(Data(mac))
        case .hs512:
            let key = SymmetricKey(data: secretData)
            let mac = HMAC<SHA512>.authenticationCode(for: Data(signingInput.utf8), using: key)
            signature = base64URLEncode(Data(mac))
        case .rs256, .es256:
            throw AuthError.unsupportedAlgorithm("\(cfg.algorithm.rawValue) requires private key material")
        }
        return "\(signingInput).\(signature)"
    }

    // MARK: - Helpers

    private func appendQueryParam(key: String, value: String, to request: inout URLRequest) {
        guard let url = request.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: key, value: value))
        components.queryItems = items
        request.url = components.url
    }

    private func percentEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .init(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) ?? string
    }

    private func md5(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func hmacSHA1(key: String, message: String) -> String {
        let keyData = Data(key.utf8)
        let messageData = Data(message.utf8)
        let key = SymmetricKey(data: keyData)
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: messageData, using: key)
        return Data(mac).base64EncodedString()
    }

    private func hmacSHA256Base64(key: String, message: String) -> String {
        let keyData = Data(key.utf8)
        let k = SymmetricKey(data: keyData)
        let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: k)
        return Data(mac).base64EncodedString()
    }

    private func hmacSHA256Hex(key: Data, message: Data) -> String {
        let k = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: message, using: k)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    private func sha256Hash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func iso8601Basic(date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(abbreviation: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f.string(from: date)
    }

    private func amzDateStamp(date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(abbreviation: "UTC")
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    private func canonicalQueryString(url: URL) -> String {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return "" }
        return items
            .map { (percentEncode($0.name), percentEncode($0.value ?? "")) }
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")
    }

    private func getAWSSigningKey(secret: String, date: String, region: String, service: String) -> Data {
        func hmac(key: Data, data: String) -> Data {
            let k = SymmetricKey(data: key)
            let mac = HMAC<SHA256>.authenticationCode(for: Data(data.utf8), using: k)
            return Data(mac)
        }
        let kSecret = Data(("AWS4" + secret).utf8)
        let kDate = hmac(key: kSecret, data: date)
        let kRegion = hmac(key: kDate, data: region)
        let kService = hmac(key: kRegion, data: service)
        return hmac(key: kService, data: "aws4_request")
    }
}

// MARK: - Auth Error

public enum AuthError: LocalizedError {
    case missingURL
    case invalidURL
    case tokenRequired
    case invalidTokenResponse
    case unsupportedAlgorithm(String)
    case invalidJWTPayload
    case oauth2FlowRequired

    public var errorDescription: String? {
        switch self {
        case .missingURL: return "Request URL is missing"
        case .invalidURL: return "Invalid token endpoint URL"
        case .tokenRequired: return "Access token required. Please authorize first."
        case .invalidTokenResponse: return "Invalid token response from server"
        case .unsupportedAlgorithm(let a): return "Unsupported algorithm: \(a)"
        case .invalidJWTPayload: return "Invalid JWT payload JSON"
        case .oauth2FlowRequired: return "OAuth 2.0 authorization flow required"
        }
    }
}

// MARK: - String + URL Encoding

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
