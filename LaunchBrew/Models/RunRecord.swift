import Foundation

/// One historical execution of a task, as shown in Run History and the
/// per-task Logs tab.
struct RunRecord: Identifiable, Equatable {
    let id: UUID
    let taskName: String
    let startedAt: Date
    let duration: TimeInterval
    let status: TaskStatus
    let exitCode: Int?

    static func == (lhs: RunRecord, rhs: RunRecord) -> Bool { lhs.id == rhs.id }
}
