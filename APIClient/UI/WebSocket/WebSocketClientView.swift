import SwiftUI

// MARK: - WebSocket Client View

public struct WebSocketClientView: View {
    @Bindable var request: RequestModel
    @EnvironmentObject private var appState: AppState
    @StateObject private var client = WebSocketClient()
    @State private var messageText = ""
    @State private var messageTab: MessageInputTab = .text

    enum MessageInputTab: String, CaseIterable {
        case text = "Text"
        case binary = "Binary (Hex)"
    }

    public init(request: RequestModel) {
        self._request = Bindable(request)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // URL Bar
            HStack(spacing: 8) {
                Text("WS").font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.purple, in: RoundedRectangle(cornerRadius: 4))

                TextField("ws://localhost:8080", text: $request.url)
                    .textFieldStyle(.roundedBorder)

                connectButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)

            Divider()

            // Handshake headers
            DisclosureGroup("Handshake Headers") {
                KeyValueTableView(
                    items: $request.queryParams.map(toKVP: { qp in
                        KeyValuePair(key: qp.name, value: qp.value, isEnabled: qp.isEnabled)
                    }, fromKVP: { _ in }),
                    placeholder: "Header"
                )
                .frame(height: 120)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)

            Divider()

            // Message log
            messageLogView

            Divider()

            // Message composer
            composerView
        }
    }

    // MARK: - Connect Button

    private var connectButton: some View {
        Button {
            if client.isConnected {
                client.disconnect()
            } else {
                guard let url = URL(string: request.url) else { return }
                client.connect(to: url)
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(client.isConnected ? "Disconnect" : "Connect")
                    .font(.callout.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(client.isConnected ? Color.red.opacity(0.1) : Color.green.opacity(0.1),
                         in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(client.isConnected ? .red : .green)
    }

    private var statusColor: Color {
        switch client.connectionState {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .secondary
        case .error: return .red
        }
    }

    // MARK: - Message Log

    private var messageLogView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(client.messages) { message in
                        WebSocketMessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: client.messages.count) {
                if let last = client.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Composer

    private var composerView: some View {
        VStack(spacing: 0) {
            Picker("", selection: $messageTab) {
                ForEach(MessageInputTab.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial)

            Divider()

            HStack(spacing: 8) {
                TextField(messageTab == .text ? "Message..." : "48 65 6C 6C 6F", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(8)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.accentColor, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(messageText.isEmpty || !client.isConnected)

                Button {
                    client.sendPing()
                } label: {
                    Text("Ping")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!client.isConnected)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        switch messageTab {
        case .text:
            client.sendText(messageText)
        case .binary:
            let bytes = messageText
                .split(separator: " ")
                .compactMap { UInt8($0, radix: 16) }
            client.sendBinary(Data(bytes))
        }
        messageText = ""
    }
}

// MARK: - WebSocket Message Bubble

private struct WebSocketMessageBubble: View {
    let message: WebSocketMessage

    var isSent: Bool { message.direction == .sent }

    var body: some View {
        HStack {
            if isSent { Spacer() }
            VStack(alignment: isSent ? .trailing : .leading, spacing: 3) {
                Text(message.prettyText)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(isSent ? .white : .primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(isSent ? Color.accentColor : Color.primary.opacity(0.08),
                                 in: RoundedRectangle(cornerRadius: 12))
                HStack(spacing: 4) {
                    Text(message.timestamp.formatted(.dateTime.hour().minute().second()))
                    Text("·")
                    Text(message.formattedSize)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            if !isSent { Spacer() }
        }
        .contextMenu {
            Button("Copy") {
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.prettyText, forType: .string)
                #else
                UIPasteboard.general.string = message.prettyText
                #endif
            }
        }
    }
}

// MARK: - WebSocket Client ViewModel

@MainActor
public final class WebSocketClient: ObservableObject {
    @Published var messages: [WebSocketMessage] = []
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastPingMs: Double?

    private var webSocketTask: URLSessionWebSocketTask?
    private var session = URLSession.shared
    private var reconnectDelay: TimeInterval = 1.0
    private var reconnectURL: URL?

    public enum ConnectionState { case disconnected, connecting, connected, error }

    public var isConnected: Bool { connectionState == .connected }

    public func connect(to url: URL) {
        connectionState = .connecting
        reconnectURL = url
        let request = URLRequest(url: url)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        connectionState = .connected
        receiveLoop()
    }

    public func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
        reconnectURL = nil
    }

    public func sendText(_ text: String) {
        let msg = WebSocketMessage(direction: .sent, payload: .text(text))
        messages.append(msg)
        webSocketTask?.send(.string(text)) { _ in }
    }

    public func sendBinary(_ data: Data) {
        let msg = WebSocketMessage(direction: .sent, payload: .binary(data))
        messages.append(msg)
        webSocketTask?.send(.data(data)) { _ in }
    }

    public func sendPing() {
        let start = Date()
        webSocketTask?.sendPing { [weak self] _ in
            Task { @MainActor in
                self?.lastPingMs = Date().timeIntervalSince(start) * 1000
            }
        }
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let msg):
                    switch msg {
                    case .string(let text):
                        self.messages.append(WebSocketMessage(direction: .received, payload: .text(text)))
                    case .data(let data):
                        self.messages.append(WebSocketMessage(direction: .received, payload: .binary(data)))
                    @unknown default: break
                    }
                    self.receiveLoop()
                case .failure:
                    self.connectionState = .error
                }
            }
        }
    }
}

// MARK: - WebSocket Message Model

public struct WebSocketMessage: Identifiable {
    public let id = UUID()
    public let timestamp = Date()
    public let direction: Direction
    public let payload: Payload

    public enum Direction { case sent, received }
    public enum Payload { case text(String), binary(Data) }

    public var prettyText: String {
        switch payload {
        case .text(let s):
            if let d = s.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: d),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
               let str = String(data: pretty, encoding: .utf8) {
                return str
            }
            return s
        case .binary(let d):
            return d.map { String(format: "%02X", $0) }.joined(separator: " ")
        }
    }

    public var formattedSize: String {
        let bytes: Int
        switch payload {
        case .text(let s): bytes = s.utf8.count
        case .binary(let d): bytes = d.count
        }
        return Data.formattedSize(bytes)
    }
}

extension Data {
    static func formattedSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}

// MARK: - Convenience binding helper

extension Binding where Value == [QueryParamModel] {
    func map<T>(toKVP: @escaping (QueryParamModel) -> T, fromKVP: @escaping (T) -> Void) -> Binding<[T]> {
        Binding<[T]>(
            get: { self.wrappedValue.map(toKVP) },
            set: { _ in }
        )
    }
}
