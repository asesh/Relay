import SwiftUI
import SwiftData

struct SidebarView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \CollectionItem.createdAt) private var collections: [CollectionItem]
  var selectedRequest: RequestItem?
  var onOpenRequest: (RequestItem) -> Void
  var onCloseTab: (RequestItem) -> Void
  @State private var showingNewCollection = false
  @State private var newCollectionName = ""
  @AppStorage("expandedCollectionNames") private var expandedNamesStore: String = ""

  private var expandedNames: Set<String> {
    Set(expandedNamesStore.isEmpty ? [] : expandedNamesStore.components(separatedBy: "\n"))
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider().background(Color.relayBorder)
      ScrollView {
        LazyVStack(spacing: 0) {
          if collections.isEmpty {
            emptyState
          } else {
            ForEach(collections) { collection in
              CollectionRow(
                collection: collection,
                isExpanded: isExpanded(collection),
                selectedRequest: selectedRequest,
                onToggle: { toggleCollection(collection) },
                onOpenRequest: onOpenRequest,
                onCloseTab: onCloseTab,
                onAddRequest: { addRequest(to: collection) },
                onDelete: { deleteCollection(collection) }
              )
            }
          }
        }
        .padding(.vertical, 4)
      }
    }
    .background(Color.relaySidebar)
    .alert("New Collection", isPresented: $showingNewCollection) {
      TextField("Collection name", text: $newCollectionName)
      Button("Create") { createCollection() }
      Button("Cancel", role: .cancel) { newCollectionName = "" }
    }
  }

  private var header: some View {
    HStack {
      Text("Collections")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.relaySecondary)
        .textCase(.uppercase)
      Spacer()
      Button {
        showingNewCollection = true
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(Color.relaySecondary)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "folder.badge.plus")
        .font(.system(size: 28))
        .foregroundStyle(Color.relaySecondary)
      Text("No collections yet")
        .font(.system(size: 12))
        .foregroundStyle(Color.relaySecondary)
      Button("New Collection") {
        showingNewCollection = true
      }
      .font(.system(size: 12))
      .foregroundStyle(Color.relayAccent)
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 40)
  }

  private func isExpanded(_ collection: CollectionItem) -> Bool {
    expandedNames.contains(collection.name)
  }

  private func setExpanded(_ collection: CollectionItem, expanded: Bool) {
    var names = expandedNames
    if expanded { names.insert(collection.name) } else { names.remove(collection.name) }
    expandedNamesStore = names.sorted().joined(separator: "\n")
  }

  private func toggleCollection(_ collection: CollectionItem) {
    setExpanded(collection, expanded: !isExpanded(collection))
  }

  private func createCollection() {
    let name = newCollectionName.trimmingCharacters(in: .whitespaces)
    let collection = CollectionItem(name: name.isEmpty ? "New Collection" : name)
    modelContext.insert(collection)
    newCollectionName = ""
    setExpanded(collection, expanded: true)
  }

  private func addRequest(to collection: CollectionItem) {
    let request = RequestItem(name: "New Request")
    request.collection = collection
    modelContext.insert(request)
    collection.requests.append(request)
    setExpanded(collection, expanded: true)
    onOpenRequest(request)
  }

  private func deleteCollection(_ collection: CollectionItem) {
    for req in collection.requests { onCloseTab(req) }
    modelContext.delete(collection)
  }
}

struct CollectionRow: View {
  @Bindable var collection: CollectionItem
  let isExpanded: Bool
  var selectedRequest: RequestItem?
  let onToggle: () -> Void
  let onOpenRequest: (RequestItem) -> Void
  let onCloseTab: (RequestItem) -> Void
  let onAddRequest: () -> Void
  let onDelete: () -> Void
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    VStack(spacing: 0) {
      Button(action: onToggle) {
        HStack(spacing: 6) {
          Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Color.relaySecondary)
            .frame(width: 12)
          Image(systemName: "folder.fill")
            .font(.system(size: 12))
            .foregroundStyle(Color.relayAccent)
          Text(collection.name)
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .lineLimit(1)
          Spacer()
          Button(action: onAddRequest) {
            Image(systemName: "plus")
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(Color.relaySecondary)
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
      }
      .buttonStyle(.plain)
      .contextMenu {
        Button("Add Request", action: onAddRequest)
        Divider()
        Button("Delete Collection", role: .destructive, action: onDelete)
      }

      if isExpanded {
        let sorted = collection.requests.sorted { $0.createdAt < $1.createdAt }
        ForEach(sorted) { request in
          RequestRow(
            request: request,
            isSelected: selectedRequest?.id == request.id,
            onSelect: { onOpenRequest(request) },
            onDelete: { deleteRequest(request) }
          )
        }
      }
    }
  }

  private func deleteRequest(_ request: RequestItem) {
    onCloseTab(request)
    modelContext.delete(request)
  }
}

struct RequestRow: View {
  let request: RequestItem
  let isSelected: Bool
  let onSelect: () -> Void
  let onDelete: () -> Void
  @State private var isRenaming = false
  @State private var editingName = ""
  @FocusState private var isRenameFocused: Bool

  var body: some View {
    HStack(spacing: 8) {
      MethodBadge(method: request.method, small: true)
      if isRenaming {
        TextField("", text: $editingName)
          .textFieldStyle(.plain)
          .font(.system(size: 12))
          .foregroundStyle(.white)
          .focused($isRenameFocused)
          .onAppear { isRenameFocused = true }
          .onSubmit { commitRename() }
          .onExitCommand { cancelRename() }
          .onChange(of: isRenameFocused) { _, focused in
            if !focused { commitRename() }
          }
      } else {
        Text(request.name)
          .font(.system(size: 12))
          .foregroundStyle(isSelected ? .white : Color(red: 0.85, green: 0.85, blue: 0.85))
          .lineLimit(1)
      }
      Spacer()
    }
    .padding(.leading, 28)
    .padding(.trailing, 12)
    .padding(.vertical, 6)
    .background(isSelected ? Color.relayAccent.opacity(0.2) : Color.clear)
    .contentShape(Rectangle())
    .onTapGesture(count: 2) { startRename() }
    .onTapGesture(count: 1) { onSelect() }
    .contextMenu {
      Button("Rename") { startRename() }
      Divider()
      Button("Delete Request", role: .destructive, action: onDelete)
    }
  }

  private func startRename() {
    editingName = request.name
    isRenaming = true
  }

  private func commitRename() {
    guard isRenaming else { return }
    let trimmed = editingName.trimmingCharacters(in: .whitespaces)
    if !trimmed.isEmpty { request.name = trimmed }
    isRenaming = false
  }

  private func cancelRename() {
    isRenaming = false
  }
}
