import Foundation
import Combine

/// Placeholder store. In the real app this would read/write LaunchAgent
/// plists and talk to the run daemon; the UI only ever sees `ScriptTask`.
final class TaskStore: ObservableObject {
    @Published var tasks: [ScriptTask] = SampleData.tasks
    @Published var history: [RunRecord] = SampleData.history

    var failingCount: Int {
        tasks.filter { if case .failed = $0.status { return true } else { return false } }.count
    }

    var dueSoonCount: Int {
        tasks.filter { $0.status == .overdue }.count
    }

    var pausedCount: Int {
        tasks.filter { $0.isPaused }.count
    }

    func runNow(_ task: ScriptTask) {
        // Would enqueue an immediate execution via the scheduler daemon.
    }

    func togglePause(_ task: ScriptTask) {
        guard let index = tasks.firstIndex(of: task) else { return }
        tasks[index].isPaused.toggle()
    }
}
