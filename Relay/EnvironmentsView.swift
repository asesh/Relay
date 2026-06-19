import SwiftUI
import SwiftData

struct EnvironmentsView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \RelayEnvironment.createdAt) private var environments: [RelayEnvironment]
  @State private var showingNewEnvironment = false
  @State private var newEnvironmentName = ""

  var body: some View {
    NavigationStack {
      Group {
        if environments.isEmpty {
          emptyState
        } else {
          List {
            ForEach(environments) { env in
              NavigationLink(value: env) {
                HStack {
                  Image(systemName: "globe")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.relayAccent)
                  Text(env.name)
                    .foregroundStyle(.white)
                  Spacer()
                  let enabledCount = env.variables.filter { $0.isEnabled }.count
                  if enabledCount > 0 {
                    Text("\(enabledCount) var\(enabledCount == 1 ? "" : "s")")
                      .font(.system(size: 11))
                      .foregroundStyle(Color.relaySecondary)
                  }
                }
              }
            }
            .onDelete { offsets in
              for index in offsets {
                modelContext.delete(environments[index])
              }
            }
          }
          .scrollContentBackground(.hidden)
          .background(Color.relaySidebar)
        }
      }
      .navigationTitle("Environments")
      .navigationDestination(for: RelayEnvironment.self) { env in
        EnvironmentDetailView(environment: env)
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
            .foregroundStyle(Color.relayAccent)
        }
        ToolbarItem(placement: .primaryAction) {
          Button {
            showingNewEnvironment = true
          } label: {
            Image(systemName: "plus")
          }
        }
      }
      .alert("New Environment", isPresented: $showingNewEnvironment) {
        TextField("Environment name", text: $newEnvironmentName)
        Button("Create") { createEnvironment() }
        Button("Cancel", role: .cancel) { newEnvironmentName = "" }
      }
    }
    .preferredColorScheme(.dark)
    .background(Color.relaySidebar)
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "globe.badge.chevron.backward")
        .font(.system(size: 40))
        .foregroundStyle(Color.relaySecondary)
      Text("No environments yet")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.white)
      Text("Create an environment to store variables like base URLs and API keys. Reference them in your requests with {{variableName}}.")
        .font(.system(size: 13))
        .foregroundStyle(Color.relaySecondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
      Button {
        showingNewEnvironment = true
      } label: {
        Text("New Environment")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 18)
          .padding(.vertical, 9)
          .background(Color.relayAccent)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
      .padding(.top, 4)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.relaySidebar)
  }

  private func createEnvironment() {
    let name = newEnvironmentName.trimmingCharacters(in: .whitespaces)
    let env = RelayEnvironment(name: name.isEmpty ? "New Environment" : name)
    modelContext.insert(env)
    newEnvironmentName = ""
  }
}

// MARK: - Environment Detail

struct EnvironmentDetailView: View {
  @Bindable var environment: RelayEnvironment
  @Environment(\.modelContext) private var modelContext
  @State private var showingRename = false
  @State private var newName = ""

  var sortedVariables: [EnvironmentVariable] {
    environment.variables.sorted { $0.key < $1.key }
  }

  var body: some View {
    VStack(spacing: 0) {
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
    .navigationTitle(environment.name)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Rename") {
          newName = environment.name
          showingRename = true
        }
        .foregroundStyle(Color.relaySecondary)
      }
    }
    .alert("Rename Environment", isPresented: $showingRename) {
      TextField("Name", text: $newName)
      Button("Rename") {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { environment.name = trimmed }
      }
      Button("Cancel", role: .cancel) {}
    }
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
    Button {
      addVariable()
    } label: {
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
