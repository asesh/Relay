import Foundation

// MARK: - cURL Parser

/// Parses curl command strings into HTTPRequest domain objects.
public final class CurlParser {

    public init() {}

    public func parse(_ curl: String) throws -> HTTPRequest {
        let tokens = tokenize(curl.trimmingCharacters(in: .whitespacesAndNewlines))
        var request = HTTPRequest()
        var i = 0

        while i < tokens.count {
            let token = tokens[i]

            switch token {
            case "curl":
                i += 1
                continue

            case "-X", "--request":
                i += 1
                guard i < tokens.count else { break }
                request.method = HTTPMethod.from(tokens[i])

            case "-H", "--header":
                i += 1
                guard i < tokens.count else { break }
                let headerStr = tokens[i]
                let parts = headerStr.components(separatedBy: ": ")
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts.dropFirst().joined(separator: ": ").trimmingCharacters(in: .whitespaces)
                    request.headers.append(KeyValuePair(key: key, value: value))
                }

            case "-d", "--data", "--data-raw", "--data-binary", "--data-ascii":
                i += 1
                guard i < tokens.count else { break }
                let body = tokens[i].hasPrefix("@") ? "" : tokens[i]
                request.body.type = .raw
                if isJSON(body) {
                    request.body.rawType = .json
                } else if isXML(body) {
                    request.body.rawType = .xml
                } else {
                    request.body.rawType = .text
                }
                request.body.rawContent = body

            case "--json":
                i += 1
                guard i < tokens.count else { break }
                request.body.type = .raw
                request.body.rawType = .json
                request.body.rawContent = tokens[i]
                request.headers.removeAll { $0.key.lowercased() == "content-type" }
                request.headers.append(KeyValuePair(key: "Content-Type", value: "application/json"))
                request.headers.removeAll { $0.key.lowercased() == "accept" }
                request.headers.append(KeyValuePair(key: "Accept", value: "application/json"))

            case "-u", "--user":
                i += 1
                guard i < tokens.count else { break }
                let creds = tokens[i].components(separatedBy: ":")
                request.auth.type = .basic
                request.auth.basicConfig = BasicAuthConfig(
                    username: creds[0],
                    password: creds.count > 1 ? creds.dropFirst().joined(separator: ":") : ""
                )

            case "-F", "--form":
                i += 1
                guard i < tokens.count else { break }
                request.body.type = .formData
                let parts = tokens[i].components(separatedBy: "=")
                if parts.count >= 2 {
                    let key = parts[0]
                    let value = parts.dropFirst().joined(separator: "=")
                    let isFile = value.hasPrefix("@")
                    let formItem = FormDataItem(
                        key: key,
                        textValue: isFile ? "" : value,
                        type: isFile ? .file : .text
                    )
                    request.body.formDataItems.append(formItem)
                }

            case "--form-string":
                i += 1
                guard i < tokens.count else { break }
                request.body.type = .formData
                let parts = tokens[i].components(separatedBy: "=")
                if parts.count >= 2 {
                    let formItem = FormDataItem(
                        key: parts[0],
                        textValue: parts.dropFirst().joined(separator: "="),
                        type: .text
                    )
                    request.body.formDataItems.append(formItem)
                }

            case "--proxy", "-x":
                // Ignore proxy for import
                i += 1

            case "-k", "--insecure":
                request.settings.sslVerification = false

            case "-L", "--location":
                request.settings.followRedirects = true

            case "--max-time", "-m":
                i += 1
                guard i < tokens.count else { break }
                if let seconds = Double(tokens[i]) {
                    request.settings.timeoutMs = Int(seconds * 1000)
                }

            case "--max-redirs":
                i += 1
                guard i < tokens.count else { break }
                if let max = Int(tokens[i]) { request.settings.maxRedirects = max }

            case "--compressed":
                request.headers.append(KeyValuePair(
                    key: "Accept-Encoding", value: "deflate, gzip, br"
                ))

            case "-A", "--user-agent":
                i += 1
                guard i < tokens.count else { break }
                request.headers.removeAll { $0.key.lowercased() == "user-agent" }
                request.headers.append(KeyValuePair(key: "User-Agent", value: tokens[i]))

            case "--cookie", "-b":
                i += 1
                guard i < tokens.count else { break }
                request.headers.append(KeyValuePair(key: "Cookie", value: tokens[i]))

            case "-o", "--output", "--cookie-jar", "-c", "--header-file", "--cacert",
                 "--cert", "--key", "--pass", "--referer", "-e",
                 "--connect-timeout", "--dns-servers",
                 "--interface", "--local-port", "--retry", "--retry-delay",
                 "--retry-max-time", "--speed-limit", "--speed-time",
                 "--time-cond", "-z":
                i += 1 // skip flag value

            default:
                if !token.hasPrefix("-") {
                    let cleaned = token
                        .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                    if cleaned.hasPrefix("http://") || cleaned.hasPrefix("https://")
                        || cleaned.hasPrefix("ws://") || cleaned.hasPrefix("wss://") {
                        // Parse URL and query params
                        if let url = URLComponents(string: cleaned) {
                            let baseURL = "\(url.scheme ?? "https")://\(url.host ?? "")\(url.port.map { ":\($0)" } ?? "")\(url.path)"
                            request.url = baseURL
                            for item in url.queryItems ?? [] {
                                request.queryParams.append(KeyValuePair(
                                    key: item.name, value: item.value ?? ""
                                ))
                            }
                        } else {
                            request.url = cleaned
                        }
                    }
                }
            }
            i += 1
        }

        // Set method based on body
        if request.method == .GET && !request.body.isEmpty {
            request.method = .POST
        }

        // Derive name from URL
        if request.name == "New Request", let url = URL(string: request.url) {
            request.name = url.lastPathComponent.isEmpty ? (url.host ?? "New Request") : url.lastPathComponent
        }

        return request
    }

    // MARK: - Tokenizer

    private func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var escaped = false
        var i = input.startIndex

        while i < input.endIndex {
            let ch = input[i]
            if escaped {
                current.append(ch)
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == "'" && !inDouble {
                inSingle.toggle()
            } else if ch == "\"" && !inSingle {
                inDouble.toggle()
            } else if (ch == " " || ch == "\t" || ch == "\n" || ch == "\r") && !inSingle && !inDouble {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                // Skip continuation backslashes
            } else if ch == "\\" && !inSingle && !inDouble {
                // line continuation, skip
            } else {
                current.append(ch)
            }
            i = input.index(after: i)
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private func isJSON(_ str: String) -> Bool {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("{") || trimmed.hasPrefix("[")
    }

    private func isXML(_ str: String) -> Bool {
        str.trimmingCharacters(in: .whitespaces).hasPrefix("<")
    }
}
