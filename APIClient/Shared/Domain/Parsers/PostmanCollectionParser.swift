import Foundation

// MARK: - Postman Collection Parser

/// Parses Postman Collection v2.1 JSON into domain models.
public final class PostmanCollectionParser {

    public init() {}

    public func parse(data: Data) throws -> ParsedCollection {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParseError.invalidJSON
        }

        guard let info = json["info"] as? [String: Any] else {
            throw ParseError.missingField("info")
        }

        let name = info["name"] as? String ?? "Imported Collection"
        let description = (info["description"] as? String) ?? ""

        let itemsRaw = json["item"] as? [[String: Any]] ?? []
        let (folders, requests) = parseItems(itemsRaw)

        // Collection-level variables
        let variables = (json["variable"] as? [[String: Any]] ?? []).compactMap { v -> EnvironmentVariable? in
            guard let key = v["key"] as? String else { return nil }
            let value = (v["value"] as? String) ?? ""
            return EnvironmentVariable(key: key, initialValue: value, currentValue: value)
        }

        // Collection-level auth
        let authConfig = parseAuth(json["auth"] as? [String: Any])

        return ParsedCollection(
            name: name, description: description,
            folders: folders, requests: requests,
            variables: variables, authConfig: authConfig
        )
    }

    // MARK: - Item Parsing

    private func parseItems(_ items: [[String: Any]]) -> ([ParsedFolder], [HTTPRequest]) {
        var folders: [ParsedFolder] = []
        var requests: [HTTPRequest] = []

        for item in items {
            if let subItems = item["item"] as? [[String: Any]] {
                // It's a folder
                let (subFolders, subRequests) = parseItems(subItems)
                let name = item["name"] as? String ?? "Folder"
                let auth = parseAuth(item["auth"] as? [String: Any])
                folders.append(ParsedFolder(
                    name: name,
                    subFolders: subFolders,
                    requests: subRequests,
                    authConfig: auth
                ))
            } else {
                // It's a request
                if let req = parseRequest(item) { requests.append(req) }
            }
        }
        return (folders, requests)
    }

    private func parseRequest(_ item: [String: Any]) -> HTTPRequest? {
        guard let reqRaw = item["request"] as? [String: Any] else { return nil }
        let name = item["name"] as? String ?? "Request"

        // URL
        var urlStr = ""
        if let urlObj = reqRaw["url"] as? [String: Any] {
            urlStr = urlObj["raw"] as? String ?? ""
        } else if let urlStr2 = reqRaw["url"] as? String {
            urlStr = urlStr2
        }

        // Method
        let methodStr = reqRaw["method"] as? String ?? "GET"
        let method = HTTPMethod.from(methodStr)

        // Headers
        let headers = (reqRaw["header"] as? [[String: Any]] ?? []).map { h -> KeyValuePair in
            KeyValuePair(
                key: h["key"] as? String ?? "",
                value: h["value"] as? String ?? "",
                description: h["description"] as? String ?? "",
                isEnabled: !((h["disabled"] as? Bool) ?? false)
            )
        }

        // Body
        let body = parseBody(reqRaw["body"] as? [String: Any])

        // Auth
        let auth = parseAuth(reqRaw["auth"] as? [String: Any]) ?? AuthConfig()

        // Description
        let description = descriptionString(reqRaw["description"])

        // Scripts
        let events = item["event"] as? [[String: Any]] ?? []
        var preRequestScript = ""
        var testScript = ""
        for event in events {
            let listen = event["listen"] as? String ?? ""
            let script = event["script"] as? [String: Any]
            let exec = (script?["exec"] as? [String])?.joined(separator: "\n") ?? ""
            if listen == "prerequest" { preRequestScript = exec }
            else if listen == "test" { testScript = exec }
        }

        // Query params
        var queryParams: [KeyValuePair] = []
        if let urlObj = reqRaw["url"] as? [String: Any],
           let queryItems = urlObj["query"] as? [[String: Any]] {
            queryParams = queryItems.map { q in
                KeyValuePair(
                    key: q["key"] as? String ?? "",
                    value: q["value"] as? String ?? "",
                    description: q["description"] as? String ?? "",
                    isEnabled: !((q["disabled"] as? Bool) ?? false)
                )
            }
        }

        return HTTPRequest(
            name: name, method: method, url: urlStr,
            queryParams: queryParams, headers: headers,
            auth: auth, body: body,
            preRequestScript: preRequestScript,
            testScript: testScript,
            description: description
        )
    }

    // MARK: - Body Parsing

    private func parseBody(_ raw: [String: Any]?) -> BodyPayload {
        guard let raw else { return BodyPayload() }
        let mode = raw["mode"] as? String ?? "none"

        switch mode {
        case "raw":
            let content = raw["raw"] as? String ?? ""
            let options = raw["options"] as? [String: Any]
            let language = (options?["raw"] as? [String: Any])?["language"] as? String ?? "json"
            let rawType = RawBodyType(rawValue: language.capitalized) ?? .json
            return BodyPayload(type: .raw, rawType: rawType, rawContent: content)

        case "formdata":
            let items = (raw["formdata"] as? [[String: Any]] ?? []).map { f -> FormDataItem in
                FormDataItem(
                    key: f["key"] as? String ?? "",
                    textValue: f["value"] as? String ?? "",
                    type: (f["type"] as? String) == "file" ? .file : .text,
                    isEnabled: !((f["disabled"] as? Bool) ?? false),
                    description: f["description"] as? String ?? ""
                )
            }
            return BodyPayload(type: .formData, formDataItems: items)

        case "urlencoded":
            let items = (raw["urlencoded"] as? [[String: Any]] ?? []).map { u -> KeyValuePair in
                KeyValuePair(
                    key: u["key"] as? String ?? "",
                    value: u["value"] as? String ?? "",
                    description: u["description"] as? String ?? "",
                    isEnabled: !((u["disabled"] as? Bool) ?? false)
                )
            }
            return BodyPayload(type: .urlEncoded, urlEncodedItems: items)

        case "graphql":
            let gql = raw["graphql"] as? [String: Any]
            let payload = GraphQLPayload(
                query: gql?["query"] as? String ?? "",
                variables: (gql?["variables"] as? String) ?? "{}",
                operationName: gql?["operationName"] as? String ?? ""
            )
            return BodyPayload(type: .graphQL, graphQL: payload)

        default:
            return BodyPayload()
        }
    }

    // MARK: - Auth Parsing

    private func parseAuth(_ raw: [String: Any]?) -> AuthConfig? {
        guard let raw else { return nil }
        let typeStr = raw["type"] as? String ?? "noauth"
        var config = AuthConfig()

        switch typeStr {
        case "noauth", "none": config.type = .none
        case "bearer":
            config.type = .bearer
            let params = authParams(raw["bearer"])
            config.bearerConfig = BearerConfig(token: params["token"] ?? "")
        case "basic":
            config.type = .basic
            let params = authParams(raw["basic"])
            config.basicConfig = BasicAuthConfig(
                username: params["username"] ?? "",
                password: params["password"] ?? ""
            )
        case "apikey":
            config.type = .apiKey
            let params = authParams(raw["apikey"])
            config.apiKeyConfig = APIKeyConfig(
                key: params["key"] ?? "X-API-Key",
                value: params["value"] ?? "",
                addTo: (params["in"] == "query") ? .queryParam : .header
            )
        case "oauth1":
            config.type = .oauth1
            let params = authParams(raw["oauth1"])
            config.oauth1Config = OAuth1Config(
                consumerKey: params["consumerKey"] ?? "",
                consumerSecret: params["consumerSecret"] ?? "",
                token: params["token"] ?? "",
                tokenSecret: params["tokenSecret"] ?? ""
            )
        case "oauth2":
            config.type = .oauth2
            let params = authParams(raw["oauth2"])
            config.oauth2Config = OAuth2Config(
                grantType: .authorizationCode,
                accessTokenURL: params["accessTokenUrl"] ?? "",
                authorizationURL: params["authUrl"] ?? "",
                clientID: params["clientId"] ?? "",
                clientSecret: params["clientSecret"] ?? ""
            )
        case "awsv4":
            config.type = .awsV4
            let params = authParams(raw["awsv4"])
            config.awsV4Config = AWSV4Config(
                accessKey: params["accessKey"] ?? "",
                secretKey: params["secretKey"] ?? "",
                sessionToken: params["sessionToken"] ?? "",
                region: params["region"] ?? "us-east-1",
                serviceName: params["service"] ?? "execute-api"
            )
        case "digest":
            config.type = .digest
            let params = authParams(raw["digest"])
            config.digestConfig = DigestAuthConfig(
                username: params["username"] ?? "",
                password: params["password"] ?? ""
            )
        default:
            config.type = .none
        }

        return config
    }

    private func authParams(_ value: Any?) -> [String: String] {
        guard let arr = value as? [[String: Any]] else { return [:] }
        var dict: [String: String] = [:]
        for item in arr {
            if let key = item["key"] as? String,
               let val = item["value"] as? String { dict[key] = val }
        }
        return dict
    }

    private func descriptionString(_ value: Any?) -> String {
        if let str = value as? String { return str }
        if let dict = value as? [String: Any] { return dict["content"] as? String ?? "" }
        return ""
    }
}

// MARK: - OpenAPI Parser

/// Parses OpenAPI 3.0 / Swagger 2.0 JSON into domain models.
public final class OpenAPIParser {

    public init() {}

    public func parse(data: Data) throws -> ParsedCollection {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParseError.invalidJSON
        }

        let isSwagger2 = json["swagger"] != nil
        let title = (json["info"] as? [String: Any])?["title"] as? String ?? "API"
        let description = (json["info"] as? [String: Any])?["description"] as? String ?? ""

        var baseURL = ""
        if isSwagger2 {
            let host = json["host"] as? String ?? "localhost"
            let basePath = json["basePath"] as? String ?? ""
            let schemes = json["schemes"] as? [String] ?? ["https"]
            baseURL = "\(schemes.first ?? "https")://\(host)\(basePath)"
        } else {
            // OpenAPI 3.0
            if let servers = json["servers"] as? [[String: Any]],
               let firstServer = servers.first {
                baseURL = firstServer["url"] as? String ?? ""
            }
        }

        let paths = json["paths"] as? [String: Any] ?? [:]
        var taggedRequests: [String: [HTTPRequest]] = [:]

        for (path, pathItemRaw) in paths {
            guard let pathItem = pathItemRaw as? [String: Any] else { continue }
            let methods = ["get", "post", "put", "patch", "delete", "head", "options"]

            for methodStr in methods {
                guard let operation = pathItem[methodStr] as? [String: Any] else { continue }
                let request = parseOperation(
                    method: methodStr.uppercased(), path: path,
                    operation: operation, baseURL: baseURL,
                    isSwagger2: isSwagger2
                )
                let tags = operation["tags"] as? [String] ?? ["Default"]
                let tag = tags.first ?? "Default"
                taggedRequests[tag, default: []].append(request)
            }
        }

        let folders = taggedRequests.map { tag, requests in
            ParsedFolder(name: tag, subFolders: [], requests: requests, authConfig: nil)
        }.sorted { $0.name < $1.name }

        return ParsedCollection(
            name: title, description: description,
            folders: folders, requests: [],
            variables: [], authConfig: nil
        )
    }

    private func parseOperation(method: String, path: String, operation: [String: Any],
                                  baseURL: String, isSwagger2: Bool) -> HTTPRequest {
        let operationID = operation["operationId"] as? String
        let summary = operation["summary"] as? String
        let name = summary ?? operationID ?? "\(method) \(path)"
        let description = operation["description"] as? String ?? ""

        let url = baseURL + path
        let parameters = operation["parameters"] as? [[String: Any]] ?? []

        var headers: [KeyValuePair] = []
        var queryParams: [KeyValuePair] = []

        for param in parameters {
            let paramName = param["name"] as? String ?? ""
            let location = param["in"] as? String ?? "query"
            let required = param["required"] as? Bool ?? false
            let desc = param["description"] as? String ?? ""
            let schema = param["schema"] as? [String: Any]
            let example = schema?["example"] as? String ?? schema?["default"] as? String ?? ""
            let item = KeyValuePair(
                key: paramName, value: example,
                description: desc + (required ? " (required)" : ""),
                isEnabled: true
            )
            if location == "header" { headers.append(item) }
            else if location == "query" { queryParams.append(item) }
        }

        // Request body
        var body = BodyPayload()
        if let requestBody = operation["requestBody"] as? [String: Any],
           let content = requestBody["content"] as? [String: Any] {
            if let jsonContent = content["application/json"] as? [String: Any] {
                body.type = .raw
                body.rawType = .json
                if let schema = jsonContent["schema"] as? [String: Any],
                   let example = jsonContent["example"] {
                    body.rawContent = (try? JSONSerialization.data(
                        withJSONObject: example, options: .prettyPrinted))
                        .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                }
            } else if content["multipart/form-data"] != nil {
                body.type = .formData
            } else if content["application/x-www-form-urlencoded"] != nil {
                body.type = .urlEncoded
            }
        }

        return HTTPRequest(
            name: name, method: HTTPMethod.from(method),
            url: url, queryParams: queryParams,
            headers: headers, body: body,
            description: description
        )
    }
}

// MARK: - HAR Parser

/// Parses HTTP Archive (HAR) 1.2 files into requests.
public final class HARParser {

    public init() {}

    public func parse(data: Data) throws -> [HTTPRequest] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let log = json["log"] as? [String: Any],
              let entries = log["entries"] as? [[String: Any]] else {
            throw ParseError.invalidJSON
        }

        return entries.compactMap { entry -> HTTPRequest? in
            guard let requestRaw = entry["request"] as? [String: Any] else { return nil }
            let method = HTTPMethod.from(requestRaw["method"] as? String ?? "GET")
            let urlStr = requestRaw["url"] as? String ?? ""

            let headers = (requestRaw["headers"] as? [[String: Any]] ?? []).map { h in
                KeyValuePair(
                    key: h["name"] as? String ?? "",
                    value: h["value"] as? String ?? ""
                )
            }.filter { !["host", "content-length", "transfer-encoding"].contains($0.key.lowercased()) }

            let queryParams = (requestRaw["queryString"] as? [[String: Any]] ?? []).map { q in
                KeyValuePair(key: q["name"] as? String ?? "", value: q["value"] as? String ?? "")
            }

            var body = BodyPayload()
            if let postData = requestRaw["postData"] as? [String: Any] {
                let mimeType = postData["mimeType"] as? String ?? ""
                let text = postData["text"] as? String ?? ""
                if mimeType.contains("application/json") {
                    body = BodyPayload(type: .raw, rawType: .json, rawContent: text)
                } else if mimeType.contains("application/x-www-form-urlencoded") {
                    body = BodyPayload(type: .urlEncoded)
                    let items = (postData["params"] as? [[String: Any]] ?? []).map { p in
                        KeyValuePair(key: p["name"] as? String ?? "", value: p["value"] as? String ?? "")
                    }
                    body.urlEncodedItems = items
                } else if mimeType.contains("multipart/form-data") {
                    body = BodyPayload(type: .formData)
                } else if !text.isEmpty {
                    body = BodyPayload(type: .raw, rawType: .text, rawContent: text)
                }
            }

            let name = URL(string: urlStr)?.lastPathComponent ?? urlStr
            return HTTPRequest(
                name: name.isEmpty ? urlStr : name,
                method: method, url: urlStr,
                queryParams: queryParams, headers: headers,
                body: body
            )
        }
    }
}

// MARK: - Parsed Models

public struct ParsedCollection {
    public var name: String
    public var description: String
    public var folders: [ParsedFolder]
    public var requests: [HTTPRequest]
    public var variables: [EnvironmentVariable]
    public var authConfig: AuthConfig?
}

public struct ParsedFolder {
    public var name: String
    public var subFolders: [ParsedFolder]
    public var requests: [HTTPRequest]
    public var authConfig: AuthConfig?
}

// MARK: - Parse Error

public enum ParseError: LocalizedError {
    case invalidJSON
    case missingField(String)
    case unsupportedVersion(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON: return "Invalid JSON format"
        case .missingField(let f): return "Missing required field: \(f)"
        case .unsupportedVersion(let v): return "Unsupported version: \(v)"
        }
    }
}
