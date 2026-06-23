import SwiftUI
import SwiftData

@main
struct RelayApp: App {
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      CollectionItem.self,
      RequestItem.self,
      HeaderItem.self,
      QueryParamItem.self,
      RelayEnvironment.self,
      EnvironmentVariable.self,
    ])
    // Delete any existing store so we always start fresh.
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    for ext in ["store", "store-shm", "store-wal"] {
      try? FileManager.default.removeItem(at: appSupport.appendingPathComponent("default.\(ext)"))
    }
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    do {
      return try ModelContainer(for: schema, configurations: [config])
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
