import SwiftUI
import SwiftData

@main
struct LaunchBrewApp: App {

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(for: [ScriptTask.self, RunRecord.self])
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
        .modelContainer(for: [ScriptTask.self, RunRecord.self])

        MenuBarExtra {
            MenuBarPopover()
        } label: {
            Image(systemName: 1 > 0 ? "bolt.trianglebadge.exclamationmark" : "bolt")
        }
        .modelContainer(for: [ScriptTask.self, RunRecord.self])
        .menuBarExtraStyle(.window)
    }
}



enum AppTab: String, CaseIterable, Identifiable {
    case tasks = "Tasks"
    case activity = "Activity"
    
    var id: String { rawValue }
}

/// Simple top-level switcher between the Tasks Workspace and Activity screens.
/// Settings opens as its own window via Cmd-, (standard macOS behavior).
private struct RootTabView: View {
    var body: some View {
        TabView {
            TasksWorkspaceView()
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet.rectangle")
                }

            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "clock.arrow.circlepath")
                }
        }
    }
}

