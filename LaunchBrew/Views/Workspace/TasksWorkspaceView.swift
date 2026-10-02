import SwiftUI
import SwiftData

struct TasksWorkspaceView: View {
    //@EnvironmentObject var store: TaskStore
    @Query(sort: \ScriptTask.name) private var scriptTaskList: [ScriptTask]
    @State private var selection: SidebarSelection? = .all
    @State private var selectedTask: ScriptTask?

    var body: some View {
        NavigationSplitView {
            WorkspaceSidebar(selection: Binding(
                get: { selection ?? .all },
                set: { selection = $0 }
            ))
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)

        } content: {
            TaskListColumn(
                selection: selection ?? .all,
                selectedTask: $selectedTask
            )
            .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 400)
        } detail: {
            TaskInspector(task: selectedTask ?? scriptTaskList.first)
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            if selectedTask == nil { selectedTask = scriptTaskList.first }
        }
        .onChange(of: selection){ _, newSelection in
            let currentSelection = newSelection ?? .all
            selectedTask = filteredTasks(for: currentSelection).first
        }
//        .background(Color.brewCaramel.opacity(0.15).ignoresSafeArea(.all))
    }
    
    /// Returns tasks matching the active sidebar filter category.
    private func filteredTasks(for selection: SidebarSelection) -> [ScriptTask] {
        switch selection {
        case .all:
            return scriptTaskList
        case .succeeded:
            return scriptTaskList.filter { $0.status == .succeeded }
        case .failing:
            return scriptTaskList.filter {
                if case .failed = $0.status { return true }
                return false
            }
        case .folder(let folderName):
            return scriptTaskList.filter { $0.name == folderName }
        default:
            return scriptTaskList
        }
    }
}

//#Preview {
//    TasksWorkspaceView()
//        .frame(width: 1100, height: 640)
//
//}
