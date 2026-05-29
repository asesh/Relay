import SwiftUI
import SwiftData

// MARK: - Sidebar View

public struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkspaceModel.sortOrder) private var workspaces: [WorkspaceModel]

    @State private var searchText = ""
    @State private var showNewCollection = false

    public init() {}

    private var workspace: WorkspaceModel? { appState.activeWorkspace }

    public var body: some View {
        VStack(spacing: 0) {
            // Workspace picker header
            WorkspacePickerView()
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            Divider()

            // Search
            SearchBarView(text: $searchText)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            Divider()

            // Nav list
            List {
                NavigationSection(title: "Collections", systemImage: "folder") {
                    if let ws = workspace {
                        ForEach(ws.collections.sorted { $0.sortOrder < $1.sortOrder }) { collection in
                            CollectionRowView(collection: collection)
                        }
                    }
                }

                NavigationSection(title: "Environments", systemImage: "circle.hexagongrid") {
                    EnvironmentListView()
                        .listRowInsets(EdgeInsets())
                        .frame(height: 0)
                        .hidden()
                    // Navigate to environment list
                    NavigationLink("Manage Environments") {
                        EnvironmentListView()
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                NavigationSection(title: "History", systemImage: "clock") {
                    NavigationLink("View History") {
                        HistoryView()
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                NavigationSection(title: "Mock Servers", systemImage: "server.rack") {
                    if let ws = workspace {
                        ForEach(ws.mockServers) { server in
                            MockServerRowView(server: server)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Footer
            HStack {
                Button {
                    showNewCollection = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("New Collection")

                Spacer()

                #if os(macOS)
                iCloudStatusView()
                #endif
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showNewCollection) {
            CollectionEditorView(collection: nil)
        }
    }

    @ViewBuilder
    private func iCloudStatusView() -> some View {
        if appState.activeWorkspace?.isCloudSyncEnabled == true {
            Image(systemName: "icloud.fill")
                .font(.caption)
                .foregroundStyle(.blue)
                .help("iCloud sync enabled")
        }
    }
}

// MARK: - Navigation Section

private struct NavigationSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content
    @State private var isExpanded = true

    var body: some View {
        Section(isExpanded: $isExpanded) {
            content()
        } header: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Collection Row View (sidebar entry)

private struct CollectionRowView: View {
    let collection: CollectionModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationLink {
            CollectionDetailView(collection: collection)
        } label: {
            Label {
                Text(collection.name)
                    .lineLimit(1)
            } icon: {
                Image(systemName: collection.sfSymbol)
                    .foregroundStyle(Color(hex: collection.colorHex))
            }
        }
        .contextMenu {
            CollectionContextMenu(collection: collection)
        }
    }
}

// MARK: - Mock Server Row View

private struct MockServerRowView: View {
    @Bindable var server: MockServerModel

    var body: some View {
        HStack {
            Label(server.name, systemImage: "server.rack")
            Spacer()
            Circle()
                .fill(server.isRunning ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Collection Context Menu

private struct CollectionContextMenu: View {
    let collection: CollectionModel
    @Environment(\.modelContext) private var context

    var body: some View {
        Button("Rename") {}
        Button("Duplicate") {}
        Button("Export") {}
        Divider()
        Button("Run Collection") {}
        Divider()
        Button("Delete", role: .destructive) {
            context.delete(collection)
        }
    }
}

// MARK: - Workspace Picker View

public struct WorkspacePickerView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \WorkspaceModel.sortOrder) private var workspaces: [WorkspaceModel]
    @Environment(\.modelContext) private var context
    @State private var showMenu = false

    public init() {}

    public var body: some View {
        Menu {
            ForEach(workspaces) { ws in
                Button {
                    appState.activeWorkspace = ws
                } label: {
                    HStack {
                        Text(ws.emoji)
                        Text(ws.name)
                        if appState.activeWorkspace?.id == ws.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Button("New Workspace") { createWorkspace() }
        } label: {
            HStack(spacing: 6) {
                Text(appState.activeWorkspace?.emoji ?? "🚀")
                    .font(.system(size: 16))
                Text(appState.activeWorkspace?.name ?? "Workspace")
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
    }

    private func createWorkspace() {
        let ws = WorkspaceModel(name: "New Workspace")
        context.insert(ws)
        appState.activeWorkspace = ws
        try? context.save()
    }
}

// MARK: - Environment Picker View

public struct EnvironmentPickerView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \EnvironmentModel.sortOrder) private var environments: [EnvironmentModel]

    public init() {}

    public var body: some View {
        Menu {
            Button {
                appState.activeEnvironment = nil
            } label: {
                HStack {
                    Text("No Environment")
                    if appState.activeEnvironment == nil {
                        Spacer(); Image(systemName: "checkmark")
                    }
                }
            }
            Divider()
            ForEach(environments.filter { $0.workspace?.id == appState.activeWorkspace?.id }) { env in
                Button {
                    appState.activeEnvironment = env
                } label: {
                    HStack {
                        Circle().fill(Color(hex: env.colorHex)).frame(width: 8, height: 8)
                        Text(env.name)
                        if appState.activeEnvironment?.id == env.id {
                            Spacer(); Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            NavigationLink("Manage Environments") { EnvironmentListView() }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(appState.activeEnvironment.map { Color(hex: $0.colorHex) } ?? Color.secondary)
                    .frame(width: 8, height: 8)
                Text(appState.activeEnvironment?.name ?? "No Environment")
                    .font(.callout)
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .keyboardShortcut("e", modifiers: .command)
        .help("Switch Environment (⌘E)")
    }
}

// MARK: - Collection Detail View

private struct CollectionDetailView: View {
    let collection: CollectionModel

    var body: some View {
        CollectionListView(filter: collection)
    }
}
