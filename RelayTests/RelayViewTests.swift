import Testing
import SwiftData
import SwiftUI
@testable import Relay

struct RequestEditorViewTests {
  @Test func testRequestEditorViewInit() async throws {
    let request = RequestItem()
    let view = RequestEditorView(request: request)
    #expect(view.body != nil)
  }
  
  @Test func testRequestEditorViewWithURL() async throws {
    let request = RequestItem(url: "https://api.example.com/users")
    let view = RequestEditorView(request: request)
    #expect(view.body != nil)
  }
  
  @Test func testBodyEditorViewDefaultNone() async throws {
    let request = RequestItem()
    let bodyView = BodyEditorView(request: request)
    #expect(bodyView.bodyType == .none)
  }
  
  @Test func testBodyEditorViewJSON() async throws {
    let request = RequestItem()
    request.bodyType = BodyType.json.rawValue
    let bodyView = BodyEditorView(request: request)
    #expect(bodyView.bodyType == .json)
  }
  
  @Test func testBodyEditorViewRaw() async throws {
    let request = RequestItem()
    request.bodyType = BodyType.raw.rawValue
    let bodyView = BodyEditorView(request: request)
    #expect(bodyView.bodyType == .raw)
  }
  
  @Test func testBodyEditorViewFormData() async throws {
    let request = RequestItem()
    request.bodyType = BodyType.formData.rawValue
    let bodyView = BodyEditorView(request: request)
    #expect(bodyView.bodyType == .formData)
  }
  
  @Test func testHeadersEditorViewInit() async throws {
    let request = RequestItem()
    let headersView = HeadersEditorView(request: request)
    #expect(headersView.body != nil)
  }
  
  @Test func testHeadersEditorViewWithHeaders() async throws {
    let request = RequestItem()
    let header1 = HeaderItem(key: "Content-Type", value: "application/json", isEnabled: true)
    let header2 = HeaderItem(key: "Authorization", value: "Bearer xyz", isEnabled: true)
    request.headers.append(contentsOf: [header1, header2])
    let headersView = HeadersEditorView(request: request)
    #expect(request.headers.count == 2)
    #expect(headersView.body != nil)
  }
  
  @Test func testHeaderRowViewEnabled() async throws {
    let header = HeaderItem(key: "Accept", value: "application/json", isEnabled: true)
    let row = HeaderRowView(header: header, onDelete: {})
    #expect(row.body != nil)
  }
  
  @Test func testHeaderRowViewDisabled() async throws {
    let header = HeaderItem(key: "X-Custom", value: "disabled", isEnabled: false)
    let row = HeaderRowView(header: header, onDelete: {})
    #expect(row.body != nil)
  }
  
  @Test func testRequestTabEnum() async throws {
    #expect(RequestTab.headers.rawValue == "Headers")
    #expect(RequestTab.body.rawValue == "Body")
    #expect(RequestTab.allCases.count == 2)
  }
  
  @Test func testResponseTabEnum() async throws {
    #expect(ResponseTab.pretty.rawValue == "Pretty")
    #expect(ResponseTab.raw.rawValue == "Raw")
    #expect(ResponseTab.headers.rawValue == "Headers")
    #expect(ResponseTab.allCases.count == 3)
  }
}

struct SidebarViewTests {
  @Test func testSidebarViewInit() async throws {
    let view = SidebarView(selectedRequest: .constant(nil))
    #expect(view.body != nil)
  }
  
  @Test func testSidebarViewWithSelection() async throws {
    let request = RequestItem(name: "Test Request")
    let view = SidebarView(selectedRequest: .constant(request))
    #expect(view.body != nil)
  }
  
  @Test func testCollectionRowNotExpanded() async throws {
    let collection = CollectionItem(name: "Test Collection")
    let row = CollectionRow(
      collection: collection,
      isExpanded: false,
      selectedRequest: .constant(nil),
      onToggle: {},
      onAddRequest: {},
      onDelete: {}
    )
    #expect(row.body != nil)
  }
  
  @Test func testCollectionRowExpanded() async throws {
    let collection = CollectionItem(name: "Test Collection")
    let row = CollectionRow(
      collection: collection,
      isExpanded: true,
      selectedRequest: .constant(nil),
      onToggle: {},
      onAddRequest: {},
      onDelete: {}
    )
    #expect(row.body != nil)
  }
  
  @Test func testCollectionRowWithRequests() async throws {
    let collection = CollectionItem(name: "API")
    let request1 = RequestItem(name: "Get Users")
    let request2 = RequestItem(name: "Create User")
    request1.collection = collection
    request2.collection = collection
    collection.requests.append(contentsOf: [request1, request2])
    
    let row = CollectionRow(
      collection: collection,
      isExpanded: true,
      selectedRequest: .constant(nil),
      onToggle: {},
      onAddRequest: {},
      onDelete: {}
    )
    #expect(row.body != nil)
    #expect(collection.requests.count == 2)
  }
  
  @Test func testRequestRowNotSelected() async throws {
    let request = RequestItem(name: "Test Request", method: "GET")
    let row = RequestRow(
      request: request,
      isSelected: false,
      onSelect: {},
      onDelete: {}
    )
    #expect(row.body != nil)
  }
  
  @Test func testRequestRowSelected() async throws {
    let request = RequestItem(name: "Test Request", method: "POST")
    let row = RequestRow(
      request: request,
      isSelected: true,
      onSelect: {},
      onDelete: {}
    )
    #expect(row.body != nil)
  }
  
  @Test func testRequestRowDifferentMethods() async throws {
    let getRequest = RequestItem(name: "Get", method: "GET")
    let postRequest = RequestItem(name: "Post", method: "POST")
    let deleteRequest = RequestItem(name: "Delete", method: "DELETE")
    
    let getRow = RequestRow(request: getRequest, isSelected: false, onSelect: {}, onDelete: {})
    let postRow = RequestRow(request: postRequest, isSelected: false, onSelect: {}, onDelete: {})
    let deleteRow = RequestRow(request: deleteRequest, isSelected: false, onSelect: {}, onDelete: {})
    
    #expect(getRow.body != nil)
    #expect(postRow.body != nil)
    #expect(deleteRow.body != nil)
  }
}

struct ContentViewTests {
  @Test func testContentViewInit() async throws {
    let view = ContentView()
    #expect(view.body != nil)
  }
  
  @Test func testWelcomeViewInit() async throws {
    let view = WelcomeView()
    #expect(view.body != nil)
  }
}

struct RelayAppTests {
  @Test func testRelayAppInit() async throws {
    let app = RelayApp()
    #expect(app.sharedModelContainer != nil)
  }
}
