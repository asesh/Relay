import SwiftUI
import SwiftData

@main
struct RelayApp: App {
  var sharedModelContainer: ModelContainer = {
    let schema = Schema(RelaySchemaV3.models)
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    do {
      return try ModelContainer(
        for: schema,
        migrationPlan: RelayMigrationPlan.self,
        configurations: [modelConfiguration]
      )
    } catch {
      // Fallback: delete the persistent store and start fresh.
      // This should only happen in development when a migration path is missing.
      let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
      for ext in ["store", "store-shm", "store-wal"] {
        try? FileManager.default.removeItem(at: appSupport.appendingPathComponent("default.\(ext)"))
      }
      do {
        return try ModelContainer(
          for: schema,
          migrationPlan: RelayMigrationPlan.self,
          configurations: [modelConfiguration]
        )
      } catch {
        fatalError("Could not create ModelContainer: \(error)")
      }
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
  }
}
