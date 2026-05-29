import SwiftUI
import SwiftData

// MARK: - Collection List View

public struct CollectionListView: View {
    var filter: CollectionModel? = nil
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \CollectionModel.sortOrder) private var allCollections: [CollectionModel]
    @State private var showNewRequest = false
    @State private var showNewFolder = false
    @State private var showRunnerFor: CollectionModel?

    private var collections: [CollectionModel] {
        if let filter { return [filter] }
        return allCollections.filter { $0.workspace?.id == appState.activeWorkspace?.id }
    }

    public init(filter: CollectionModel? = nil) {
        self.filter = filter
    }

    public var body: some View {
        List {
            ForEach(collections) { collection in
                Section {
                    // Collection-level requests
                    ForEach(collection.requests.filter { $0.folder == nil }
                                .sorted { $0.sortOrder < $1.sortOrder }) { request in
                        RequestRowView(request: request)
                    }
                    .onMove { source, dest in
                        // Reorder requests
                    }

                    // Folders
                    ForEach(collection.folders.sorted { $0.sortOrder < $1.sortOrder }) { folder in
                        FolderRowView(folder: folder)
                    }
                } header: {
                    CollectionHeaderView(collection: collection,
                                         onRun: { showRunnerFor = collection })
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Collections")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createNewRequest()
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Request (⌘N)")
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(item: $showRunnerFor) { col in
            CollectionRunnerView(collection: col)
        }
    }

    private func createNewRequest() {
        guard let workspace = appState.activeWorkspace else { return }
        let collection = collections.first ?? {
            let col = CollectionModel(name: "My Collection", workspace: workspace)
            context.insert(col)
            return col
        }()
        let request = RequestModel(name: "New Request", collection: collection)
        context.insert(request)
        try? context.save()
        appState.openTab(request)
    }
}

// MARK: - Collection Header View

private struct CollectionHeaderView: View {
    @Bindable var collection: CollectionModel
    var onRun: () -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: collection.sfSymbol)
                .foregroundStyle(Color(hex: collection.colorHex))
            Text(collection.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            Button(action: onRun) {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button("Run Collection") { onRun() }
            Button("Add Request") { addRequest() }
            Button("Add Folder") { addFolder() }
            Divider()
            Button("Rename") {}
            Button("Export") {}
            Divider()
            Button("Delete", role: .destructive) {
                context.delete(collection)
            }
        }
    }

    private func addRequest() {
        let req = RequestModel(name: "New Request", collection: collection)
        context.insert(req)
        try? context.save()
    }

    private func addFolder() {
        let folder = FolderModel(name: "New Folder", collection: collection)
        context.insert(folder)
        try? context.save()
    }
}

// MARK: - Request Row View

private struct RequestRowView: View {
    @Bindable var request: RequestModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context

    var body: some View {
        Button {
            appState.openTab(request)
        } label: {
            HStack(spacing: 6) {
                MethodBadgeView(method: request.method, compact: true)
                    .frame(width: 44)
                Text(request.name)
                    .font(.callout)
                    .lineLimit(1)
                Spacer()
                if request.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .background(
            appState.selectedRequest?.id == request.id
                ? Color.accentColor.opacity(0.1) : Color.clear
        )
        .contextMenu {
            Button("Open") { appState.openTab(request) }
            Button("Open in New Tab") { appState.openTab(request) }
            Divider()
            Button(request.isFavorite ? "Unfavorite" : "Favorite") {
                request.isFavorite.toggle()
            }
            Button("Duplicate") { duplicateRequest() }
            Button("Rename") {}
            Divider()
            Button("Copy as cURL") { copyAsCurl() }
            Button("Generate Code Snippet") {}
            Divider()
            Button("Delete", role: .destructive) {
                context.delete(request)
            }
        }
    }

    private func duplicateRequest() {
        let dup = RequestModel(
            name: request.name + " Copy",
            url: request.url, method: request.method,
            collection: request.collection, folder: request.folder
        )
        dup.authConfig = request.authConfig
        dup.bodyType = request.bodyType
        dup.rawBodyContent = request.rawBodyContent
        context.insert(dup)
        try? context.save()
    }

    private func copyAsCurl() {
        let req = request.toHTTPRequest()
        var urlRequest = (try? RequestExecutor.shared.description) != nil ? URLRequest(url: URL(string: req.url)!) : URLRequest(url: URL(string: "https://localhost")!)
        urlRequest.httpMethod = req.effectiveMethodName
        for h in req.headers where h.isEnabled { urlRequest.setValue(h.value, forHTTPHeaderField: h.key) }
        let curl = urlRequest.asCurlCommand()
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(curl, forType: .string)
        #else
        UIPasteboard.general.string = curl
        #endif
    }
}

// MARK: - Folder Row View

private struct FolderRowView: View {
    @Bindable var folder: FolderModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(folder.requests.sorted { $0.sortOrder < $1.sortOrder }) { request in
                RequestRowView(request: request)
                    .padding(.leading, 12)
            }
            ForEach(folder.subFolders.sorted { $0.sortOrder < $1.sortOrder }) { sub in
                FolderRowView(folder: sub).padding(.leading, 12)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "folder.fill" : "folder")
                    .foregroundStyle(.secondary)
                Text(folder.name)
                    .font(.callout)
                Spacer()
            }
        }
        .contextMenu {
            Button("Add Request") { addRequest() }
            Button("Add Subfolder") { addSubfolder() }
            Divider()
            Button("Rename") {}
            Button("Delete", role: .destructive) { context.delete(folder) }
        }
    }

    private func addRequest() {
        let req = RequestModel(name: "New Request", collection: folder.collection, folder: folder)
        context.insert(req)
        try? context.save()
    }

    private func addSubfolder() {
        let sub = FolderModel(name: "New Folder", collection: folder.collection, parentFolder: folder)
        context.insert(sub)
        try? context.save()
    }
}

// MARK: - Collection Editor View

public struct CollectionEditorView: View {
    @Bindable var collection: CollectionModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState

    let isNew: Bool

    public init(collection: CollectionModel?) {
        if let col = collection {
            self._collection = Bindable(col)
            self.isNew = false
        } else {
            self._collection = Bindable(CollectionModel(name: "New Collection"))
            self.isNew = true
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Collection") {
                    HStack {
                        TextField("Name", text: $collection.name)
                        Image(systemName: collection.sfSymbol)
                            .foregroundStyle(Color(hex: collection.colorHex))
                    }
                    TextField("Description", text: $collection.collectionDescription, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Appearance") {
                    HStack {
                        Text("Color")
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: collection.colorHex) },
                            set: { collection.colorHex = $0.hexString }
                        ))
                    }
                }

                Section("Authorization") {
                    AuthEditorView(authConfig: Binding(
                        get: { collection.authConfig ?? AuthConfig() },
                        set: { collection.authConfig = $0 }
                    ))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isNew ? "New Collection" : "Edit Collection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isNew {
                            context.insert(collection)
                        }
                        collection.updatedAt = Date()
                        try? context.save()
                        dismiss()
                    }
                    .disabled(collection.name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Collection Runner View

public struct CollectionRunnerView: View {
    let collection: CollectionModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var runner = CollectionRunner()

    @State private var iterations = 1
    @State private var delayMs = 0
    @State private var dataFileURL: URL?
    @State private var dataRows: [[String: String]] = []

    public init(collection: CollectionModel) {
        self.collection = collection
    }

    private var allRequests: [HTTPRequest] {
        collection.requests.sorted { $0.sortOrder < $1.sortOrder }.map { $0.toHTTPRequest() }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Config panel
                if !runner.isRunning {
                    Form {
                        Section("Run Settings") {
                            Stepper("Iterations: \(iterations)", value: $iterations, in: 1...1000)
                            HStack {
                                Text("Delay (ms)")
                                Spacer()
                                TextField("0", value: $delayMs, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        }
                        Section("Data File") {
                            Button("Select CSV or JSON") {}
                            if let url = dataFileURL {
                                Text(url.lastPathComponent).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .formStyle(.grouped)
                }

                // Progress / Results
                if runner.isRunning || !runner.results.isEmpty {
                    VStack(spacing: 0) {
                        if runner.isRunning {
                            VStack(spacing: 8) {
                                ProgressView(value: runner.progress)
                                Text(runner.currentRequestName)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }

                        // Results list
                        List(runner.results) { result in
                            RunResultRowView(result: result)
                        }
                        .listStyle(.plain)

                        if !runner.isRunning && !runner.results.isEmpty {
                            Divider()
                            runSummary
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Run: \(collection.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if runner.isRunning {
                        Button("Stop", role: .destructive) { runner.cancel() }
                    } else {
                        Button("Run") { startRun() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private var runSummary: some View {
        let passed = runner.results.filter(\.passed).count
        let failed = runner.results.count - passed
        return HStack(spacing: 16) {
            SummaryChip("Total", "\(runner.results.count)")
            SummaryChip("Passed", "\(passed)", color: .green)
            SummaryChip("Failed", "\(failed)", color: failed > 0 ? .red : .secondary)
            Spacer()
            Button("Export") {}
                .buttonStyle(.bordered).controlSize(.small)
        }
        .padding()
        .background(.regularMaterial)
    }

    private func startRun() {
        let options = RunnerOptions(iterations: iterations, delayMs: delayMs, dataRows: dataRows)
        Task {
            await runner.run(requests: allRequests, resolver: appState.currentResolver, options: options)
        }
    }
}

private struct RunResultRowView: View {
    let result: RunResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.passed ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.requestName).font(.callout)
                Text("Iteration \(result.iteration)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if result.statusCode > 0 {
                StatusCodeBadgeView(statusCode: result.statusCode, showText: false)
            }
            Text("\(result.durationMs) ms")
                .font(.caption.monospaced()).foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

private struct SummaryChip: View {
    let label: String
    let value: String
    var color: Color = .primary

    init(_ label: String, _ value: String, color: Color = .primary) {
        self.label = label; self.value = value; self.color = color
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
