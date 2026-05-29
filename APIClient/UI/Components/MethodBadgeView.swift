import SwiftUI

// MARK: - Method Badge View

/// Colored pill badge showing HTTP method.
public struct MethodBadgeView: View {
    public let method: String
    public var compact: Bool = false

    public init(method: String, compact: Bool = false) {
        self.method = method
        self.compact = compact
    }

    public var body: some View {
        Text(method)
            .font(.system(size: compact ? 9 : 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 4 : 6)
            .padding(.vertical, compact ? 2 : 3)
            .background(Color.methodColor(method), in: RoundedRectangle(cornerRadius: 4))
            .fixedSize()
    }
}

// MARK: - Status Code Badge View

/// Colored badge showing HTTP status code.
public struct StatusCodeBadgeView: View {
    public let statusCode: Int
    public var showText: Bool = true

    public init(statusCode: Int, showText: Bool = true) {
        self.statusCode = statusCode
        self.showText = showText
    }

    private var label: String {
        showText
            ? "\(statusCode) \(HTTPResponse.defaultStatusText(for: statusCode))"
            : "\(statusCode)"
    }

    public var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.statusColor(statusCode), in: Capsule())
            .accessibilityValue("\(statusCode) \(HTTPResponse.defaultStatusText(for: statusCode))")
    }
}

// MARK: - Search Bar View

public struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search"
    var onSubmit: (() -> Void)? = nil

    public init(text: Binding<String>, placeholder: String = "Search", onSubmit: (() -> Void)? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .onSubmit { onSubmit?() }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - ResizableDivider

/// Drag-to-resize horizontal divider. Stores split fraction externally.
public struct ResizableDivider: View {
    @Binding var fraction: Double
    var axis: Axis = .horizontal
    var range: ClosedRange<Double> = 0.2...0.8
    var defaultFraction: Double = 0.5

    @State private var isDragging = false

    public init(
        fraction: Binding<Double>,
        axis: Axis = .horizontal,
        range: ClosedRange<Double> = 0.2...0.8,
        defaultFraction: Double = 0.5
    ) {
        self._fraction = fraction
        self.axis = axis
        self.range = range
        self.defaultFraction = defaultFraction
    }

    public var body: some View {
        GeometryReader { geo in
            let totalSize = axis == .horizontal ? geo.size.height : geo.size.width
            ZStack {
                if axis == .horizontal {
                    Rectangle()
                        .fill(isDragging ? Color.accentColor.opacity(0.4) : Color.appSeparator)
                        .frame(height: isDragging ? 3 : 1)
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 10, weight: .heavy))
                        .rotationEffect(.degrees(90))
                } else {
                    Rectangle()
                        .fill(isDragging ? Color.accentColor.opacity(0.4) : Color.appSeparator)
                        .frame(width: isDragging ? 3 : 1)
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 10, weight: .heavy))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            #if os(macOS)
            .onHover { hovering in
                if axis == .horizontal {
                    hovering ? NSCursor.resizeUpDown.push() : NSCursor.pop()
                } else {
                    hovering ? NSCursor.resizeLeftRight.push() : NSCursor.pop()
                }
            }
            #endif
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        isDragging = true
                        let delta = axis == .horizontal
                            ? value.translation.height / totalSize
                            : value.translation.width / totalSize
                        let newFraction = (fraction + delta).clamped(to: range)
                        fraction = newFraction
                    }
                    .onEnded { _ in isDragging = false }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3)) { fraction = defaultFraction }
            }
            .accessibilityLabel("Resize divider")
            .accessibilityHint("Drag to resize panels")
        }
        .frame(
            width: axis == .vertical ? 8 : nil,
            height: axis == .horizontal ? 8 : nil
        )
    }
}

// MARK: - Comparable + Clamped

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
