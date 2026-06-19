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

// V2: current schema (auth fields + queryParams + environments)
enum RelaySchemaV2: VersionedSchema {
  static let versionIdentifier = Schema.Version(2, 0, 0)

  static var models: [any PersistentModel.Type] {
    [
      CollectionItem.self,
      RequestItem.self,
      HeaderItem.self,
      QueryParamItem.self,
      RelayEnvironment.self,
      EnvironmentVariable.self,
    ]
  }
}

enum RelayMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] { [RelaySchemaV1.self, RelaySchemaV2.self] }

  static var stages: [MigrationStage] { [migrateV1toV2] }

  static let migrateV1toV2 = MigrationStage.custom(
    fromVersion: RelaySchemaV1.self,
    toVersion: RelaySchemaV2.self,
    willMigrate: nil,
    didMigrate: { context in
      // Set sensible defaults for auth fields on all pre-existing RequestItems.
      // CoreData copies "" for new non-optional String columns; authType and
      // authApiKeyLocation need non-empty values to be valid raw values.
      let requests = try context.fetch(FetchDescriptor<RequestItem>())
      for request in requests {
        if request.authType.isEmpty { request.authType = "None" }
        if request.authApiKeyLocation.isEmpty { request.authApiKeyLocation = "Header" }
      }
      try context.save()
    }
  )
}
