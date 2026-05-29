import SwiftUI
import SwiftData

public struct iPadOSRootView: View {
    @StateObject private var appState = AppState()
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.colorScheme) private var colorScheme = ColorSchemePreference.system
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: workspace/navigation
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } content: {
            // Content: collection/request list
            if let collection = appState.selectedCollection {
                CollectionListView(filter: collection)
            } else {
                CollectionListView()
            }
        } detail: {
            // Detail: request editor + response
            DetailView()
        }
        .environmentObject(appState)
        .preferredColorScheme(colorScheme.swiftUIColorScheme)
        .onAppear { loadWorkspace() }
        .keyboardShortcut("k", modifiers: .command) // Command palette
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
