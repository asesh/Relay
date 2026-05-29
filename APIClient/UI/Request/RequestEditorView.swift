import SwiftUI
import SwiftData

// MARK: - Request Editor View

public struct RequestEditorView: View {
    @Bindable var request: RequestModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context

    @State private var selectedTab: RequestTab = .params
    @State private var isExecuting = false
    @State private var lastResponse: HTTPResponse?
    @State private var executionError: String?
    @State private var showCodeSnippet = false
    @State private var showImportCurl = false

    private let executor = RequestExecutor.shared

    public init(request: RequestModel?) {
        // Provide a default binding-friendly approach
        if let request {
            self._request = Bindable(request)
        } else {
            // This won't be reached since we guard at the parent
            self._request = Bindable(RequestModel())
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // URL Bar
            URLBarView(
                method: $request.method,
                url: $request.url,
                isExecuting: isExecuting,
                onSend: sendRequest,
                onCancel: cancelRequest
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)

            Divider()

            // Tab selector
            requestTabSelector

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .params:
                    ParamsEditorView(request: request)
                case .headers:
                    HeadersEditorView(request: request)
                case .auth:
                    AuthEditorView(authConfig: Binding(
                        get: { request.authConfig },
                        set: { request.authConfig = $0 }
                    ))
                case .body:
                    BodyEditorView(request: request)
                case .preRequest:
                    PreRequestScriptView(
                        source: $request.preRequestScript,
                        theme: appState.syntaxTheme
                    )
                case .tests:
                    TestsScriptView(
                        source: $request.testScript,
                        testResults: lastResponse?.testResults ?? [],
                        theme: appState.syntaxTheme
                    )
                case .settings:
                    RequestSettingsView(settings: Binding(
                        get: { request.settings },
                        set: { request.settings = $0 }
                    ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showCodeSnippet = true
                } label: {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                }
                .help("Generate Code Snippet (⌘⇧C)")
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
        .sheet(isPresented: $showCodeSnippet) {
            CodeSnippetSheetView(request: request.toHTTPRequest())
        }
    }

    // MARK: - Tab Selector

    private var requestTabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(RequestTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 4) {
                            Text(tab.title)
                                .font(.callout)
                            if let badge = tabBadge(tab) {
                                Text(badge)
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.accentColor, in: Capsule())
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    .background(
                        selectedTab == tab
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear,
                        in: Rectangle()
                    )
                    .overlay(alignment: .bottom) {
                        if selectedTab == tab {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(height: 2)
                        }
                    }
                }
            }
        }
        .keyboardShortcut("1", modifiers: .command) // handled individually below
    }

    private func tabBadge(_ tab: RequestTab) -> String? {
        switch tab {
        case .params:
            let count = request.queryParams.filter(\.isEnabled).count
            return count > 0 ? "\(count)" : nil
        case .headers:
            let count = request.headers.filter(\.isEnabled).count
            return count > 0 ? "\(count)" : nil
        case .auth:
            let cfg = request.authConfig
            return cfg.type != .none && cfg.type != .inherit ? "!" : nil
        case .body:
            let cfg = request.settings
            return request.bodyType != "none" ? "!" : nil
        case .preRequest:
            return !request.preRequestScript.isEmpty ? "!" : nil
        case .tests:
            let passed = lastResponse?.testResults.filter(\.passed).count ?? 0
            let failed = lastResponse?.testResults.filter { !$0.passed }.count ?? 0
            if passed + failed > 0 { return "\(passed)/\(passed + failed)" }
            return !request.testScript.isEmpty ? "!" : nil
        case .settings:
            return nil
        }
    }

    // MARK: - Send Request

    private func sendRequest() {
        guard !isExecuting else { return }
        isExecuting = true
        executionError = nil

        let req = request.toHTTPRequest()
        let resolver = appState.currentResolver

        Task {
            do {
                let response = try await executor.execute(
                    request: req,
                    resolver: resolver
                )
                await MainActor.run {
                    lastResponse = response
                    isExecuting = false
                    // Log to history
                    logHistory(request: req, response: response)
                }
            } catch {
                await MainActor.run {
                    executionError = error.localizedDescription
                    isExecuting = false
                }
            }
        }
    }

    private func cancelRequest() {
        executor.cancel(id: request.id)
        isExecuting = false
    }

    private func logHistory(request: HTTPRequest, response: HTTPResponse) {
        guard let workspace = appState.activeWorkspace else { return }
        let entry = HistoryModel(
            method: request.effectiveMethodName,
            url: request.url,
            statusCode: response.statusCode,
            durationMs: response.durationMs,
            responseSizeBytes: response.bodySize,
            requestData: try? JSONEncoder().encode(request),
            responseBodyPreview: String(response.body.prefix(200).utf8String ?? ""),
            workspace: workspace
        )
        context.insert(entry)
        try? context.save()
    }
}

// MARK: - Request Tab

public enum RequestTab: String, CaseIterable {
    case params, headers, auth, body, preRequest, tests, settings

    public var title: String {
        switch self {
        case .params: return "Params"
        case .headers: return "Headers"
        case .auth: return "Auth"
        case .body: return "Body"
        case .preRequest: return "Pre-request"
        case .tests: return "Tests"
        case .settings: return "Settings"
        }
    }
}
