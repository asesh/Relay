import Foundation

// MARK: - Request Executor

/// Core networking engine with interceptor pipeline and metrics collection.
public final class RequestExecutor: NSObject, ObservableObject {

    public static let shared = RequestExecutor()

    @Published public var activeTasks: [UUID: URLSessionTask] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private var metricsStore: [Int: URLSessionTaskMetrics] = [:]
    private var metricsLock = NSLock()

    public override init() { super.init() }

    // MARK: - Execute

    public func execute(
        request: HTTPRequest,
        resolver: VariableResolver,
        authHandler: AuthHandler = AuthHandler(),
        scriptEngine: ScriptEngine? = nil,
        cookieStorage: HTTPCookieStorage = .shared
    ) async throws -> HTTPResponse {
        let executionID = request.id

        // Phase 1: Resolve variables
        var resolvedRequest = resolver.resolve(request: request)

        // Phase 2: Run pre-request script
        if !resolvedRequest.preRequestScript.isEmpty, let engine = scriptEngine {
            var localVars: [String: String] = [:]
            let result = await engine.execute(
                source: resolvedRequest.preRequestScript,
                request: resolvedRequest,
                response: nil,
                resolver: resolver,
                variables: &localVars
            )
            if let mutated = result.mutatedRequest { resolvedRequest = mutated }
        }

        // Phase 3: Build URLRequest
        var urlRequest = try buildURLRequest(from: resolvedRequest)

        // Phase 4: Inject auth
        try await authHandler.inject(auth: resolvedRequest.auth, into: &urlRequest, for: resolvedRequest)

        // Phase 5: Configure SSL & proxy
        if !resolvedRequest.settings.sslVerification {
            // SSL bypass handled in delegate
        }

        // Phase 6: Execute
        let startTime = Date()
        let (data, urlResponse) = try await executeWithProgress(request: urlRequest, id: executionID)
        let duration = Date().timeIntervalSince(startTime)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // Phase 7: Extract headers & cookies
        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let k = key as? String, let v = value as? String { headers[k] = v }
        }

        var cookies: [HTTPCookieInfo] = []
        if resolvedRequest.settings.storeCookies {
            let httpCookies = HTTPCookie.cookies(
                withResponseHeaderFields: headers,
                for: httpResponse.url ?? URL(string: "https://localhost")!
            )
            cookies = httpCookies.map { HTTPCookieInfo(cookie: $0) }
            if resolvedRequest.settings.sendCookies {
                cookieStorage.setCookies(httpCookies, for: httpResponse.url, mainDocumentURL: nil)
            }
        }

        // Phase 8: Build timeline from metrics
        let timeline = buildTimeline(taskID: (urlRequest as NSObject).hash, duration: duration)

        var response = HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: headers,
            body: data,
            requestDuration: duration,
            timeline: timeline,
            cookies: cookies,
            requestID: executionID
        )

        // Phase 9: Run test scripts
        if !resolvedRequest.testScript.isEmpty, let engine = scriptEngine {
            var localVars: [String: String] = [:]
            let result = await engine.execute(
                source: resolvedRequest.testScript,
                request: resolvedRequest,
                response: response,
                resolver: resolver,
                variables: &localVars
            )
            response.testResults = result.testResults
        }

        return response
    }

    // MARK: - URLRequest Builder

    private func buildURLRequest(from request: HTTPRequest) throws -> URLRequest {
        guard var urlStr = URL(string: request.url) else {
            throw NetworkError.invalidURL(request.url)
        }

        // Merge query params
        let enabledParams = request.queryParams.filter(\.isEnabled)
        if !enabledParams.isEmpty {
            var components = URLComponents(url: urlStr, resolvingAgainstBaseURL: false)
                ?? URLComponents()
            var items = components.queryItems ?? []
            for param in enabledParams {
                items.append(URLQueryItem(name: param.key, value: param.value))
            }
            components.queryItems = items
            if let newURL = components.url { urlStr = newURL }
        }

        var urlRequest = URLRequest(url: urlStr)
        urlRequest.httpMethod = request.effectiveMethodName
        urlRequest.timeoutInterval = Double(request.settings.timeoutMs) / 1000.0

        // Headers
        for header in request.headers where header.isEnabled && !header.key.isEmpty {
            urlRequest.setValue(header.value, forHTTPHeaderField: header.key)
        }

        // Body
        if let (bodyData, contentType) = try buildBody(from: request.body) {
            urlRequest.httpBody = bodyData
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        }

        return urlRequest
    }

    private func buildBody(from body: BodyPayload) throws -> (Data, String)? {
        switch body.type {
        case .none: return nil
        case .raw:
            guard !body.rawContent.isEmpty else { return nil }
            return (Data(body.rawContent.utf8), body.rawType.contentType)
        case .urlEncoded:
            let enabled = body.urlEncodedItems.filter(\.isEnabled)
            guard !enabled.isEmpty else { return nil }
            let str = enabled.map { "\($0.key.urlQueryEncoded)=\($0.value.urlQueryEncoded)" }
                .joined(separator: "&")
            return (Data(str.utf8), "application/x-www-form-urlencoded")
        case .formData:
            return try buildMultipartFormData(body.formDataItems.filter(\.isEnabled))
        case .binary:
            guard let file = body.binaryFile,
                  let bookmarkData = file.bookmarkData else { return nil }
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
            let data = try Data(contentsOf: url)
            return (data, file.mimeType)
        case .graphQL:
            guard let jsonData = body.graphQL.toJSONBody() else { return nil }
            return (jsonData, "application/json")
        }
    }

    private func buildMultipartFormData(_ items: [FormDataItem]) throws -> (Data, String) {
        let boundary = "----APIClientBoundary\(UUID().uuidString.prefix(16))"
        var data = Data()
        for item in items where item.isEnabled {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            if item.type == .file, let file = item.fileAttachment, let bookmarkData = file.bookmarkData {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
                let fileData = try Data(contentsOf: url)
                data.append("Content-Disposition: form-data; name=\"\(item.key)\"; filename=\"\(file.fileName)\"\r\n".data(using: .utf8)!)
                data.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
                data.append(fileData)
            } else {
                data.append("Content-Disposition: form-data; name=\"\(item.key)\"\r\n\r\n".data(using: .utf8)!)
                data.append(item.textValue.data(using: .utf8)!)
            }
            data.append("\r\n".data(using: .utf8)!)
        }
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return (data, "multipart/form-data; boundary=\(boundary)")
    }

    // MARK: - Execute with Progress

    private func executeWithProgress(request: URLRequest, id: UUID) async throws -> (Data, URLResponse) {
        return try await withTaskCancellationHandler {
            try await session.data(for: request)
        } onCancel: {
            Task { @MainActor in
                self.activeTasks[id]?.cancel()
                self.activeTasks.removeValue(forKey: id)
            }
        }
    }

    // MARK: - Cancel

    public func cancel(id: UUID) {
        activeTasks[id]?.cancel()
        activeTasks.removeValue(forKey: id)
    }

    // MARK: - Metrics

    private func buildTimeline(taskID: Int, duration: TimeInterval) -> ResponseTimeline {
        metricsLock.lock()
        let metrics = metricsStore[taskID]
        metricsStore.removeValue(forKey: taskID)
        metricsLock.unlock()

        guard let transactionMetrics = metrics?.transactionMetrics.first else {
            return ResponseTimeline(totalMs: duration * 1000)
        }

        func ms(_ start: Date?, _ end: Date?) -> Double {
            guard let s = start, let e = end else { return 0 }
            return max(0, e.timeIntervalSince(s) * 1000)
        }

        let t = transactionMetrics
        return ResponseTimeline(
            dnsLookupMs: ms(t.domainLookupStartDate, t.domainLookupEndDate),
            tcpConnectMs: ms(t.connectStartDate, t.connectEndDate),
            tlsHandshakeMs: ms(t.secureConnectionStartDate, t.secureConnectionEndDate),
            requestSentMs: ms(t.requestStartDate, t.requestEndDate),
            waitingMs: ms(t.requestEndDate, t.responseStartDate),
            downloadMs: ms(t.responseStartDate, t.responseEndDate),
            totalMs: duration * 1000
        )
    }
}

// MARK: - URLSessionDelegate

extension RequestExecutor: URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, task: URLSessionTask,
                            didFinishCollecting metrics: URLSessionTaskMetrics) {
        metricsLock.lock()
        metricsStore[task.taskIdentifier] = metrics
        metricsLock.unlock()
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask,
                            willPerformHTTPRedirection response: HTTPURLResponse,
                            newRequest request: URLRequest,
                            completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request) // follow redirects by default
    }

    public func urlSession(_ session: URLSession,
                            didReceive challenge: URLAuthenticationChallenge,
                            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}

// MARK: - Network Error

public enum NetworkError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case timeout
    case cancelled
    case noConnection
    case sslError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .invalidResponse: return "Invalid HTTP response"
        case .timeout: return "Request timed out"
        case .cancelled: return "Request was cancelled"
        case .noConnection: return "No internet connection"
        case .sslError(let msg): return "SSL Error: \(msg)"
        }
    }
}

// MARK: - String URL Encoding

private extension String {
    var urlQueryEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
