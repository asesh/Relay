import SwiftUI
import SwiftData

// MARK: - Detail View

/// Trailing pane: request editor (top) + response panel (bottom).
public struct DetailView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("responsePanelFraction") private var fraction: Double = 0.5
    @State private var showResponsePanel = true

    public init() {}

    public var body: some View {
        if let request = appState.selectedRequest {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // Request editor (top portion)
                    RequestEditorView(request: request)
                        .frame(height: showResponsePanel
                               ? geo.size.height * fraction - 4
                               : geo.size.height)

                    if showResponsePanel {
                        ResizableDivider(fraction: $fraction)
                            .frame(height: 8)

                        // Response panel (bottom portion)
                        ResponsePanelContainerView(requestID: request.id)
                            .frame(height: geo.size.height * (1 - fraction) - 4)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $showResponsePanel) {
                        Image(systemName: "square.bottomhalf.filled")
                    }
                    .toggleStyle(.button)
                    .help("Toggle Response Panel (⌘⌥R)")
                    .keyboardShortcut("r", modifiers: [.command, .option])
                }
            }
        } else {
            WelcomeView()
        }
    }
}

// MARK: - Welcome View

public struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context

    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.up.arrow.down.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("API Client")
                .font(.title)
                .fontWeight(.semibold)
            Text("Select a request from the sidebar\nor create a new one to get started.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button {
                    createNewRequest()
                } label: {
                    Label("New Request", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("n", modifiers: .command)

                Button {
                    // Open import sheet
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private func createNewRequest() {
        guard let workspace = appState.activeWorkspace else { return }
        let request = RequestModel(name: "New Request")
        context.insert(request)
        // Attach to first collection or create one
        if workspace.collections.isEmpty {
            let col = CollectionModel(name: "My Collection", workspace: workspace)
            context.insert(col)
            request.collection = col
        } else {
            request.collection = workspace.collections.first
        }
        try? context.save()
        appState.selectedRequest = request
        appState.openTab(request)
    }
}

// MARK: - Response Panel Container

struct ResponsePanelContainerView: View {
    let requestID: UUID
    @State private var response: HTTPResponse?
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if let response {
            ResponsePanelView(response: response)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Send a request to see the response.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Tab Strip View (macOS / iPadOS)

public struct TabStripView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(appState.openTabs) { tab in
                    TabItemView(tab: tab,
                                isActive: appState.activeTabID == tab.requestID)
                    .onTapGesture {
                        appState.activeTabID = tab.requestID
                    }
                    Divider().frame(height: 20)
                }
            }
        }
        .frame(height: 36)
        .background(.regularMaterial)
    }
}

// MARK: - Tab Item View

private struct TabItemView: View {
    let tab: TabItem
    let isActive: Bool
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            MethodBadgeView(method: tab.method, compact: true)
            Text(tab.name)
                .font(.callout)
                .lineLimit(1)
                .frame(maxWidth: 120)
            if tab.isDirty {
                Circle().fill(Color.accentColor).frame(width: 6, height: 6)
            }
            Button {
                appState.closeTab(id: tab.requestID)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Close") { appState.closeTab(id: tab.requestID) }
            Button("Close Others") {
                appState.openTabs.removeAll { $0.requestID != tab.requestID }
            }
            Button("Close All") { appState.closeAllTabs() }
            Divider()
            #if os(macOS)
            Button("Move to New Window") {}
            #endif
        }
    }
}
