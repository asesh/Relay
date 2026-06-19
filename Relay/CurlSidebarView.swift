import SwiftUI

struct CurlSidebarView: View {
  let request: RequestItem
  let environment: RelayEnvironment?
  @State private var copied = false

  private var curlString: String { buildCurl() }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider().background(Color.relayBorder)
      ScrollView {
        Text(curlString)
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(Color(red: 0.85, green: 0.85, blue: 0.85))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
          .textSelection(.enabled)
      }
      .background(Color.relayBg)
    }
    .background(Color.relaySidebar)
  }

  private var header: some View {
    HStack {
      Text("cURL")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.relaySecondary)
        .textCase(.uppercase)
      Spacer()
      Button {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(curlString, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
      } label: {
        Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
          .font(.system(size: 11))
          .foregroundStyle(copied ? Color.relayAccent : Color.relaySecondary)
      }
      .buttonStyle(.plain)
      .help("Copy cURL command")
      .animation(.easeInOut(duration: 0.15), value: copied)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color.relayPanel)
  }

  // MARK: - cURL Builder

  private func substitute(_ text: String) -> String {
    guard let env = environment else { return text }
    var result = text
    for v in env.variables where v.isEnabled && !v.key.isEmpty {
      result = result.replacingOccurrences(of: "{{\(v.key)}}", with: v.value)
    }
    return result
  }

  private func buildCurl() -> String {
    var rawURL = substitute(request.url.trimmingCharacters(in: .whitespaces))
    if !rawURL.isEmpty && !rawURL.contains("://") {
      rawURL = "https://" + rawURL
    }

    let authType = AuthType(rawValue: request.authType) ?? .none
    var components = URLComponents(string: rawURL) ?? URLComponents()
    var queryItems = components.queryItems ?? []

    for param in request.queryParams.sorted(by: { $0.key < $1.key }) where param.isEnabled && !param.key.isEmpty {
      queryItems.append(URLQueryItem(name: substitute(param.key), value: substitute(param.value)))
    }

    if authType == .apiKey && request.authApiKeyLocation == APIKeyLocation.queryParam.rawValue {
      let name = request.authApiKeyName.isEmpty ? "apikey" : request.authApiKeyName
      let value = substitute(request.authApiKeyValue)
      if !value.isEmpty { queryItems.append(URLQueryItem(name: name, value: value)) }
    }

    components.queryItems = queryItems.isEmpty ? nil : queryItems
    let fullURL = components.string ?? rawURL

    var parts: [String] = []

    let method = request.method
    parts.append(method == "GET" ? "curl '\(fullURL)'" : "curl -X \(method) '\(fullURL)'")

    switch authType {
    case .bearer:
      let token = substitute(request.authBearerToken)
      if !token.isEmpty { parts.append("  -H 'Authorization: Bearer \(token)'") }
    case .basic:
      let user = substitute(request.authBasicUsername)
      let pass = substitute(request.authBasicPassword)
      if !user.isEmpty { parts.append("  -u '\(user):\(pass)'") }
    case .apiKey:
      if request.authApiKeyLocation == APIKeyLocation.header.rawValue {
        let name = request.authApiKeyName.isEmpty ? "X-API-Key" : request.authApiKeyName
        let value = substitute(request.authApiKeyValue)
        if !value.isEmpty { parts.append("  -H '\(name): \(value)'") }
      }
    case .none:
      break
    }

    for header in request.headers.sorted(by: { $0.key < $1.key }) where header.isEnabled && !header.key.isEmpty {
      parts.append("  -H '\(header.key): \(substitute(header.value))'")
    }

    let bodyType = BodyType(rawValue: request.bodyType) ?? .none
    if bodyType != .none && !request.bodyContent.isEmpty {
      if bodyType == .json { parts.append("  -H 'Content-Type: application/json'") }
      let escaped = request.bodyContent.replacingOccurrences(of: "'", with: "'\\''")
      parts.append("  --data-raw '\(escaped)'")
    }

    return parts.joined(separator: " \\\n")
  }
}
