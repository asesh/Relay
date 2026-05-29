import Foundation
import SwiftData

// MARK: - AppDatabase

/// Central configuration for the SwiftData model container.
public enum AppDatabase {

    public static var schema: Schema {
        Schema([
            WorkspaceModel.self,
            CollectionModel.self,
            FolderModel.self,
            RequestModel.self,
            HeaderModel.self,
            QueryParamModel.self,
            EnvironmentModel.self,
            VariableModel.self,
            HistoryModel.self,
            MockServerModel.self,
            MockRouteModel.self,
            TabSessionModel.self,
        ])
    }

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Returns a container suitable for SwiftUI previews (in-memory, pre-populated).
    public static var previewContainer: ModelContainer {
        let container = try! makeContainer(inMemory: true)
        Task { @MainActor in
            let ctx = container.mainContext
            let workspace = WorkspaceModel(name: "Preview Workspace", emoji: "🧪")
            ctx.insert(workspace)
            let collection = CollectionModel(name: "Sample API", workspace: workspace)
            ctx.insert(collection)
            let request = RequestModel(name: "GET Users", url: "https://jsonplaceholder.typicode.com/users", method: "GET", collection: collection)
            ctx.insert(request)
            try? ctx.save()
        }
        return container
    }
}
