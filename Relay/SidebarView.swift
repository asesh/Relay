import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CollectionItem.createdAt) private var collections: [CollectionItem]
    @Binding var selectedRequest: RequestItem?
    @State private var showingNewCollection = false
    @State private var newCollectionName = ""
    @State private var expandedCollections: Set<PersistentIdentifier> = []

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
                                isExpanded: expandedCollections.contains(collection.id),
                                selectedRequest: $selectedRequest,
                                onToggle: { toggleCollection(collection) },
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

    private func toggleCollection(_ collection: CollectionItem) {
        if expandedCollections.contains(collection.id) {
            expandedCollections.remove(collection.id)
        } else {
            expandedCollections.insert(collection.id)
        }
    }

    private func createCollection() {
        let name = newCollectionName.trimmingCharacters(in: .whitespaces)
        let collection = CollectionItem(name: name.isEmpty ? "New Collection" : name)
        modelContext.insert(collection)
        newCollectionName = ""
        expandedCollections.insert(collection.id)
    }

    private func addRequest(to collection: CollectionItem) {
        let request = RequestItem(name: "New Request")
        request.collection = collection
        modelContext.insert(request)
        collection.requests.append(request)
        expandedCollections.insert(collection.id)
        selectedRequest = request
    }

    private func deleteCollection(_ collection: CollectionItem) {
        if let req = selectedRequest, req.collection?.id == collection.id {
            selectedRequest = nil
        }
        modelContext.delete(collection)
    }
}

struct CollectionRow: View {
    @Bindable var collection: CollectionItem
    let isExpanded: Bool
    @Binding var selectedRequest: RequestItem?
    let onToggle: () -> Void
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
                        onSelect: { selectedRequest = request },
                        onDelete: { deleteRequest(request) }
                    )
                }
            }
        }
    }

    private func deleteRequest(_ request: RequestItem) {
        if selectedRequest?.id == request.id { selectedRequest = nil }
        modelContext.delete(request)
    }
}

struct RequestRow: View {
    let request: RequestItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                MethodBadge(method: request.method, small: true)
                Text(request.name)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .white : Color(red: 0.85, green: 0.85, blue: 0.85))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.leading, 28)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.relayAccent.opacity(0.2) : Color.clear)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete Request", role: .destructive, action: onDelete)
        }
    }
}
