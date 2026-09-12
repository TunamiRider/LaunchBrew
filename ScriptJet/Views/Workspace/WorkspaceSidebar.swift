import SwiftUI

enum SidebarSelection: Hashable {
    case all, failing, dueSoon, paused
    case folder(String)
}

struct WorkspaceSidebar: View {
    @EnvironmentObject var store: TaskStore
    @Binding var selection: SidebarSelection

    private var folders: [String] {
        Array(Set(store.tasks.map(\.folder))).sorted()
    }

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                Label("All Tasks", systemImage: "tray.full")
                    .badge(store.tasks.count)
                    .tag(SidebarSelection.all)

                Label {
                    Text("Failing")
                } icon: {
                    StatusDot(status: .failed(exitCode: 1))
                }
                .badge(store.failingCount)
                .tag(SidebarSelection.failing)

                Label {
                    Text("Due Soon")
                } icon: {
                    StatusDot(status: .overdue)
                }
                .badge(store.dueSoonCount)
                .tag(SidebarSelection.dueSoon)

                Label {
                    Text("Paused")
                } icon: {
                    StatusDot(status: .paused)
                }
                .badge(store.pausedCount)
                .tag(SidebarSelection.paused)
            }

            Section("Folders") {
                ForEach(folders, id: \.self) { folder in
                    Label(folder, systemImage: "folder")
                        .tag(SidebarSelection.folder(folder))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("ScriptJet")
    }
}
