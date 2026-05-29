import SwiftUI

// MARK: - Key Value Table View

/// Generic editable table for key-value pairs (headers, params, etc.)
public struct KeyValueTableView: View {
    @Binding var items: [KeyValuePair]
    var keyPlaceholder: String = "Key"
    var valuePlaceholder: String = "Value"
    var showDescription: Bool = false
    var allowFiles: Bool = false
    var autoAddRow: Bool = true

    public init(
        items: Binding<[KeyValuePair]>,
        keyPlaceholder: String = "Key",
        valuePlaceholder: String = "Value",
        showDescription: Bool = false,
        allowFiles: Bool = false,
        autoAddRow: Bool = true
    ) {
        self._items = items
        self.keyPlaceholder = keyPlaceholder
        self.valuePlaceholder = valuePlaceholder
        self.showDescription = showDescription
        self.allowFiles = allowFiles
        self.autoAddRow = autoAddRow
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                Spacer().frame(width: 28)
                Text(keyPlaceholder).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                Text(valuePlaceholder).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                if showDescription {
                    Text("Description").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer().frame(width: 28)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()

            // Rows
            List {
                ForEach($items) { $item in
                    KeyValueRowView(
                        item: $item,
                        keyPlaceholder: keyPlaceholder,
                        valuePlaceholder: valuePlaceholder,
                        showDescription: showDescription,
                        onDelete: { removeItem(item) }
                    )
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    .listRowSeparator(.hidden)
                }
                .onMove { source, dest in
                    items.move(fromOffsets: source, toOffset: dest)
                }
                .onDelete { offsets in
                    items.remove(atOffsets: offsets)
                }
            }
            .listStyle(.plain)
            .frame(minHeight: 100)

            Divider()

            // Footer buttons
            HStack {
                Button {
                    addRow()
                } label: {
                    Label("Add Row", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                Spacer()

                Button {
                    bulkPasteSheet()
                } label: {
                    Text("Bulk Edit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func addRow() {
        items.append(KeyValuePair())
    }

    private func removeItem(_ item: KeyValuePair) {
        items.removeAll { $0.id == item.id }
    }

    private func bulkPasteSheet() {
        // Handled externally via sheet presentation
    }
}

// MARK: - Key Value Row View

private struct KeyValueRowView: View {
    @Binding var item: KeyValuePair
    var keyPlaceholder: String
    var valuePlaceholder: String
    var showDescription: Bool
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            // Enable toggle
            Toggle("", isOn: $item.isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: 20)

            // Key
            TextField(keyPlaceholder, text: $item.key)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity)

            // Value (masked if secret)
            if item.type == .secret {
                SecureField(valuePlaceholder, text: $item.value)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity)
            } else {
                TextField(valuePlaceholder, text: $item.value)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity)
            }

            // Description
            if showDescription {
                TextField("Description", text: $item.description)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            // Delete
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .frame(width: 20)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Variable Highlight Field

/// TextField that renders {{variable}} tokens as colored capsule chips.
public struct VariableHighlightField: View {
    @Binding var text: String
    var placeholder: String = ""
    var resolver: VariableResolver?
    var font: Font = .body
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool
    @State private var showTooltip: String?
    @State private var tooltipPosition: CGPoint = .zero

    public init(
        text: Binding<String>,
        placeholder: String = "",
        resolver: VariableResolver? = nil,
        font: Font = .body,
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.resolver = resolver
        self.font = font
        self.onSubmit = onSubmit
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(font)
                    .foregroundStyle(.tertiary)
                    .allowsHitTesting(false)
            }

            if isFocused || !text.contains("{{") {
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(font)
                    .focused($isFocused)
                    .onSubmit { onSubmit?() }
            } else {
                // Render token highlights
                tokenizedView
                    .onTapGesture { isFocused = true }
            }
        }
    }

    private var tokenizedView: some View {
        let tokens = resolver?.tokens(in: text) ?? []
        if tokens.isEmpty {
            return AnyView(Text(text).font(font))
        }

        var parts: [AttributedStringPart] = []
        var lastEnd = text.startIndex

        for token in tokens {
            guard let range = Range(token.range, in: text) else { continue }
            if lastEnd < range.lowerBound {
                parts.append(.plain(String(text[lastEnd..<range.lowerBound])))
            }
            parts.append(.variable(token))
            lastEnd = range.upperBound
        }
        if lastEnd < text.endIndex {
            parts.append(.plain(String(text[lastEnd...])))
        }

        return AnyView(
            FlowLayout(spacing: 2) {
                ForEach(parts.indices, id: \.self) { i in
                    switch parts[i] {
                    case .plain(let str):
                        Text(str).font(font)
                    case .variable(let token):
                        VariableChip(token: token, resolver: resolver)
                    }
                }
            }
        )
    }

    private enum AttributedStringPart {
        case plain(String)
        case variable(VariableToken)
    }
}

// MARK: - Variable Chip

private struct VariableChip: View {
    let token: VariableToken
    let resolver: VariableResolver?
    @State private var showPopover = false

    var body: some View {
        Text("{{\(token.name)}}")
            .font(.system(.body, design: .monospaced).bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                token.isResolved ? Color.accentColor : Color.red,
                in: Capsule()
            )
            .onTapGesture { showPopover = true }
            .popover(isPresented: $showPopover) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(token.name).font(.headline)
                    if let val = token.resolvedValue {
                        Text(val).font(.caption.monospaced()).foregroundStyle(.secondary)
                    } else {
                        Text("Unresolved").font(.caption).foregroundStyle(.red)
                    }
                }
                .padding()
            }
    }
}

// MARK: - Flow Layout

private struct FlowLayout<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat = 4, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        content()
    }
}
