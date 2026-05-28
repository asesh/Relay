import Foundation

struct HTTPResponse {
    let statusCode: Int
    let responseHeaders: [String: String]
    let body: Data
    let duration: TimeInterval

    var bodyString: String {
        String(data: body, encoding: .utf8) ?? String(data: body, encoding: .isoLatin1) ?? ""
    }

    var prettyBody: String {
        guard let json = try? JSONSerialization.jsonObject(with: body),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else {
            return bodyString
        }
        return str
    }

    var sizeString: String {
        let bytes = body.count
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    }

    var durationString: String {
        duration < 1 ? "\(Int(duration * 1000)) ms" : String(format: "%.2f s", duration)
    }

    var statusColor: RelayColor {
        switch statusCode {
        case 200..<300: return .statusSuccess
        case 300..<400: return .statusRedirect
        case 400..<500: return .statusClientError
        default: return .statusServerError
        }
    }
}

class NetworkService {
    static let shared = NetworkService()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    func send(_ request: RequestItem) async throws -> HTTPResponse {
        let trimmed = request.url.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            throw URLError(.badURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method

        for header in request.headers where header.isEnabled && !header.key.isEmpty {
            urlRequest.setValue(header.value, forHTTPHeaderField: header.key)
        }

        let bodyType = BodyType(rawValue: request.bodyType) ?? .none
        if bodyType != .none && !request.bodyContent.isEmpty {
            urlRequest.httpBody = request.bodyContent.data(using: .utf8)
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil && bodyType == .json {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        let start = Date()
        let (data, response) = try await session.data(for: urlRequest)
        let duration = Date().timeIntervalSince(start)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            headers["\(key)"] = "\(value)"
        }

        return HTTPResponse(statusCode: httpResponse.statusCode, responseHeaders: headers, body: data, duration: duration)
    }
}
