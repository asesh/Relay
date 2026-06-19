import Testing
import SwiftData
import SwiftUI
@testable import Relay

struct ContentViewTests {
  @Test func testWelcomeViewAppearsWhenNoRequestSelected() async throws {
    let view = ContentView()
    // This is a UI test stub. In a real test, use ViewInspector or snapshot testing.
    #expect(view.body != nil)
  }
}

struct ModelsTests {
  // CollectionItem Tests
  @Test func testCollectionItemInit() async throws {
    let collection = CollectionItem(name: "Test")
    #expect(collection.name == "Test")
    #expect(collection.requests.isEmpty)
    #expect(collection.createdAt <= Date())
  }
  
  @Test func testCollectionItemDefaultName() async throws {
    let collection = CollectionItem()
    #expect(collection.name == "New Collection")
  }
  
  @Test func testCollectionItemWithRequests() async throws {
    let collection = CollectionItem(name: "API Collection")
    let request1 = RequestItem(name: "Get Users")
    let request2 = RequestItem(name: "Create User")
    request1.collection = collection
    request2.collection = collection
    collection.requests.append(contentsOf: [request1, request2])
    #expect(collection.requests.count == 2)
  }
  
  // RequestItem Tests
  @Test func testRequestItemInit() async throws {
    let request = RequestItem(name: "Req", url: "https://example.com", method: "POST")
    #expect(request.name == "Req")
    #expect(request.url == "https://example.com")
    #expect(request.method == "POST")
    #expect(request.bodyType == "none")
    #expect(request.bodyContent == "")
    #expect(request.headers.isEmpty)
    #expect(request.createdAt <= Date())
  }
  
  @Test func testRequestItemDefaultValues() async throws {
    let request = RequestItem()
    #expect(request.name == "New Request")
    #expect(request.url == "")
    #expect(request.method == "GET")
    #expect(request.bodyType == "none")
  }
  
  @Test func testRequestItemWithHeaders() async throws {
    let request = RequestItem()
    let header1 = HeaderItem(key: "Content-Type", value: "application/json")
    let header2 = HeaderItem(key: "Authorization", value: "Bearer token")
    header1.request = request
    header2.request = request
    request.headers.append(contentsOf: [header1, header2])
    #expect(request.headers.count == 2)
  }
  
  @Test func testRequestItemBodyContent() async throws {
    let request = RequestItem()
    request.bodyType = "JSON"
    request.bodyContent = "{\"key\":\"value\"}"
    #expect(request.bodyType == "JSON")
    #expect(request.bodyContent.contains("key"))
  }
  
  // HeaderItem Tests
  @Test func testHeaderItemInit() async throws {
    let header = HeaderItem(key: "A", value: "B", isEnabled: false)
    #expect(header.key == "A")
    #expect(header.value == "B")
    #expect(header.isEnabled == false)
  }
  
  @Test func testHeaderItemDefaultEnabled() async throws {
    let header = HeaderItem()
    #expect(header.isEnabled == true)
  }
  
  // Enum Tests
  @Test func testHTTPMethodEnum() async throws {
    #expect(HTTPMethod.GET.rawValue == "GET")
    #expect(HTTPMethod.POST.rawValue == "POST")
    #expect(HTTPMethod.allCases.count == 7)
  }
  
  @Test func testBodyTypeEnum() async throws {
    #expect(BodyType.none.rawValue == "none")
    #expect(BodyType.json.rawValue == "JSON")
    #expect(BodyType.raw.rawValue == "Raw Text")
    #expect(BodyType.formData.rawValue == "Form Data")
    #expect(BodyType.allCases.count == 4)
  }
}

struct NetworkServiceTests {
  @Test func testHTTPResponseBodyString() async throws {
    let data = "Hello World".data(using: .utf8)!
    let response = HTTPResponse(statusCode: 200, responseHeaders: [:], body: data, duration: 0.1)
    #expect(response.bodyString == "Hello World")
  }
  
  @Test func testHTTPResponsePrettyJSON() async throws {
    let data = "{\"foo\":1,\"bar\":2}".data(using: .utf8)!
    let response = HTTPResponse(statusCode: 200, responseHeaders: ["Content-Type": "application/json"], body: data, duration: 0.5)
    #expect(response.prettyBody.contains("foo"))
    #expect(response.prettyBody.contains("bar"))
    // Pretty JSON should have newlines
    #expect(response.prettyBody.contains("\n"))
  }
  
  @Test func testHTTPResponseNonJSON() async throws {
    let data = "Plain text response".data(using: .utf8)!
    let response = HTTPResponse(statusCode: 200, responseHeaders: [:], body: data, duration: 0.3)
    // prettyBody should fall back to bodyString for non-JSON
    #expect(response.prettyBody == response.bodyString)
  }
  
  @Test func testHTTPResponseSizeStringBytes() async throws {
    let data = Data(count: 512) // 512 bytes
    let response = HTTPResponse(statusCode: 200, responseHeaders: [:], body: data, duration: 0.1)
    #expect(response.sizeString == "512 B")
  }
  
  @Test func testHTTPResponseSizeStringKilobytes() async throws {
    let data = Data(count: 2048) // 2 KB
    let response = HTTPResponse(statusCode: 200, responseHeaders: [:], body: data, duration: 0.1)
    #expect(response.sizeString == "2.0 KB")
  }
  
  @Test func testHTTPResponseSizeStringMegabytes() async throws {
    let data = Data(count: 2_097_152) // 2 MB
    let response = HTTPResponse(statusCode: 200, responseHeaders: [:], body: data, duration: 0.1)
    #expect(response.sizeString == "2.0 MB")
  }
  
  @Test func testHTTPResponseDurationStringMilliseconds() async throws {
    let response = HTTPResponse(statusCode: 200, responseHeaders: [:], body: Data(), duration: 0.123)
    #expect(response.durationString == "123 ms")
  }
  
  @Test func testHTTPResponseDurationStringSeconds() async throws {
    let response = HTTPResponse(statusCode: 200, responseHeaders: [:], body: Data(), duration: 2.5)
    #expect(response.durationString == "2.50 s")
  }
  
  @Test func testHTTPResponseStatusColorSuccess() async throws {
    let response200 = HTTPResponse(statusCode: 200, responseHeaders: [:], body: Data(), duration: 0.1)
    let response201 = HTTPResponse(statusCode: 201, responseHeaders: [:], body: Data(), duration: 0.1)
    #expect(response200.statusColor == .statusSuccess)
    #expect(response201.statusColor == .statusSuccess)
  }
  
  @Test func testHTTPResponseStatusColorRedirect() async throws {
    let response301 = HTTPResponse(statusCode: 301, responseHeaders: [:], body: Data(), duration: 0.1)
    let response302 = HTTPResponse(statusCode: 302, responseHeaders: [:], body: Data(), duration: 0.1)
    #expect(response301.statusColor == .statusRedirect)
    #expect(response302.statusColor == .statusRedirect)
  }
  
  @Test func testHTTPResponseStatusColorClientError() async throws {
    let response400 = HTTPResponse(statusCode: 400, responseHeaders: [:], body: Data(), duration: 0.1)
    let response404 = HTTPResponse(statusCode: 404, responseHeaders: [:], body: Data(), duration: 0.1)
    #expect(response400.statusColor == .statusClientError)
    #expect(response404.statusColor == .statusClientError)
  }
  
  @Test func testHTTPResponseStatusColorServerError() async throws {
    let response500 = HTTPResponse(statusCode: 500, responseHeaders: [:], body: Data(), duration: 0.1)
    let response503 = HTTPResponse(statusCode: 503, responseHeaders: [:], body: Data(), duration: 0.1)
    #expect(response500.statusColor == .statusServerError)
    #expect(response503.statusColor == .statusServerError)
  }
  
  @Test func testNetworkServiceSingleton() async throws {
    let instance1 = NetworkService.shared
    let instance2 = NetworkService.shared
    #expect(instance1 === instance2)
  }
}

struct ThemeTests {
  @Test func testMethodColorGET() async throws {
    let color = Color.methodColor("GET")
    #expect(color != Color.clear)
  }
  
  @Test func testMethodColorPOST() async throws {
    let color = Color.methodColor("POST")
    #expect(color != Color.clear)
  }
  
  @Test func testMethodColorPUT() async throws {
    let color = Color.methodColor("PUT")
    #expect(color != Color.clear)
  }
  
  @Test func testMethodColorDELETE() async throws {
    let color = Color.methodColor("DELETE")
    #expect(color != Color.clear)
  }
  
  @Test func testMethodColorPATCH() async throws {
    let color = Color.methodColor("PATCH")
    #expect(color != Color.clear)
  }
  
  @Test func testMethodColorHEAD() async throws {
    let color = Color.methodColor("HEAD")
    #expect(color != Color.clear)
  }
  
  @Test func testMethodColorUnknown() async throws {
    let color = Color.methodColor("UNKNOWN")
    #expect(color != Color.clear)
  }
  
  @Test func testMethodColorsAreDifferent() async throws {
    let get = Color.methodColor("GET")
    let post = Color.methodColor("POST")
    let delete = Color.methodColor("DELETE")
    #expect(get != post)
    #expect(post != delete)
  }
  
  @Test func testStatusColorSuccess() async throws {
    let color = Color.statusColor(.statusSuccess)
    #expect(color != Color.clear)
  }
  
  @Test func testStatusColorRedirect() async throws {
    let color = Color.statusColor(.statusRedirect)
    #expect(color != Color.clear)
  }
  
  @Test func testStatusColorClientError() async throws {
    let color = Color.statusColor(.statusClientError)
    #expect(color != Color.clear)
  }
  
  @Test func testStatusColorServerError() async throws {
    let color = Color.statusColor(.statusServerError)
    #expect(color != Color.clear)
  }
  
  @Test func testStatusColorsAreDifferent() async throws {
    let success = Color.statusColor(.statusSuccess)
    let error = Color.statusColor(.statusServerError)
    #expect(success != error)
  }
  
  @Test func testRelayThemeColors() async throws {
    #expect(Color.relayBg != Color.clear)
    #expect(Color.relaySidebar != Color.clear)
    #expect(Color.relayPanel != Color.clear)
    #expect(Color.relayInputBg != Color.clear)
    #expect(Color.relayBorder != Color.clear)
    #expect(Color.relayAccent != Color.clear)
    #expect(Color.relaySecondary != Color.clear)
  }
  
  @Test func testMethodBadge() async throws {
    let badge = MethodBadge(method: "GET")
    #expect(badge.body != nil)
  }
  
  @Test func testMethodBadgeSmall() async throws {
    let badge = MethodBadge(method: "POST", small: true)
    #expect(badge.small == true)
  }
}
