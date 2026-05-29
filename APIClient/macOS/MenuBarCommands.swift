import SwiftUI

// MARK: - macOS Menu Bar Commands

public struct MenuBarCommands: Commands {

    public init() {}

    public var body: some Commands {
        fileMenu
        editMenuAdditions
        viewMenu
        requestMenu
        collectionMenu
    }
}

// MARK: - File Menu

private extension MenuBarCommands {
    var fileMenu: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Request") {}
                .keyboardShortcut("n", modifiers: .command)

            Button("New Tab") {}
                .keyboardShortcut("t", modifiers: .command)

            Button("New Window") {}
                .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("Open Collection…") {}
                .keyboardShortcut("o", modifiers: .command)

            Button("Close Tab") {}
                .keyboardShortcut("w", modifiers: .command)

            Divider()

            Button("Save") {}
                .keyboardShortcut("s", modifiers: .command)

            Button("Save As…") {}
                .keyboardShortcut("s", modifiers: [.command, .shift])

            Divider()

            Button("Import…") {}
                .keyboardShortcut("o", modifiers: [.command, .shift])

            Button("Export…") {}
        }
    }
}

// MARK: - Edit Menu Additions

private extension MenuBarCommands {
    var editMenuAdditions: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Find in Response") {}
                .keyboardShortcut("f", modifiers: .command)

            Button("Find in Collection") {}
                .keyboardShortcut("f", modifiers: [.command, .shift])
        }
    }
}

// MARK: - View Menu

private extension MenuBarCommands {
    var viewMenu: some Commands {
        CommandMenu("View") {
            Button("Toggle Sidebar") {}
                .keyboardShortcut("s", modifiers: [.command, .option])

            Button("Toggle Response Panel") {}
                .keyboardShortcut("r", modifiers: [.command, .option])

            Button("Show Timeline") {}
                .keyboardShortcut("t", modifiers: [.command, .option])

            Divider()

            Button("Increase Font Size") {}
                .keyboardShortcut("+", modifiers: .command)

            Button("Decrease Font Size") {}
                .keyboardShortcut("-", modifiers: .command)

            Button("Reset Font Size") {}
                .keyboardShortcut("0", modifiers: .command)

            Divider()

            Menu("Theme") {
                Button("System") {}
                Button("Light") {}
                Button("Dark") {}
            }

            Menu("Syntax Theme") {
                Button("Default Light") {}
                Button("Default Dark") {}
                Button("Dracula") {}
                Button("Solarized Light") {}
                Button("Solarized Dark") {}
                Button("Monokai") {}
                Button("GitHub Light") {}
                Button("GitHub Dark") {}
            }
        }
    }
}

// MARK: - Request Menu

private extension MenuBarCommands {
    var requestMenu: some Commands {
        CommandMenu("Request") {
            Button("Send") {}
                .keyboardShortcut(.return, modifiers: .command)

            Button("Cancel") {}
                .keyboardShortcut(".", modifiers: .command)

            Divider()

            Button("Save to Collection") {}
                .keyboardShortcut("s", modifiers: .command)

            Button("Duplicate Request") {}
                .keyboardShortcut("d", modifiers: .command)

            Divider()

            Button("Generate Code Snippet") {}
                .keyboardShortcut("c", modifiers: [.command, .shift])

            Button("Copy as cURL") {}
                .keyboardShortcut("c", modifiers: [.command, .option])

            Divider()

            Button("Params Tab") {}
                .keyboardShortcut("1", modifiers: .command)
            Button("Headers Tab") {}
                .keyboardShortcut("2", modifiers: .command)
            Button("Auth Tab") {}
                .keyboardShortcut("3", modifiers: .command)
            Button("Body Tab") {}
                .keyboardShortcut("4", modifiers: .command)
            Button("Scripts Tab") {}
                .keyboardShortcut("5", modifiers: .command)

            Divider()

            Button("Previous Tab") {}
                .keyboardShortcut("[", modifiers: .command)
            Button("Next Tab") {}
                .keyboardShortcut("]", modifiers: .command)
        }
    }
}

// MARK: - Collection Menu

private extension MenuBarCommands {
    var collectionMenu: some Commands {
        CommandMenu("Collection") {
            Button("New Collection") {}
                .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("Run Collection") {}
                .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button("Export Collection") {}
            Button("Import into Collection") {}
        }
    }
}

// MARK: - Window Manager

@MainActor
public final class WindowManager: ObservableObject {
    public static let shared = WindowManager()
    private init() {}

    #if os(macOS)
    public func openNewWindow() {
        let controller = NSWindowController(window: NSWindow())
        controller.window?.contentView = nil
        controller.showWindow(nil)
    }

    public func openRequest(_ request: RequestModel) {
        let window = NSWindow(
            contentRect: .init(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = request.name
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
    }
    #endif
}
