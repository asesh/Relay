//
//  RelayTests.swift
//  RelayTests
//
//  Created by Asesh Shrestha on 28/05/2026.
//

import Testing
import SwiftData
@testable import Relay

struct RelayIntegrationTests {

    @Test func testCollectionWithRequestsRelationship() async throws {
        let collection = CollectionItem(name: "API Tests")
        let request1 = RequestItem(name: "Get Users", url: "https://api.example.com/users", method: "GET")
        let request2 = RequestItem(name: "Create User", url: "https://api.example.com/users", method: "POST")
        
        request1.collection = collection
        request2.collection = collection
        collection.requests.append(contentsOf: [request1, request2])
        
        #expect(collection.requests.count == 2)
        #expect(request1.collection?.name == "API Tests")
        #expect(request2.collection?.name == "API Tests")
    }
    
    @Test func testRequestWithHeadersRelationship() async throws {
        let request = RequestItem(name: "Auth Request")
        let header1 = HeaderItem(key: "Authorization", value: "Bearer token123")
        let header2 = HeaderItem(key: "Content-Type", value: "application/json")
        
        header1.request = request
        header2.request = request
        request.headers.append(contentsOf: [header1, header2])
        
        #expect(request.headers.count == 2)
        #expect(header1.request?.name == "Auth Request")
        #expect(header2.request?.name == "Auth Request")
    }
    
    @Test func testHTTPResponseWithMultipleStatusCodes() async throws {
        let testCases: [(Int, RelayColor)] = [
            (200, .statusSuccess),
            (204, .statusSuccess),
            (301, .statusRedirect),
            (302, .statusRedirect),
            (400, .statusClientError),
            (404, .statusClientError),
            (500, .statusServerError),
            (503, .statusServerError)
        ]
        
        for (code, expectedColor) in testCases {
            let response = HTTPResponse(statusCode: code, responseHeaders: [:], body: Data(), duration: 0.1)
            #expect(response.statusColor == expectedColor)
        }
    }
    
    @Test func testRequestBodyTypes() async throws {
        let request = RequestItem()
        
        // Test all body types
        let bodyTypes = ["none", "JSON", "Raw Text", "Form Data"]
        for bodyType in bodyTypes {
            request.bodyType = bodyType
            #expect(request.bodyType == bodyType)
        }
    }
    
    @Test func testHTTPMethodsExist() async throws {
        let methods = HTTPMethod.allCases
        #expect(methods.contains(.GET))
        #expect(methods.contains(.POST))
        #expect(methods.contains(.PUT))
        #expect(methods.contains(.DELETE))
        #expect(methods.contains(.PATCH))
        #expect(methods.contains(.HEAD))
        #expect(methods.contains(.OPTIONS))
    }
    
    @Test func testRequestWithJSONBody() async throws {
        let request = RequestItem(name: "Create Item", url: "https://api.example.com/items", method: "POST")
        request.bodyType = BodyType.json.rawValue
        request.bodyContent = "{\"name\":\"Test Item\",\"price\":99.99}"
        
        #expect(request.method == "POST")
        #expect(request.bodyType == "JSON")
        #expect(request.bodyContent.contains("name"))
        #expect(request.bodyContent.contains("price"))
    }
    
    @Test func testEnabledAndDisabledHeaders() async throws {
        let request = RequestItem()
        let enabledHeader = HeaderItem(key: "Authorization", value: "Bearer token", isEnabled: true)
        let disabledHeader = HeaderItem(key: "X-Debug", value: "true", isEnabled: false)
        
        request.headers.append(contentsOf: [enabledHeader, disabledHeader])
        
        let enabledHeaders = request.headers.filter { $0.isEnabled }
        let disabledHeaders = request.headers.filter { !$0.isEnabled }
        
        #expect(enabledHeaders.count == 1)
        #expect(disabledHeaders.count == 1)
        #expect(enabledHeaders.first?.key == "Authorization")
        #expect(disabledHeaders.first?.key == "X-Debug")
    }
    
    @Test func testHTTPResponseWithEmptyBody() async throws {
        let response = HTTPResponse(statusCode: 204, responseHeaders: [:], body: Data(), duration: 0.05)
        #expect(response.body.isEmpty)
        #expect(response.bodyString == "")
        #expect(response.sizeString == "0 B")
    }
    
    @Test func testHTTPResponseWithLargeBody() async throws {
        let largeData = Data(count: 5_242_880) // 5 MB
        let response = HTTPResponse(statusCode: 200, responseHeaders: [:], body: largeData, duration: 1.5)
        #expect(response.sizeString == "5.0 MB")
        #expect(response.durationString == "1.50 s")
    }

}
