import SwiftUI

struct TaskListColumn: View {
    @EnvironmentObject var store: TaskStore
    let selection: SidebarSelection
    @Binding var selectedTask: ScriptTask?
    @State private var query = ""
    @State private var showingNewTask = false

    private var filtered: [ScriptTask] {
        var result = store.tasks
        switch selection {
        case .all: break
        case .failing: result = result.filter { if case .failed = $0.status { return true }; return false }
        case .dueSoon: result = result.filter { $0.status == .overdue }
        case .paused: result = result.filter { $0.isPaused }
        case .folder(let name): result = result.filter { $0.folder == name }
        }
        guard !query.isEmpty else { return result }
        return result.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search tasks…", text: $query)
                    .textFieldStyle(.roundedBorder)
                Button {
                    showingNewTask = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
            }
            .padding(10)

            Divider()

            List(filtered, selection: Binding(
                get: { selectedTask?.id },
                set: { id in selectedTask = filtered.first { $0.id == id } }
            )) { task in
                TaskRow(task: task)
                    .tag(task.id)
            }
            .listStyle(.plain)
        }
        .frame(minWidth: 300, idealWidth: 340)
        .sheet(isPresented: $showingNewTask) {
            NewTaskSheet()
        }
    }
}

private struct TaskRow: View {
    let task: ScriptTask

    private var nextRunText: String {
        task.nextRunDate < Date() ? "overdue" : "in \(task.nextRunDate.formattedRelativeShort())"
    }

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(status: task.status)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.name)
                    .font(.system(size: 13, weight: .medium))
                Text(task.scriptPath)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(nextRunText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

extension Date {
    /// "3h", "1d 4h" style relative label used throughout the app.
    func formattedRelativeShort(from reference: Date = Date()) -> String {
        let seconds = abs(self.timeIntervalSince(reference))
        let hours = Int(seconds / 3600)
        if hours < 24 { return "\(max(hours, 0))h" }
        let days = hours / 24
        let remHours = hours % 24
        return "\(days)d \(remHours)h"
    }
}
