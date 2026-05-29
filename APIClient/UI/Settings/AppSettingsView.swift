import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - App Settings View

public struct AppSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage(SettingsKey.colorScheme) private var colorScheme = ColorSchemePreference.system
    @AppStorage(SettingsKey.syntaxTheme) private var syntaxTheme = SyntaxTheme.defaultDark
    @AppStorage(SettingsKey.layoutDensity) private var density = LayoutDensity.default
    @AppStorage(SettingsKey.editorFontSize) private var editorFontSize = 13
    @AppStorage(SettingsKey.followRedirects) private var followRedirects = true
    @AppStorage(SettingsKey.sslVerification) private var sslVerification = true
    @AppStorage(SettingsKey.sendTimeout) private var sendTimeout = 30000
    @State private var selectedSection: SettingsSection = .general

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "General"
        case appearance = "Appearance"
        case network = "Network"
        case certificates = "Certificates"
        case proxy = "Proxy"
        case keyboard = "Keyboard Shortcuts"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .general: return "gear"
            case .appearance: return "paintpalette"
            case .network: return "network"
            case .certificates: return "lock.shield"
            case .proxy: return "arrow.triangle.2.circlepath"
            case .keyboard: return "keyboard"
            }
        }
    }

    public init() {}

    public var body: some View {
        #if os(macOS)
        TabView(selection: $selectedSection) {
            ForEach(SettingsSection.allCases) { section in
                sectionContent(section)
                    .tabItem {
                        Label(section.rawValue, systemImage: section.icon)
                    }
                    .tag(section)
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        #else
        NavigationStack {
            List {
                ForEach(SettingsSection.allCases) { section in
                    NavigationLink(value: section) {
                        Label(section.rawValue, systemImage: section.icon)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsSection.self) { section in
                sectionContent(section).navigationTitle(section.rawValue)
            }
        }
        #endif
    }

    @ViewBuilder
    private func sectionContent(_ section: SettingsSection) -> some View {
        switch section {
        case .general: GeneralSettingsView()
        case .appearance: ThemeSettingsView()
        case .network: NetworkSettingsView()
        case .certificates: CertificatesView()
        case .proxy: ProxySettingsView()
        case .keyboard: KeyboardShortcutsView()
        }
    }
}

// MARK: - General Settings View

private struct GeneralSettingsView: View {
    @AppStorage(SettingsKey.followRedirects) private var followRedirects = true
    @AppStorage(SettingsKey.sslVerification) private var sslVerification = true
    @AppStorage(SettingsKey.sendTimeout) private var sendTimeout = 30000
    @AppStorage(SettingsKey.sendCookies) private var sendCookies = true
    @AppStorage(SettingsKey.storeCookies) private var storeCookies = true

    var body: some View {
        Form {
            Section("Requests") {
                Toggle("Follow Redirects by Default", isOn: $followRedirects)
                Toggle("SSL Certificate Verification", isOn: $sslVerification)
                HStack {
                    Text("Default Timeout (ms)")
                    Spacer()
                    TextField("30000", value: $sendTimeout, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder).frame(width: 80)
                }
            }
            Section("Cookies") {
                Toggle("Send Cookies", isOn: $sendCookies)
                Toggle("Store Cookies", isOn: $storeCookies)
            }
            Section("Data") {
                Button("Clear Request History") {}
                    .foregroundStyle(.red)
                Button("Reset All Settings") {}
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Theme Settings View

public struct ThemeSettingsView: View {
    @AppStorage(SettingsKey.colorScheme) private var colorScheme = ColorSchemePreference.system
    @AppStorage(SettingsKey.syntaxTheme) private var syntaxTheme = SyntaxTheme.defaultDark
    @AppStorage(SettingsKey.layoutDensity) private var density = LayoutDensity.default
    @AppStorage(SettingsKey.editorFontSize) private var editorFontSize = 13
    @AppStorage(SettingsKey.monospacedFont) private var monospacedFont = "SF Mono"

    public init() {}

    public var body: some View {
        Form {
            Section("Appearance") {
                Picker("Color Scheme", selection: $colorScheme) {
                    Text("System").tag(ColorSchemePreference.system)
                    Text("Light").tag(ColorSchemePreference.light)
                    Text("Dark").tag(ColorSchemePreference.dark)
                }

                Picker("Layout Density", selection: $density) {
                    Text("Compact").tag(LayoutDensity.compact)
                    Text("Default").tag(LayoutDensity.default)
                    Text("Spacious").tag(LayoutDensity.spacious)
                }
            }

            Section("Code Editor") {
                Picker("Syntax Theme", selection: $syntaxTheme) {
                    Text("Default Light").tag(SyntaxTheme.defaultLight)
                    Text("Default Dark").tag(SyntaxTheme.defaultDark)
                    Text("Dracula").tag(SyntaxTheme.dracula)
                    Text("Solarized Light").tag(SyntaxTheme.solarizedLight)
                    Text("Solarized Dark").tag(SyntaxTheme.solarizedDark)
                    Text("Monokai").tag(SyntaxTheme.monokai)
                    Text("GitHub Light").tag(SyntaxTheme.githubLight)
                    Text("GitHub Dark").tag(SyntaxTheme.githubDark)
                }

                Picker("Font", selection: $monospacedFont) {
                    ForEach(["SF Mono", "Menlo", "Monaco", "Courier New"], id: \.self) {
                        Text($0).tag($0)
                    }
                }

                Stepper("Font Size: \(editorFontSize)pt", value: $editorFontSize, in: 10...24)
            }

            Section("Preview") {
                codePreview
            }
        }
        .formStyle(.grouped)
    }

    private var codePreview: some View {
        let sampleCode = """
        {
          "name": "John Doe",
          "age": 30,
          "active": true
        }
        """
        let binding = Binding(get: { sampleCode }, set: { _ in })
        return CodeEditorView(
            text: binding,
            language: .json,
            isReadOnly: true,
            fontSize: CGFloat(editorFontSize),
            theme: syntaxTheme
        )
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Network Settings View

private struct NetworkSettingsView: View {
    @AppStorage(SettingsKey.sslVerification) private var sslVerification = true

    var body: some View {
        Form {
            Section("SSL") {
                Toggle("Verify SSL Certificates", isOn: $sslVerification)
                if !sslVerification {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("Disabling SSL verification exposes your requests to man-in-the-middle attacks.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Certificates View

public struct CertificatesView: View {
    @State private var showImport = false

    public init() {}

    public var body: some View {
        Form {
            Section("Client Certificates") {
                ContentUnavailableView("No Certificates", systemImage: "lock.badge.clock",
                                       description: Text("Import a .p12 or PEM certificate."))
                    .frame(height: 120)
                Button("Import Certificate…") { showImport = true }
            }
            Section("Certificate Pinning") {
                ContentUnavailableView("No Pins", systemImage: "pin",
                                       description: Text("Add SHA-256 public key hash pins for hosts."))
                    .frame(height: 120)
                Button("Add Pin…") {}
            }
            Section("Custom CA Certificates") {
                Button("Import Root CA (PEM/DER)…") {}
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Certificates")
    }
}

// MARK: - Proxy Settings View

public struct ProxySettingsView: View {
    @AppStorage("proxy.mode") private var mode = "system"
    @AppStorage("proxy.host") private var host = ""
    @AppStorage("proxy.port") private var port = 8080
    @AppStorage("proxy.auth.user") private var proxyUser = ""
    @AppStorage("proxy.auth.password") private var proxyPassword = ""
    @AppStorage("proxy.noProxy") private var noProxy = ""

    public init() {}

    public var body: some View {
        Form {
            Section("Proxy Mode") {
                Picker("Mode", selection: $mode) {
                    Text("System Proxy").tag("system")
                    Text("Custom Proxy").tag("custom")
                    Text("No Proxy").tag("none")
                }
                .pickerStyle(.segmented)
            }

            if mode == "custom" {
                Section("Custom Proxy") {
                    TextField("Host", text: $host)
                    Stepper("Port: \(port)", value: $port, in: 1...65535)
                    TextField("Username (optional)", text: $proxyUser)
                    SecureField("Password (optional)", text: $proxyPassword)
                }
            }

            Section("Bypass Proxy") {
                TextField("Comma-separated hosts (e.g., localhost, *.internal)", text: $noProxy)
                    .font(.system(.callout, design: .monospaced))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Proxy")
    }
}

// MARK: - Keyboard Shortcuts View

private struct KeyboardShortcutsView: View {
    let shortcuts: [(String, String)] = [
        ("Send Request", "⌘↩"),
        ("Cancel Request", "⌘."),
        ("Save Request", "⌘S"),
        ("New Tab", "⌘T"),
        ("Close Tab", "⌘W"),
        ("New Window", "⌘⇧N"),
        ("Global Search", "⌘K"),
        ("Toggle Sidebar", "⌘⌥S"),
        ("Toggle Response Panel", "⌘⌥R"),
        ("Find in Response", "⌘F"),
        ("Find in Collection", "⌘⇧F"),
        ("Copy as cURL", "⌘⌥C"),
        ("Generate Code Snippet", "⌘⇧C"),
        ("Run Collection", "⌘⇧R"),
        ("Previous Tab", "⌘["),
        ("Next Tab", "⌘]"),
        ("Params Tab", "⌘1"),
        ("Headers Tab", "⌘2"),
        ("Auth Tab", "⌘3"),
        ("Body Tab", "⌘4"),
        ("Scripts Tab", "⌘5"),
        ("Increase Font Size", "⌘+"),
        ("Decrease Font Size", "⌘-"),
    ]

    var body: some View {
        List(shortcuts, id: \.0) { name, shortcut in
            HStack {
                Text(name).font(.callout)
                Spacer()
                Text(shortcut)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .listStyle(.plain)
        .navigationTitle("Keyboard Shortcuts")
    }
}
