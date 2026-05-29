import SwiftUI
import SwiftData

@main
struct iPadOSApp: App {
    var body: some Scene {
        WindowGroup {
            iPadOSRootView()
        }
        .modelContainer(AppDatabase.makeContainer())
    }
}
