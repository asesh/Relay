# Relay

A native iOS/macOS HTTP client app built with SwiftUI and SwiftData — similar to Postman, but native.

## Features

- Organize requests into named collections
- Full HTTP method support: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
- Request configuration: headers, query parameters, and request body (JSON, raw text, form data)
- Authentication: Bearer token, Basic auth, and API Key (header or query param)
- Environment variables for reusable values across requests
- Response viewer with Pretty (formatted JSON), Raw, and Headers tabs
- Dark color scheme throughout

## Requirements

- Xcode 26+
- iOS 26.2 / macOS deployment target
- No external dependencies — pure Xcode project

## Platforms

- iOS
- iOS Simulator
- macOS
- xrOS

## Getting Started

1. Clone the repository
2. Open `Relay.xcodeproj` in Xcode
3. Select a simulator or device and press `⌘ + R` to build and run

## Project Structure

```
Relay/
├── RelayApp.swift          # App entry point, SwiftData ModelContainer setup
├── ContentView.swift       # Root NavigationSplitView (sidebar + detail)
├── SidebarView.swift       # Collections and requests list
├── RequestEditorView.swift # URL bar, request tabs, response panel
├── EnvironmentsView.swift  # Environment variable management
├── Models.swift            # SwiftData models and enums
├── NetworkService.swift    # URLSession-based HTTP client
└── Theme.swift             # Colors, method badge component
```

**Data model:**
```
CollectionItem (1:N) → RequestItem (1:N) → HeaderItem
                                         → QueryParamItem
RelayEnvironment (1:N) → EnvironmentVariable
```

## Building & Testing

```bash
# Build
xcodebuild -project "Relay.xcodeproj" -scheme Relay \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run unit tests
xcodebuild test -project "Relay.xcodeproj" -scheme RelayTests \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run UI tests
xcodebuild test -project "Relay.xcodeproj" -scheme RelayUITests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or press `⌘ + U` in Xcode to run all tests.

See [TESTING.md](TESTING.md) for full test documentation and CI setup.

## Coding Guidelines

- **Indentation:** 2 spaces (no tabs)
- **Line length:** 120 characters maximum

## Architecture Notes

- `@Model` classes store enum-valued fields as `String` (raw value); convert at the call site using `HTTPMethod`/`BodyType`/`AuthType`.
- SwiftData queries use `@Query` with `SortDescriptor` by `createdAt`.
- `@Bindable` is used (not `@ObservedObject`) for editing model instances in views.
- `NetworkService.shared` is an async/await singleton with a 30-second timeout. Only headers where `isEnabled == true` are sent.
- App Sandbox is enabled with outbound network client access (`Relay.entitlements`).
