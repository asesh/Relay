import SwiftUI
import SwiftData

struct ContentView: View {
  @State private var openTabs: [RequestItem] = []
  @State private var selectedTab: RequestItem?
  @State private var showingEnvironments = false
  @AppStorage("activeEnvironmentName") private var activeEnvironmentName: String = ""
  @Query(sort: \RelayEnvironment.createdAt) private var environments: [RelayEnvironment]

  var activeEnvironment: RelayEnvironment? {
    guard !activeEnvironmentName.isEmpty else { return nil }
    return environments.first { $0.name == activeEnvironmentName }
  }

  var body: some View {
    NavigationSplitView {
      SidebarView(
        selectedRequest: selectedTab,
        onOpenRequest: openRequest,
        onCloseTab: closeTab
      )
      .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
    } detail: {
      VStack(spacing: 0) {
        if !openTabs.isEmpty {
          tabBar
          Divider().background(Color.relayBorder)
        }
        if let tab = selectedTab {
          RequestEditorView(request: tab, activeEnvironment: activeEnvironment)
            .id(tab.id)
        } else {
          WelcomeView()
        }
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

  // MARK: - Tab Bar

  private var tabBar: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 0) {
        ForEach(openTabs) { tab in
          TabButton(
            tab: tab,
            isSelected: selectedTab?.id == tab.id,
            onSelect: { selectedTab = tab },
            onClose: { closeTab(tab) }
          )
          Rectangle()
            .fill(Color.relayBorder)
            .frame(width: 1)
        }
        Spacer(minLength: 0)
      }
    }
    .frame(height: 36)
    .background(Color.relayPanel)
  }

  // MARK: - Tab Management

  private func openRequest(_ request: RequestItem) {
    if !openTabs.contains(where: { $0.id == request.id }) {
      openTabs.append(request)
    }
    selectedTab = request
  }

  private func closeTab(_ request: RequestItem) {
    guard let idx = openTabs.firstIndex(where: { $0.id == request.id }) else { return }
    openTabs.remove(at: idx)
    if selectedTab?.id == request.id {
      if openTabs.isEmpty {
        selectedTab = nil
      } else {
        selectedTab = openTabs[max(0, idx - 1)]
      }
    }
  }

  // MARK: - Environment Picker

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

// MARK: - Tab Button

private struct TabButton: View {
  let tab: RequestItem
  let isSelected: Bool
  let onSelect: () -> Void
  let onClose: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      Button(action: onSelect) {
        HStack(spacing: 6) {
          MethodBadge(method: tab.method, small: true)
          Text(tab.name)
            .font(.system(size: 12))
            .foregroundStyle(isSelected ? .white : Color.relaySecondary)
            .lineLimit(1)
            .frame(maxWidth: 120, alignment: .leading)
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(height: 36)
      }
      .buttonStyle(.plain)

      Button(action: onClose) {
        Image(systemName: "xmark")
          .font(.system(size: 9, weight: .medium))
          .foregroundStyle(Color.relaySecondary)
          .frame(width: 24, height: 36)
      }
      .buttonStyle(.plain)
    }
    .background(isSelected ? Color.relayBg : Color.relayPanel)
    .overlay(alignment: .bottom) {
      if isSelected {
        Rectangle()
          .fill(Color.relayAccent)
          .frame(height: 2)
      }
    }
  }
}

// MARK: - Welcome View

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
    .modelContainer(
      for: [
        CollectionItem.self, RequestItem.self, HeaderItem.self,
        QueryParamItem.self, RelayEnvironment.self, EnvironmentVariable.self,
      ],
      inMemory: true
    )
}
