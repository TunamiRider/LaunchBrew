import Foundation
import SwiftData

@Model
final class RunRecord: Identifiable, Equatable {
    @Attribute(.unique) var id: UUID
    var taskName: String
    var startedAt: Date
    var duration: TimeInterval
    
    // Status Persistence
    var statusRaw: String
    var exitCode: Int?
    
    // Inverse relationship back to ScriptTask
    var task: ScriptTask?

    init(
        id: UUID = UUID(),
        taskName: String,
        startedAt: Date = Date(),
        duration: TimeInterval = 0,
        status: TaskStatus = .succeeded,
        task: ScriptTask? = nil
    ) {
        self.id = id
        self.taskName = taskName
        self.startedAt = startedAt
        self.duration = duration
        self.task = task

        // Encode TaskStatus enum into persistable raw values
        switch status {
        case .succeeded:
            self.statusRaw = "succeeded"
            self.exitCode = nil
        case .failed(let code):
            self.statusRaw = "failed"
            self.exitCode = code
        case .overdue:
            self.statusRaw = "overdue"
            self.exitCode = nil
        case .paused:
            self.statusRaw = "paused"
            self.exitCode = nil
        case .running:
            self.statusRaw = "running"
            self.exitCode = nil
        }
    }

    // MARK: - Computed TaskStatus Property
    var status: TaskStatus {
        get {
            switch statusRaw {
            case "succeeded": return .succeeded
            case "failed": return .failed(exitCode: exitCode ?? 1)
            case "overdue": return .overdue
            case "paused": return .paused
            case "running": return .running
            default: return .succeeded
            }
        }
        set {
            switch newValue {
            case .succeeded:
                statusRaw = "succeeded"
                exitCode = nil
            case .failed(let code):
                statusRaw = "failed"
                exitCode = code
            case .overdue:
                statusRaw = "overdue"
                exitCode = nil
            case .paused:
                statusRaw = "paused"
                exitCode = nil
            case .running:
                statusRaw = "running"
                exitCode = nil
            }
        }
    }

    // MARK: - Equatable
    static func == (lhs: RunRecord, rhs: RunRecord) -> Bool {
        lhs.id == rhs.id
    }
}
