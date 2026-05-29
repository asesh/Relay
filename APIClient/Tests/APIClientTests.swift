import XCTest

// MARK: - Variable Resolver Tests
class VariableResolverTests: XCTestCase {

    func testResolveSimpleVariable() {
        let resolver = VariableResolver()
            .withEnvironment(["baseUrl": "https://api.example.com"])
        let result = resolver.resolve("{{baseUrl}}/users")
        XCTAssertEqual(result, "https://api.example.com/users")
    }

    func testResolveMultipleVariables() {
        let resolver = VariableResolver()
            .withEnvironment(["host": "api.example.com", "version": "v2"])
        let result = resolver.resolve("https://{{host}}/{{version}}/users")
        XCTAssertEqual(result, "https://api.example.com/v2/users")
    }

    func testUnresolvedVariableRemainsUnchanged() {
        let resolver = VariableResolver()
        let result = resolver.resolve("{{missing}}")
        XCTAssertEqual(result, "{{missing}}")
    }

    func testScopeChain_LocalOverridesEnvironment() {
        let resolver = VariableResolver()
            .withEnvironment(["key": "env-value"])
            .withLocal(["key": "local-value"])
        let result = resolver.resolve("{{key}}")
        XCTAssertEqual(result, "local-value")
    }

    func testTokenExtraction() {
        let tokens = VariableResolver.extractTokens(from: "Hello {{name}}, welcome to {{place}}!")
        XCTAssertEqual(tokens.sorted(), ["name", "place"])
    }

    func testNoTokens() {
        let tokens = VariableResolver.extractTokens(from: "plain string")
        XCTAssertTrue(tokens.isEmpty)
    }
}

// MARK: - Auth Handler Tests
class AuthHandlerTests: XCTestCase {

    func testAPIKeyInHeader() {
        var request = HTTPRequest(url: "https://api.example.com", method: .GET)
        let config = AuthConfig(
            type: .apiKey,
            apiKey: APIKeyConfig(key: "X-API-Key", value: "secret123", placement: .header)
        )
        request.auth = config
        let handler = AuthHandler()
        var urlRequest = URLRequest(url: URL(string: request.url)!)
        handler.inject(auth: config, into: &urlRequest, request: request)
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "X-API-Key"), "secret123")
    }

    func testBearerTokenInjection() {
        var request = HTTPRequest(url: "https://api.example.com", method: .GET)
        let config = AuthConfig(
            type: .bearer,
            bearer: BearerConfig(token: "my-bearer-token")
        )
        request.auth = config
        let handler = AuthHandler()
        var urlRequest = URLRequest(url: URL(string: request.url)!)
        handler.inject(auth: config, into: &urlRequest, request: request)
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer my-bearer-token")
    }

    func testBasicAuthEncoding() {
        var request = HTTPRequest(url: "https://api.example.com", method: .GET)
        let config = AuthConfig(
            type: .basic,
            basic: BasicAuthConfig(username: "user", password: "pass")
        )
        request.auth = config
        let handler = AuthHandler()
        var urlRequest = URLRequest(url: URL(string: request.url)!)
        handler.inject(auth: config, into: &urlRequest, request: request)
        let expected = "Basic " + Data("user:pass".utf8).base64EncodedString()
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), expected)
    }
}

// MARK: - cURL Parser Tests
class CurlParserTests: XCTestCase {

    func testParseSimpleGET() {
        let curl = "curl https://api.example.com/users"
        let req = CurlParser.parse(curl)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.url, "https://api.example.com/users")
        XCTAssertEqual(req?.method, .GET)
    }

    func testParseWithMethod() {
        let curl = "curl -X POST https://api.example.com/users"
        let req = CurlParser.parse(curl)
        XCTAssertEqual(req?.method, .POST)
    }

    func testParseWithHeaders() {
        let curl = #"curl -H "Content-Type: application/json" -H "X-API-Key: secret" https://api.example.com"#
        let req = CurlParser.parse(curl)
        let headers = req?.headers ?? []
        XCTAssertTrue(headers.contains { $0.key == "Content-Type" && $0.value == "application/json" })
        XCTAssertTrue(headers.contains { $0.key == "X-API-Key" && $0.value == "secret" })
    }

    func testParseWithBody() {
        let curl = #"curl -X POST -d '{"name":"John"}' https://api.example.com/users"#
        let req = CurlParser.parse(curl)
        if case .raw(let content, _) = req?.body {
            XCTAssertEqual(content, "{\"name\":\"John\"}")
        } else {
            XCTFail("Expected raw body")
        }
    }

    func testParseWithBasicAuth() {
        let curl = #"curl -u user:pass https://api.example.com"#
        let req = CurlParser.parse(curl)
        XCTAssertEqual(req?.auth.type, .basic)
        XCTAssertEqual(req?.auth.basic?.username, "user")
        XCTAssertEqual(req?.auth.basic?.password, "pass")
    }
}

// MARK: - Postman Collection Parser Tests
class PostmanCollectionParserTests: XCTestCase {

    func testParseMinimalCollection() {
        let json = """
        {
          "info": { "name": "Test API", "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json" },
          "item": [
            { "name": "Get Users", "request": { "method": "GET", "url": { "raw": "https://api.example.com/users" } } }
          ]
        }
        """.data(using: .utf8)!

        let collection = try? PostmanCollectionParser.parse(json)
        XCTAssertNotNil(collection)
        XCTAssertEqual(collection?.name, "Test API")
        XCTAssertEqual(collection?.requests.count, 1)
        XCTAssertEqual(collection?.requests.first?.name, "Get Users")
    }

    func testParseCollectionWithFolder() {
        let json = """
        {
          "info": { "name": "API", "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json" },
          "item": [
            {
              "name": "Users",
              "item": [
                { "name": "List", "request": { "method": "GET", "url": { "raw": "https://api.example.com/users" } } }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let collection = try? PostmanCollectionParser.parse(json)
        XCTAssertEqual(collection?.folders.count, 1)
        XCTAssertEqual(collection?.folders.first?.name, "Users")
        XCTAssertEqual(collection?.folders.first?.requests.count, 1)
    }
}

// MARK: - Code Generator Tests
class CodeGeneratorTests: XCTestCase {

    private var sampleRequest: HTTPRequest {
        var req = HTTPRequest(url: "https://api.example.com/users", method: .POST)
        req.headers = [
            KeyValuePair(key: "Content-Type", value: "application/json", isEnabled: true),
            KeyValuePair(key: "X-API-Key", value: "secret", isEnabled: true),
        ]
        req.body = .raw("{\"name\":\"John\"}", .json)
        return req
    }

    func testSwiftGeneration() {
        let code = CodeGenerator.generate(for: sampleRequest, language: .swiftURLSession)
        XCTAssertTrue(code.contains("URLSession"))
        XCTAssertTrue(code.contains("POST"))
        XCTAssertTrue(code.contains("api.example.com"))
    }

    func testPythonGeneration() {
        let code = CodeGenerator.generate(for: sampleRequest, language: .python)
        XCTAssertTrue(code.contains("requests"))
        XCTAssertTrue(code.contains("post"))
    }

    func testJavaScriptGeneration() {
        let code = CodeGenerator.generate(for: sampleRequest, language: .javaScriptFetch)
        XCTAssertTrue(code.contains("fetch"))
        XCTAssertTrue(code.contains("POST"))
    }

    func testGoGeneration() {
        let code = CodeGenerator.generate(for: sampleRequest, language: .go)
        XCTAssertTrue(code.contains("http.NewRequest"))
    }

    func testCurlExport() {
        var urlReq = URLRequest(url: URL(string: sampleRequest.url)!)
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlReq.httpBody = "{\"name\":\"John\"}".data(using: .utf8)
        let curl = urlReq.asCurlCommand()
        XCTAssertTrue(curl.contains("curl"))
        XCTAssertTrue(curl.contains("-X POST"))
    }
}
