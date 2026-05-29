import Foundation
import SwiftData

@Model
public final class WorkspaceModel {
    public var id: UUID
    public var name: String
    public var emoji: String
    public var colorHex: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isCloudSyncEnabled: Bool
    public var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \CollectionModel.workspace)
    public var collections: [CollectionModel]

    @Relationship(deleteRule: .cascade, inverse: \EnvironmentModel.workspace)
    public var environments: [EnvironmentModel]

    @Relationship(deleteRule: .cascade, inverse: \HistoryModel.workspace)
    public var history: [HistoryModel]

    @Relationship(deleteRule: .cascade, inverse: \MockServerModel.workspace)
    public var mockServers: [MockServerModel]

    @Relationship(deleteRule: .cascade, inverse: \TabSessionModel.workspace)
    public var tabSessions: [TabSessionModel]

    public init(
        id: UUID = UUID(),
        name: String = "My Workspace",
        emoji: String = "🚀",
        colorHex: String = "#3B82F6",
        isCloudSyncEnabled: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isCloudSyncEnabled = isCloudSyncEnabled
        self.sortOrder = sortOrder
        self.collections = []
        self.environments = []
        self.history = []
        self.mockServers = []
        self.tabSessions = []
    }
}
