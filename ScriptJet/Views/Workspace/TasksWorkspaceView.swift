import SwiftUI

struct TasksWorkspaceView: View {
    @EnvironmentObject var store: TaskStore
    @State private var selection: SidebarSelection? = .all
    @State private var selectedTask: ScriptTask?

    var body: some View {
        NavigationSplitView {
            WorkspaceSidebar(selection: Binding(
                get: { selection ?? .all },
                set: { selection = $0 }
            ))
        } content: {
            TaskListColumn(
                selection: selection ?? .all,
                selectedTask: $selectedTask
            )
        } detail: {
            TaskInspector(task: selectedTask ?? store.tasks.first)
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            if selectedTask == nil { selectedTask = store.tasks.first }
        }
    }
}

#Preview {
    TasksWorkspaceView()
        .environmentObject(TaskStore())
        .frame(width: 1100, height: 640)
}
