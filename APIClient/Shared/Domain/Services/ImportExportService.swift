import Foundation

// MARK: - Import/Export Service

public final class ImportExportService {

    public static let shared = ImportExportService()
    private init() {}

    // MARK: - Import

    /// Detect format from filename/content and import
    public func importData(_ data: Data, filename: String) throws -> [ParsedCollection] {
        let name = filename.lowercased()
        if name.hasSuffix(".har") {
            return try importHAR(data)
        } else if name.hasSuffix(".yaml") || name.hasSuffix(".yml") {
            return try importOpenAPI(data)
        } else if name.hasSuffix(".sh") || name.hasSuffix(".curl") {
            let curl = String(data: data, encoding: .utf8) ?? ""
            if let req = CurlParser.parse(curl) {
                let col = ParsedCollection(name: "Imported cURL", requests: [req], folders: [])
                return [col]
            }
            return []
        } else {
            // Try Postman JSON first, then OpenAPI JSON
            if let collection = try? PostmanCollectionParser.parse(data) {
                return [collection]
            }
            return try importOpenAPI(data)
        }
    }

    private func importHAR(_ data: Data) throws -> [ParsedCollection] {
        let col = try HARParser.parse(data)
        return [col]
    }

    private func importOpenAPI(_ data: Data) throws -> [ParsedCollection] {
        let col = try OpenAPIParser.parse(data)
        return [col]
    }

    // MARK: - Export

    /// Export a collection to Postman v2.1 JSON
    public func exportPostman(collection: CollectionModel) throws -> Data {
        var items: [[String: Any]] = []
        for folder in collection.folders.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            items.append(try exportFolder(folder))
        }
        for req in collection.requests.filter({ $0.folder == nil }).sorted(by: { $0.sortOrder < $1.sortOrder }) {
            items.append(exportRequest(req))
        }

        let root: [String: Any] = [
            "info": [
                "name": collection.name,
                "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
                "_postman_id": collection.id?.uuidString ?? UUID().uuidString
            ],
            "item": items
        ]
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    private func exportFolder(_ folder: FolderModel) throws -> [String: Any] {
        var items: [[String: Any]] = []
        for sub in folder.subFolders.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            items.append(try exportFolder(sub))
        }
        for req in folder.requests.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            items.append(exportRequest(req))
        }
        return ["name": folder.name, "item": items]
    }

    private func exportRequest(_ req: RequestModel) -> [String: Any] {
        var headers: [[String: Any]] = req.headers.map { h in
            ["key": h.name, "value": h.value, "disabled": !h.isEnabled]
        }
        var body: [String: Any] = ["mode": "raw"]
        if let raw = req.rawBodyContent, !raw.isEmpty {
            body["raw"] = raw
        }

        return [
            "name": req.name,
            "request": [
                "method": req.method,
                "header": headers,
                "url": ["raw": req.url],
                "body": body
            ]
        ]
    }

    /// Export as cURL command
    public func exportCURL(request: RequestModel) -> String {
        let req = request.toHTTPRequest()
        var urlReq = URLRequest(url: URL(string: req.url)!)
        urlReq.httpMethod = req.effectiveMethodName
        for h in req.headers where h.isEnabled {
            urlReq.setValue(h.value, forHTTPHeaderField: h.key)
        }
        if case .raw(let content, _) = req.body {
            urlReq.httpBody = content.data(using: .utf8)
        }
        return urlReq.asCurlCommand()
    }

    /// Export as HAR
    public func exportHAR(response: HTTPResponse) throws -> Data {
        let harEntry: [String: Any] = [
            "startedDateTime": ISO8601DateFormatter().string(from: Date()),
            "time": response.durationMs,
            "request": [
                "method": "GET",
                "url": "",
                "httpVersion": "HTTP/1.1",
                "headers": response.headers.map { ["name": $0.key, "value": $0.value] },
                "queryString": [],
                "cookies": [],
                "headersSize": -1,
                "bodySize": response.body?.count ?? 0
            ],
            "response": [
                "status": response.statusCode,
                "statusText": HTTPURLResponse.localizedString(forStatusCode: response.statusCode),
                "httpVersion": "HTTP/1.1",
                "headers": response.headers.map { ["name": $0.key, "value": $0.value] },
                "cookies": [],
                "content": [
                    "size": response.body?.count ?? 0,
                    "mimeType": response.contentType ?? "text/plain",
                    "text": response.bodyString ?? ""
                ],
                "redirectURL": "",
                "headersSize": -1,
                "bodySize": response.body?.count ?? 0
            ],
            "cache": [:] as [String: Any],
            "timings": [
                "send": response.timeline.requestSentMs,
                "wait": response.timeline.waitingMs,
                "receive": response.timeline.downloadMs
            ]
        ]

        let har: [String: Any] = [
            "log": [
                "version": "1.2",
                "creator": ["name": "APIClient", "version": "1.0"],
                "entries": [harEntry]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: har, options: .prettyPrinted)
    }

    /// Export collection as OpenAPI 3.0 YAML (basic)
    public func exportOpenAPI(collection: CollectionModel) -> String {
        var yaml = """
        openapi: "3.0.0"
        info:
          title: "\(collection.name)"
          version: "1.0.0"
        paths:
        """
        for req in collection.requests {
            let path = URL(string: req.url)?.path ?? "/\(req.name.lowercased())"
            yaml += "\n  \(path):"
            yaml += "\n    \(req.method.lowercased()):"
            yaml += "\n      summary: \"\(req.name)\""
            yaml += "\n      responses:"
            yaml += "\n        '200':"
            yaml += "\n          description: OK"
        }
        return yaml
    }

    /// Generate Markdown API docs from collection
    public func exportMarkdownDocs(collection: CollectionModel) -> String {
        var md = "# \(collection.name)\n\n"
        if !collection.collectionDescription.isEmpty {
            md += collection.collectionDescription + "\n\n"
        }
        md += "## Endpoints\n\n"

        for req in collection.requests.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            md += "### \(req.method) `\(req.url)`\n\n"
            md += "**\(req.name)**\n\n"
            if !req.headers.isEmpty {
                md += "**Headers:**\n\n"
                for h in req.headers where h.isEnabled {
                    md += "- `\(h.name)`: `\(h.value)`\n"
                }
                md += "\n"
            }
            if let body = req.rawBodyContent, !body.isEmpty {
                md += "**Body:**\n\n```json\n\(body)\n```\n\n"
            }
        }
        return md
    }
}
