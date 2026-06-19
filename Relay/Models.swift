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

enum AuthType: String, CaseIterable, Codable {
  case none = "None"
  case bearer = "Bearer"
  case basic = "Basic"
  case apiKey = "API Key"
}

enum APIKeyLocation: String, CaseIterable, Codable {
  case header = "Header"
  case queryParam = "Query Param"
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
  @Relationship(deleteRule: .cascade, inverse: \QueryParamItem.request)
  var queryParams: [QueryParamItem]

  // Auth
  var authType: String
  var authBearerToken: String
  var authBasicUsername: String
  var authBasicPassword: String
  var authApiKeyName: String
  var authApiKeyValue: String
  var authApiKeyLocation: String

  init(name: String = "New Request", url: String = "", method: String = "GET") {
    self.name = name
    self.url = url
    self.method = method
    self.bodyType = BodyType.none.rawValue
    self.bodyContent = ""
    self.createdAt = Date()
    self.headers = []
    self.queryParams = []
    self.authType = AuthType.none.rawValue
    self.authBearerToken = ""
    self.authBasicUsername = ""
    self.authBasicPassword = ""
    self.authApiKeyName = ""
    self.authApiKeyValue = ""
    self.authApiKeyLocation = APIKeyLocation.header.rawValue
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

@Model
final class QueryParamItem {
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

@Model
final class RelayEnvironment {
  var name: String
  var createdAt: Date
  @Relationship(deleteRule: .cascade, inverse: \EnvironmentVariable.environment)
  var variables: [EnvironmentVariable]

  init(name: String = "New Environment") {
    self.name = name
    self.createdAt = Date()
    self.variables = []
  }
}

@Model
final class EnvironmentVariable {
  var key: String
  var value: String
  var isEnabled: Bool
  var environment: RelayEnvironment?

  init(key: String = "", value: String = "", isEnabled: Bool = true) {
    self.key = key
    self.value = value
    self.isEnabled = isEnabled
  }
}
