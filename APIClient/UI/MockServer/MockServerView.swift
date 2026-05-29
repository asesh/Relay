import SwiftUI
import SwiftData
import Darwin

// MARK: - Mock Server View

public struct MockServerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \MockServerModel.name) private var servers: [MockServerModel]
    @State private var selectedServer: MockServerModel?
    @State private var showNewServer = false

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(servers, selection: $selectedServer) { server in
                MockServerListRow(server: server)
            }
            .navigationTitle("Mock Servers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showNewServer = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        } detail: {
            if let server = selectedServer {
                MockServerDetailView(server: server)
            } else {
                ContentUnavailableView("No Server Selected",
                                       systemImage: "server.rack",
                                       description: Text("Select or create a mock server."))
            }
        }
        .sheet(isPresented: $showNewServer) {
            CreateMockServerView()
        }
    }
}

// MARK: - Mock Server List Row

private struct MockServerListRow: View {
    @Bindable var server: MockServerModel

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(server.isRunning ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name).font(.callout)
                Text("Port \(server.port)").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Mock Server Detail View

private struct MockServerDetailView: View {
    @Bindable var server: MockServerModel
    @StateObject private var mockService = MockServerService()
    @Environment(\.modelContext) private var context
    @State private var showAddRoute = false
    @State private var selectedTab: MockServerTab = .routes

    enum MockServerTab: String, CaseIterable {
        case routes = "Routes"
        case log = "Request Log"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header / control bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name).font(.headline)
                    if server.isRunning {
                        Text("http://\(localIPAddress()):\(server.port)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.green)
                    } else {
                        Text("Port \(server.port)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()

                Button {
                    if server.isRunning {
                        mockService.stop()
                        server.isRunning = false
                    } else {
                        mockService.start(server: server)
                        server.isRunning = true
                    }
                    try? context.save()
                } label: {
                    Label(server.isRunning ? "Stop" : "Start",
                          systemImage: server.isRunning ? "stop.circle.fill" : "play.circle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(server.isRunning ? .red : .green)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)

            Divider()

            // Tabs
            Picker("Tab", selection: $selectedTab) {
                ForEach(MockServerTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Content
            switch selectedTab {
            case .routes:
                routesView
            case .log:
                logView
            }
        }
        .navigationTitle(server.name)
        .toolbar {
            if selectedTab == .routes {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddRoute = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddRoute) {
            MockRouteEditorView(server: server)
        }
    }

    // MARK: - Routes View

    private var routesView: some View {
        List {
            if server.routes.isEmpty {
                ContentUnavailableView("No Routes", systemImage: "arrow.right.arrow.left.circle",
                                       description: Text("Add routes to define how the server responds."))
            }
            ForEach(server.routes.sorted { $0.path < $1.path }) { route in
                RouteRowView(route: route)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Log View

    private var logView: some View {
        List(mockService.requestLog) { entry in
            MockLogEntryRow(entry: entry)
        }
        .listStyle(.plain)
        .overlay(
            mockService.requestLog.isEmpty
                ? AnyView(ContentUnavailableView("No Requests Yet", systemImage: "tray",
                                                  description: Text("Incoming requests will appear here.")))
                : AnyView(EmptyView())
        )
    }

    private func localIPAddress() -> String {
        var address = "localhost"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0, var ptr = ifaddr {
            defer { freeifaddrs(ifaddr) }
            repeat {
                let interface = ptr.pointee
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET),
                   let name = interface.ifa_name,
                   String(cString: name) == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
                ptr = ptr.pointee.ifa_next!
            } while ptr.pointee.ifa_next != nil
        }
        return address
    }
}

// MARK: - Route Row View

private struct RouteRowView: View {
    @Bindable var route: MockRouteModel
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $route.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)

            MethodBadgeView(method: route.method, compact: true)
                .frame(width: 52)

            Text(route.path)
                .font(.system(.callout, design: .monospaced))

            Spacer()

            Text("\(route.statusCode)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            if route.responseDelayMs > 0 {
                Text("\(route.responseDelayMs)ms delay")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .contextMenu {
            Button("Delete", role: .destructive) { context.delete(route) }
        }
    }
}

// MARK: - Mock Log Entry Row

private struct MockLogEntryRow: View {
    let entry: MockLogEntry

    var body: some View {
        HStack(spacing: 8) {
            MethodBadgeView(method: entry.method, compact: true).frame(width: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.path).font(.callout.monospaced())
                Text(entry.timestamp.formatted(.dateTime.hour().minute().second()))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(entry.statusCode)")
                .font(.caption.monospaced())
                .foregroundStyle(Color.statusColor(entry.statusCode))
        }
    }
}

// MARK: - Mock Route Editor View

private struct MockRouteEditorView: View {
    let server: MockServerModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var method = "GET"
    @State private var path = "/api/example"
    @State private var statusCode = 200
    @State private var responseBody = "{\n  \"message\": \"Hello from mock!\"\n}"
    @State private var responseDelayMs = 0
    @State private var contentType = "application/json"

    var body: some View {
        NavigationStack {
            Form {
                Section("Route") {
                    HStack {
                        Picker("Method", selection: $method) {
                            ForEach(["GET", "POST", "PUT", "PATCH", "DELETE", "ANY"], id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 90)
                        TextField("Path", text: $path)
                    }
                }
                Section("Response") {
                    HStack {
                        Text("Status Code")
                        Spacer()
                        TextField("200", value: $statusCode, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder).frame(width: 70)
                    }
                    TextField("Content-Type", text: $contentType)
                    Stepper("Delay: \(responseDelayMs)ms",
                            value: $responseDelayMs, in: 0...10000, step: 50)
                }
                Section("Body") {
                    TextEditor(text: $responseBody)
                        .font(.system(.callout, design: .monospaced))
                        .frame(height: 150)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Route")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addRoute() }
                        .disabled(path.isEmpty)
                }
            }
        }
    }

    private func addRoute() {
        let route = MockRouteModel(
            server: server,
            method: method,
            path: path,
            statusCode: statusCode,
            responseBody: responseBody,
            responseContentType: contentType
        )
        route.responseDelayMs = responseDelayMs
        context.insert(route)
        try? context.save()
        dismiss()
    }
}

// MARK: - Create Mock Server View

private struct CreateMockServerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = "My Mock Server"
    @State private var port = 3000

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Stepper("Port: \(port)", value: $port, in: 1024...65535)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Mock Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard let workspace = appState.activeWorkspace else { return }
                        let server = MockServerModel(name: name, port: port, workspace: workspace)
                        context.insert(server)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Mock Server Service

@MainActor
public final class MockServerService: ObservableObject {
    @Published var requestLog: [MockLogEntry] = []
    private var mockServer: MockServer?

    public func start(server model: MockServerModel) {
        mockServer = MockServer(port: UInt16(model.port))
        mockServer?.onRequest = { [weak self] log in
            Task { @MainActor in
                self?.requestLog.insert(log, at: 0)
            }
        }
        do { try mockServer?.start() } catch { print("MockServer error: \(error)") }
    }

    public func stop() {
        mockServer?.stop()
        mockServer = nil
    }
}

// MARK: - Mock Log Entry

public struct MockLogEntry: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let method: String
    public let path: String
    public let statusCode: Int
}
