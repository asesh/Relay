import Foundation
import SwiftData

enum HTTPMethod: String, CaseIterable, Codable {
    case GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
}

enum BodyType: String, CaseIterable, Codable {
    case none = "none"
    case json = "JSON"
    case raw = "Raw Text"
    case formData = "Form Data"
}

@Model
final class CollectionItem {
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \RequestItem.collection)
    var requests: [RequestItem]

    init(name: String = "New Collection") {
        self.name = name
        self.createdAt = Date()
        self.requests = []
    }
}

@Model
final class RequestItem {
    var name: String
    var url: String
    var method: String
    var bodyType: String
    var bodyContent: String
    var createdAt: Date
    var collection: CollectionItem?
    @Relationship(deleteRule: .cascade, inverse: \HeaderItem.request)
    var headers: [HeaderItem]

    init(name: String = "New Request", url: String = "", method: String = "GET") {
        self.name = name
        self.url = url
        self.method = method
        self.bodyType = "none"
        self.bodyContent = ""
        self.createdAt = Date()
        self.headers = []
    }
}

@Model
final class HeaderItem {
    var key: String
    var value: String
    var isEnabled: Bool
    var request: RequestItem?

    init(key: String = "", value: String = "", isEnabled: Bool = true) {
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
    }
}
