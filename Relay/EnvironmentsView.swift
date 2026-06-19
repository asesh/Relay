import SwiftUI
import SwiftData

struct EnvironmentsView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \RelayEnvironment.createdAt) private var environments: [RelayEnvironment]
  @State private var selectedEnvironment: RelayEnvironment?
  @State private var showingNewEnvironment = false
  @State private var newEnvironmentName = ""

  var body: some View {
    VStack(spacing: 0) {
      windowTitleBar
      Divider().background(Color.relayBorder)
      HStack(spacing: 0) {
        environmentList
        Divider().background(Color.relayBorder)
        detailPane
      }
    }
    .frame(minWidth: 640, minHeight: 420)
    .preferredColorScheme(.dark)
    .alert("New Environment", isPresented: $showingNewEnvironment) {
      TextField("Environment name", text: $newEnvironmentName)
      Button("Create") { createEnvironment() }
      Button("Cancel", role: .cancel) { newEnvironmentName = "" }
    }
  }

  // MARK: - Title Bar

  private var windowTitleBar: some View {
    HStack {
      Text("Environments")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white)
      Spacer()
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 16))
          .foregroundStyle(Color.relaySecondary)
      }
      .buttonStyle(.plain)
      .keyboardShortcut(.escape, modifiers: [])
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(Color.relayPanel)
  }

  // MARK: - Left column

  private var environmentList: some View {
    VStack(spacing: 0) {
      listHeader
      Divider().background(Color.relayBorder)
      ScrollView {
        LazyVStack(spacing: 0) {
          if environments.isEmpty {
            emptyList
          } else {
            ForEach(environments) { env in
              EnvRowView(
                env: env,
                isSelected: selectedEnvironment?.id == env.id,
                onSelect: { selectedEnvironment = env },
                onDelete: {
                  if selectedEnvironment?.id == env.id { selectedEnvironment = nil }
                  modelContext.delete(env)
                }
              )
            }
          }
        }
        .padding(.vertical, 4)
      }
    }
    .frame(width: 210)
    .background(Color.relaySidebar)
  }

  private var listHeader: some View {
    HStack {
      Text("All Environments")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.relaySecondary)
        .textCase(.uppercase)
      Spacer()
      Button {
        showingNewEnvironment = true
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(Color.relaySecondary)
      }
      .buttonStyle(.plain)
      .help("New Environment")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  private var emptyList: some View {
    VStack(spacing: 8) {
      Image(systemName: "globe.badge.chevron.backward")
        .font(.system(size: 28))
        .foregroundStyle(Color.relaySecondary)
      Text("No environments")
        .font(.system(size: 12))
        .foregroundStyle(Color.relaySecondary)
      Button("New Environment") {
        showingNewEnvironment = true
      }
      .font(.system(size: 12))
      .foregroundStyle(Color.relayAccent)
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 40)
  }

  // MARK: - Right column

  @ViewBuilder
  private var detailPane: some View {
    if let env = selectedEnvironment {
      EnvironmentDetailView(environment: env)
    } else {
      VStack(spacing: 12) {
        Image(systemName: "curlybraces")
          .font(.system(size: 36))
          .foregroundStyle(Color.relaySecondary)
        Text("Select an environment to edit its variables")
          .font(.system(size: 13))
          .foregroundStyle(Color.relaySecondary)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.relayBg)
    }
  }

  // MARK: - Actions

  private func createEnvironment() {
    let name = newEnvironmentName.trimmingCharacters(in: .whitespaces)
    let env = RelayEnvironment(name: name.isEmpty ? "New Environment" : name)
    modelContext.insert(env)
    newEnvironmentName = ""
    selectedEnvironment = env
  }
}

// MARK: - Environment Row

private struct EnvRowView: View {
  let env: RelayEnvironment
  let isSelected: Bool
  let onSelect: () -> Void
  let onDelete: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 8) {
        Image(systemName: "globe")
          .font(.system(size: 11))
          .foregroundStyle(isSelected ? Color.relayAccent : Color.relaySecondary)
        Text(env.name)
          .font(.system(size: 13))
          .foregroundStyle(isSelected ? .white : Color(red: 0.85, green: 0.85, blue: 0.85))
          .lineLimit(1)
        Spacer()
        let count = env.variables.filter { $0.isEnabled }.count
        if count > 0 {
          Text("\(count)")
            .font(.system(size: 10))
            .foregroundStyle(Color.relaySecondary)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(isSelected ? Color.relayAccent.opacity(0.2) : Color.clear)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .contextMenu {
      Button("Delete Environment", role: .destructive, action: onDelete)
    }
  }
}

// MARK: - Environment Detail

struct EnvironmentDetailView: View {
  @Bindable var environment: RelayEnvironment
  @Environment(\.modelContext) private var modelContext
  @State private var showingRename = false
  @State private var showingDeleteConfirm = false
  @State private var newName = ""

  var sortedVariables: [EnvironmentVariable] {
    environment.variables.sorted { $0.key < $1.key }
  }

  var body: some View {
    VStack(spacing: 0) {
      detailHeader
      Divider().background(Color.relayBorder)
      columnHeader
      Divider().background(Color.relayBorder)
      if environment.variables.isEmpty {
        emptyVariables
      } else {
        ScrollView {
          VStack(spacing: 0) {
            ForEach(sortedVariables) { variable in
              VariableRowView(variable: variable, onDelete: { deleteVariable(variable) })
              Divider().background(Color.relayBorder.opacity(0.5))
            }
          }
        }
        .background(Color.relayBg)
      }
      addVariableButton
    }
    .background(Color.relayBg)
    .alert("Rename Environment", isPresented: $showingRename) {
      TextField("Name", text: $newName)
      Button("Rename") {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { environment.name = trimmed }
      }
      Button("Cancel", role: .cancel) {}
    }
    .confirmationDialog(
      "Delete \"\(environment.name)\"?",
      isPresented: $showingDeleteConfirm,
      titleVisibility: .visible
    ) {
      Button("Delete Environment", role: .destructive) {
        modelContext.delete(environment)
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("All variables in this environment will be permanently deleted.")
    }
  }

  private var detailHeader: some View {
    HStack {
      Text(environment.name)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white)
      Spacer()
      Button("Rename") {
        newName = environment.name
        showingRename = true
      }
      .font(.system(size: 12))
      .foregroundStyle(Color.relaySecondary)
      .buttonStyle(.plain)
      Button {
        showingDeleteConfirm = true
      } label: {
        Image(systemName: "trash")
          .font(.system(size: 12))
          .foregroundStyle(Color(red: 0.976, green: 0.243, blue: 0.243))
      }
      .buttonStyle(.plain)
      .help("Delete Environment")
      .padding(.leading, 8)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(Color.relayPanel)
  }

  private var columnHeader: some View {
    HStack(spacing: 0) {
      Text("Enabled").frame(width: 60)
      Text("Variable").frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
      Text("Value").frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
      Spacer().frame(width: 36)
    }
    .font(.system(size: 11, weight: .semibold))
    .foregroundStyle(Color.relaySecondary)
    .padding(.horizontal, 14)
    .padding(.vertical, 7)
    .background(Color.relayPanel)
  }

  private var emptyVariables: some View {
    VStack(spacing: 8) {
      Image(systemName: "curlybraces")
        .font(.system(size: 28))
        .foregroundStyle(Color.relaySecondary)
      Text("No variables")
        .font(.system(size: 13))
        .foregroundStyle(Color.relaySecondary)
      Text("Add variables and reference them with {{name}} in your requests.")
        .font(.system(size: 12))
        .foregroundStyle(Color.relaySecondary.opacity(0.7))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.relayBg)
  }

  private var addVariableButton: some View {
    Button { addVariable() } label: {
      HStack(spacing: 6) {
        Image(systemName: "plus.circle")
        Text("Add Variable")
      }
      .font(.system(size: 12))
      .foregroundStyle(Color.relayAccent)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.relayPanel)
  }

  private func addVariable() {
    let variable = EnvironmentVariable()
    variable.environment = environment
    modelContext.insert(variable)
    environment.variables.append(variable)
  }

  private func deleteVariable(_ variable: EnvironmentVariable) {
    environment.variables.removeAll { $0.id == variable.id }
    modelContext.delete(variable)
  }
}

// MARK: - Variable Row

struct VariableRowView: View {
  @Bindable var variable: EnvironmentVariable
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      Toggle("", isOn: $variable.isEnabled)
        .toggleStyle(.checkbox)
        .frame(width: 60)
        .tint(Color.relayAccent)
      TextField("name", text: $variable.key)
        .textFieldStyle(.plain)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Color.relayAccent)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .opacity(variable.isEnabled ? 1 : 0.4)
      Divider().frame(height: 20).background(Color.relayBorder)
      TextField("value", text: $variable.value)
        .textFieldStyle(.plain)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Color(red: 0.85, green: 0.85, blue: 0.85))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .opacity(variable.isEnabled ? 1 : 0.4)
      Button(action: onDelete) {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(Color.relaySecondary)
          .frame(width: 28)
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 7)
    .padding(.horizontal, 14)
    .background(Color.relayBg)
  }
}
