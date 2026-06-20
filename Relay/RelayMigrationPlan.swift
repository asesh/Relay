import SwiftData
import Foundation

// V1: schema before Phase 1 (no auth fields, no queryParams, no RelayEnvironment/EnvironmentVariable)
enum RelaySchemaV1: VersionedSchema {
  static let versionIdentifier = Schema.Version(1, 0, 0)

  static var models: [any PersistentModel.Type] {
    [CollectionItem.self, RequestItem.self, HeaderItem.self]
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

    init(name: String = "New Request") {
      self.name = name
      self.url = ""
      self.method = "GET"
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
}

// V2: added auth fields, queryParams, RelayEnvironment, EnvironmentVariable
enum RelaySchemaV2: VersionedSchema {
  static let versionIdentifier = Schema.Version(2, 0, 0)

  static var models: [any PersistentModel.Type] {
    [
      CollectionItem.self, RequestItem.self, HeaderItem.self,
      QueryParamItem.self, RelayEnvironment.self, EnvironmentVariable.self,
    ]
  }

  @Model final class CollectionItem {
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \RequestItem.collection)
    var requests: [RequestItem]
    init(name: String = "New Collection") {
      self.name = name; self.createdAt = Date(); self.requests = []
    }
  }

  @Model final class RequestItem {
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
    var authType: String
    var authBearerToken: String
    var authBasicUsername: String
    var authBasicPassword: String
    var authApiKeyName: String
    var authApiKeyValue: String
    var authApiKeyLocation: String
    init(name: String = "New Request", url: String = "", method: String = "GET") {
      self.name = name; self.url = url; self.method = method
      self.bodyType = "none"; self.bodyContent = ""; self.createdAt = Date()
      self.headers = []; self.queryParams = []
      self.authType = "None"; self.authBearerToken = ""
      self.authBasicUsername = ""; self.authBasicPassword = ""
      self.authApiKeyName = ""; self.authApiKeyValue = ""; self.authApiKeyLocation = "Header"
    }
  }

  @Model final class HeaderItem {
    var key: String
    var value: String
    var isEnabled: Bool
    var request: RequestItem?
    init(key: String = "", value: String = "", isEnabled: Bool = true) {
      self.key = key; self.value = value; self.isEnabled = isEnabled
    }
  }

  @Model final class QueryParamItem {
    var key: String
    var value: String
    var isEnabled: Bool
    var request: RequestItem?
    init(key: String = "", value: String = "", isEnabled: Bool = true) {
      self.key = key; self.value = value; self.isEnabled = isEnabled
    }
  }

  @Model final class RelayEnvironment {
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \EnvironmentVariable.environment)
    var variables: [EnvironmentVariable]
    init(name: String = "New Environment") {
      self.name = name; self.createdAt = Date(); self.variables = []
    }
  }

  @Model final class EnvironmentVariable {
    var key: String
    var value: String
    var isEnabled: Bool
    var environment: RelayEnvironment?
    init(key: String = "", value: String = "", isEnabled: Bool = true) {
      self.key = key; self.value = value; self.isEnabled = isEnabled
    }
  }
}

// V3: added createdAt to HeaderItem and QueryParamItem for stable insertion-order sorting
enum RelaySchemaV3: VersionedSchema {
  static let versionIdentifier = Schema.Version(3, 0, 0)

  static var models: [any PersistentModel.Type] {
    [
      CollectionItem.self, RequestItem.self, HeaderItem.self,
      QueryParamItem.self, RelayEnvironment.self, EnvironmentVariable.self,
    ]
  }
}

enum RelayMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    [RelaySchemaV1.self, RelaySchemaV2.self, RelaySchemaV3.self]
  }

  static var stages: [MigrationStage] { [migrateV1toV2, migrateV2toV3] }

  static let migrateV1toV2 = MigrationStage.custom(
    fromVersion: RelaySchemaV1.self,
    toVersion: RelaySchemaV2.self,
    willMigrate: nil,
    didMigrate: { context in
      let requests = try context.fetch(FetchDescriptor<RequestItem>())
      for request in requests {
        if request.authType.isEmpty { request.authType = "None" }
        if request.authApiKeyLocation.isEmpty { request.authApiKeyLocation = "Header" }
      }
      try context.save()
    }
  )

  // Assigns createdAt to all existing HeaderItem and QueryParamItem rows using their
  // SQLite fetch order (which reflects rowid / insertion order) so sorting is stable.
  static let migrateV2toV3 = MigrationStage.custom(
    fromVersion: RelaySchemaV2.self,
    toVersion: RelaySchemaV3.self,
    willMigrate: nil,
    didMigrate: { context in
      let headers = try context.fetch(FetchDescriptor<HeaderItem>())
      for (i, header) in headers.enumerated() {
        header.createdAt = Date(timeIntervalSince1970: Double(i))
      }
      let params = try context.fetch(FetchDescriptor<QueryParamItem>())
      for (i, param) in params.enumerated() {
        param.createdAt = Date(timeIntervalSince1970: Double(i))
      }
      try context.save()
    }
  )
}
