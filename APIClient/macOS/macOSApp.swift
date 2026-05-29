import SwiftUI
import SwiftData

@main
struct macOSApp: App {
    @StateObject private var appState = AppState()
    @AppStorage(SettingsKey.colorScheme) private var colorScheme = ColorSchemePreference.system

    var body: some Scene {
        WindowGroup {
            macOSRootView()
                .environmentObject(appState)
                .preferredColorScheme(colorScheme.swiftUIColorScheme)
        }
        .modelContainer(AppDatabase.makeContainer())
        .commands { MenuBarCommands() }

        // Settings window
        Settings {
            AppSettingsView()
                .environmentObject(appState)
        }
    }
}
