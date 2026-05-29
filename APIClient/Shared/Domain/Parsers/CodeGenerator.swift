import Foundation

// MARK: - Code Generator

/// Generates code snippets for HTTP requests in multiple languages.
public final class CodeGenerator {

    public init() {}

    public func generate(request: HTTPRequest, language: CodeLanguage) -> String {
        switch language {
        case .swift: return generateSwift(request)
        case .python: return generatePython(request)
        case .javascript: return generateJavaScript(request)
        case .axios: return generateAxios(request)
        case .nodejs: return generateNodeJS(request)
        case .go: return generateGo(request)
        case .java: return generateJava(request)
        case .php: return generatePHP(request)
        case .ruby: return generateRuby(request)
        case .kotlin: return generateKotlin(request)
        case .csharp: return generateCSharp(request)
        }
    }

    // MARK: - Swift / URLSession

    private func generateSwift(_ r: HTTPRequest) -> String {
        var lines = [
            "import Foundation",
            "",
            "let url = URL(string: \"\(r.url)\")!",
            "var request = URLRequest(url: url)",
            "request.httpMethod = \"\(r.effectiveMethodName)\"",
        ]
        for h in r.headers where h.isEnabled {
            lines.append("request.setValue(\"\(h.value)\", forHTTPHeaderField: \"\(h.key)\")")
        }
        if r.body.type == .raw && !r.body.rawContent.isEmpty {
            lines.append("request.httpBody = \"\"\"\n\(r.body.rawContent)\n\"\"\".data(using: .utf8)")
        }
        lines += [
            "",
            "let task = URLSession.shared.dataTask(with: request) { data, response, error in",
            "    guard let data, error == nil else { print(error!); return }",
            "    print(String(data: data, encoding: .utf8)!)",
            "}",
            "task.resume()"
        ]
        return lines.joined(separator: "\n")
    }

    // MARK: - Python / requests

    private func generatePython(_ r: HTTPRequest) -> String {
        var lines = [
            "import requests",
            "",
            "url = \"\(r.url)\"",
        ]
        let headers = r.headers.filter(\.isEnabled)
        if !headers.isEmpty {
            lines.append("headers = {")
            for h in headers { lines.append("    \"\(h.key)\": \"\(h.value)\",") }
            lines.append("}")
        }
        let headerArg = headers.isEmpty ? "" : ", headers=headers"
        switch r.body.type {
        case .raw where !r.body.rawContent.isEmpty:
            if r.body.rawType == .json {
                lines.append("data = \(r.body.rawContent)")
                lines.append("response = requests.\(r.effectiveMethodName.lowercased())(url\(headerArg), json=data)")
            } else {
                let escaped = r.body.rawContent.replacingOccurrences(of: "\"", with: "\\\"")
                lines.append("response = requests.\(r.effectiveMethodName.lowercased())(url\(headerArg), data=\"\(escaped)\")")
            }
        default:
            lines.append("response = requests.\(r.effectiveMethodName.lowercased())(url\(headerArg))")
        }
        lines += ["", "print(response.status_code)", "print(response.json())"]
        return lines.joined(separator: "\n")
    }

    // MARK: - JavaScript / fetch

    private func generateJavaScript(_ r: HTTPRequest) -> String {
        var lines = ["const options = {", "  method: '\(r.effectiveMethodName)',"]
        let headers = r.headers.filter(\.isEnabled)
        if !headers.isEmpty {
            lines.append("  headers: {")
            for h in headers { lines.append("    '\(h.key)': '\(h.value)',") }
            lines.append("  },")
        }
        if r.body.type == .raw && !r.body.rawContent.isEmpty {
            let escaped = r.body.rawContent.replacingOccurrences(of: "`", with: "\\`")
            lines.append("  body: `\(escaped)`,")
        }
        lines += ["};", "", "fetch('\(r.url)', options)", "  .then(res => res.json())", "  .then(data => console.log(data))", "  .catch(err => console.error(err));"]
        return lines.joined(separator: "\n")
    }

    // MARK: - Axios

    private func generateAxios(_ r: HTTPRequest) -> String {
        var lines = ["const axios = require('axios');", ""]
        var config = "{\n  method: '\(r.effectiveMethodName.lowercased())',\n  url: '\(r.url)',"
        let headers = r.headers.filter(\.isEnabled)
        if !headers.isEmpty {
            config += "\n  headers: {"
            for h in headers { config += "\n    '\(h.key)': '\(h.value)'," }
            config += "\n  },"
        }
        if r.body.type == .raw && !r.body.rawContent.isEmpty {
            config += "\n  data: `\(r.body.rawContent.replacingOccurrences(of: "`", with: "\\`"))`,"
        }
        config += "\n}"
        lines += ["axios(\(config))", "  .then(response => console.log(response.data))", "  .catch(error => console.error(error));"]
        return lines.joined(separator: "\n")
    }

    // MARK: - Node.js / http

    private func generateNodeJS(_ r: HTTPRequest) -> String {
        guard let url = URL(string: r.url) else { return "// Invalid URL" }
        let isHTTPS = url.scheme == "https"
        let body = r.body.type == .raw ? r.body.rawContent : ""
        var lines = [
            "const \(isHTTPS ? "https" : "http") = require('\(isHTTPS ? "https" : "http")');",
            "",
            "const options = {",
            "  hostname: '\(url.host ?? "")',",
            "  port: \(url.port ?? (isHTTPS ? 443 : 80)),",
            "  path: '\(url.path)\(url.query.map { "?\($0)" } ?? "")',",
            "  method: '\(r.effectiveMethodName)',"
        ]
        let headers = r.headers.filter(\.isEnabled)
        if !headers.isEmpty {
            lines.append("  headers: {")
            for h in headers { lines.append("    '\(h.key)': '\(h.value)',") }
            lines.append("  },")
        }
        lines += ["};", "", "const req = \(isHTTPS ? "https" : "http").request(options, (res) => {",
                  "  let data = '';", "  res.on('data', chunk => data += chunk);",
                  "  res.on('end', () => console.log(data));", "});"]
        if !body.isEmpty {
            let escaped = body.replacingOccurrences(of: "`", with: "\\`")
            lines.append("req.write(`\(escaped)`);")
        }
        lines.append("req.end();")
        return lines.joined(separator: "\n")
    }

    // MARK: - Go

    private func generateGo(_ r: HTTPRequest) -> String {
        var lines = [
            "package main",
            "",
            "import (",
            "    \"fmt\"",
            "    \"io\"",
            "    \"net/http\"",
        ]
        if r.body.type == .raw { lines.append("    \"strings\"") }
        lines += [")", "", "func main() {"]
        if r.body.type == .raw && !r.body.rawContent.isEmpty {
            let escaped = r.body.rawContent.replacingOccurrences(of: "`", with: "`+\"`\"+`")
            lines.append("    body := strings.NewReader(`\(escaped)`)")
            lines.append("    req, _ := http.NewRequest(\"\(r.effectiveMethodName)\", \"\(r.url)\", body)")
        } else {
            lines.append("    req, _ := http.NewRequest(\"\(r.effectiveMethodName)\", \"\(r.url)\", nil)")
        }
        for h in r.headers where h.isEnabled {
            lines.append("    req.Header.Add(\"\(h.key)\", \"\(h.value)\")")
        }
        lines += [
            "    res, _ := http.DefaultClient.Do(req)",
            "    defer res.Body.Close()",
            "    body2, _ := io.ReadAll(res.Body)",
            "    fmt.Println(string(body2))",
            "}"
        ]
        return lines.joined(separator: "\n")
    }

    // MARK: - Java / OkHttp

    private func generateJava(_ r: HTTPRequest) -> String {
        var lines = [
            "OkHttpClient client = new OkHttpClient();",
            ""
        ]
        if r.body.type == .raw && !r.body.rawContent.isEmpty {
            let ct = r.body.rawType.contentType
            let escaped = r.body.rawContent.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            lines.append("MediaType mediaType = MediaType.parse(\"\(ct)\");")
            lines.append("RequestBody body = RequestBody.create(\"\(escaped)\", mediaType);")
        }
        lines += ["Request request = new Request.Builder()", "    .url(\"\(r.url)\")"]
        for h in r.headers where h.isEnabled {
            lines.append("    .addHeader(\"\(h.key)\", \"\(h.value)\")")
        }
        if r.body.type == .raw { lines.append("    .\(r.effectiveMethodName.lowercased())(body)") }
        else { lines.append("    .get()") }
        lines += ["    .build();", "", "Response response = client.newCall(request).execute();",
                  "System.out.println(response.body().string());"]
        return lines.joined(separator: "\n")
    }

    // MARK: - PHP / cURL

    private func generatePHP(_ r: HTTPRequest) -> String {
        var lines = [
            "<?php",
            "$curl = curl_init();",
            "",
            "curl_setopt_array($curl, [",
            "  CURLOPT_URL => \"\(r.url)\",",
            "  CURLOPT_RETURNTRANSFER => true,",
            "  CURLOPT_CUSTOMREQUEST => \"\(r.effectiveMethodName)\","
        ]
        let headers = r.headers.filter(\.isEnabled)
        if !headers.isEmpty {
            lines.append("  CURLOPT_HTTPHEADER => [")
            for h in headers { lines.append("    \"\(h.key): \(h.value)\",") }
            lines.append("  ],")
        }
        if r.body.type == .raw && !r.body.rawContent.isEmpty {
            let escaped = r.body.rawContent.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            lines.append("  CURLOPT_POSTFIELDS => \"\(escaped)\",")
        }
        lines += ["]);", "", "$response = curl_exec($curl);", "curl_close($curl);", "echo $response;"]
        return lines.joined(separator: "\n")
    }

    // MARK: - Ruby

    private func generateRuby(_ r: HTTPRequest) -> String {
        guard let url = URL(string: r.url) else { return "# Invalid URL" }
        let isHTTPS = url.scheme == "https"
        var lines = [
            "require 'net/http'",
            "require 'uri'",
            isHTTPS ? "require 'openssl'" : "",
            "",
            "uri = URI.parse('\(r.url)')",
            "http = Net::HTTP.new(uri.host, uri.port)",
        ]
        if isHTTPS { lines.append("http.use_ssl = true") }
        let path = url.path.isEmpty ? "/" : url.path
        let query = url.query.map { "?\($0)" } ?? ""
        lines += ["request = Net::HTTP::\(r.effectiveMethodName.capitalized).new('\(path)\(query)')"]
        for h in r.headers where h.isEnabled {
            lines.append("request['\(h.key)'] = '\(h.value)'")
        }
        if r.body.type == .raw && !r.body.rawContent.isEmpty {
            let escaped = r.body.rawContent.replacingOccurrences(of: "'", with: "\\'")
            lines.append("request.body = '\(escaped)'")
        }
        lines += ["response = http.request(request)", "puts response.body"]
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    // MARK: - Kotlin / OkHttp

    private func generateKotlin(_ r: HTTPRequest) -> String {
        var lines = [
            "val client = OkHttpClient()",
            ""
        ]
        if r.body.type == .raw && !r.body.rawContent.isEmpty {
            lines.append("val mediaType = \"\(r.body.rawType.contentType)\".toMediaType()")
            lines.append("val body = \"\"\"\n\(r.body.rawContent)\n\"\"\".toRequestBody(mediaType)")
        }
        lines += ["val request = Request.Builder()", "    .url(\"\(r.url)\")"]
        for h in r.headers where h.isEnabled {
            lines.append("    .addHeader(\"\(h.key)\", \"\(h.value)\")")
        }
        if r.body.type == .raw { lines.append("    .\(r.effectiveMethodName.lowercased())(body)") }
        lines += ["    .build()", "", "val response = client.newCall(request).execute()",
                  "println(response.body!!.string())"]
        return lines.joined(separator: "\n")
    }

    // MARK: - C# / HttpClient

    private func generateCSharp(_ r: HTTPRequest) -> String {
        var lines = [
            "using System.Net.Http;",
            "using System.Text;",
            "",
            "var client = new HttpClient();",
            "var request = new HttpRequestMessage(HttpMethod.\(r.effectiveMethodName.capitalized), \"\(r.url)\");"
        ]
        for h in r.headers where h.isEnabled {
            lines.append("request.Headers.Add(\"\(h.key)\", \"\(h.value)\");")
        }
        if r.body.type == .raw && !r.body.rawContent.isEmpty {
            let escaped = r.body.rawContent.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            let ct = r.body.rawType.contentType
            lines.append("request.Content = new StringContent(\"\(escaped)\", Encoding.UTF8, \"\(ct)\");")
        }
        lines += ["var response = await client.SendAsync(request);",
                  "var content = await response.Content.ReadAsStringAsync();",
                  "Console.WriteLine(content);"]
        return lines.joined(separator: "\n")
    }
}

// Fix string replacement
private extension String {
    func replacingOccurrences(_ of: String) -> String { self }
}
