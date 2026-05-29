import SwiftUI

// MARK: - Body Editor View

public struct BodyEditorView: View {
    @Bindable var request: RequestModel
    @EnvironmentObject private var appState: AppState
    @State private var showFilePicker = false
    @State private var filePickerTarget: FilePickerTarget = .binary

    enum FilePickerTarget { case binary, formDataIndex(Int) }

    var bodyType: Binding<BodyType> {
        Binding(
            get: { BodyType(rawValue: request.bodyType) ?? .none },
            set: { request.bodyType = $0.rawValue }
        )
    }
    var rawBodyType: Binding<RawBodyType> {
        Binding(
            get: { RawBodyType(rawValue: request.rawBodyType) ?? .json },
            set: { request.rawBodyType = $0.rawValue }
        )
    }

    public init(request: RequestModel) {
        self._request = Bindable(request)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Body type selector
            bodyTypeSelector

            Divider()

            // Body content
            Group {
                switch bodyType.wrappedValue {
                case .none:
                    emptyBodyView
                case .raw:
                    rawBodyView
                case .formData:
                    formDataBodyView
                case .urlEncoded:
                    urlEncodedBodyView
                case .binary:
                    binaryBodyView
                case .graphQL:
                    graphQLBodyView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Type Selector

    private var bodyTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(BodyType.allCases, id: \.self) { type in
                    Button {
                        bodyType.wrappedValue = type
                    } label: {
                        Text(bodyTypeLabel(type))
                            .font(.callout)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(bodyType.wrappedValue == type ? .primary : .secondary)
                    .background(
                        bodyType.wrappedValue == type
                            ? Color.accentColor.opacity(0.1) : Color.clear
                    )
                    .overlay(alignment: .bottom) {
                        if bodyType.wrappedValue == type {
                            Rectangle().fill(Color.accentColor).frame(height: 2)
                        }
                    }

                    // Raw sub-type picker
                    if type == .raw && bodyType.wrappedValue == .raw {
                        Picker("", selection: rawBodyType) {
                            ForEach(RawBodyType.allCases, id: \.self) { rt in
                                Text(rt.rawValue).tag(rt)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .font(.callout)
                    }
                }
            }
        }
    }

    private func bodyTypeLabel(_ type: BodyType) -> String {
        switch type {
        case .none: return "None"
        case .raw: return "Raw"
        case .formData: return "form-data"
        case .urlEncoded: return "x-www-form-urlencoded"
        case .binary: return "Binary"
        case .graphQL: return "GraphQL"
        }
    }

    // MARK: - Body Views

    private var emptyBodyView: some View {
        VStack {
            Text("This request has no body.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rawBodyView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Format") {
                    formatBody()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.accentColor)
                .padding(8)
            }
            CodeEditorView(
                text: $request.rawBodyContent,
                language: rawBodyType.wrappedValue.language,
                fontSize: CGFloat(appState.editorFontSize),
                theme: appState.syntaxTheme
            )
        }
    }

    private var formDataBodyView: some View {
        let items = Binding<[KeyValuePair]>(
            get: {
                request.formDataItems.map { item in
                    KeyValuePair(id: item.id, key: item.key, value: item.textValue,
                                 isEnabled: item.isEnabled)
                }
            },
            set: { pairs in
                let existing = Dictionary(uniqueKeysWithValues: request.formDataItems.map { ($0.id, $0) })
                request.formDataItems = pairs.map { pair in
                    if let ex = existing[pair.id] {
                        ex.key = pair.key; ex.textValue = pair.value
                        ex.isEnabled = pair.isEnabled
                        return ex
                    }
                    return FormDataItem(id: pair.id, key: pair.key, textValue: pair.value,
                                        isEnabled: pair.isEnabled)
                }
            }
        )
        return KeyValueTableView(
            items: items,
            keyPlaceholder: "Key",
            valuePlaceholder: "Value",
            allowFiles: true
        )
    }

    private var urlEncodedBodyView: some View {
        let items = Binding<[KeyValuePair]>(
            get: { request.urlEncodedItems },
            set: { request.urlEncodedItems = $0 }
        )
        return KeyValueTableView(items: items, keyPlaceholder: "Key", valuePlaceholder: "Value")
    }

    private var binaryBodyView: some View {
        VStack(spacing: 16) {
            if let file = request.settings.clientCertificateID.map({ _ in "file" }) {
                // Show file info
                VStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.accentColor)
                    Text("File selected")
                        .font(.callout.weight(.medium))
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Select a file to send as binary body")
                        .foregroundStyle(.secondary)
                    Button("Choose File") {
                        showFilePicker = true
                        filePickerTarget = .binary
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(isPresented: $showFilePicker,
                      allowedContentTypes: [.data]) { result in
            if case .success(let url) = result {
                // Store bookmark
                if let bookmark = try? url.bookmarkData(options: .minimalBookmark) {
                    request.binaryFileData = try? JSONEncoder().encode(
                        FileAttachment(
                            fileName: url.lastPathComponent,
                            mimeType: url.mimeType,
                            fileSize: (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0,
                            bookmarkData: bookmark
                        )
                    )
                }
            }
        }
    }

    private var graphQLBodyView: some View {
        let payload = Binding<GraphQLPayload>(
            get: { request.graphQLPayload },
            set: { request.graphQLPayload = $0 }
        )
        return GraphQLBodyView(payload: payload, theme: appState.syntaxTheme)
    }

    // MARK: - Format

    private func formatBody() {
        if rawBodyType.wrappedValue == .json,
           let data = request.rawBodyContent.data(using: .utf8),
           let pretty = data.prettyPrintedJSON {
            request.rawBodyContent = pretty
        }
    }
}

// MARK: - GraphQL Body View

struct GraphQLBodyView: View {
    @Binding var payload: GraphQLPayload
    let theme: SyntaxTheme
    @State private var selectedTab = 0
    @State private var isIntrospecting = false

    var body: some View {
        VStack(spacing: 0) {
            // Operation name + tabs
            HStack {
                TextField("Operation Name (optional)", text: $payload.operationName)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .frame(maxWidth: 200)
                Spacer()
                Button {
                    runIntrospection()
                } label: {
                    HStack(spacing: 4) {
                        if isIntrospecting { ProgressView().controlSize(.mini) }
                        Text(payload.cachedSchema == nil ? "Fetch Schema" : "Re-fetch Schema")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Picker("", selection: $selectedTab) {
                Text("Query").tag(0)
                Text("Variables").tag(1)
                if payload.cachedSchema != nil { Text("Schema Explorer").tag(2) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            switch selectedTab {
            case 0:
                CodeEditorView(text: $payload.query, language: .graphql, theme: theme)
            case 1:
                CodeEditorView(text: $payload.variables, language: .json, theme: theme)
            case 2:
                if let schema = payload.cachedSchema {
                    GraphQLSchemaExplorer(schema: schema)
                }
            default: EmptyView()
            }
        }
    }

    private func runIntrospection() {
        isIntrospecting = true
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run { isIntrospecting = false }
        }
    }
}

// MARK: - GraphQL Schema Explorer

private struct GraphQLSchemaExplorer: View {
    let schema: GraphQLSchema
    @State private var searchText = ""
    @State private var selectedType: GraphQLType?

    var filteredTypes: [GraphQLType] {
        if searchText.isEmpty { return schema.types }
        return schema.types.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Type list
            VStack(spacing: 0) {
                SearchBarView(text: $searchText, placeholder: "Search types")
                    .padding(8)
                List(filteredTypes) { type in
                    Button {
                        selectedType = type
                    } label: {
                        HStack {
                            Text(type.name)
                                .font(.system(.callout, design: .monospaced))
                            Spacer()
                            Text(type.kind)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
            .frame(width: 200)

            Divider()

            // Field list
            if let type = selectedType {
                List(type.fields) { field in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(field.name)
                                .font(.system(.body, design: .monospaced).weight(.medium))
                            Spacer()
                            Text(field.typeName)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.accentColor)
                        }
                        if let desc = field.description, !desc.isEmpty {
                            Text(desc).font(.caption).foregroundStyle(.secondary)
                        }
                        if !field.args.isEmpty {
                            Text("Args: " + field.args.map { "\($0.name): \($0.typeName)" }.joined(separator: ", "))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            } else {
                Text("Select a type to explore its fields")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - URL MimeType Helper

private extension URL {
    var mimeType: String {
        let ext = pathExtension.lowercased()
        let types: [String: String] = [
            "json": "application/json", "xml": "application/xml",
            "html": "text/html", "txt": "text/plain",
            "pdf": "application/pdf", "png": "image/png",
            "jpg": "image/jpeg", "jpeg": "image/jpeg",
            "gif": "image/gif", "zip": "application/zip",
            "csv": "text/csv"
        ]
        return types[ext] ?? "application/octet-stream"
    }
}
