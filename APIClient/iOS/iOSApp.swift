import SwiftUI
import SwiftData

@main
struct iOSApp: App {
    var body: some Scene {
        WindowGroup {
            iOSRootView()
        }
        .modelContainer(AppDatabase.makeContainer())
    }
}
