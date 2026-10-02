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
    
    /// Reads an existing launchd plist file and builds a new `ScriptTask` instance with initial OS log state.
        static func createFromPlist(executableName: String, timeWindow: String = "1h") throws -> ScriptTask {
//            let plistURL = LaunchAgentManager.getPlistURL(for: executableName)
//            let fileManager = FileManager.default
            let fileManager = FileManager.default
            let plistURL = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents/", isDirectory: true)
                .appendingPathComponent("\(executableName).plist", isDirectory: false)
            
            guard fileManager.fileExists(atPath: plistURL.path) else {
                throw TestRunnerError.plistNotFound(plistURL.path)
            }
            
            let data = try Data(contentsOf: plistURL)
            guard let plistDict = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any] else {
                throw TestRunnerError.invalidPlistFormat
            }
            
            // Extract arguments array or program string
            let programArgs = plistDict["ProgramArguments"] as? [String] ?? []
            let scriptPath = programArgs.first ?? (plistDict["Program"] as? String) ?? ""
            let extraArgs = programArgs.dropFirst().joined(separator: " ")
            
            // Extract schedule info or default
            var scheduleDesc = "Manual / Unscheduled"
            if let calendarDict = plistDict["StartCalendarInterval"] as? [String: Any] {
                let hour = calendarDict["Hour"] as? Int ?? 0
                let minute = calendarDict["Minute"] as? Int ?? 0
                scheduleDesc = String(format: "Daily · %02d:%02d", hour, minute)
            } else if let interval = plistDict["StartInterval"] as? Int {
                scheduleDesc = "Every \(interval)s"
            }
            
            // Instantiate task
            let newTask = ScriptTask(
                id: UUID(),
                name: executableName,
                scriptPath: scriptPath,
                arguments: extraArgs,
                folder: (scriptPath as NSString).deletingLastPathComponent,
                scheduleDescription: scheduleDesc,
                plistURL: plistURL,
                nextRunDate: Date().addingTimeInterval(3600),
                status: .succeeded,
                isPaused: false,
                runs: []
            )
            
            // Sync recent logs immediately
            //newTask.syncOSLogs(timeWindow: timeWindow)
            return newTask
        }
    
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
