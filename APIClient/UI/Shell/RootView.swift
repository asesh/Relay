import SwiftUI
import SwiftData

// MARK: - App State

@MainActor
public final class AppState: ObservableObject {
    @Published public var activeWorkspace: WorkspaceModel?
    @Published public var activeEnvironment: EnvironmentModel?
    @Published public var selectedRequest: RequestModel?
    @Published public var selectedCollection: CollectionModel?
    @Published public var openTabs: [TabItem] = []
    @Published public var activeTabID: UUID?
    @Published public var selectedTab: TabItem = .request
    @Published public var globalVariables: [String: String] = [:]
    @Published public var localVariables: [String: String] = [:]
    @Published public var searchQuery = ""
    @Published public var showGlobalSearch = false
    @Published public var showCommandPalette = false

    // Settings
    @AppStorage(SettingsKey.colorScheme) public var colorSchemePreference = ColorSchemePreference.system.rawValue
    @AppStorage(SettingsKey.syntaxTheme) public var syntaxThemeName = SyntaxTheme.defaultDark.rawValue
    @AppStorage(SettingsKey.editorFontSize) public var editorFontSize: Double = 13
    @AppStorage(SettingsKey.layoutDensity) public var layoutDensityName = LayoutDensity.default.rawValue
    @AppStorage(SettingsKey.globalSSLVerification) public var globalSSLVerification = true

    public var syntaxTheme: SyntaxTheme { SyntaxTheme(rawValue: syntaxThemeName) ?? .defaultDark }
    public var layoutDensity: LayoutDensity { LayoutDensity(rawValue: layoutDensityName) ?? .default }

    public var currentResolver: VariableResolver {
        VariableResolver(
            globalVars: globalVariables,
            collectionVars: [:],
            environmentVars: activeEnvironment?.toAPIEnvironment().asDict ?? [:],
            dataVars: [:],
            localVars: localVariables
        )
    }

    public func openTab(_ request: RequestModel) {
        if openTabs.count >= Constants.maxTabs { return }
        if !openTabs.contains(where: { $0.requestID == request.id }) {
            openTabs.append(TabItem(requestID: request.id, name: request.name, method: request.method))
        }
        activeTabID = request.id
        selectedRequest = request
    }

    public func closeTab(id: UUID) {
        openTabs.removeAll { $0.requestID == id }
        if activeTabID == id {
            activeTabID = openTabs.last?.requestID
        }
    }

    public func closeAllTabs() { openTabs.removeAll(); activeTabID = nil }

    public func openTab(from history: HistoryModel) {
        // Create a transient request from history; in a real app would open in editor
        // For now just switch to the request tab
        selectedTab = .request
    }

    public var preferredColorScheme: ColorScheme? {
        switch ColorSchemePreference(rawValue: colorSchemePreference) {
        case .light: return .light
        case .dark: return .dark
        default: return nil
        }
    }
}

// MARK: - Navigation Tab (iPhone TabView)

public enum NavigationTab: Hashable {
    case request, collections, environments, history, settings
}

// For iOS TabView, use NavigationTab; TabItem is the multi-tab strip item
extension AppState {
    public var selectedNavigationTab: NavigationTab {
        get { _selectedNavTab }
        set { _selectedNavTab = newValue }
    }

    private var _selectedNavTab: NavigationTab {
        get { NavigationTab.request }
        set { }
    }
}

// MARK: - Tab Item

public struct TabItem: Identifiable, Equatable {
    public var id = UUID()
    public var requestID: UUID
    public var name: String
    public var method: String
    public var isDirty = false

    public init(requestID: UUID, name: String, method: String) {
        self.requestID = requestID; self.name = name; self.method = method
    }
}

// MARK: - Root View (Platform-Adaptive)

public struct RootView: View {
    @StateObject private var appState = AppState()
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkspaceModel.sortOrder) private var workspaces: [WorkspaceModel]

    public init() {}

    public var body: some View {
        Group {
            #if os(macOS)
            macOSRootView()
            #elseif os(iOS)
            iOSRootView()
            #endif
        }
        .environmentObject(appState)
        .preferredColorScheme(appState.preferredColorScheme)
        .onAppear {
            if appState.activeWorkspace == nil {
                if let first = workspaces.first {
                    appState.activeWorkspace = first
                } else {
                    let ws = WorkspaceModel(name: "My Workspace")
                    context.insert(ws)
                    appState.activeWorkspace = ws
                    try? context.save()
                }
            }
        }
    }

    // MARK: - macOS Layout

    @ViewBuilder
    private func macOSRootView() -> some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } content: {
            CollectionListView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 400)
        } detail: {
            DetailView()
        }
        .toolbar {
            macOSToolbar()
        }
        .overlay {
            if appState.showCommandPalette { CommandPaletteView() }
        }
    }

    // MARK: - iOS Layout

    @ViewBuilder
    private func iOSRootView() -> some View {
        #if os(iOS)
        let sizeClass = horizontalSizeClass
        if sizeClass == .regular {
            // iPad: 3-column NavigationSplitView
            NavigationSplitView {
                SidebarView()
            } content: {
                CollectionListView()
            } detail: {
                DetailView()
            }
        } else {
            // iPhone: TabView
            TabView {
                RequestEditorView(request: appState.selectedRequest)
                    .tabItem { Label("Request", systemImage: "arrow.up.arrow.down") }
                CollectionListView()
                    .tabItem { Label("Collections", systemImage: "folder") }
                EnvironmentListView()
                    .tabItem { Label("Environments", systemImage: "circle.hexagongrid") }
                HistoryView()
                    .tabItem { Label("History", systemImage: "clock") }
                AppSettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
        }
        #endif
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ToolbarContentBuilder
    private func macOSToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            WorkspacePickerView()
        }
        ToolbarItem {
            EnvironmentPickerView()
        }
    }
}
