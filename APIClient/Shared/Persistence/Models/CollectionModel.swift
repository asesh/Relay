import Foundation
import SwiftData

@Model
public final class CollectionModel {
    public var id: UUID
    public var name: String
    public var collectionDescription: String
    public var colorHex: String
    public var sfSymbol: String
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    // Inherited settings stored as JSON
    public var authConfigData: Data?
    public var headersData: Data?
    public var variablesData: Data?
    public var preRequestScriptData: String
    public var testScriptData: String

    public var workspace: WorkspaceModel?

    @Relationship(deleteRule: .cascade, inverse: \FolderModel.collection)
    public var folders: [FolderModel]

    @Relationship(deleteRule: .cascade, inverse: \RequestModel.collection)
    public var requests: [RequestModel]

    public init(
        id: UUID = UUID(),
        name: String = "New Collection",
        collectionDescription: String = "",
        colorHex: String = "#3B82F6",
        sfSymbol: String = "folder",
        sortOrder: Int = 0,
        workspace: WorkspaceModel? = nil
    ) {
        self.id = id; self.name = name
        self.collectionDescription = collectionDescription
        self.colorHex = colorHex; self.sfSymbol = sfSymbol
        self.sortOrder = sortOrder
        self.createdAt = Date(); self.updatedAt = Date()
        self.workspace = workspace
        self.preRequestScriptData = ""; self.testScriptData = ""
        self.folders = []; self.requests = []
    }

    public var authConfig: AuthConfig? {
        get {
            guard let data = authConfigData else { return nil }
            return try? JSONDecoder().decode(AuthConfig.self, from: data)
        }
        set {
            authConfigData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }

    public var collectionVariables: [EnvironmentVariable] {
        get {
            guard let data = variablesData else { return [] }
            return (try? JSONDecoder().decode([EnvironmentVariable].self, from: data)) ?? []
        }
        set {
            variablesData = try? JSONEncoder().encode(newValue)
        }
    }
}

@Model
public final class FolderModel {
    public var id: UUID
    public var name: String
    public var folderDescription: String
    public var sortOrder: Int
    public var createdAt: Date

    public var authConfigData: Data?
    public var headersData: Data?
    public var preRequestScriptData: String
    public var testScriptData: String

    public var collection: CollectionModel?
    public var parentFolder: FolderModel?

    @Relationship(deleteRule: .cascade, inverse: \FolderModel.parentFolder)
    public var subFolders: [FolderModel]

    @Relationship(deleteRule: .cascade, inverse: \RequestModel.folder)
    public var requests: [RequestModel]

    public init(
        id: UUID = UUID(),
        name: String = "New Folder",
        folderDescription: String = "",
        sortOrder: Int = 0,
        collection: CollectionModel? = nil,
        parentFolder: FolderModel? = nil
    ) {
        self.id = id; self.name = name
        self.folderDescription = folderDescription
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.collection = collection; self.parentFolder = parentFolder
        self.preRequestScriptData = ""; self.testScriptData = ""
        self.subFolders = []; self.requests = []
    }
}
