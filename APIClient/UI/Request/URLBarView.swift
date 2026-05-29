import SwiftUI

// MARK: - URL Bar View

public struct URLBarView: View {
    @Binding var method: String
    @Binding var url: String
    var isExecuting: Bool
    var onSend: () -> Void
    var onCancel: () -> Void

    @State private var showMethodPicker = false
    @FocusState private var urlFocused: Bool

    private let commonMethods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS", "TRACE", "CONNECT"]

    public init(
        method: Binding<String>,
        url: Binding<String>,
        isExecuting: Bool,
        onSend: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._method = method
        self._url = url
        self.isExecuting = isExecuting
        self.onSend = onSend
        self.onCancel = onCancel
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Method picker
            #if os(macOS)
            Picker("Method", selection: $method) {
                ForEach(commonMethods, id: \.self) { m in
                    Text(m).tag(m)
                }
                Divider()
                Text("Custom").tag("CUSTOM")
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 90)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.methodColor(method).opacity(0.3), lineWidth: 1)
            }
            #else
            Button {
                showMethodPicker = true
            } label: {
                Text(method)
                    .font(.system(.callout, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.methodColor(method))
                    .frame(minWidth: 52)
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $showMethodPicker) {
                methodPickerPopover
            }
            #endif

            // URL field
            HStack(spacing: 4) {
                VariableHighlightField(
                    text: $url,
                    placeholder: "Enter URL or paste a cURL command",
                    font: .system(.body, design: .monospaced)
                )
                .focused($urlFocused)
                .onSubmit {
                    if !isExecuting { onSend() }
                }

                if !url.isEmpty && !isExecuting {
                    Button { url = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.callout)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(urlFocused ? Color.accentColor.opacity(0.5) : Color.appSeparator, lineWidth: 1)
            }

            // Send / Cancel button
            sendButton
        }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            if isExecuting { onCancel() } else { onSend() }
        } label: {
            HStack(spacing: 4) {
                if isExecuting {
                    ProgressView()
                        .controlSize(.small)
                    Text("Cancel")
                        .font(.callout.weight(.medium))
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Send")
                        .font(.callout.weight(.semibold))
                }
            }
            .frame(minWidth: 72)
        }
        .buttonStyle(.borderedProminent)
        .tint(isExecuting ? .red : .accentColor)
        .keyboardShortcut(.return, modifiers: .command)
        .accessibilityLabel(isExecuting ? "Cancel request" : "Send request")
        .accessibilityHint(isExecuting ? "Cancels the in-flight HTTP request" : "Sends the HTTP request")
    }

    // MARK: - Method Picker Popover (iOS)

    private var methodPickerPopover: some View {
        VStack(spacing: 0) {
            ForEach(commonMethods, id: \.self) { m in
                Button {
                    method = m
                    showMethodPicker = false
                } label: {
                    HStack {
                        MethodBadgeView(method: m)
                        Spacer()
                        if method == m { Image(systemName: "checkmark") }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if m != commonMethods.last { Divider() }
            }
        }
        .frame(width: 200)
    }
}

// MARK: - Params Editor View

public struct ParamsEditorView: View {
    @Bindable var request: RequestModel
    @State private var showBulkEdit = false
    @State private var bulkText = ""

    var queryItems: Binding<[KeyValuePair]> {
        Binding(
            get: {
                request.queryParams.map { p in
                    KeyValuePair(id: p.id, key: p.key, value: p.value,
                                 description: p.paramDescription, isEnabled: p.isEnabled)
                }
            },
            set: { pairs in
                // Sync back to persistent QueryParamModel
                let existing = Dictionary(uniqueKeysWithValues: request.queryParams.map { ($0.id, $0) })
                request.queryParams = pairs.map { pair in
                    if let existing = existing[pair.id] {
                        existing.key = pair.key; existing.value = pair.value
                        existing.paramDescription = pair.description
                        existing.isEnabled = pair.isEnabled
                        return existing
                    }
                    let model = QueryParamModel(
                        id: pair.id, key: pair.key, value: pair.value,
                        paramDescription: pair.description, isEnabled: pair.isEnabled,
                        request: request
                    )
                    return model
                }
                syncURLFromParams()
            }
        )
    }

    public init(request: RequestModel) {
        self._request = Bindable(request)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // URL preview with params highlighted
            urlPreviewBar

            Divider()

            KeyValueTableView(
                items: queryItems,
                keyPlaceholder: "Parameter",
                valuePlaceholder: "Value",
                showDescription: true
            )
        }
    }

    private var urlPreviewBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                Text(request.url.components(separatedBy: "?").first ?? request.url)
                    .foregroundStyle(.primary)
                let params = request.queryParams.filter(\.isEnabled)
                if !params.isEmpty {
                    Text("?")
                        .foregroundStyle(.secondary)
                    ForEach(params.indices, id: \.self) { i in
                        if i > 0 { Text("&").foregroundStyle(.secondary) }
                        Text(params[i].key).foregroundStyle(Color.accentColor)
                        Text("=").foregroundStyle(.secondary)
                        Text(params[i].value).foregroundStyle(.orange)
                    }
                }
            }
            .font(.system(.callout, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func syncURLFromParams() {
        guard var components = URLComponents(string: request.url) else { return }
        let enabled = request.queryParams.filter(\.isEnabled)
        components.queryItems = enabled.isEmpty ? nil
            : enabled.map { URLQueryItem(name: $0.key, value: $0.value) }
        if let newURL = components.url { request.url = newURL.absoluteString }
    }
}

// MARK: - Headers Editor View

public struct HeadersEditorView: View {
    @Bindable var request: RequestModel

    var headers: Binding<[KeyValuePair]> {
        Binding(
            get: {
                request.headers.map { h in
                    KeyValuePair(id: h.id, key: h.key, value: h.value,
                                 description: h.headerDescription, isEnabled: h.isEnabled)
                }
            },
            set: { pairs in
                let existing = Dictionary(uniqueKeysWithValues: request.headers.map { ($0.id, $0) })
                request.headers = pairs.map { pair in
                    if let ex = existing[pair.id] {
                        ex.key = pair.key; ex.value = pair.value
                        ex.headerDescription = pair.description; ex.isEnabled = pair.isEnabled
                        return ex
                    }
                    return HeaderModel(id: pair.id, key: pair.key, value: pair.value,
                                       headerDescription: pair.description,
                                       isEnabled: pair.isEnabled, request: request)
                }
            }
        )
    }

    public init(request: RequestModel) {
        self._request = Bindable(request)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Preset templates picker
            HStack {
                Menu("Add Header Template") {
                    Button("Content-Type: application/json") {
                        appendHeader(key: "Content-Type", value: "application/json")
                    }
                    Button("Accept: application/json") {
                        appendHeader(key: "Accept", value: "application/json")
                    }
                    Button("Authorization: Bearer") {
                        appendHeader(key: "Authorization", value: "Bearer <token>")
                    }
                    Button("Cache-Control: no-cache") {
                        appendHeader(key: "Cache-Control", value: "no-cache")
                    }
                    Button("X-Requested-With: XMLHttpRequest") {
                        appendHeader(key: "X-Requested-With", value: "XMLHttpRequest")
                    }
                }
                .menuStyle(.borderlessButton)
                .foregroundStyle(.accentColor)
                .font(.callout)
                .padding(.leading, 8)
                Spacer()
            }
            .padding(.vertical, 6)
            .background(.regularMaterial)

            Divider()

            KeyValueTableView(
                items: headers,
                keyPlaceholder: "Header",
                valuePlaceholder: "Value",
                showDescription: true
            )
        }
    }

    private func appendHeader(key: String, value: String) {
        let model = HeaderModel(key: key, value: value, request: request)
        request.headers.append(model)
    }
}
