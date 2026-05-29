import SwiftUI
import SwiftData

public struct macOSRootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 360)
        } content: {
            Group {
                if let collection = appState.selectedCollection {
                    CollectionListView(filter: collection)
                } else {
                    CollectionListView()
                }
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 420)
        } detail: {
            DetailView()
        }
        .onAppear { loadWorkspace() }
        .overlay(alignment: .center) {
            if appState.showCommandPalette {
                CommandPaletteView(isPresented: $appState.showCommandPalette)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.25), value: appState.showCommandPalette)
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
