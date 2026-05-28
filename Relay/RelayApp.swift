import SwiftUI
import SwiftData

@main
struct RelayApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CollectionItem.self,
            RequestItem.self,
            HeaderItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
