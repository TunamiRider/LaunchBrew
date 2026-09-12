import SwiftUI

@main
struct ScriptJetApp: App {
    @StateObject private var store = TaskStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(store)
        }

        MenuBarExtra {
            MenuBarPopover()
                .environmentObject(store)
        } label: {
            Image(systemName: store.failingCount > 0 ? "bolt.trianglebadge.exclamationmark" : "bolt")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Simple top-level switcher between the Tasks Workspace and Activity screens.
/// Settings opens as its own window via Cmd-, (standard macOS behavior).
private struct RootTabView: View {
    var body: some View {
        TabView {
            TasksWorkspaceView()
                .tabItem { Label("Tasks", systemImage: "list.bullet.rectangle") }

            ActivityView()
                .tabItem { Label("Activity", systemImage: "clock.arrow.circlepath") }
        }
    }
}
