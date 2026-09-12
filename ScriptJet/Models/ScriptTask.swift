import SwiftUI

/// Overall health of a task, driving the reliability dashboard color language.
enum TaskStatus: Equatable {
    case succeeded
    case failed(exitCode: Int)
    case overdue
    case paused
    case running

    var color: Color {
        switch self {
        case .succeeded, .running: return .statusGreen
        case .overdue, .paused:    return .statusAmber
        case .failed:               return .statusRed
        }
    }

    var label: String {
        switch self {
        case .succeeded:            return "Succeeded"
        case .running:               return "Running"
        case .overdue:               return "Overdue"
        case .paused:                 return "Paused"
        case .failed(let code):     return "Failed · exit \(code)"
        }
    }
}

/// A single scheduled automation. Mirrors what the LaunchAgent plist encodes,
/// but expressed in terms the user actually thinks in.
struct ScriptTask: Identifiable, Equatable {
    let id: UUID
    var name: String
    var scriptPath: String
    var arguments: String
    var folder: String
    var scheduleDescription: String     // "Daily · 02:00"
    var plistURL: URL?
    var nextRunDate: Date
    var lastRunDate: Date?
    var lastDuration: TimeInterval?
    var status: TaskStatus
    var lastErrorExcerpt: String?
    var isPaused: Bool
    var runs: [RunRecord]

    static func == (lhs: ScriptTask, rhs: ScriptTask) -> Bool { lhs.id == rhs.id }
}

extension ScriptTask {
    /// Syncs recent background system events directly from Unified Logging
    mutating func syncOSLogs(timeWindow: String = "1h") {
        let logs = LaunchAgentManager.fetchLaunchdLogs(for: name, timeWindow: timeWindow)
        
        if let lastLog = logs.last {
            // Update last run timestamp from system logs
            self.lastRunDate = lastLog.timestamp
            
            // Infer status based on system log messages
            if lastLog.message.contains("exited with code: 0") || lastLog.message.contains("service state: running") {
                self.status = .succeeded
            } else if lastLog.message.contains("exited abnormally") || lastLog.message.contains("respawning too quickly") {
                self.status = .failed(exitCode: 1)
                self.lastErrorExcerpt = lastLog.message
            }
        }
    }
}
