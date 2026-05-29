import SwiftUI

// MARK: - Command Palette View

public struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    struct PaletteItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let category: String
        let action: () -> Void
    }

    private var results: [PaletteItem] {
        if query.isEmpty { return defaultItems }
        let q = query.lowercased()
        return allItems.filter {
            $0.title.lowercased().contains(q) ||
            $0.subtitle.lowercased().contains(q) ||
            $0.category.lowercased().contains(q)
        }
    }

    private var defaultItems: [PaletteItem] {
        [
            PaletteItem(title: "New Request", subtitle: "Create a new HTTP request", icon: "plus.circle", category: "Actions") {
                isPresented = false
            },
            PaletteItem(title: "New Collection", subtitle: "Create a new collection", icon: "folder.badge.plus", category: "Actions") {
                isPresented = false
            },
            PaletteItem(title: "Open Collection Runner", subtitle: "Run a collection of requests", icon: "play.circle", category: "Actions") {
                isPresented = false
            },
            PaletteItem(title: "Switch Environment", subtitle: "Change active environment", icon: "square.stack.3d.up", category: "Actions") {
                isPresented = false
            },
        ]
    }

    private var allItems: [PaletteItem] {
        defaultItems
        // In production: also search collections, environments, history
    }

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Palette
            VStack(spacing: 0) {
                // Search input
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search commands, requests, environments…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($isSearchFocused)
                        .onSubmit { activateSelected() }
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()

                // Results
                if results.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.secondary)
                        Text("No results for "\(query)"").foregroundStyle(.secondary)
                    }
                    .frame(height: 100)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(results.indices, id: \.self) { i in
                                PaletteRow(item: results[i], isSelected: selectedIndex == i) {
                                    selectedIndex = i
                                    activateSelected()
                                }
                                .onHover { if $0 { selectedIndex = i } }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 340)
                }

                // Footer
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        KeyCap("↩")
                        Text("to select").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        KeyCap("↑↓")
                        Text("to navigate").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        KeyCap("esc")
                        Text("to close").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.03))
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.25), radius: 24)
            .frame(maxWidth: 600)
            .padding(.horizontal, 40)
            .onKeyPress(.upArrow) {
                selectedIndex = max(0, selectedIndex - 1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                selectedIndex = min(results.count - 1, selectedIndex + 1)
                return .handled
            }
            .onKeyPress(.escape) {
                dismiss()
                return .handled
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    private func activateSelected() {
        guard selectedIndex < results.count else { return }
        results[selectedIndex].action()
        dismiss()
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.25)) {
            isPresented = false
        }
    }
}

// MARK: - Palette Row

private struct PaletteRow: View {
    let item: CommandPaletteView.PaletteItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .frame(width: 24, height: 24)
                    .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
                                 in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.callout.weight(.medium))
                    Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                Text(item.category)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Key Cap

private struct KeyCap: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Code Snippet Sheet View

public struct CodeSnippetSheetView: View {
    let request: HTTPRequest
    @State private var selectedLanguage = CodeLanguage.swiftURLSession
    @Environment(\.dismiss) private var dismiss

    public init(request: HTTPRequest) { self.request = request }

    private var snippet: String {
        CodeGenerator.generate(for: request, language: selectedLanguage)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Language picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CodeLanguage.allCases, id: \.self) { lang in
                            Button(lang.displayName) {
                                selectedLanguage = lang
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(selectedLanguage == lang ? .accentColor : .secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(.regularMaterial)

                Divider()

                let binding = Binding(get: { snippet }, set: { _ in })
                CodeEditorView(
                    text: binding,
                    language: selectedLanguage.syntaxLanguage,
                    isReadOnly: true,
                    fontSize: 13,
                    theme: .defaultDark
                )
            }
            .navigationTitle("Code Snippet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        copySnippet()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }

    private func copySnippet() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
        #else
        UIPasteboard.general.string = snippet
        #endif
    }
}

// MARK: - CodeLanguage Extension

extension CodeLanguage {
    var syntaxLanguage: SyntaxLanguage {
        switch self {
        case .swiftURLSession: return .plain
        case .python: return .plain
        case .javaScriptFetch, .axios, .nodeJS: return .javascript
        case .go, .java, .kotlin: return .plain
        case .phpCURL, .ruby, .csharp: return .plain
        }
    }
}
