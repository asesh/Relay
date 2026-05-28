import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedRequest: RequestItem?

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedRequest: $selectedRequest)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            if let request = selectedRequest {
                RequestEditorView(request: request)
            } else {
                WelcomeView()
            }
        }
        .preferredColorScheme(.dark)
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
        .modelContainer(for: [CollectionItem.self, RequestItem.self, HeaderItem.self], inMemory: true)
}
