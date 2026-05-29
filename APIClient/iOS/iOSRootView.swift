import SwiftUI
import SwiftData

public struct iOSRootView: View {
    @StateObject private var appState = AppState()
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.colorScheme) private var colorScheme = ColorSchemePreference.system
    @State private var selectedNavTab: NavigationTab = .request

    public init() {}

    public var body: some View {
        TabView(selection: $selectedNavTab) {
            // Tab 1: Active Request
            NavigationStack {
                if let request = appState.selectedRequest {
                    RequestEditorView(request: request)
                } else {
                    WelcomeView()
                }
            }
            .tabItem { Label("Request", systemImage: "doc.text") }
            .tag(NavigationTab.request)

            // Tab 2: Collections
            NavigationStack {
                CollectionListView()
            }
            .tabItem { Label("Collections", systemImage: "folder") }
            .tag(NavigationTab.collections)

            // Tab 3: Environments
            NavigationStack {
                EnvironmentListView()
            }
            .tabItem { Label("Environments", systemImage: "square.stack.3d.up") }
            .tag(NavigationTab.environments)

            // Tab 4: History
            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            .tag(NavigationTab.history)

            // Tab 5: Settings
            NavigationStack {
                AppSettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(NavigationTab.settings)
        }
        .environmentObject(appState)
        .preferredColorScheme(colorScheme.swiftUIColorScheme)
        .onAppear {
            loadWorkspace()
        }
    }

    private func loadWorkspace() {
        let descriptor = FetchDescriptor<WorkspaceModel>(sortBy: [SortDescriptor(\.createdAt)])
        if let workspace = try? context.fetch(descriptor).first {
            appState.activeWorkspace = workspace
        } else {
            let workspace = WorkspaceModel(name: "My Workspace")
            context.insert(workspace)
            try? context.save()
            appState.activeWorkspace = workspace
        }
    }
}
