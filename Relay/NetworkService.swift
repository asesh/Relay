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

  func send(_ request: RequestItem, environment: RelayEnvironment?) async throws -> HTTPResponse {
    let rawURL = substitute(request.url.trimmingCharacters(in: .whitespaces), with: environment)
    guard !rawURL.isEmpty, var components = URLComponents(string: rawURL) else {
      throw URLError(.badURL)
    }

    let authType = AuthType(rawValue: request.authType) ?? .none
    let existingParams = components.queryItems ?? []
    var additionalParams: [URLQueryItem] = []

    for param in request.queryParams where param.isEnabled && !param.key.isEmpty {
      additionalParams.append(URLQueryItem(
        name: substitute(param.key, with: environment),
        value: substitute(param.value, with: environment)
      ))
    }

    if authType == .apiKey && request.authApiKeyLocation == APIKeyLocation.queryParam.rawValue {
      let keyName = request.authApiKeyName.isEmpty ? "apikey" : request.authApiKeyName
      let keyValue = substitute(request.authApiKeyValue, with: environment)
      if !keyValue.isEmpty {
        additionalParams.append(URLQueryItem(name: keyName, value: keyValue))
      }
    }

    if !additionalParams.isEmpty {
      components.queryItems = existingParams + additionalParams
    }

    guard let url = components.url else {
      throw URLError(.badURL)
    }

    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = request.method

    switch authType {
    case .bearer:
      let token = substitute(request.authBearerToken, with: environment)
      if !token.isEmpty {
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      }
    case .basic:
      let user = substitute(request.authBasicUsername, with: environment)
      let pass = substitute(request.authBasicPassword, with: environment)
      if !user.isEmpty {
        let encoded = Data("\(user):\(pass)".utf8).base64EncodedString()
        urlRequest.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
      }
    case .apiKey:
      if request.authApiKeyLocation == APIKeyLocation.header.rawValue {
        let keyName = request.authApiKeyName.isEmpty ? "X-API-Key" : request.authApiKeyName
        let keyValue = substitute(request.authApiKeyValue, with: environment)
        if !keyValue.isEmpty {
          urlRequest.setValue(keyValue, forHTTPHeaderField: keyName)
        }
      }
    case .none:
      break
    }

    for header in request.headers where header.isEnabled && !header.key.isEmpty {
      urlRequest.setValue(substitute(header.value, with: environment), forHTTPHeaderField: header.key)
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

  private func substitute(_ text: String, with environment: RelayEnvironment?) -> String {
    guard let env = environment else { return text }
    var result = text
    for variable in env.variables where variable.isEnabled && !variable.key.isEmpty {
      result = result.replacingOccurrences(of: "{{\(variable.key)}}", with: variable.value)
    }
    return result
  }
}
