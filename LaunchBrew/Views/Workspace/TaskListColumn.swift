import SwiftUI
import SwiftData
struct TaskListColumn: View {
    @Query(sort: \ScriptTask.name) private var scriptTaskList: [ScriptTask]
    let selection: SidebarSelection
    @Binding var selectedTask: ScriptTask?
    @State private var query = ""
    @State private var showingNewTask = false

    private var filtered: [ScriptTask] {
        var result = scriptTaskList
        switch selection {
        case .all: break
        case .succeeded: result = result.filter { if case .succeeded = $0.status { return true}; return false }
        case .failing: result = result.filter { if case .failed = $0.status { return true }; return false }
        case .dueSoon: result = result.filter { $0.status == .overdue }
        case .paused: result = result.filter { $0.isPaused }
        case .folder(let name): result = result.filter { $0.workingDirectory == name }
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
        guard let nextRunDate = task.nextRunDate else { return "-" }
        return nextRunDate < Date() ? "overdue" : "in \(nextRunDate.formattedRelativeShort())"
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
    /// "1d 5h 3m", "5h 12m", "3m" style relative label used throughout the app.
        func formattedRelativeShort(from reference: Date = Date()) -> String {
            let totalSeconds = Int(abs(self.timeIntervalSince(reference)))
            
            let days = totalSeconds / 86400
            let hours = (totalSeconds % 86400) / 3600
            let minutes = (totalSeconds % 3600) / 60
            
            var parts: [String] = []
            
            if days > 0 {
                parts.append("\(days)d")
            }
            
            if hours > 0 {
                parts.append("\(hours)h")
            }
            
            // Show minutes if present or if total duration is under an hour (< 1h)
            if minutes > 0 || (days == 0 && hours == 0) {
                parts.append("\(minutes)m")
            }
            
            return parts.joined(separator: " ")
        }
}
