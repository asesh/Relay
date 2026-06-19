import SwiftUI
import SwiftData

enum RequestTab: String, CaseIterable {
  case params = "Params"
  case auth = "Auth"
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
  var activeEnvironment: RelayEnvironment?
  @Environment(\.modelContext) private var modelContext
  @State private var requestTab: RequestTab = .params
  @State private var responseTab: ResponseTab = .pretty
  @State private var response: HTTPResponse?
  @State private var isLoading = false
  @State private var errorMessage: String?

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

  private func tabLabel(_ tab: RequestTab) -> String {
    switch tab {
    case .params:
      let count = request.queryParams.filter { $0.isEnabled && !$0.key.isEmpty }.count
      return count > 0 ? "Params (\(count))" : "Params"
    case .auth:
      let isConfigured = (AuthType(rawValue: request.authType) ?? .none) != .none
      return isConfigured ? "Auth ●" : "Auth"
    case .headers:
      let count = request.headers.filter { $0.isEnabled && !$0.key.isEmpty }.count
      return count > 0 ? "Headers (\(count))" : "Headers"
    case .body:
      let hasBody = (BodyType(rawValue: request.bodyType) ?? .none) != .none
      return hasBody ? "Body ●" : "Body"
    }
  }

  private var requestTabs: some View {
    HStack(spacing: 0) {
      ForEach(RequestTab.allCases, id: \.rawValue) { tab in
        tabButton(tabLabel(tab), isSelected: requestTab == tab) {
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
    case .params:
      ParamsEditorView(request: request)
    case .auth:
      AuthEditorView(request: request)
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
      response = try await NetworkService.shared.send(request, environment: activeEnvironment)
    } catch {
      errorMessage = error.localizedDescription
    }
    isLoading = false
  }
}

// MARK: - Params Editor

struct ParamsEditorView: View {
  @Bindable var request: RequestItem
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    VStack(spacing: 0) {
      columnHeader
      Divider().background(Color.relayBorder)
      ScrollView {
        VStack(spacing: 0) {
          let sorted = request.queryParams.sorted { $0.key < $1.key }
          ForEach(sorted) { param in
            KeyValueRowView(
              key: Binding(get: { param.key }, set: { param.key = $0 }),
              value: Binding(get: { param.value }, set: { param.value = $0 }),
              isEnabled: Binding(get: { param.isEnabled }, set: { param.isEnabled = $0 }),
              onDelete: { deleteParam(param) }
            )
            Divider().background(Color.relayBorder.opacity(0.5))
          }
        }
      }
      .background(Color.relayBg)
      addButton("Add Param") { addParam() }
    }
    .background(Color.relayBg)
  }

  private var columnHeader: some View {
    HStack(spacing: 0) {
      Text("Enabled").frame(width: 60)
      Text("Key").frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
      Text("Value").frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
      Spacer().frame(width: 36)
    }
    .font(.system(size: 11, weight: .semibold))
    .foregroundStyle(Color.relaySecondary)
    .padding(.horizontal, 14)
    .padding(.vertical, 7)
    .background(Color.relayPanel)
  }

  private func addParam() {
    let param = QueryParamItem()
    param.request = request
    modelContext.insert(param)
    request.queryParams.append(param)
  }

  private func deleteParam(_ param: QueryParamItem) {
    request.queryParams.removeAll { $0.id == param.id }
    modelContext.delete(param)
  }
}

// MARK: - Headers Editor

struct HeadersEditorView: View {
  @Bindable var request: RequestItem
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    VStack(spacing: 0) {
      columnHeader
      Divider().background(Color.relayBorder)
      ScrollView {
        VStack(spacing: 0) {
          let sorted = request.headers.sorted { ($0.key + $0.value) < ($1.key + $1.value) }
          ForEach(sorted) { header in
            KeyValueRowView(
              key: Binding(get: { header.key }, set: { header.key = $0 }),
              value: Binding(get: { header.value }, set: { header.value = $0 }),
              isEnabled: Binding(get: { header.isEnabled }, set: { header.isEnabled = $0 }),
              onDelete: { deleteHeader(header) }
            )
            Divider().background(Color.relayBorder.opacity(0.5))
          }
        }
      }
      .background(Color.relayBg)
      addButton("Add Header") { addHeader() }
    }
    .background(Color.relayBg)
  }

  private var columnHeader: some View {
    HStack(spacing: 0) {
      Text("Enabled").frame(width: 60)
      Text("Key").frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
      Text("Value").frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
      Spacer().frame(width: 36)
    }
    .font(.system(size: 11, weight: .semibold))
    .foregroundStyle(Color.relaySecondary)
    .padding(.horizontal, 14)
    .padding(.vertical, 7)
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

// MARK: - Shared Key/Value Row

struct KeyValueRowView: View {
  @Binding var key: String
  @Binding var value: String
  @Binding var isEnabled: Bool
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      Toggle("", isOn: $isEnabled)
        .toggleStyle(.checkbox)
        .frame(width: 60)
        .tint(Color.relayAccent)
      TextField("Key", text: $key)
        .textFieldStyle(.plain)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .opacity(isEnabled ? 1 : 0.4)
      Divider().frame(height: 20).background(Color.relayBorder)
      TextField("Value", text: $value)
        .textFieldStyle(.plain)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Color(red: 0.85, green: 0.85, blue: 0.85))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .opacity(isEnabled ? 1 : 0.4)
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

// MARK: - Shared Add Button

private func addButton(_ label: String, action: @escaping () -> Void) -> some View {
  Button(action: action) {
    HStack(spacing: 6) {
      Image(systemName: "plus.circle")
      Text(label)
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

// MARK: - Auth Editor

struct AuthEditorView: View {
  @Bindable var request: RequestItem

  var authType: AuthType {
    AuthType(rawValue: request.authType) ?? .none
  }

  var body: some View {
    VStack(spacing: 0) {
      authTypePicker
      Divider().background(Color.relayBorder)
      authContent
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.relayBg)
    }
    .background(Color.relayBg)
  }

  private var authTypePicker: some View {
    HStack(spacing: 16) {
      ForEach(AuthType.allCases, id: \.rawValue) { type in
        Button {
          request.authType = type.rawValue
        } label: {
          HStack(spacing: 5) {
            Circle()
              .fill(authType == type ? Color.relayAccent : Color.relayBorder)
              .frame(width: 8, height: 8)
            Text(type.rawValue)
              .font(.system(size: 12))
              .foregroundStyle(authType == type ? .white : Color.relaySecondary)
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

  @ViewBuilder
  private var authContent: some View {
    switch authType {
    case .none:
      Text("This request has no authorization")
        .font(.system(size: 13))
        .foregroundStyle(Color.relaySecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .bearer:
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          authField("Token", placeholder: "Enter bearer token or {{variable}}", text: $request.authBearerToken)
          Text("Sent as: Authorization: Bearer <token>")
            .font(.system(size: 11))
            .foregroundStyle(Color.relaySecondary)
            .padding(.leading, 122)
        }
        .padding(.vertical, 16)
      }
    case .basic:
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          authField("Username", placeholder: "Enter username or {{variable}}", text: $request.authBasicUsername)
          authField("Password", placeholder: "Enter password or {{variable}}", text: $request.authBasicPassword, isSecure: true)
          Text("Encoded as: Authorization: Basic <base64(user:pass)>")
            .font(.system(size: 11))
            .foregroundStyle(Color.relaySecondary)
            .padding(.leading, 122)
        }
        .padding(.vertical, 16)
      }
    case .apiKey:
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          authField("Key Name", placeholder: "e.g. X-API-Key", text: $request.authApiKeyName)
          authField("Key Value", placeholder: "Enter API key or {{variable}}", text: $request.authApiKeyValue)
          HStack(spacing: 12) {
            Text("Add to")
              .font(.system(size: 12))
              .foregroundStyle(Color.relaySecondary)
              .frame(width: 108, alignment: .trailing)
            ForEach(APIKeyLocation.allCases, id: \.rawValue) { loc in
              Button {
                request.authApiKeyLocation = loc.rawValue
              } label: {
                HStack(spacing: 5) {
                  Circle()
                    .fill(request.authApiKeyLocation == loc.rawValue ? Color.relayAccent : Color.relayBorder)
                    .frame(width: 8, height: 8)
                  Text(loc.rawValue)
                    .font(.system(size: 12))
                    .foregroundStyle(request.authApiKeyLocation == loc.rawValue ? .white : Color.relaySecondary)
                }
              }
              .buttonStyle(.plain)
            }
          }
        }
        .padding(.vertical, 16)
      }
    }
  }

  private func authField(_ label: String, placeholder: String, text: Binding<String>, isSecure: Bool = false) -> some View {
    HStack(spacing: 12) {
      Text(label)
        .font(.system(size: 12))
        .foregroundStyle(Color.relaySecondary)
        .frame(width: 108, alignment: .trailing)
      Group {
        if isSecure {
          SecureField(placeholder, text: text)
        } else {
          TextField(placeholder, text: text)
        }
      }
      .textFieldStyle(.plain)
      .font(.system(size: 12, design: .monospaced))
      .foregroundStyle(.white)
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(Color.relayInputBg)
      .clipShape(RoundedRectangle(cornerRadius: 5))
      .padding(.trailing, 14)
    }
    .padding(.leading, 14)
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
