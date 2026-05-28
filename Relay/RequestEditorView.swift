import SwiftUI
import SwiftData

enum RequestTab: String, CaseIterable {
    case headers = "Headers"
    case body = "Body"
}

enum ResponseTab: String, CaseIterable {
    case pretty = "Pretty"
    case raw = "Raw"
    case headers = "Headers"
}

struct RequestEditorView: View {
    @Bindable var request: RequestItem
    @Environment(\.modelContext) private var modelContext
    @State private var requestTab: RequestTab = .headers
    @State private var responseTab: ResponseTab = .pretty
    @State private var response: HTTPResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var responseHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            urlBar
            Divider().background(Color.relayBorder)
            requestTabs
            Divider().background(Color.relayBorder)
            requestTabContent
                .frame(minHeight: 160)
            Divider().background(Color.relayBorder)
            responsePanel
        }
        .background(Color.relayBg)
    }

    // MARK: - URL Bar

    private var urlBar: some View {
        HStack(spacing: 8) {
            methodPicker
            TextField("Enter request URL", text: $request.url)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.relayInputBg)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            sendButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.relayPanel)
    }

    private var methodPicker: some View {
        Menu {
            ForEach(HTTPMethod.allCases, id: \.rawValue) { method in
                Button(method.rawValue) {
                    request.method = method.rawValue
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(request.method)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.methodColor(request.method))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.relaySecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.relayInputBg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var sendButton: some View {
        Button {
            Task { await sendRequest() }
        } label: {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Text("Send")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(isLoading ? Color.relayAccent.opacity(0.6) : Color.relayAccent)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(isLoading || request.url.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: - Request Tabs

    private var requestTabs: some View {
        HStack(spacing: 0) {
            ForEach(RequestTab.allCases, id: \.rawValue) { tab in
                tabButton(tab.rawValue, isSelected: requestTab == tab) {
                    requestTab = tab
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .background(Color.relayPanel)
    }

    private func tabButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.relayAccent : Color.relaySecondary)
                .padding(.vertical, 9)
                .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .overlay(alignment: .bottom) {
            if isSelected {
                Rectangle()
                    .fill(Color.relayAccent)
                    .frame(height: 2)
            }
        }
    }

    // MARK: - Request Tab Content

    @ViewBuilder
    private var requestTabContent: some View {
        switch requestTab {
        case .headers:
            HeadersEditorView(request: request)
        case .body:
            BodyEditorView(request: request)
        }
    }

    // MARK: - Response Panel

    private var responsePanel: some View {
        VStack(spacing: 0) {
            responseHeader
            Divider().background(Color.relayBorder)
            if let error = errorMessage {
                errorView(error)
            } else if let response {
                VStack(spacing: 0) {
                    responseTabs(response)
                    Divider().background(Color.relayBorder)
                    responseBody(response)
                }
            } else {
                emptyResponseView
            }
        }
        .frame(minHeight: 200)
    }

    private var responseHeader: some View {
        HStack {
            Text("Response")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.relaySecondary)
                .textCase(.uppercase)
            Spacer()
            if let response {
                HStack(spacing: 12) {
                    statusBadge(response)
                    Text(response.durationString)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.relaySecondary)
                    Text(response.sizeString)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.relaySecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.relayPanel)
    }

    private func statusBadge(_ response: HTTPResponse) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.statusColor(response.statusColor))
                .frame(width: 6, height: 6)
            Text("\(response.statusCode)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.statusColor(response.statusColor))
        }
    }

    private func responseTabs(_ response: HTTPResponse) -> some View {
        HStack(spacing: 0) {
            ForEach(ResponseTab.allCases, id: \.rawValue) { tab in
                tabButton(tab.rawValue, isSelected: responseTab == tab) {
                    responseTab = tab
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .background(Color.relayPanel)
    }

    @ViewBuilder
    private func responseBody(_ response: HTTPResponse) -> some View {
        switch responseTab {
        case .pretty:
            ScrollView {
                Text(response.prettyBody)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(red: 0.85, green: 0.85, blue: 0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .textSelection(.enabled)
            }
            .background(Color.relayBg)
        case .raw:
            ScrollView {
                Text(response.bodyString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(red: 0.85, green: 0.85, blue: 0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .textSelection(.enabled)
            }
            .background(Color.relayBg)
        case .headers:
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(response.responseHeaders.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top, spacing: 0) {
                            Text(key)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color(red: 0.38, green: 0.75, blue: 1.0))
                                .frame(maxWidth: 220, alignment: .leading)
                                .padding(.trailing, 8)
                            Text(value)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Color(red: 0.85, green: 0.85, blue: 0.85))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 14)
                        Divider().background(Color.relayBorder.opacity(0.5))
                    }
                }
                .textSelection(.enabled)
            }
            .background(Color.relayBg)
        }
    }

    private func errorView(_ message: String) -> some View {
        ScrollView {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(red: 0.976, green: 0.243, blue: 0.243))
                Text(message)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color(red: 0.976, green: 0.243, blue: 0.243))
                Spacer()
            }
            .padding(14)
        }
        .background(Color.relayBg)
    }

    private var emptyResponseView: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.up.circle")
                .font(.system(size: 32))
                .foregroundStyle(Color.relaySecondary)
            Text("Enter a URL and press Send to get a response")
                .font(.system(size: 13))
                .foregroundStyle(Color.relaySecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.relayBg)
    }

    // MARK: - Networking

    private func sendRequest() async {
        isLoading = true
        errorMessage = nil
        response = nil
        do {
            response = try await NetworkService.shared.send(request)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Headers Editor

struct HeadersEditorView: View {
    @Bindable var request: RequestItem
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Divider().background(Color.relayBorder)
            ScrollView {
                VStack(spacing: 0) {
                    let sorted = request.headers.sorted { ($0.key + $0.value) < ($1.key + $1.value) }
                    ForEach(sorted) { header in
                        HeaderRowView(header: header, onDelete: { deleteHeader(header) })
                        Divider().background(Color.relayBorder.opacity(0.5))
                    }
                }
            }
            .background(Color.relayBg)
            addButton
        }
        .background(Color.relayBg)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Enabled")
                .frame(width: 60)
            Text("Key")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
            Text("Value")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
            Spacer().frame(width: 36)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.relaySecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.relayPanel)
    }

    private var addButton: some View {
        Button {
            addHeader()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                Text("Add Header")
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.relayAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.relayPanel)
    }

    private func addHeader() {
        let header = HeaderItem()
        header.request = request
        modelContext.insert(header)
        request.headers.append(header)
    }

    private func deleteHeader(_ header: HeaderItem) {
        request.headers.removeAll { $0.id == header.id }
        modelContext.delete(header)
    }
}

struct HeaderRowView: View {
    @Bindable var header: HeaderItem
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Toggle("", isOn: $header.isEnabled)
                .toggleStyle(.checkbox)
                .frame(width: 60)
                .tint(Color.relayAccent)
            TextField("Key", text: $header.key)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .opacity(header.isEnabled ? 1 : 0.4)
            Divider().frame(height: 20).background(Color.relayBorder)
            TextField("Value", text: $header.value)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(red: 0.85, green: 0.85, blue: 0.85))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .opacity(header.isEnabled ? 1 : 0.4)
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.relaySecondary)
                    .frame(width: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 14)
        .background(Color.relayBg)
    }
}

// MARK: - Body Editor

struct BodyEditorView: View {
    @Bindable var request: RequestItem

    var bodyType: BodyType {
        BodyType(rawValue: request.bodyType) ?? .none
    }

    var body: some View {
        VStack(spacing: 0) {
            bodyTypePicker
            Divider().background(Color.relayBorder)
            if bodyType == .none {
                Text("This request does not have a body")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.relaySecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.relayBg)
            } else {
                TextEditor(text: $request.bodyContent)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.relayBg)
                    .padding(8)
            }
        }
        .background(Color.relayBg)
    }

    private var bodyTypePicker: some View {
        HStack(spacing: 16) {
            ForEach(BodyType.allCases, id: \.rawValue) { type in
                Button {
                    request.bodyType = type.rawValue
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(bodyType == type ? Color.relayAccent : Color.relayBorder)
                            .frame(width: 8, height: 8)
                        Text(type.rawValue)
                            .font(.system(size: 12))
                            .foregroundStyle(bodyType == type ? .white : Color.relaySecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.relayPanel)
    }
}
