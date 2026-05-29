import Foundation

// MARK: - HTTP Method

public enum HTTPMethod: String, CaseIterable, Codable, Sendable {
    case GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS, TRACE, CONNECT
    case custom

    public var displayName: String { rawValue }

    public static func from(_ string: String) -> HTTPMethod {
        HTTPMethod(rawValue: string.uppercased()) ?? .custom
    }
}

// MARK: - Body Type

public enum BodyType: String, CaseIterable, Codable, Sendable {
    case none = "none"
    case raw = "raw"
    case formData = "form-data"
    case urlEncoded = "x-www-form-urlencoded"
    case binary = "binary"
    case graphQL = "graphql"

    public var contentType: String? {
        switch self {
        case .none: return nil
        case .raw: return nil // determined by raw sub-type
        case .formData: return "multipart/form-data"
        case .urlEncoded: return "application/x-www-form-urlencoded"
        case .binary: return "application/octet-stream"
        case .graphQL: return "application/json"
        }
    }
}

// MARK: - Raw Body Type

public enum RawBodyType: String, CaseIterable, Codable, Sendable {
    case text = "Text"
    case json = "JSON"
    case xml = "XML"
    case html = "HTML"
    case javascript = "JavaScript"
    case yaml = "YAML"

    public var contentType: String {
        switch self {
        case .text: return "text/plain"
        case .json: return "application/json"
        case .xml: return "application/xml"
        case .html: return "text/html"
        case .javascript: return "application/javascript"
        case .yaml: return "application/x-yaml"
        }
    }

    public var language: SyntaxLanguage {
        switch self {
        case .text: return .plain
        case .json: return .json
        case .xml: return .xml
        case .html: return .html
        case .javascript: return .javascript
        case .yaml: return .yaml
        }
    }
}

// MARK: - Syntax Language

public enum SyntaxLanguage: String, Codable, Sendable {
    case plain, json, xml, html, javascript, graphql, yaml
}

// MARK: - Auth Type

public enum AuthType: String, CaseIterable, Codable, Sendable {
    case none = "No Auth"
    case apiKey = "API Key"
    case bearer = "Bearer Token"
    case basic = "Basic Auth"
    case digest = "Digest Auth"
    case oauth1 = "OAuth 1.0"
    case oauth2 = "OAuth 2.0"
    case awsV4 = "AWS Signature V4"
    case ntlm = "NTLM"
    case hawk = "Hawk"
    case jwt = "JWT Bearer"
    case inherit = "Inherit auth from parent"
}

// MARK: - HTTPRequest (Domain Entity — not a SwiftData model)

public struct HTTPRequest: Identifiable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var method: HTTPMethod
    public var url: String
    public var queryParams: [KeyValuePair]
    public var headers: [KeyValuePair]
    public var auth: AuthConfig
    public var body: BodyPayload
    public var preRequestScript: String
    public var testScript: String
    public var settings: RequestSettings
    public var description: String
    public var customMethodName: String?

    public init(
        id: UUID = UUID(),
        name: String = "New Request",
        method: HTTPMethod = .GET,
        url: String = "",
        queryParams: [KeyValuePair] = [],
        headers: [KeyValuePair] = [],
        auth: AuthConfig = AuthConfig(),
        body: BodyPayload = BodyPayload(),
        preRequestScript: String = "",
        testScript: String = "",
        settings: RequestSettings = RequestSettings(),
        description: String = "",
        customMethodName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.method = method
        self.url = url
        self.queryParams = queryParams
        self.headers = headers
        self.auth = auth
        self.body = body
        self.preRequestScript = preRequestScript
        self.testScript = testScript
        self.settings = settings
        self.description = description
        self.customMethodName = customMethodName
    }

    public var effectiveMethodName: String {
        method == .custom ? (customMethodName ?? "GET") : method.rawValue
    }
}

// MARK: - Request Settings

public struct RequestSettings: Codable, Sendable {
    public var followRedirects: Bool
    public var maxRedirects: Int
    public var sslVerification: Bool
    public var clientCertificateID: String?
    public var proxyMode: ProxyMode
    public var timeoutMs: Int
    public var encodeURL: Bool
    public var sendCookies: Bool
    public var storeCookies: Bool

    public init(
        followRedirects: Bool = true,
        maxRedirects: Int = 10,
        sslVerification: Bool = true,
        clientCertificateID: String? = nil,
        proxyMode: ProxyMode = .system,
        timeoutMs: Int = 30000,
        encodeURL: Bool = true,
        sendCookies: Bool = true,
        storeCookies: Bool = true
    ) {
        self.followRedirects = followRedirects
        self.maxRedirects = maxRedirects
        self.sslVerification = sslVerification
        self.clientCertificateID = clientCertificateID
        self.proxyMode = proxyMode
        self.timeoutMs = timeoutMs
        self.encodeURL = encodeURL
        self.sendCookies = sendCookies
        self.storeCookies = storeCookies
    }
}

// MARK: - Proxy Mode

public enum ProxyMode: String, Codable, Sendable {
    case system = "System"
    case custom = "Custom"
    case none = "No Proxy"
}
