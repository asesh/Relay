import SwiftUI
import SwiftData

struct ContentView: View {
  @State private var selectedRequest: RequestItem?
  @State private var showingEnvironments = false
  @AppStorage("activeEnvironmentName") private var activeEnvironmentName: String = ""
  @Query(sort: \RelayEnvironment.createdAt) private var environments: [RelayEnvironment]

  var activeEnvironment: RelayEnvironment? {
    guard !activeEnvironmentName.isEmpty else { return nil }
    return environments.first { $0.name == activeEnvironmentName }
  }

  var body: some View {
    NavigationSplitView {
      SidebarView(selectedRequest: $selectedRequest)
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
    } detail: {
      if let request = selectedRequest {
        RequestEditorView(request: request, activeEnvironment: activeEnvironment)
      } else {
        WelcomeView()
      }
    }
    .preferredColorScheme(.dark)
    .toolbar {
      ToolbarItem(placement: .navigation) {
        environmentPicker
      }
      ToolbarItem(placement: .primaryAction) {
        Button {
          showingEnvironments = true
        } label: {
          Image(systemName: "slider.horizontal.3")
            .foregroundStyle(Color.relaySecondary)
        }
        .help("Manage Environments")
      }
    }
    .sheet(isPresented: $showingEnvironments) {
      EnvironmentsView()
    }
  }

  private var environmentPicker: some View {
    Menu {
      Button {
        activeEnvironmentName = ""
      } label: {
        if activeEnvironmentName.isEmpty {
          Label("No Environment", systemImage: "checkmark")
        } else {
          Text("No Environment")
        }
      }
      if !environments.isEmpty {
        Divider()
        ForEach(environments) { env in
          Button {
            activeEnvironmentName = env.name
          } label: {
            if activeEnvironmentName == env.name {
              Label(env.name, systemImage: "checkmark")
            } else {
              Text(env.name)
            }
          }
        }
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: "globe")
          .font(.system(size: 12))
        Text(activeEnvironmentName.isEmpty ? "No Environment" : activeEnvironmentName)
          .font(.system(size: 12))
        Image(systemName: "chevron.down")
          .font(.system(size: 9))
      }
      .foregroundStyle(activeEnvironmentName.isEmpty ? Color.relaySecondary : Color.relayAccent)
    }
  }
}

struct WelcomeView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "network")
        .font(.system(size: 52))
        .foregroundStyle(Color.relayAccent)
      Text("Relay")
        .font(.system(size: 28, weight: .bold))
        .foregroundStyle(.white)
      Text("Select a request from the sidebar or create a new one.")
        .font(.system(size: 14))
        .foregroundStyle(Color.relaySecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.relayBg)
  }
}

#Preview {
  ContentView()
    .modelContainer(for: [CollectionItem.self, RequestItem.self, HeaderItem.self, QueryParamItem.self, RelayEnvironment.self, EnvironmentVariable.self], inMemory: true)
}
