import Foundation
import Network

// MARK: - Mock Server

/// NWListener-based local HTTP mock server.
@MainActor
public final class MockServer: ObservableObject {

    @Published public var isRunning = false
    @Published public var localAddress: String = ""
    @Published public var requestLog: [MockRequestLog] = []
    @Published public var lastError: String?

    private var listener: NWListener?
    private let serverModel: MockServerModel
    private var connections: [NWConnection] = []

    public init(serverModel: MockServerModel) {
        self.serverModel = serverModel
    }

    // MARK: - Start / Stop

    public func start() {
        guard !isRunning else { return }
        do {
            let port = NWEndpoint.Port(integerLiteral: UInt16(serverModel.port))
            listener = try NWListener(using: .tcp, on: port)
        } catch {
            lastError = "Failed to create listener: \(error.localizedDescription)"
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isRunning = true
                    self?.localAddress = self?.getLocalIPAddress() ?? "localhost"
                    self?.lastError = nil
                case .failed(let err):
                    self?.isRunning = false
                    self?.lastError = err.localizedDescription
                default: break
                }
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: .global(qos: .userInitiated))
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        isRunning = false
        localAddress = ""
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        Task { @MainActor in
            self.connections.append(connection)
        }
        connection.start(queue: .global(qos: .userInitiated))
        receiveData(from: connection)
    }

    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, let data, !data.isEmpty else {
                if isComplete { connection.cancel() }
                return
            }

            guard let requestStr = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            let parsed = self.parseHTTPRequest(requestStr)
            Task { @MainActor in
                let (responseData, matchedRoute) = self.buildResponse(for: parsed)
                let logEntry = MockRequestLog(
                    method: parsed.method,
                    path: parsed.path,
                    matchedRoute: matchedRoute?.path,
                    responseCode: matchedRoute?.statusCode ?? 404,
                    requestHeaders: parsed.headers,
                    requestBody: parsed.body
                )
                self.requestLog.insert(logEntry, at: 0)
                self.sendResponse(responseData, on: connection)
            }
        }
    }

    private func sendResponse(_ data: Data, on connection: NWConnection) {
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Request Parsing

    private func parseHTTPRequest(_ raw: String) -> ParsedMockRequest {
        let lines = raw.components(separatedBy: "\r\n")
        var method = "GET"
        var path = "/"
        var headers: [String: String] = [:]
        var body = ""

        if let firstLine = lines.first {
            let parts = firstLine.components(separatedBy: " ")
            if parts.count >= 2 {
                method = parts[0]
                path = parts[1]
            }
        }

        var i = 1
        while i < lines.count && !lines[i].isEmpty {
            let parts = lines[i].components(separatedBy: ": ")
            if parts.count >= 2 {
                headers[parts[0]] = parts.dropFirst().joined(separator: ": ")
            }
            i += 1
        }

        if i + 1 < lines.count {
            body = lines[(i + 1)...].joined(separator: "\r\n")
        }

        return ParsedMockRequest(method: method, path: path, headers: headers, body: body)
    }

    // MARK: - Response Building

    private func buildResponse(for request: ParsedMockRequest) -> (Data, MockRouteModel?) {
        let route = matchRoute(method: request.method, path: request.path)

        let statusCode = route?.statusCode ?? 404
        let body = route?.responseBody ?? "{\"error\":\"No route matched\"}"
        var headers = route?.responseHeaders ?? ["Content-Type": "application/json"]

        // Simulate delay (skip async for now — in production, use Task.sleep)
        let statusLine = "HTTP/1.1 \(statusCode) \(HTTPResponse.defaultStatusText(for: statusCode))\r\n"
        let headerLines = headers.map { "\($0.key): \($0.value)" }.joined(separator: "\r\n")
        let bodyData = Data(body.utf8)
        let response = "\(statusLine)\(headerLines)\r\nContent-Length: \(bodyData.count)\r\n\r\n"

        var data = Data(response.utf8)
        data.append(bodyData)
        return (data, route)
    }

    private func matchRoute(method: String, path: String) -> MockRouteModel? {
        let enabledRoutes = serverModel.routes.filter(\.isEnabled)
        for route in enabledRoutes {
            if route.method.uppercased() == method.uppercased() || route.method == "*" {
                if pathMatches(pattern: route.path, path: path) { return route }
            }
        }
        return nil
    }

    private func pathMatches(pattern: String, path: String) -> Bool {
        if pattern == path { return true }
        if pattern == "*" { return true }
        // Support :param wildcards
        let patternParts = pattern.components(separatedBy: "/")
        let pathParts = path.components(separatedBy: "/")
        guard patternParts.count == pathParts.count else { return false }
        return zip(patternParts, pathParts).allSatisfy { p, s in
            p.hasPrefix(":") || p == s || p == "*"
        }
    }

    // MARK: - Local IP

    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            var addr = ptr.pointee.ifa_addr.pointee
            if (flags & IFF_UP) == IFF_UP && addr.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                let ip = String(cString: hostname)
                if ip != "127.0.0.1" { address = ip; break }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }
}

// MARK: - Supporting Types

public struct ParsedMockRequest: Sendable {
    public var method: String
    public var path: String
    public var headers: [String: String]
    public var body: String
}

public struct MockRequestLog: Identifiable, Sendable {
    public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var method: String
    public var path: String
    public var matchedRoute: String?
    public var responseCode: Int
    public var requestHeaders: [String: String]
    public var requestBody: String
}
