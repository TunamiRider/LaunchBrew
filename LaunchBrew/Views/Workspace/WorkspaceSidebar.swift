import SwiftUI
import SwiftData

enum SidebarSelection: Hashable {
    case all, succeeded, failing, dueSoon, paused
    case folder(String)
}

struct WorkspaceSidebar: View {
    //@EnvironmentObject var store: TaskStore
    @Query(sort: \ScriptTask.name) private var scriptTaskList: [ScriptTask]
    @Binding var selection: SidebarSelection

    private var folders: [String] {
        Array(Set(scriptTaskList.map(\.name))).sorted()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Clean Sidebar Header (Outside of List to avoid row-selection styles)
            HStack(spacing: 10) {
                Image("LaunchBrewLogo")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 0) {
                    Text("LaunchBrew")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Task Manager")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()
                .opacity(0.5)

            // Sidebar List Navigation
            List(selection: $selection) {
                Section("Library") {
                    Label("All Tasks", systemImage: "tray.full")
                        .badge(scriptTaskList.count)
                        .tag(SidebarSelection.all)

                    Label {
                        Text("Succeeded")
                    } icon: {
                        StatusDot(status: .succeeded)
                    }
                    .badge(scriptTaskList.successCount)
                    .tag(SidebarSelection.succeeded)

                    Label {
                        Text("Failed")
                    } icon: {
                        StatusDot(status: .failed(exitCode: 1))
                    }
                    .badge(scriptTaskList.failingCount)
                    .tag(SidebarSelection.failing)
                        
                    Label {
                        Text("Paused")
                    } icon: {
                        StatusDot(status: .paused)
                    }
                    .badge(scriptTaskList.pausedCount)
                    .tag(SidebarSelection.paused)
                }
                
                ////            Section("Folders") {
                ////                ForEach(folders, id: \.self) { folder in
                ////                    Label(folder, systemImage: "folder")
                ////                        .tag(SidebarSelection.folder(folder))
                ////                }
                ////            }
            }
            .listStyle(.sidebar)
        }
        .navigationTitle("") // Keep the window titlebar clean
    }
}
