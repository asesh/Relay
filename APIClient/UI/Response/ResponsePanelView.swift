import SwiftUI

// MARK: - Response Panel View

public struct ResponsePanelView: View {
    let response: HTTPResponse
    @State private var selectedTab: ResponseTab = .body
    @State private var findText = ""
    @State private var showFind = false
    @EnvironmentObject private var appState: AppState

    public init(response: HTTPResponse) {
        self.response = response
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar

            Divider()

            // Tab selector
            responseTabSelector

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .body:
                    ResponseBodyView(response: response, findText: showFind ? findText : "")
                case .headers:
                    ResponseHeadersView(headers: response.headers)
                case .cookies:
                    ResponseCookiesView(cookies: response.cookies)
                case .testResults:
                    ResponseTestResultsView(results: response.testResults)
                case .timeline:
                    ResponseTimelineView(timeline: response.timeline)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .top) {
            if showFind {
                findBar.transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            StatusCodeBadgeView(statusCode: response.statusCode)

            Divider().frame(height: 16)

            Label("\(response.durationMs) ms", systemImage: "clock")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider().frame(height: 16)

            Label(response.formattedSize, systemImage: "doc.text")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            // Find
            Button {
                withAnimation(.spring(response: 0.3)) { showFind.toggle() }
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)
            .help("Find in Response (⌘F)")

            // Copy body
            Button {
                copyBody()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .help("Copy response body")

            // Save
            Button {
                saveResponse()
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .buttonStyle(.plain)
            .help("Save response to file")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    // MARK: - Find Bar

    private var findBar: some View {
        HStack {
            SearchBarView(text: $findText, placeholder: "Find in response")
            Button("Done") {
                withAnimation { showFind = false; findText = "" }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    // MARK: - Tab Selector

    private var responseTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ResponseTab.allCases, id: \.self) { tab in
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
                                .background(badgeColor(tab), in: Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                .overlay(alignment: .bottom) {
                    if selectedTab == tab { Rectangle().fill(Color.accentColor).frame(height: 2) }
                }
            }
            Spacer()
        }
    }

    private func tabBadge(_ tab: ResponseTab) -> String? {
        switch tab {
        case .testResults where !response.testResults.isEmpty:
            let p = response.testResults.filter(\.passed).count
            let t = response.testResults.count
            return "\(p)/\(t)"
        case .cookies where !response.cookies.isEmpty:
            return "\(response.cookies.count)"
        default: return nil
        }
    }

    private func badgeColor(_ tab: ResponseTab) -> Color {
        if tab == .testResults {
            let failed = response.testResults.filter { !$0.passed }.count
            return failed > 0 ? .red : .green
        }
        return .accentColor
    }

    // MARK: - Actions

    private func copyBody() {
        let text = response.prettyBody ?? response.bodyString ?? ""
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    private func saveResponse() {
        // Trigger save panel / share sheet
    }
}

// MARK: - Response Tab

public enum ResponseTab: String, CaseIterable {
    case body, headers, cookies, testResults, timeline

    public var title: String {
        switch self {
        case .body: return "Body"
        case .headers: return "Headers"
        case .cookies: return "Cookies"
        case .testResults: return "Test Results"
        case .timeline: return "Timeline"
        }
    }
}

// MARK: - Response Body View

public struct ResponseBodyView: View {
    let response: HTTPResponse
    var findText: String = ""
    @State private var viewMode: BodyViewMode = .pretty
    @State private var wrapLines = true
    @State private var jsonValue: JSONValue?
    @EnvironmentObject private var appState: AppState

    enum BodyViewMode: String, CaseIterable {
        case pretty = "Pretty"
        case raw = "Raw"
        case preview = "Preview"
    }

    public init(response: HTTPResponse, findText: String = "") {
        self.response = response
        self.findText = findText
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Mode toolbar
            HStack {
                Picker("", selection: $viewMode) {
                    ForEach(BodyViewMode.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                Spacer()

                Toggle("Wrap", isOn: $wrapLines)
                    .toggleStyle(.button)
                    .font(.caption)

                Text(response.contentType?.components(separatedBy: ";").first ?? "")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial)

            Divider()

            // Content
            Group {
                switch viewMode {
                case .pretty:
                    prettyView
                case .raw:
                    rawView
                case .preview:
                    previewView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if response.isJSON, let value = JSONValue.parse(from: response.body) {
                jsonValue = value
            }
        }
    }

    @ViewBuilder
    private var prettyView: some View {
        if response.isJSON, let json = jsonValue {
            ScrollView {
                JSONTreeView(value: json, searchText: findText)
                    .padding(12)
            }
        } else if response.isImage, let imageData = response.body as Data? {
            ScrollView([.horizontal, .vertical]) {
                #if os(iOS)
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
                #elseif os(macOS)
                if let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
                #endif
            }
        } else {
            rawView
        }
    }

    private var rawView: some View {
        let bodyText = response.prettyBody ?? response.bodyString ?? "(Binary data)"
        let binding = Binding(get: { bodyText }, set: { _ in })
        return CodeEditorView(
            text: binding,
            language: response.isJSON ? .json : response.isXML ? .xml : response.isHTML ? .html : .plain,
            isReadOnly: true,
            fontSize: CGFloat(appState.editorFontSize),
            theme: appState.syntaxTheme
        )
    }

    @ViewBuilder
    private var previewView: some View {
        #if os(macOS) || os(iOS)
        if response.isHTML, let htmlString = response.bodyString {
            WebViewWrapper(html: htmlString)
        } else {
            rawView
        }
        #else
        rawView
        #endif
    }
}

// MARK: - WebView Wrapper

#if os(macOS)
import WebKit

struct WebViewWrapper: NSViewRepresentable {
    let html: String
    func makeNSView(context: Context) -> WKWebView { WKWebView() }
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: nil)
    }
}
#elseif os(iOS)
import WebKit

struct WebViewWrapper: UIViewRepresentable {
    let html: String
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: nil)
    }
}
#endif

// MARK: - Response Headers View

public struct ResponseHeadersView: View {
    let headers: [String: String]
    @State private var searchText = ""

    var filteredHeaders: [(String, String)] {
        let sorted = headers.sorted { $0.key < $1.key }
        if searchText.isEmpty { return sorted }
        return sorted.filter { $0.key.localizedCaseInsensitiveContains(searchText) || $0.value.localizedCaseInsensitiveContains(searchText) }
    }

    public init(headers: [String: String]) { self.headers = headers }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                SearchBarView(text: $searchText, placeholder: "Filter headers")
                Button("Copy All as JSON") { copyAllAsJSON() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            .padding(8)

            Divider()

            List(filteredHeaders, id: \.0) { key, value in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(key)
                        .font(.system(.callout, design: .monospaced).weight(.medium))
                        .frame(maxWidth: 180, alignment: .leading)
                    Text(value)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .padding(.vertical, 3)
                .contextMenu {
                    Button("Copy Value") {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(value, forType: .string)
                        #else
                        UIPasteboard.general.string = value
                        #endif
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func copyAllAsJSON() {
        let json = (try? JSONSerialization.data(withJSONObject: headers, options: .prettyPrinted))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(json, forType: .string)
        #else
        UIPasteboard.general.string = json
        #endif
    }
}

// MARK: - Response Cookies View

public struct ResponseCookiesView: View {
    let cookies: [HTTPCookieInfo]

    public init(cookies: [HTTPCookieInfo]) { self.cookies = cookies }

    public var body: some View {
        if cookies.isEmpty {
            VStack {
                Image(systemName: "cube.box").font(.system(size: 36)).foregroundStyle(.secondary)
                Text("No cookies in this response.").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(cookies) { cookie in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(cookie.name).font(.callout.weight(.semibold))
                        Spacer()
                        Text(cookie.domain).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(cookie.value)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        if cookie.httpOnly { Badge("HttpOnly", color: .blue) }
                        if cookie.secure { Badge("Secure", color: .green) }
                        if let expires = cookie.expires {
                            Badge(expires < Date() ? "Expired" : "Expires \(expires.formatted(.relative(presentation: .named)))",
                                  color: expires < Date() ? .red : .secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Response Test Results View

public struct ResponseTestResultsView: View {
    let results: [TestResult]

    public init(results: [TestResult]) { self.results = results }

    public var body: some View {
        VStack(spacing: 0) {
            // Summary
            let passed = results.filter(\.passed).count
            let total = results.count

            HStack(spacing: 16) {
                SummaryChip(label: "Total", value: "\(total)", color: .secondary)
                SummaryChip(label: "Passed", value: "\(passed)", color: .green)
                SummaryChip(label: "Failed", value: "\(total - passed)", color: total - passed > 0 ? .red : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            Divider()

            List(results) { result in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.passed ? .green : .red)
                        .font(.callout)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.name).font(.callout)
                        if let err = result.errorMessage, !result.passed {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Response Timeline View

public struct ResponseTimelineView: View {
    let timeline: ResponseTimeline

    public init(timeline: ResponseTimeline) { self.timeline = timeline }

    private var phases: [(String, Double, Color)] {
        [
            ("DNS Lookup", timeline.dnsLookupMs, Color(hex: "#6366F1")),
            ("TCP Connect", timeline.tcpConnectMs, Color(hex: "#06B6D4")),
            ("TLS Handshake", timeline.tlsHandshakeMs, Color(hex: "#8B5CF6")),
            ("Request Sent", timeline.requestSentMs, Color(hex: "#3B82F6")),
            ("Waiting (TTFB)", timeline.waitingMs, Color(hex: "#F59E0B")),
            ("Download", timeline.downloadMs, Color(hex: "#10B981")),
        ].filter { $0.1 > 0 }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Total
            HStack {
                Text("Total: \(Int(timeline.totalMs)) ms")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    Canvas { context, size in
                        drawWaterfall(context: context, size: size)
                    }
                    .frame(height: CGFloat(phases.count) * 36 + 24)
                    .padding(.horizontal, 16)

                    Divider()

                    // Phase details
                    VStack(spacing: 4) {
                        ForEach(phases.indices, id: \.self) { i in
                            HStack {
                                Circle().fill(phases[i].2).frame(width: 10, height: 10)
                                Text(phases[i].0).font(.callout)
                                Spacer()
                                Text("\(Int(phases[i].1)) ms")
                                    .font(.callout.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    private func drawWaterfall(context: GraphicsContext, size: CGSize) {
        let total = max(timeline.totalMs, 1)
        let barHeight: CGFloat = 20
        let rowHeight: CGFloat = 36
        let labelWidth: CGFloat = 120
        let barArea = size.width - labelWidth - 16
        var yOffset: CGFloat = 12
        var cumMs: Double = 0

        for (label, ms, color) in phases {
            let startX = labelWidth + CGFloat(cumMs / total) * barArea
            let barWidth = max(CGFloat(ms / total) * barArea, 2)

            let rect = CGRect(x: startX, y: yOffset, width: barWidth, height: barHeight)
            context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color))

            // Label
            context.draw(Text(label).font(.caption).foregroundStyle(.primary),
                          at: CGPoint(x: labelWidth - 8, y: yOffset + barHeight / 2),
                          anchor: .trailing)

            // Value
            context.draw(Text("\(Int(ms)) ms").font(.caption2.monospaced()).foregroundStyle(.secondary),
                          at: CGPoint(x: startX + barWidth + 4, y: yOffset + barHeight / 2),
                          anchor: .leading)

            cumMs += ms
            yOffset += rowHeight
        }
    }
}

// MARK: - Supporting Components

private struct Badge: View {
    let label: String
    let color: Color

    init(_ label: String, color: Color = .secondary) {
        self.label = label; self.color = color
    }

    var body: some View {
        Text(label)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.1), in: Capsule())
    }
}

private struct SummaryChip: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.weight(.semibold)).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
