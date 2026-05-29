import Foundation

// MARK: - HTTPResponse

public struct HTTPResponse: Identifiable, Sendable {
    public var id: UUID
    public var statusCode: Int
    public var statusText: String
    public var headers: [String: String]
    public var body: Data
    public var requestDuration: TimeInterval  // seconds
    public var timeline: ResponseTimeline
    public var cookies: [HTTPCookieInfo]
    public var testResults: [TestResult]
    public var requestID: UUID?

    public init(
        id: UUID = UUID(),
        statusCode: Int,
        statusText: String = "",
        headers: [String: String] = [:],
        body: Data = Data(),
        requestDuration: TimeInterval = 0,
        timeline: ResponseTimeline = ResponseTimeline(),
        cookies: [HTTPCookieInfo] = [],
        testResults: [TestResult] = [],
        requestID: UUID? = nil
    ) {
        self.id = id
        self.statusCode = statusCode
        self.statusText = statusText.isEmpty ? HTTPResponse.defaultStatusText(for: statusCode) : statusText
        self.headers = headers
        self.body = body
        self.requestDuration = requestDuration
        self.timeline = timeline
        self.cookies = cookies
        self.testResults = testResults
        self.requestID = requestID
    }

    public var durationMs: Int { Int(requestDuration * 1000) }

    public var bodySize: Int { body.count }

    public var contentType: String? {
        headers["Content-Type"] ?? headers["content-type"]
    }

    public var isJSON: Bool {
        contentType?.contains("application/json") == true
    }

    public var isXML: Bool {
        contentType?.contains("xml") == true
    }

    public var isHTML: Bool {
        contentType?.contains("text/html") == true
    }

    public var isImage: Bool {
        contentType?.contains("image/") == true
    }

    public var bodyString: String? {
        String(data: body, encoding: .utf8)
    }

    public var prettyBody: String? {
        guard isJSON, let str = bodyString else { return bodyString }
        if let data = str.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) {
            return String(data: pretty, encoding: .utf8)
        }
        return str
    }

    public var formattedSize: String {
        let bytes = Double(bodySize)
        if bytes < 1024 { return "\(bodySize) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", bytes / 1024) }
        return String(format: "%.1f MB", bytes / (1024 * 1024))
    }

    public var statusCategory: StatusCategory {
        switch statusCode {
        case 100..<200: return .informational
        case 200..<300: return .success
        case 300..<400: return .redirection
        case 400..<500: return .clientError
        case 500..<600: return .serverError
        default: return .unknown
        }
    }

    static func defaultStatusText(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 301: return "Moved Permanently"
        case 302: return "Found"
        case 304: return "Not Modified"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 422: return "Unprocessable Entity"
        case 429: return "Too Many Requests"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        default: return "Unknown"
        }
    }
}

// MARK: - Status Category

public enum StatusCategory: Sendable {
    case informational, success, redirection, clientError, serverError, unknown

    public init(code: Int) {
        switch code {
        case 100..<200: self = .informational
        case 200..<300: self = .success
        case 300..<400: self = .redirection
        case 400..<500: self = .clientError
        case 500..<600: self = .serverError
        default: self = .unknown
        }
    }
}

// MARK: - Response Timeline

public struct ResponseTimeline: Sendable {
    public var dnsLookupMs: Double
    public var tcpConnectMs: Double
    public var tlsHandshakeMs: Double
    public var requestSentMs: Double
    public var waitingMs: Double   // TTFB
    public var downloadMs: Double
    public var totalMs: Double

    public init(
        dnsLookupMs: Double = 0,
        tcpConnectMs: Double = 0,
        tlsHandshakeMs: Double = 0,
        requestSentMs: Double = 0,
        waitingMs: Double = 0,
        downloadMs: Double = 0,
        totalMs: Double = 0
    ) {
        self.dnsLookupMs = dnsLookupMs
        self.tcpConnectMs = tcpConnectMs
        self.tlsHandshakeMs = tlsHandshakeMs
        self.requestSentMs = requestSentMs
        self.waitingMs = waitingMs
        self.downloadMs = downloadMs
        self.totalMs = totalMs
    }
}

// MARK: - Test Result

public struct TestResult: Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var passed: Bool
    public var errorMessage: String?

    public init(id: UUID = UUID(), name: String, passed: Bool, errorMessage: String? = nil) {
        self.id = id
        self.name = name
        self.passed = passed
        self.errorMessage = errorMessage
    }
}

// MARK: - Cookie Info

public struct HTTPCookieInfo: Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var value: String
    public var domain: String
    public var path: String
    public var expires: Date?
    public var httpOnly: Bool
    public var secure: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        value: String,
        domain: String = "",
        path: String = "/",
        expires: Date? = nil,
        httpOnly: Bool = false,
        secure: Bool = false
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expires = expires
        self.httpOnly = httpOnly
        self.secure = secure
    }

    public init(cookie: HTTPCookie) {
        self.id = UUID()
        self.name = cookie.name
        self.value = cookie.value
        self.domain = cookie.domain
        self.path = cookie.path
        self.expires = cookie.expiresDate
        self.httpOnly = cookie.isHTTPOnly
        self.secure = cookie.isSecure
    }
}
