import Foundation

// MARK: - AuthConfig

public struct AuthConfig: Codable, Sendable {
    public var type: AuthType
    public var apiKeyConfig: APIKeyConfig?
    public var bearerConfig: BearerConfig?
    public var basicConfig: BasicAuthConfig?
    public var digestConfig: DigestAuthConfig?
    public var oauth1Config: OAuth1Config?
    public var oauth2Config: OAuth2Config?
    public var awsV4Config: AWSV4Config?
    public var ntlmConfig: NTLMConfig?
    public var hawkConfig: HawkConfig?
    public var jwtConfig: JWTConfig?

    public init(type: AuthType = .none) {
        self.type = type
    }
}

// MARK: - API Key Config

public struct APIKeyConfig: Codable, Sendable {
    public var key: String
    public var value: String
    public var addTo: APIKeyLocation

    public enum APIKeyLocation: String, Codable, Sendable {
        case header = "Header"
        case queryParam = "Query Param"
    }

    public init(key: String = "X-API-Key", value: String = "", addTo: APIKeyLocation = .header) {
        self.key = key
        self.value = value
        self.addTo = addTo
    }
}

// MARK: - Bearer Config

public struct BearerConfig: Codable, Sendable {
    public var token: String
    public var prefix: String

    public init(token: String = "", prefix: String = "Bearer") {
        self.token = token
        self.prefix = prefix
    }
}

// MARK: - Basic Auth Config

public struct BasicAuthConfig: Codable, Sendable {
    public var username: String
    public var password: String
    public var showPassword: Bool

    public init(username: String = "", password: String = "", showPassword: Bool = false) {
        self.username = username
        self.password = password
        self.showPassword = showPassword
    }

    public var encoded: String {
        let credentials = "\(username):\(password)"
        return Data(credentials.utf8).base64EncodedString()
    }
}

// MARK: - Digest Auth Config

public struct DigestAuthConfig: Codable, Sendable {
    public var username: String
    public var password: String
    public var realm: String
    public var nonce: String
    public var algorithm: String
    public var qop: String
    public var nonceCount: String
    public var clientNonce: String
    public var opaque: String

    public init(
        username: String = "", password: String = "", realm: String = "",
        nonce: String = "", algorithm: String = "MD5", qop: String = "",
        nonceCount: String = "00000001", clientNonce: String = "",
        opaque: String = ""
    ) {
        self.username = username; self.password = password; self.realm = realm
        self.nonce = nonce; self.algorithm = algorithm; self.qop = qop
        self.nonceCount = nonceCount; self.clientNonce = clientNonce; self.opaque = opaque
    }
}

// MARK: - OAuth 1.0 Config

public struct OAuth1Config: Codable, Sendable {
    public var consumerKey: String
    public var consumerSecret: String
    public var token: String
    public var tokenSecret: String
    public var signatureMethod: SignatureMethod
    public var realm: String
    public var version: String
    public var addTo: OAuth1Location

    public enum SignatureMethod: String, Codable, Sendable, CaseIterable {
        case hmacSHA1 = "HMAC-SHA1"
        case rsaSHA1 = "RSA-SHA1"
        case plaintext = "PLAINTEXT"
    }

    public enum OAuth1Location: String, Codable, Sendable {
        case header = "Request Header"
        case body = "Request Body"
        case queryParam = "Query Params"
    }

    public init(
        consumerKey: String = "", consumerSecret: String = "",
        token: String = "", tokenSecret: String = "",
        signatureMethod: SignatureMethod = .hmacSHA1,
        realm: String = "", version: String = "1.0",
        addTo: OAuth1Location = .header
    ) {
        self.consumerKey = consumerKey; self.consumerSecret = consumerSecret
        self.token = token; self.tokenSecret = tokenSecret
        self.signatureMethod = signatureMethod; self.realm = realm
        self.version = version; self.addTo = addTo
    }
}

// MARK: - OAuth 2.0 Config

public struct OAuth2Config: Codable, Sendable {
    public var grantType: GrantType
    public var accessTokenURL: String
    public var authorizationURL: String
    public var clientID: String
    public var clientSecret: String
    public var scope: String
    public var redirectURI: String
    public var username: String      // for password grant
    public var password: String      // for password grant
    public var state: String
    public var usePKCE: Bool
    public var tokenPlacement: TokenPlacement
    public var headerPrefix: String
    public var customHeaderName: String
    public var storedToken: StoredOAuthToken?
    public var autoRefresh: Bool

    public enum GrantType: String, Codable, Sendable, CaseIterable {
        case authorizationCode = "Authorization Code"
        case clientCredentials = "Client Credentials"
        case passwordCredentials = "Password Credentials"
        case implicit = "Implicit"
    }

    public enum TokenPlacement: String, Codable, Sendable {
        case header = "Request Header"
        case queryParam = "Query Param"
    }

    public init(
        grantType: GrantType = .authorizationCode,
        accessTokenURL: String = "", authorizationURL: String = "",
        clientID: String = "", clientSecret: String = "",
        scope: String = "", redirectURI: String = "",
        username: String = "", password: String = "",
        state: String = "", usePKCE: Bool = false,
        tokenPlacement: TokenPlacement = .header,
        headerPrefix: String = "Bearer", customHeaderName: String = "Authorization",
        storedToken: StoredOAuthToken? = nil, autoRefresh: Bool = true
    ) {
        self.grantType = grantType; self.accessTokenURL = accessTokenURL
        self.authorizationURL = authorizationURL; self.clientID = clientID
        self.clientSecret = clientSecret; self.scope = scope
        self.redirectURI = redirectURI; self.username = username
        self.password = password; self.state = state; self.usePKCE = usePKCE
        self.tokenPlacement = tokenPlacement; self.headerPrefix = headerPrefix
        self.customHeaderName = customHeaderName; self.storedToken = storedToken
        self.autoRefresh = autoRefresh
    }
}

// MARK: - Stored OAuth Token

public struct StoredOAuthToken: Codable, Sendable {
    public var accessToken: String
    public var tokenType: String
    public var expiresAt: Date?
    public var refreshToken: String?
    public var scope: String?

    public init(
        accessToken: String, tokenType: String = "Bearer",
        expiresAt: Date? = nil, refreshToken: String? = nil, scope: String? = nil
    ) {
        self.accessToken = accessToken; self.tokenType = tokenType
        self.expiresAt = expiresAt; self.refreshToken = refreshToken; self.scope = scope
    }

    public var isExpired: Bool {
        guard let expiry = expiresAt else { return false }
        return expiry <= Date()
    }

    public var expiresIn: TimeInterval? {
        guard let expiry = expiresAt else { return nil }
        return expiry.timeIntervalSinceNow
    }
}

// MARK: - AWS V4 Config

public struct AWSV4Config: Codable, Sendable {
    public var accessKey: String
    public var secretKey: String
    public var sessionToken: String
    public var region: String
    public var serviceName: String

    public init(
        accessKey: String = "", secretKey: String = "",
        sessionToken: String = "", region: String = "us-east-1",
        serviceName: String = "execute-api"
    ) {
        self.accessKey = accessKey; self.secretKey = secretKey
        self.sessionToken = sessionToken; self.region = region
        self.serviceName = serviceName
    }
}

// MARK: - NTLM Config

public struct NTLMConfig: Codable, Sendable {
    public var username: String
    public var password: String
    public var domain: String

    public init(username: String = "", password: String = "", domain: String = "") {
        self.username = username; self.password = password; self.domain = domain
    }
}

// MARK: - Hawk Config

public struct HawkConfig: Codable, Sendable {
    public var authID: String
    public var authKey: String
    public var algorithm: HawkAlgorithm
    public var user: String
    public var nonce: String
    public var extraData: String
    public var appID: String
    public var delegation: String
    public var timestamp: String

    public enum HawkAlgorithm: String, Codable, Sendable, CaseIterable {
        case sha256 = "sha256"
        case sha1 = "sha1"
    }

    public init(
        authID: String = "", authKey: String = "",
        algorithm: HawkAlgorithm = .sha256, user: String = "",
        nonce: String = "", extraData: String = "",
        appID: String = "", delegation: String = "", timestamp: String = ""
    ) {
        self.authID = authID; self.authKey = authKey; self.algorithm = algorithm
        self.user = user; self.nonce = nonce; self.extraData = extraData
        self.appID = appID; self.delegation = delegation; self.timestamp = timestamp
    }
}

// MARK: - JWT Config

public struct JWTConfig: Codable, Sendable {
    public var algorithm: JWTAlgorithm
    public var secret: String
    public var payload: String      // JSON string
    public var addTo: JWTLocation
    public var headerPrefix: String
    public var queryParamKey: String
    public var isBase64Encoded: Bool

    public enum JWTAlgorithm: String, Codable, Sendable, CaseIterable {
        case hs256 = "HS256"
        case hs384 = "HS384"
        case hs512 = "HS512"
        case rs256 = "RS256"
        case es256 = "ES256"
    }

    public enum JWTLocation: String, Codable, Sendable {
        case header = "Request Header"
        case queryParam = "Query Param"
    }

    public init(
        algorithm: JWTAlgorithm = .hs256, secret: String = "",
        payload: String = "{}", addTo: JWTLocation = .header,
        headerPrefix: String = "Bearer", queryParamKey: String = "token",
        isBase64Encoded: Bool = false
    ) {
        self.algorithm = algorithm; self.secret = secret; self.payload = payload
        self.addTo = addTo; self.headerPrefix = headerPrefix
        self.queryParamKey = queryParamKey; self.isBase64Encoded = isBase64Encoded
    }
}
