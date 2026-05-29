import SwiftUI
import SwiftData

// MARK: - History View

public struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \HistoryModel.timestamp, order: .reverse) private var allHistory: [HistoryModel]

    @State private var searchText = ""
    @State private var methodFilter: String? = nil
    @State private var statusFilter: StatusCategory? = nil
    @State private var showClearConfirm = false

    private var filteredHistory: [HistoryModel] {
        allHistory
            .filter { $0.workspaceId == appState.activeWorkspace?.id?.uuidString }
            .filter { searchText.isEmpty || $0.url.localizedCaseInsensitiveContains(searchText) }
            .filter { methodFilter == nil || $0.method == methodFilter }
            .filter { statusFilter == nil || StatusCategory(code: $0.statusCode) == statusFilter }
    }

    private var groupedHistory: [(String, [HistoryModel])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let grouped = Dictionary(grouping: filteredHistory) { item -> String in
            if Calendar.current.isDateInToday(item.timestamp) { return "Today" }
            if Calendar.current.isDateInYesterday(item.timestamp) { return "Yesterday" }
            return formatter.string(from: item.timestamp)
        }
        return grouped.sorted { a, b in
            if a.key == "Today" { return true }
            if b.key == "Today" { return false }
            if a.key == "Yesterday" { return true }
            if b.key == "Yesterday" { return false }
            return a.key > b.key
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            SearchBarView(text: $searchText, placeholder: "Search history")
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            // Filters
            filterChips

            Divider()

            if groupedHistory.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(groupedHistory, id: \.0) { day, items in
                        Section(day) {
                            ForEach(items) { item in
                                HistoryRowView(item: item)
                                    .swipeActions(edge: .trailing) {
                                        Button("Delete", role: .destructive) {
                                            context.delete(item)
                                        }
                                        Button("Save") { saveToCollection(item) }
                                            .tint(.accentColor)
                                    }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("Clear All") { clearHistory(.all) }
                    Button("Clear Older than 7 Days") { clearHistory(.week) }
                    Button("Clear Older than 30 Days") { clearHistory(.month) }
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip("All Methods", isActive: methodFilter == nil) {
                    methodFilter = nil
                }
                ForEach(["GET", "POST", "PUT", "PATCH", "DELETE"], id: \.self) { m in
                    FilterChip(m, isActive: methodFilter == m) {
                        methodFilter = methodFilter == m ? nil : m
                    }
                }
                Divider().frame(height: 16)
                FilterChip("2xx", isActive: statusFilter == .success) {
                    statusFilter = statusFilter == .success ? nil : .success
                }
                FilterChip("3xx", isActive: statusFilter == .redirection) {
                    statusFilter = statusFilter == .redirection ? nil : .redirection
                }
                FilterChip("4xx", isActive: statusFilter == .clientError) {
                    statusFilter = statusFilter == .clientError ? nil : .clientError
                }
                FilterChip("5xx", isActive: statusFilter == .serverError) {
                    statusFilter = statusFilter == .serverError ? nil : .serverError
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No History")
                .font(.title2.weight(.semibold))
            Text("Requests you send will appear here.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private enum ClearPeriod { case all, week, month }

    private func clearHistory(_ period: ClearPeriod) {
        let cutoff: Date?
        switch period {
        case .all: cutoff = nil
        case .week: cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case .month: cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        }
        let toDelete = allHistory.filter { item in
            guard let cut = cutoff else { return true }
            return item.timestamp < cut
        }
        toDelete.forEach { context.delete($0) }
        try? context.save()
    }

    private func saveToCollection(_ item: HistoryModel) {
        // TODO: show collection picker, then create RequestModel
    }
}

// MARK: - History Row View

private struct HistoryRowView: View {
    let item: HistoryModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Button {
            openRequest()
        } label: {
            HStack(spacing: 8) {
                MethodBadgeView(method: item.method, compact: true)
                    .frame(width: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.url)
                        .font(.callout)
                        .lineLimit(1)
                    Text(item.timestamp.formatted(.dateTime.hour().minute().second()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    StatusCodeBadgeView(statusCode: item.statusCode, showText: false)
                    Text("\(item.durationMs) ms")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open Request") { openRequest() }
            Button("Copy URL") { copyURL() }
            Button("Save to Collection") {}
        }
    }

    private func openRequest() {
        // Build a temporary HTTPRequest from history and create/open a transient tab
        var req = HTTPRequest(url: item.url, method: HTTPMethod(rawValue: item.method) ?? .GET)
        appState.openTab(from: item)
    }

    private func copyURL() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.url, forType: .string)
        #else
        UIPasteboard.general.string = item.url
        #endif
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isActive ? Color.accentColor : Color.primary.opacity(0.06),
                             in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
