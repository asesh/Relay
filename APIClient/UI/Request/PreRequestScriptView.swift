import SwiftUI

// MARK: - Pre-Request Script View

public struct PreRequestScriptView: View {
    @Binding var source: String
    var theme: SyntaxTheme
    @State private var consoleOutput: [ScriptConsoleEntry] = []
    @State private var showConsole = true

    public init(source: Binding<String>, theme: SyntaxTheme = .defaultDark) {
        self._source = source
        self.theme = theme
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Help text
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("This script runs before the request is sent. Use ")
                Text("pm.request").font(.caption.monospaced()).foregroundStyle(.accentColor)
                Text(" to mutate the request.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)

            Divider()

            CodeEditorView(
                text: $source,
                language: .javascript,
                fontSize: 13,
                theme: theme
            )
            .frame(maxHeight: showConsole ? .infinity : .infinity)

            if showConsole {
                Divider()
                ScriptConsoleView(entries: consoleOutput, onClear: { consoleOutput = [] })
                    .frame(height: 120)
            }
        }
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $showConsole) {
                    Label("Console", systemImage: "terminal")
                }
                .toggleStyle(.button)
                .font(.caption)
            }
        }
    }
}

// MARK: - Tests Script View

public struct TestsScriptView: View {
    @Binding var source: String
    var testResults: [TestResult]
    var theme: SyntaxTheme
    @State private var showConsole = true

    public init(source: Binding<String>, testResults: [TestResult] = [], theme: SyntaxTheme = .defaultDark) {
        self._source = source
        self.testResults = testResults
        self.theme = theme
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
                Text("Write tests using ")
                Text("pm.test('name', fn)").font(.caption.monospaced()).foregroundStyle(.accentColor)
                Text(" and ")
                Text("pm.expect(value)").font(.caption.monospaced()).foregroundStyle(.accentColor)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)

            Divider()

            CodeEditorView(text: $source, language: .javascript, fontSize: 13, theme: theme)

            if !testResults.isEmpty {
                Divider()
                TestResultsInlineView(results: testResults)
                    .frame(height: 120)
            }
        }
    }
}

// MARK: - Script Console View

public struct ScriptConsoleView: View {
    let entries: [ScriptConsoleEntry]
    var onClear: () -> Void

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Console")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear", action: onClear)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.regularMaterial)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(entries) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: entry.level == .error ? "xmark.circle" : entry.level == .warn ? "exclamationmark.triangle" : "info.circle")
                                .foregroundStyle(entry.level == .error ? .red : entry.level == .warn ? .orange : .secondary)
                                .font(.caption2)
                            Text(entry.message)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                    }
                }
            }
            .background(Color(hex: "#1E1E2E"))
        }
    }
}

// MARK: - Test Results Inline View

public struct TestResultsInlineView: View {
    let results: [TestResult]

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Test Results")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                let passed = results.filter(\.passed).count
                let total = results.count
                Text("\(passed)/\(total) passed")
                    .font(.caption)
                    .foregroundStyle(passed == total ? .green : .orange)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.regularMaterial)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(results) { result in
                        HStack(spacing: 6) {
                            Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result.passed ? .green : .red)
                                .font(.caption)
                            Text(result.name)
                                .font(.caption)
                            if let err = result.errorMessage, !result.passed {
                                Text("— \(err)")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }
}

// MARK: - Request Settings View

public struct RequestSettingsView: View {
    @Binding var settings: RequestSettings

    public init(settings: Binding<RequestSettings>) {
        self._settings = settings
    }

    public var body: some View {
        Form {
            Section("Redirects") {
                Toggle("Follow Redirects", isOn: $settings.followRedirects)
                if settings.followRedirects {
                    Stepper("Max Redirects: \(settings.maxRedirects)", value: $settings.maxRedirects, in: 1...20)
                }
            }

            Section("Security") {
                Toggle("SSL Certificate Verification", isOn: $settings.sslVerification)
                if !settings.sslVerification {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Disabling SSL verification is insecure. Use only for testing.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Proxy") {
                Picker("Proxy", selection: $settings.proxyMode) {
                    Text("System Proxy").tag(ProxyMode.system)
                    Text("Custom Proxy").tag(ProxyMode.custom)
                    Text("No Proxy").tag(ProxyMode.none)
                }
                .pickerStyle(.segmented)
            }

            Section("Timeout") {
                HStack {
                    Text("Timeout (ms)")
                    Spacer()
                    TextField("30000", value: $settings.timeoutMs, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }

            Section("Cookies") {
                Toggle("Send Cookies", isOn: $settings.sendCookies)
                Toggle("Store Cookies", isOn: $settings.storeCookies)
            }

            Section("URL") {
                Toggle("Encode URL", isOn: $settings.encodeURL)
            }
        }
        .formStyle(.grouped)
    }
}
