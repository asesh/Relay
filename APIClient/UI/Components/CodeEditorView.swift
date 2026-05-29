import SwiftUI

// MARK: - Code Editor View

/// Syntax-highlighted code editor wrapping TextEditor with TextKit 2 highlighting.
public struct CodeEditorView: View {
    @Binding var text: String
    var language: SyntaxLanguage = .plain
    var isReadOnly: Bool = false
    var showLineNumbers: Bool = true
    var fontSize: CGFloat = 13
    var theme: SyntaxTheme = .defaultDark

    @State private var findText = ""
    @State private var showFind = false
    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        language: SyntaxLanguage = .plain,
        isReadOnly: Bool = false,
        showLineNumbers: Bool = true,
        fontSize: CGFloat = 13,
        theme: SyntaxTheme = .defaultDark
    ) {
        self._text = text
        self.language = language
        self.isReadOnly = isReadOnly
        self.showLineNumbers = showLineNumbers
        self.fontSize = fontSize
        self.theme = theme
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Find bar
            if showFind {
                HStack {
                    SearchBarView(text: $findText, placeholder: "Find in editor")
                    Button("Done") { showFind = false; findText = "" }
                        .buttonStyle(.plain)
                        .foregroundStyle(.accentColor)
                }
                .padding(8)
                .background(.regularMaterial)
                Divider()
            }

            // Editor
            HStack(spacing: 0) {
                if showLineNumbers {
                    LineNumberGutter(text: text, fontSize: fontSize, theme: theme)
                        .frame(minWidth: 36)
                    Divider()
                }
                HighlightedTextEditor(
                    text: $text,
                    language: language,
                    isReadOnly: isReadOnly,
                    fontSize: fontSize,
                    theme: theme,
                    findText: findText
                )
            }
        }
        .font(.system(size: fontSize, design: .monospaced))
        .background(themeBackground)
        .keyboardShortcut("f", modifiers: .command)
    }

    var themeBackground: Color {
        switch theme {
        case .defaultDark, .dracula, .solarizedDark, .githubDark, .monokai:
            return Color(hex: "#1E1E2E")
        default:
            return Color(hex: "#FAFAFA")
        }
    }
}

// MARK: - Line Number Gutter

private struct LineNumberGutter: View {
    let text: String
    let fontSize: CGFloat
    let theme: SyntaxTheme

    var lineCount: Int {
        text.components(separatedBy: "\n").count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...max(1, lineCount), id: \.self) { line in
                    Text("\(line)")
                        .font(.system(size: fontSize, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .frame(minWidth: 30, alignment: .trailing)
                        .padding(.trailing, 6)
                        .lineSpacing(0)
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Highlighted Text Editor

/// Cross-platform syntax-highlighted TextEditor using AttributedString.
private struct HighlightedTextEditor: View {
    @Binding var text: String
    let language: SyntaxLanguage
    let isReadOnly: Bool
    let fontSize: CGFloat
    let theme: SyntaxTheme
    let findText: String

    var body: some View {
        #if os(macOS)
        HighlightedTextEditorMac(
            text: $text, language: language,
            isReadOnly: isReadOnly, fontSize: fontSize, theme: theme
        )
        #else
        HighlightedTextEditorIOS(
            text: $text, language: language,
            isReadOnly: isReadOnly, fontSize: fontSize, theme: theme
        )
        #endif
    }
}

// MARK: - macOS NSTextView Wrapper

#if os(macOS)
import AppKit

private struct HighlightedTextEditorMac: NSViewRepresentable {
    @Binding var text: String
    let language: SyntaxLanguage
    let isReadOnly: Bool
    let fontSize: CGFloat
    let theme: SyntaxTheme

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = !isReadOnly
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.automaticQuoteSubstitutionEnabled = false
        textView.automaticDashSubstitutionEnabled = false
        textView.automaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.backgroundColor = context.coordinator.bgColor(theme)
        textView.textColor = context.coordinator.textColor(theme)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
        applyHighlighting(to: textView, theme: theme)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    private func applyHighlighting(to textView: NSTextView, theme: SyntaxTheme) {
        guard let storage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.removeAttribute(.foregroundColor, range: fullRange)

        let highlights = SyntaxHighlighter.highlight(text: text, language: language, theme: theme)
        for (range, color) in highlights {
            storage.addAttribute(.foregroundColor, value: NSColor(color), range: range)
        }
        storage.endEditing()
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightedTextEditorMac

        init(parent: HighlightedTextEditorMac) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }

        func bgColor(_ theme: SyntaxTheme) -> NSColor {
            switch theme {
            case .defaultDark, .dracula, .solarizedDark, .githubDark, .monokai:
                return NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
            default:
                return NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1)
            }
        }

        func textColor(_ theme: SyntaxTheme) -> NSColor {
            switch theme {
            case .defaultDark, .dracula, .solarizedDark, .githubDark, .monokai:
                return NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
            default:
                return NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
            }
        }
    }
}
#endif

// MARK: - iOS UITextView Wrapper

#if os(iOS)
import UIKit

private struct HighlightedTextEditorIOS: UIViewRepresentable {
    @Binding var text: String
    let language: SyntaxLanguage
    let isReadOnly: Bool
    let fontSize: CGFloat
    let theme: SyntaxTheme

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.isEditable = !isReadOnly
        tv.isSelectable = true
        tv.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.smartDashesType = .no
        tv.smartQuotesType = .no
        tv.backgroundColor = isDark(theme) ? UIColor(white: 0.12, alpha: 1) : UIColor(white: 0.98, alpha: 1)
        tv.textColor = isDark(theme) ? UIColor(white: 0.9, alpha: 1) : UIColor(white: 0.1, alpha: 1)
        tv.text = text
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text { tv.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    private func isDark(_ theme: SyntaxTheme) -> Bool {
        [SyntaxTheme.defaultDark, .dracula, .solarizedDark, .githubDark, .monokai].contains(theme)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: HighlightedTextEditorIOS
        init(parent: HighlightedTextEditorIOS) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
    }
}
#endif

// MARK: - Syntax Highlighter

enum SyntaxHighlighter {

    static func highlight(text: String, language: SyntaxLanguage, theme: SyntaxTheme) -> [(NSRange, Color)] {
        let colors = ThemeColors(theme: theme)
        var results: [(NSRange, Color)] = []
        let patterns = tokenPatterns(for: language)
        let nsText = text as NSString

        for (pattern, color) in zip(patterns, tokenColors(for: language, theme: theme)) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { continue }
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                results.append((match.range, color))
            }
        }
        return results
    }

    private static func tokenPatterns(for language: SyntaxLanguage) -> [String] {
        switch language {
        case .json:
            return [
                #""(?:[^"\\]|\\.)*""#,          // strings
                #"\b-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#, // numbers
                #"\b(true|false|null)\b"#,       // keywords
                #"[{}\[\],:]{1}"#               // punctuation
            ]
        case .javascript:
            return [
                #"//[^\n]*"#,                   // line comment
                #"/\*[\s\S]*?\*/"#,             // block comment
                #""(?:[^"\\]|\\.)*""#,          // double-quoted strings
                #"'(?:[^'\\]|\\.)*'"#,          // single-quoted strings
                #"`(?:[^`\\]|\\.)*`"#,          // template literals
                #"\b(var|let|const|function|return|if|else|for|while|class|import|export|from|async|await|new|this|typeof|instanceof|null|undefined|true|false)\b"#
            ]
        case .xml, .html:
            return [
                #"<!--[\s\S]*?-->"#,            // comments
                #"<[!/]?[a-zA-Z][^>]*/?>"#,     // tags
                #""[^"]*""#,                    // attribute values
            ]
        case .graphql:
            return [
                #"#[^\n]*"#,                    // comments
                #"\b(query|mutation|subscription|fragment|on|type|schema|directive)\b"#,
                #""[^"]*""#,
            ]
        case .yaml:
            return [
                #"#[^\n]*"#,
                #"^[^:]+(?=:)"#,
                #""[^"]*""#,
                #"'[^']*'"#,
            ]
        default: return []
        }
    }

    private static func tokenColors(for language: SyntaxLanguage, theme: SyntaxTheme) -> [Color] {
        let c = ThemeColors(theme: theme)
        switch language {
        case .json: return [c.string, c.number, c.keyword, c.punctuation]
        case .javascript: return [c.comment, c.comment, c.string, c.string, c.string, c.keyword]
        case .xml, .html: return [c.comment, c.tag, c.string]
        case .graphql: return [c.comment, c.keyword, c.string]
        case .yaml: return [c.comment, c.key, c.string, c.string]
        default: return []
        }
    }
}

// MARK: - Theme Colors

struct ThemeColors {
    let theme: SyntaxTheme
    var string: Color { theme == .defaultDark || theme == .dracula ? Color(hex: "#CE9178") : Color(hex: "#A31515") }
    var number: Color { theme == .defaultDark || theme == .dracula ? Color(hex: "#B5CEA8") : Color(hex: "#098658") }
    var keyword: Color { theme == .defaultDark || theme == .dracula ? Color(hex: "#569CD6") : Color(hex: "#0000FF") }
    var comment: Color { Color(hex: "#6A9955") }
    var tag: Color { Color(hex: "#4EC9B0") }
    var punctuation: Color { theme == .defaultDark ? Color(hex: "#D4D4D4") : Color(hex: "#333333") }
    var key: Color { Color(hex: "#9CDCFE") }
}

// MARK: - JSON Tree View

/// Collapsible recursive JSON tree viewer.
public struct JSONTreeView: View {
    public let value: JSONValue
    public var searchText: String = ""
    public var level: Int = 0

    public init(value: JSONValue, searchText: String = "", level: Int = 0) {
        self.value = value
        self.searchText = searchText
        self.level = level
    }

    public var body: some View {
        switch value {
        case .object(let dict):
            JSONObjectView(dict: dict, searchText: searchText, level: level)
        case .array(let arr):
            JSONArrayView(arr: arr, searchText: searchText, level: level)
        default:
            JSONLeafView(value: value, searchText: searchText)
        }
    }
}

// MARK: - JSON Object View

private struct JSONObjectView: View {
    let dict: [(String, JSONValue)]
    let searchText: String
    let level: Int
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(dict.indices, id: \.self) { i in
                let (key, val) = dict[i]
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(key)
                        .foregroundStyle(Color(hex: "#9CDCFE"))
                        .font(.system(.caption, design: .monospaced))
                    Text(":")
                        .foregroundStyle(.secondary)
                    JSONTreeView(value: val, searchText: searchText, level: level + 1)
                }
                .padding(.leading, CGFloat(level + 1) * 16)
            }
        } label: {
            HStack(spacing: 4) {
                Text("{}")
                    .foregroundStyle(.secondary)
                    .font(.system(.caption, design: .monospaced))
                Text("\(dict.count)")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.secondary.opacity(0.4), in: Capsule())
            }
        }
    }
}

// MARK: - JSON Array View

private struct JSONArrayView: View {
    let arr: [JSONValue]
    let searchText: String
    let level: Int
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(arr.indices, id: \.self) { i in
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(i)")
                        .foregroundStyle(.secondary.opacity(0.5))
                        .font(.system(.caption2, design: .monospaced))
                    JSONTreeView(value: arr[i], searchText: searchText, level: level + 1)
                }
                .padding(.leading, CGFloat(level + 1) * 16)
            }
        } label: {
            HStack(spacing: 4) {
                Text("[]")
                    .foregroundStyle(.secondary)
                    .font(.system(.caption, design: .monospaced))
                Text("\(arr.count)")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.secondary.opacity(0.4), in: Capsule())
            }
        }
    }
}

// MARK: - JSON Leaf View

private struct JSONLeafView: View {
    let value: JSONValue
    let searchText: String
    @State private var isCopied = false

    var body: some View {
        HStack(spacing: 4) {
            Text(value.displayString)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(value.color)
                .textSelection(.enabled)
            if isCopied {
                Image(systemName: "checkmark").font(.caption2).foregroundStyle(.green)
                    .transition(.scale)
            }
        }
        .onTapGesture(count: 2) {
            copyValue()
        }
        .contextMenu {
            Button("Copy Value") { copyValue() }
        }
    }

    private func copyValue() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value.rawString, forType: .string)
        #else
        UIPasteboard.general.string = value.rawString
        #endif
        withAnimation { isCopied = true }
        Task { try? await Task.sleep(nanoseconds: 1_500_000_000); isCopied = false }
    }
}

// MARK: - JSON Value

public indirect enum JSONValue: Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case object([(String, JSONValue)])
    case array([JSONValue])

    public static func parse(from data: Data) -> JSONValue? {
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
        return fromAny(obj)
    }

    static func fromAny(_ value: Any) -> JSONValue {
        switch value {
        case let str as String: return .string(str)
        case let num as NSNumber:
            if CFGetTypeID(num) == CFBooleanGetTypeID() { return .bool(num.boolValue) }
            return .number(num.doubleValue)
        case is NSNull: return .null
        case let arr as [Any]: return .array(arr.map { fromAny($0) })
        case let dict as [String: Any]:
            return .object(dict.sorted { $0.key < $1.key }.map { ($0.key, fromAny($0.value)) })
        default: return .string("\(value)")
        }
    }

    var displayString: String {
        switch self {
        case .string(let s): return "\"\(s)\""
        case .number(let n): return n.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(n))" : "\(n)"
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .object: return "{...}"
        case .array: return "[...]"
        }
    }

    var rawString: String {
        switch self {
        case .string(let s): return s
        case .number(let n): return n.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(n))" : "\(n)"
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        default: return displayString
        }
    }

    var color: Color {
        switch self {
        case .string: return Color(hex: "#CE9178")
        case .number: return Color(hex: "#B5CEA8")
        case .bool: return Color(hex: "#569CD6")
        case .null: return .secondary
        default: return .primary
        }
    }
}
