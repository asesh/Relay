import Foundation

// MARK: - Constants

public enum Constants {
    public static let appName = "APIClient"
    public static let bundleIDPrefix = "com.apiclient"
    public static let keychainService = "com.apiclient.keychain"
    public static let keychainAccessGroup = "com.apiclient.shared"
    public static let iCloudContainerID = "iCloud.com.apiclient"
    public static let maxTabs = 30
    public static let scriptTimeoutSeconds: Double = 5.0
    public static let defaultRequestTimeoutMs = 30_000
    public static let maxRedirects = 10
    public static let mockServerDefaultPort = 3000
    public static let historyRetentionDays = 90
    public static let maxCollectionRunnerIterations = 1000

    // URL variable pattern
    public static let variablePattern = #"\{\{([^}]+)\}\}"#

    // Supported languages for code generation
    public static let codeSnippetLanguages: [CodeLanguage] = [
        .swift, .python, .javascript, .axios, .nodejs,
        .go, .java, .php, .ruby, .kotlin, .csharp
    ]
}

// MARK: - Code Language

public enum CodeLanguage: String, CaseIterable, Sendable {
    case swift = "Swift"
    case python = "Python"
    case javascript = "JavaScript (fetch)"
    case axios = "Axios"
    case nodejs = "Node.js"
    case go = "Go"
    case java = "Java (OkHttp)"
    case php = "PHP (cURL)"
    case ruby = "Ruby"
    case kotlin = "Kotlin (OkHttp)"
    case csharp = "C# (HttpClient)"
}

// MARK: - App Settings Keys

public enum SettingsKey {
    public static let colorScheme = "colorScheme"
    public static let syntaxTheme = "syntaxTheme"
    public static let layoutDensity = "layoutDensity"
    public static let monospacedFont = "monospacedFont"
    public static let editorFontSize = "editorFontSize"
    public static let accentColorHex = "accentColorHex"
    public static let activeWorkspaceID = "activeWorkspaceID"
    public static let activeEnvironmentID = "activeEnvironmentID"
    public static let globalSSLVerification = "globalSSLVerification"
    public static let globalFollowRedirects = "globalFollowRedirects"
    public static let proxyHost = "proxyHost"
    public static let proxyPort = "proxyPort"
    public static let proxyUsername = "proxyUsername"
    public static let proxyMode = "proxyMode"
    public static let sendAnonymousAnalytics = "sendAnonymousAnalytics"
}

// MARK: - Color Scheme Preference

public enum ColorSchemePreference: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

// MARK: - Syntax Theme

public enum SyntaxTheme: String, CaseIterable {
    case defaultLight = "Default Light"
    case defaultDark = "Default Dark"
    case dracula = "Dracula"
    case solarizedLight = "Solarized Light"
    case solarizedDark = "Solarized Dark"
    case monokai = "Monokai"
    case githubLight = "GitHub Light"
    case githubDark = "GitHub Dark"
}

// MARK: - Layout Density

public enum LayoutDensity: String, CaseIterable {
    case compact = "Compact"
    case `default` = "Default"
    case spacious = "Spacious"

    public var rowHeight: CGFloat {
        switch self {
        case .compact: return 32
        case .default: return 44
        case .spacious: return 56
        }
    }

    public var padding: CGFloat {
        switch self {
        case .compact: return 6
        case .default: return 10
        case .spacious: return 16
        }
    }
}
