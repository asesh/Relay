# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

Relay is a native iOS/macOS HTTP client app (Postman-style) built with SwiftUI and SwiftData. It lets users create request collections, configure HTTP requests, send them, and view formatted responses.

- Deployment target: iOS 26.2
- Platforms: iOS, iOS Simulator, macOS, xrOS
- No Swift Package Manager dependencies; pure Xcode project

## Build & Test Commands

Build and run via Xcode (no CLI build script). Use `xcodebuild` for CI or scripted builds:

```bash
# Build
xcodebuild -project "Relay.xcodeproj" -scheme Relay -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run unit tests
xcodebuild test -project "Relay.xcodeproj" -scheme RelayTests -destination 'platform=iOS Simulator,name=iPhone 16'

# Run UI tests
xcodebuild test -project "Relay.xcodeproj" -scheme RelayUITests -destination 'platform=iOS Simulator,name=iPhone 16'
```

The test targets use Apple's `Testing` framework (unit tests) and `XCTest` (UI tests). Both are currently stubs.

## Architecture

**Entry point:** `RelayApp.swift` — configures the SwiftData `ModelContainer` with `CollectionItem`, `RequestItem`, and `HeaderItem`, then presents `ContentView`.

**Navigation:** `ContentView` uses a `NavigationSplitView` — sidebar (`SidebarView`) for collections/requests, detail pane for `RequestEditorView` or `WelcomeView` when nothing is selected. Dark color scheme is enforced globally here.

**Data models** (`Models.swift`):
```
CollectionItem (1:N) → RequestItem (1:N) → HeaderItem
```
All relationships use cascade delete. `RequestItem` stores `method` and `bodyType` as raw `String` (not enum), matching the `HTTPMethod` and `BodyType` enum raw values.

**Networking** (`NetworkService.swift`): Singleton `NetworkService.shared` wraps `URLSession` with async/await. Only `isEnabled == true` headers are sent. JSON body type automatically adds `Content-Type: application/json`. Returns `HTTPResponse` (statusCode, headers, body `Data`, duration). 30-second timeout.

**Theme** (`Theme.swift`): All colors and HTTP method colors live here as static extensions on `Color` (prefix `relay*`). `MethodBadge` is the shared component for rendering HTTP method labels.

**Request editor** (`RequestEditorView.swift`): The largest file (~485 lines). Contains the URL bar, request tabs (Headers + Body), and the response panel (Pretty/Raw/Headers tabs). `HeadersEditorView` and `BodyEditorView` are defined in this same file.

## Sandbox & Permissions

`Relay/Relay.entitlements` enables App Sandbox with outbound network client access. Any new capability (e.g., file access, iCloud) must be added here and in the Xcode target's Signing & Capabilities tab.

## Key Conventions

- `@Model` classes use `String` for enum-valued fields; convert to/from `HTTPMethod`/`BodyType` at the call site.
- SwiftData queries use `@Query` with explicit `SortDescriptor` by `createdAt`.
- `@Bindable` is used (not `@ObservedObject`) for editing SwiftData model instances in views.
- Response body formatting: `prettyBody` attempts JSON pretty-print, falls back to `bodyString` (UTF-8 decode).
