# APIClient

A complete, production-grade native API client application for iOS 17+, iPadOS 17+, and macOS 14+ (Sonoma). A full-featured Postman equivalent built with SwiftUI and SwiftData. No third-party dependencies.

---

## Features

### Request Editor
- HTTP methods: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS, TRACE, CONNECT + custom
- URL bar with live `{{variable}}` token rendering (colored capsule chips)
- Params tab with bidirectional URL sync
- Headers tab with preset templates
- Auth tab: None, API Key, Bearer, Basic, Digest, OAuth 1.0, OAuth 2.0 (PKCE, auth code, client credentials, password, implicit), AWS Signature V4, NTLM, Hawk, JWT Bearer
- Body tab: None, Raw (JSON/XML/HTML/JS), form-data, x-www-form-urlencoded, binary, GraphQL
- Pre-request script tab (JavaScriptCore, full `pm.*` API)
- Tests script tab with Chai-style assertions
- Per-request settings: redirects, SSL, proxy, timeout, cookies

### Response Panel
- Status badge, response time, size
- Body: Pretty (JSONTreeView / image / hex dump), Raw, Preview (WKWebView)
- Headers, Cookies, Test Results, Timeline (waterfall chart)
- In-response search (⌘F)

### Collections
- Hierarchy: Workspace → Collection → Folder → Request (unlimited depth)
- Drag-and-drop reorder
- Context menus (right-click / long-press)
- Collection-level auth, headers, variables inherited by children
- Markdown descriptions

### Collection Runner
- Iterations, delay, data file (CSV/JSON)
- Live streaming progress
- JUnit XML export

### Environments & Variables
- Global, Collection, Environment, Local scopes
- Secret variables (masked, excluded from export)
- Active environment toolbar picker
- Live `{{var}}` resolution in all open editors

### History
- Auto-logged on every request
- Grouped by day, searchable, filterable
- Swipe to delete, save to collection

### WebSocket Client
- Text / binary message log (chat-bubble layout)
- Reconnect with exponential backoff
- Ping/pong timing

### GraphQL
- Introspection (caches schema per URL)
- Schema Explorer panel
- Query/variables editors with syntax highlighting
- Subscription support

### Mock Server
- NWListener-based HTTP mock server (Network.framework)
- Route table with `:param` wildcards
- Conditional response rules
- Live request log

### Import / Export
- **Import:** Postman v2.1, OpenAPI 3.0 / Swagger 2.0 YAML+JSON, cURL, HAR, RAML 1.0 (basic)
- **Export:** Postman v2.1, OpenAPI 3.0 YAML, cURL, HAR, Markdown docs
- **Code snippets:** Swift, Python, JS fetch, Axios, Node.js, Go, Java, PHP, Ruby, Kotlin, C#

### SSL & Certificates
- Global + per-request SSL toggle
- Client certificates (.p12 + PEM/key) stored in Keychain
- Certificate pinning (SHA-256 public key hash)
- Custom CA import
- Server certificate inspector

### Multi-tab Interface
- Tab strip with method badge + URL host
- Unsaved changes indicator
- Tab context menu: close, duplicate, move to new window (macOS)
- Session persistence across launches

### Workspaces
- Multiple named workspaces (collections, environments, history, tabs)
- iCloud sync toggle per workspace
- Export as `.apiclient` bundle

---

## Project Structure

```
APIClient/
├── APIClient.xcodeproj/         # Xcode project (4 targets)
├── Shared/                      # Cross-platform code
│   ├── Domain/
│   │   ├── Entities/            # HTTPRequest, HTTPResponse, AuthConfig, etc.
│   │   ├── Services/            # RequestExecutor, AuthHandler, ScriptEngine, etc.
│   │   └── Parsers/             # CurlParser, PostmanCollectionParser, CodeGenerator
│   ├── Persistence/
│   │   ├── AppDatabase.swift    # SwiftData container factory
│   │   └── Models/              # @Model classes (WorkspaceModel, RequestModel, etc.)
│   └── Utilities/               # KeychainHelper, Constants, Extensions
├── UI/                          # Shared SwiftUI views
│   ├── Shell/                   # RootView, SidebarView, DetailView
│   ├── Request/                 # RequestEditorView, URLBarView, AuthEditorView, etc.
│   ├── Response/                # ResponsePanelView, JSONTreeView, timeline
│   ├── Collections/             # CollectionListView, CollectionRunnerView
│   ├── Environments/            # EnvironmentListView, EnvironmentEditorView
│   ├── History/                 # HistoryView
│   ├── WebSocket/               # WebSocketClientView
│   ├── MockServer/              # MockServerView
│   ├── Settings/                # AppSettingsView, CertificatesView, ProxySettingsView
│   └── Components/              # CodeEditorView, JSONTreeView, KeyValueTableView, etc.
├── iOS/                         # iPhone-specific shell (TabView layout)
├── iPadOS/                      # iPad-specific shell (NavigationSplitView)
├── macOS/                       # macOS shell + menu bar + window manager
└── Tests/                       # XCTest unit tests
```

---

## Architecture

### Data Flow
```
UI (SwiftUI + @Bindable)
  ↓ @Model (SwiftData)
  ↓ toHTTPRequest() / update(from:)
Domain Entities (pure structs)
  ↓ Interceptor pipeline
RequestExecutor (URLSession)
  ↓ HTTPResponse
Response Pipeline (metrics, tests, cookies)
  ↓ UI update via @Published
```

### Interceptor Pipeline
1. `VariableResolver` — substitute `{{var}}` tokens
2. `AuthInjector` — inject auth headers/params
3. `PreRequestScriptRunner` — execute JS, mutate request
4. `LoggingInterceptor` — append to history

### Variable Scope Resolution
Local → Data file → Environment → Collection → Global

---

## Building

### Requirements
- Xcode 15+
- iOS Simulator (iPhone 16 recommended) or physical device
- macOS 14+ for macOS target

### Build
```bash
# iOS
xcodebuild -project APIClient/APIClient.xcodeproj -scheme APIClientIOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# macOS
xcodebuild -project APIClient/APIClient.xcodeproj -scheme APIClientMacOS \
  -destination 'platform=macOS' build
```

### Tests
```bash
xcodebuild test -project APIClient/APIClient.xcodeproj -scheme APIClientTests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## Keychain & Entitlements

The app requires the following entitlements in `*.entitlements`:
- `com.apple.security.network.client` — outbound network access
- `com.apple.security.application-groups` — shared keychain group for cross-platform credential sync

For iCloud sync, add `com.apple.developer.icloud-container-identifiers`.

---

## iCloud Sync Setup

1. In Xcode, enable iCloud capability on each app target
2. Add a CloudKit container: `iCloud.com.apiclient`
3. In `AppDatabase.makeContainer()`, swap to `NSPersistentCloudKitContainer` for workspaces with `iCloudSync = true`

---

## Security Notes

- All secrets (OAuth tokens, API keys marked secret, client cert private keys) are stored in the Keychain via `KeychainHelper.swift` — never in SwiftData
- Secret environment variables are excluded from JSON exports
- Certificate pinning rejects requests where the server's public key hash doesn't match stored pins
- SSL verification can be disabled per-request for development; a warning is shown in the UI

---

## Known Limitations

- OAuth 2.0 Authorization Code flow requires `ASWebAuthenticationSession`; this is fully implemented but requires correct redirect URI configuration in the authorization server
- RAML 1.0 import is basic (resources + methods only; no RAML types/traits)
- Mock server background operation on iOS/iPadOS is subject to App Background Modes entitlement; works fully on macOS
- GraphQL subscription requires a WebSocket-capable endpoint; the transport layer connects using `URLSessionWebSocketTask`
- The code editor (CodeEditorView) uses `NSTextView`/`UITextView` wrappers with manual syntax highlighting via `NSAttributedString`; very large files (>500KB) may be slow to highlight

---

## License

MIT License. See LICENSE file.
