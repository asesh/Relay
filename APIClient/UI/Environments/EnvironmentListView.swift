import SwiftUI
import SwiftData

// MARK: - Environment List View

public struct EnvironmentListView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \EnvironmentModel.name) private var allEnvironments: [EnvironmentModel]
    @State private var editingEnvironment: EnvironmentModel?
    @State private var showNewEnvironment = false

    private var environments: [EnvironmentModel] {
        allEnvironments.filter { $0.workspace?.id == appState.activeWorkspace?.id }
    }

    public init() {}

    public var body: some View {
        List {
            Section("Environments") {
                ForEach(environments) { env in
                    HStack {
                        Circle()
                            .fill(Color(hex: env.colorHex))
                            .frame(width: 10, height: 10)
                        Text(env.name)
                            .font(.callout)
                        Spacer()
                        if appState.activeEnvironment?.id == env.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.accentColor)
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { appState.activeEnvironment = env }
                    .contextMenu {
                        Button("Set Active") { appState.activeEnvironment = env }
                        Button("Edit") { editingEnvironment = env }
                        Button("Duplicate") { duplicateEnvironment(env) }
                        Divider()
                        Button("Delete", role: .destructive) { context.delete(env) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Environments")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNewEnvironment = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewEnvironment) {
            EnvironmentEditorView(environment: nil)
                .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(item: $editingEnvironment) { env in
            EnvironmentEditorView(environment: env)
                .frame(minWidth: 500, minHeight: 400)
        }
    }

    private func duplicateEnvironment(_ env: EnvironmentModel) {
        guard let workspace = appState.activeWorkspace else { return }
        let dup = EnvironmentModel(name: env.name + " Copy", workspace: workspace)
        dup.colorHex = env.colorHex
        for v in env.variables {
            let newVar = VariableModel(name: v.name, value: v.currentValue, environment: dup)
            newVar.isSecret = v.isSecret
            context.insert(newVar)
        }
        context.insert(dup)
        try? context.save()
    }
}

// MARK: - Environment Editor View

public struct EnvironmentEditorView: View {
    @Bindable var environment: EnvironmentModel
    let isNew: Bool

    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var newVarName = ""
    @State private var newVarValue = ""
    @State private var newVarIsSecret = false
    @State private var showImport = false

    public init(environment: EnvironmentModel?) {
        if let env = environment {
            self._environment = Bindable(env)
            self.isNew = false
        } else {
            self._environment = Bindable(EnvironmentModel(name: "New Environment"))
            self.isNew = true
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    TextField("Environment Name", text: $environment.name)
                        .font(.title3.weight(.semibold))
                        .textFieldStyle(.plain)

                    ColorPicker("", selection: Binding(
                        get: { Color(hex: environment.colorHex) },
                        set: { environment.colorHex = $0.hexString }
                    ))
                    .labelsHidden()
                }
                .padding(16)
                .background(.regularMaterial)

                Divider()

                // Variables table header
                HStack {
                    Text("Variable").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Initial Value").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Current Value").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "lock").foregroundStyle(.secondary).frame(width: 30)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))

                Divider()

                // Variables list
                List {
                    ForEach(environment.variables.sorted { $0.name < $1.name }) { variable in
                        VariableRowView(variable: variable)
                    }
                    .onDelete { idxSet in
                        let sorted = environment.variables.sorted { $0.name < $1.name }
                        for idx in idxSet { context.delete(sorted[idx]) }
                    }

                    // Add row
                    HStack(spacing: 8) {
                        TextField("New variable name", text: $newVarName)
                            .textFieldStyle(.plain)
                            .frame(maxWidth: .infinity)
                        TextField("Initial value", text: $newVarValue)
                            .textFieldStyle(.plain)
                            .frame(maxWidth: .infinity)
                        Text("").frame(maxWidth: .infinity)
                        Toggle("", isOn: $newVarIsSecret)
                            .labelsHidden()
                            .frame(width: 30)
                        Button("Add") { addVariable() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(newVarName.isEmpty)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
            .navigationTitle(isNew ? "New Environment" : "Edit Environment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isNew {
                            if let workspace = appState.activeWorkspace {
                                environment.workspace = workspace
                            }
                            context.insert(environment)
                        }
                        try? context.save()
                        dismiss()
                    }
                    .disabled(environment.name.isEmpty)
                }
                ToolbarItem {
                    Menu {
                        Button("Import (JSON)") { showImport = true }
                        Button("Export (JSON)") { exportEnvironment() }
                        Divider()
                        Button("Preview Resolved URL") {}
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private func addVariable() {
        guard !newVarName.isEmpty else { return }
        let variable = VariableModel(name: newVarName, value: newVarValue, environment: environment)
        variable.isSecret = newVarIsSecret
        context.insert(variable)
        newVarName = ""
        newVarValue = ""
        newVarIsSecret = false
        try? context.save()
    }

    private func exportEnvironment() {
        let export: [String: Any] = [
            "name": environment.name,
            "values": environment.variables.map { v -> [String: Any] in
                ["key": v.name, "value": v.isSecret ? "" : v.currentValue,
                 "enabled": true, "type": v.isSecret ? "secret" : "default"]
            }
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: export, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8) else { return }
        #if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(environment.name).json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
        #else
        UIPasteboard.general.string = json
        #endif
    }
}

// MARK: - Variable Row View

private struct VariableRowView: View {
    @Bindable var variable: VariableModel
    @State private var showSecret = false

    var body: some View {
        HStack(spacing: 8) {
            Text(variable.name)
                .font(.system(.callout, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Initial value", text: $variable.initialValue)
                .textFieldStyle(.plain)
                .font(.system(.callout, design: .monospaced))
                .frame(maxWidth: .infinity)

            // Current value
            if variable.isSecret && !showSecret {
                HStack {
                    Text(String(repeating: "•", count: min(variable.currentValue.count, 12)))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Button {
                        showSecret = true
                    } label: {
                        Image(systemName: "eye").font(.caption)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                TextField("Current value", text: $variable.currentValue)
                    .textFieldStyle(.plain)
                    .font(.system(.callout, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .onSubmit { showSecret = false }
            }

            Toggle("", isOn: $variable.isSecret)
                .labelsHidden()
                .frame(width: 30)
        }
        .padding(.vertical, 3)
        .listRowSeparator(.hidden)
    }
}
