import Foundation
import SwiftUI
import SwiftData

// MARK: - Task Status
/// Overall health of a task, driving the reliability dashboard color language.
enum TaskStatus: Equatable {
    case succeeded
    case failed(exitCode: Int)
    case overdue
    case paused
    case running

    var color: Color {
        switch self {
        case .succeeded: return .statusGreen
        case .running: return .statusOrange
        case .overdue, .paused:    return .statusAmber
        case .failed:              return .statusRed
        }
    }

    var label: String {
        switch self {
        case .succeeded:           return "Succeeded"
        case .running:             return "Running"
        case .overdue:             return "Overdue"
        case .paused:              return "Paused"
        case .failed(let code):    return "Failed · exit \(code)"
        }
    }
}

// MARK: - SwiftData Model
@Model
final class ScriptTask: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var scriptPath: String
    var interpreterPath: String?       // e.g. "/bin/zsh" or "/usr/bin/python3" if scriptPath is a script
    var kindRaw: String                // "shellScript", "unixExecutable", "macho"
    var arguments: String              // Command line parameters joined as space-separated string
    var workingDirectory: String       // Plist 'WorkingDirectory' or parent folder of script
    var scheduleDescription: String    // "Daily · 02:00", "Every 300s"
    var plistURL: URL?
    var nextRunDate: Date?
    var lastRunDate: Date?
    var lastDuration: TimeInterval?
    
    // TaskStatus Persistence
    var statusRaw: String              // "succeeded", "failed", "overdue", "paused", "running"
    var exitCode: Int?                 // Associated value for .failed
    
    var lastErrorExcerpt: String?
    var isPaused: Bool
    
    @Relationship(deleteRule: .cascade)
    var runs: [RunRecord] = []
    
    /// Transient flag to prevent background timer sync collisions during manual `runNow`
    @Transient var isManuallyExecuting: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        scriptPath: String,
        interpreterPath: String? = nil,
        kindRaw: String = "unixExecutable",
        arguments: String = "",
        workingDirectory: String = "",
        scheduleDescription: String = "Manual",
        plistURL: URL? = nil,
        nextRunDate: Date? = nil,
        lastRunDate: Date? = nil,
        lastDuration: TimeInterval? = nil,
        status: TaskStatus = .succeeded,
        lastErrorExcerpt: String? = nil,
        isPaused: Bool = false,
        runs: [RunRecord] = []
    ) {
        self.id = id
        self.name = name
        self.scriptPath = scriptPath
        self.interpreterPath = interpreterPath
        self.kindRaw = kindRaw
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.scheduleDescription = scheduleDescription
        self.plistURL = plistURL
        self.nextRunDate = nextRunDate
        self.lastRunDate = lastRunDate
        self.lastDuration = lastDuration
        self.lastErrorExcerpt = lastErrorExcerpt
        self.isPaused = isPaused
        self.runs = runs
        
        // Encode initial status
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
}

// MARK: - Computed Properties & Helpers
extension ScriptTask {
    /// Strongly-typed wrapper around statusRaw and exitCode
    var status: TaskStatus {
        get {
            switch statusRaw {
            case "succeeded": return .succeeded
            case "failed":    return .failed(exitCode: exitCode ?? 1)
            case "overdue":   return .overdue
            case "paused":    return .paused
            case "running":   return .running
            default:          return .succeeded
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
}

// MARK: - Plist Import & Syncing
extension ScriptTask {
    
    /// Reads an existing launchd plist file and builds a new `ScriptTask` instance.
    static func createFromPlist(executableName: String) throws -> ScriptTask {
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
        
        // 1. Extract arguments & determine if there is an interpreter
        let programArgs = plistDict["ProgramArguments"] as? [String] ?? []
        let rawProgram = plistDict["Program"] as? String ?? programArgs.first ?? ""
        
        var scriptPath = rawProgram
        var interpreterPath: String? = nil
        var kindRaw = "unixExecutable"
        var remainingArgs: [String] = []
        
        // Detect shell interpreters passed in ProgramArguments (e.g., ["/bin/zsh", "/path/to/script.sh", "arg1"])
        let knownInterpreters = ["/bin/zsh", "/bin/bash", "/bin/sh", "/usr/bin/python3", "/usr/local/bin/python3", "/usr/bin/perl", "/usr/bin/ruby"]
        
        if let firstArg = programArgs.first, knownInterpreters.contains(firstArg) {
            interpreterPath = firstArg
            kindRaw = "shellScript"
            if programArgs.count > 1 {
                scriptPath = programArgs[1]
                remainingArgs = Array(programArgs.dropFirst(2))
            }
        } else if programArgs.count > 1 {
            scriptPath = programArgs[0]
            remainingArgs = Array(programArgs.dropFirst(1))
        }
        
        let argumentsString = remainingArgs.joined(separator: " ")
        
        // 2. Extract WorkingDirectory or default to script folder
        let parsedWorkingDir = plistDict["WorkingDirectory"] as? String
        let folder = parsedWorkingDir ?? (scriptPath as NSString).deletingLastPathComponent
        
        // 3. Extract Schedule Description
        var scheduleDesc = "Manual / Unscheduled"

        if let calendarArray = plistDict["StartCalendarInterval"] as? [[String: Any]] {
            // Case A: Array of dictionaries (Selected Days)
            scheduleDesc = parseCalendarDicts(calendarArray)
            
        } else if let calendarDict = plistDict["StartCalendarInterval"] as? [String: Any] {
            // Case B: Single dictionary (Daily schedule)
            scheduleDesc = parseCalendarDicts([calendarDict])
            
        } else if let interval = (plistDict["StartInterval"] as? NSNumber)?.intValue ?? (plistDict["StartInterval"] as? Int) {
            // Case C: Repeat Interval
            if interval >= 3600 {
                scheduleDesc = "Every \(interval / 3600)h"
            } else if interval >= 60 {
                scheduleDesc = "Every \(interval / 60)m"
            } else {
                scheduleDesc = "Every \(interval)s"
            }
        }
        
        // 4. Instantiate task
        let calculatedNextRun = computeNextRunDate(from: plistDict)
        
        let newTask = ScriptTask(
            id: UUID(),
            name: executableName,
            scriptPath: scriptPath,
            interpreterPath: interpreterPath,
            kindRaw: kindRaw,
            arguments: argumentsString,
            workingDirectory: folder,
            scheduleDescription: scheduleDesc,
            plistURL: plistURL,
            nextRunDate: calculatedNextRun,
            status: .succeeded,
            isPaused: false,
            runs: []
        )
        
        return newTask
    }
    func updateScheduleDesc(_ plistDict: [String: Any], modelContext: ModelContext) -> Bool {
        // 3. Extract Schedule Description
        var scheduleDesc = "Manual / Unscheduled"

        if let calendarArray = plistDict["StartCalendarInterval"] as? [[String: Any]] {
            // Case A: Array of dictionaries (Selected Days)
            scheduleDesc = parseCalendarDicts(calendarArray)
            
        } else if let calendarDict = plistDict["StartCalendarInterval"] as? [String: Any] {
            // Case B: Single dictionary (Daily schedule)
            scheduleDesc = parseCalendarDicts([calendarDict])
            
        } else if let interval = (plistDict["StartInterval"] as? NSNumber)?.intValue ?? (plistDict["StartInterval"] as? Int) {
            // Case C: Repeat Interval
            if interval >= 3600 {
                scheduleDesc = "Every \(interval / 3600)h"
            } else if interval >= 60 {
                scheduleDesc = "Every \(interval / 60)m"
            } else {
                scheduleDesc = "Every \(interval)s"
            }
        }
        
        // Assign the description to your model property
        self.scheduleDescription = scheduleDesc

        // Save and return true if successful, false if it throws
        do {
            try modelContext.save()
            return true
        } catch {
            print("Failed to save schedule description: \(error.localizedDescription)")
            return false
        }
    }
    private func parseCalendarDicts(_ dicts: [[String: Any]]) -> String {
        guard !dicts.isEmpty else { return "Scheduled" }
        
        let first = dicts[0]
        let hour = (first["Hour"] as? NSNumber)?.intValue ?? 0
        let minute = (first["Minute"] as? NSNumber)?.intValue ?? 0
        let timeStr = String(format: "%02d:%02d", hour, minute)
        
        // Collect all weekday numbers present
        let weekdays = dicts.compactMap { dict -> Int? in
            (dict["Weekday"] as? NSNumber)?.intValue ?? (dict["Weekday"] as? Int)
        }.sorted()
        
        // Map launchd weekday values (0=Sun, 1=Mon, ..., 6=Sat) to short names
        let dayMap: [Int: String] = [
            0: "Sun", 1: "Mon", 2: "Tue", 3: "Wed", 4: "Thu", 5: "Fri", 6: "Sat", 7: "Sun"
        ]
        
        if weekdays.count == 7 {
            return "Daily · \(timeStr)"
        } else if weekdays.count > 0 {
            let dayNames = weekdays.compactMap { dayMap[$0] }.joined(separator: ", ")
            return "\(dayNames) · \(timeStr)"
        }
        
        return "Daily · \(timeStr)"
    }
    
    private static func parseCalendarDicts(_ dicts: [[String: Any]]) -> String {
        guard !dicts.isEmpty else { return "Scheduled" }
        
        let first = dicts[0]
        let hour = (first["Hour"] as? NSNumber)?.intValue ?? 0
        let minute = (first["Minute"] as? NSNumber)?.intValue ?? 0
        let timeStr = String(format: "%02d:%02d", hour, minute)
        
        // Collect all weekday numbers present
        let weekdays = dicts.compactMap { dict -> Int? in
            (dict["Weekday"] as? NSNumber)?.intValue ?? (dict["Weekday"] as? Int)
        }.sorted()
        
        // Map launchd weekday values (0=Sun, 1=Mon, ..., 6=Sat) to short names
        let dayMap: [Int: String] = [
            0: "Sun", 1: "Mon", 2: "Tue", 3: "Wed", 4: "Thu", 5: "Fri", 6: "Sat", 7: "Sun"
        ]
        
        if weekdays.count == 7 {
            return "Daily · \(timeStr)"
        } else if weekdays.count > 0 {
            let dayNames = weekdays.compactMap { dayMap[$0] }.joined(separator: ", ")
            return "\(dayNames) · \(timeStr)"
        }
        
        return "Daily · \(timeStr)"
    }
    /// Calculates the next expected fire date based on launchd plist scheduling properties.
    private static func computeNextRunDate(from plistDict: [String: Any], now: Date = Date()) -> Date? {
        let calendar = Calendar.current

        // 1. Handle StartCalendarInterval (Array or Single Dict)
        let calendarDicts: [[String: Any]] = {
            if let arr = plistDict["StartCalendarInterval"] as? [[String: Any]] {
                return arr
            } else if let dict = plistDict["StartCalendarInterval"] as? [String: Any] {
                return [dict]
            }
            return []
        }()

        if !calendarDicts.isEmpty {
            var candidateDates: [Date] = []

            for dict in calendarDicts {
                let hour = (dict["Hour"] as? NSNumber)?.intValue ?? 0
                let minute = (dict["Minute"] as? NSNumber)?.intValue ?? 0
                let weekday = (dict["Weekday"] as? NSNumber)?.intValue ?? (dict["Weekday"] as? Int)

                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                components.second = 0

                if let weekday = weekday {
                    // Convert launchd weekday (0=Sun, 1=Mon, ..., 6=Sat, 7=Sun) to Calendar weekday (1=Sun, 2=Mon, ..., 7=Sat)
                    let targetWeekday = (weekday % 7) + 1
                    components.weekday = targetWeekday

                    if let nextDate = calendar.nextDate(
                        after: now,
                        matching: components,
                        matchingPolicy: .nextTime,
                        direction: .forward
                    ) {
                        candidateDates.append(nextDate)
                    }
                } else {
                    // Daily schedule at specified hour/minute
                    if let nextDate = calendar.nextDate(
                        after: now,
                        matching: components,
                        matchingPolicy: .nextTime,
                        direction: .forward
                    ) {
                        candidateDates.append(nextDate)
                    }
                }
            }

            // Return the earliest candidate run date found
            if let nextUpcomingDate = candidateDates.min() {
                return nextUpcomingDate
            }
        }

//        // 2. Handle StartInterval (Repeating interval in seconds)
//        if let lastRunDate = getLastRunDateFromPlist(plistDict){
//            return lastRunDate
//        }

        // 3. Fallback for manual/unscheduled tasks: distant future or 24 hours out
        return nil
    }
    
    /// Reads `StandardOutPath` and `StandardErrorPath` from the plist dictionary and returns
    /// the most recent modification date between the two log files.
    private static func getLastRunDateFromPlist(_ plistDict: [String: Any]) -> Date? {
        let fileManager = FileManager.default
        
        // Extract paths from plist or fallback to standard /tmp defaults
        let label = plistDict["Label"] as? String ?? ""
        let stdoutPath = plistDict["StandardOutPath"] as? String ?? "/tmp/\(label).out"
        let stderrPath = plistDict["StandardErrorPath"] as? String ?? "/tmp/\(label).err"
        
        var dates: [Date] = []
        
        // Check stdout file modification date
        if fileManager.fileExists(atPath: stdoutPath),
           let stdoutAttrs = try? fileManager.attributesOfItem(atPath: stdoutPath),
           let stdoutDate = stdoutAttrs[.modificationDate] as? Date {
            dates.append(stdoutDate)
        }
        
        // Check stderr file modification date
        if fileManager.fileExists(atPath: stderrPath),
           let stderrAttrs = try? fileManager.attributesOfItem(atPath: stderrPath),
           let stderrDate = stderrAttrs[.modificationDate] as? Date {
            dates.append(stderrDate)
        }
        
        // Return whichever file was updated most recently
        return dates.max()
    }

    /// Syncs recent background system events directly from Unified Logging
    func syncOSLogs(timeWindow: String = "1h", in context: ModelContext? = nil) {
        
        let predicateType: LaunchAgentManager.LogPredicateType
        if self.kindRaw.elementsEqual("unixExecutable") {
            predicateType = .exe
        } else if self.kindRaw.elementsEqual("shellScript") {
            predicateType = .shellScript
        } else {
            predicateType = .log // Default fallback for generic jobs
        }
        
        
        let logs = LaunchAgentManager.fetchLaunchdLogs(for: name, timeWindow: timeWindow, logPredicateType: predicateType)
        
        // 2. Check if the LaunchAgent is registered in launchd
        let isRegistered = LaunchAgentManager.isLoaded(label: self.name)

        if isRegistered, let plistURL = self.plistURL, let data = try? Data(contentsOf: plistURL) {
            
                if let plistDict = try? PropertyListSerialization.propertyList(
                    from: data,
                    options: [],
                    format: nil
                ) as? [String: Any] {
                    // 4. Instantiate task
                    let calculatedNextRun = ScriptTask.computeNextRunDate(from: plistDict)
                    self.nextRunDate = calculatedNextRun
                }
        }
//        
//        // 4. Instantiate task
//        let calculatedNextRun = computeNextRunDate(from: plistDict)
        
        if let lastLog = logs.last {
            self.lastRunDate = lastLog.timestamp
            
            if lastLog.message.contains("exited with code: 0") || lastLog.message.contains("service state: running") {
                self.status = .succeeded
            } else if lastLog.message.contains("exited abnormally") || lastLog.message.contains("respawning too quickly") {
                self.status = .failed(exitCode: 1)
                self.lastErrorExcerpt = lastLog.message
            }
        }
        
        if let logStatus = LaunchAgentManager.fetchLaunchdStatus(for: self.name) {
            if logStatus.isPaused {
                self.status = .paused
                self.lastErrorExcerpt = logStatus.errorMessage ?? ""
            } else if logStatus.isRunning {
                // Active execution takes priority over previous run exit codes
                self.status = .running
                self.lastErrorExcerpt = nil
            } else if logStatus.hasRun && (logStatus.lastExitCode ?? 0) != 0 {
                // Only mark as failed if it actually completed and returned a non-zero exit code
                self.status = .failed(exitCode: logStatus.lastExitCode ?? -1)
                self.lastErrorExcerpt = logStatus.errorMessage ?? ""
            } else if logStatus.isSuccess {
                self.status = .succeeded
            }
        }
        
        
        // print("Trying to update the logs.")
        
        try? context?.save()
    }
    
    func readPListContent() throws -> [String: Any] {
        if let plistURL = self.plistURL, let data = try? Data(contentsOf: plistURL) {
            
            let plistDict = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any]

            return plistDict ?? [String: Any]()
        }
        
        return [String: Any]()
    }
    
    func updatePlist(plistDict: [String: Any]) throws -> Bool {
        guard let plistURL = self.plistURL else {
            throw TestRunnerError.plistNotFound("Missing plistURL for task: \(name)")
        }
        
        // Validate property list data types before serialization
        guard PropertyListSerialization.propertyList(plistDict, isValidFor: .xml) else {
            throw TestRunnerError.invalidPlistFormat
        }
        
        // 1. Serialize dictionary to XML plist data
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plistDict,
            format: .xml,
            options: 0
        )
        
        // 2. Write safely to disk
        try plistData.write(to: plistURL, options: .atomic)
        
        return true
    }
    func reloadLaunchdAgent() throws -> Bool {
        guard let plistURL = self.plistURL,
              FileManager.default.fileExists(atPath: plistURL.path) else {
            throw TestRunnerError.plistNotFound(self.plistURL?.path ?? name)
        }
        
        return try LaunchAgentManager.reloadLaunchdAgent(plistURL: plistURL)
    }
    
    
    /// Unregisters the agent from launchd (if present) and ALWAYS deletes the task from SwiftData.
    /// - Parameter context: The SwiftData `ModelContext` used to delete the task.
    /// - Returns: `true` if launchd successfully unregistered a plist file, `false` if no plist was found or unregistration failed.
    @discardableResult
    func unregisterAndDelete(in context: ModelContext) -> Bool {
        var isUnregistered = false
        
        // 1. Resolve plist URL (either stored or inferred by name)
        let targetPlistURL: URL = plistURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/", isDirectory: true)
            .appendingPathComponent("\(name).plist", isDirectory: false)
        
        // 2. Attempt unregistration from launchd if file exists
        if FileManager.default.fileExists(atPath: targetPlistURL.path) {
            do {
                isUnregistered = try LaunchAgentManager.unregister(
                    plistURL: targetPlistURL,
                    deletePlistFile: true
                )
            } catch {
                print("Warning: Could not unregister launchd agent at \(targetPlistURL.path): \(error.localizedDescription)")
            }
        }
        
        // 3. ALWAYS remove the task from SwiftData
        context.delete(self)
        
        // 4. Save SwiftData changes
        do {
            try context.save()
            // print("Successfully deleted ScriptTask '\(name)' from SwiftData.")
        } catch {
            print("Failed to save context after deleting ScriptTask: \(error.localizedDescription)")
        }
        
        return isUnregistered
    }
    
    @discardableResult
    func unregister(in context: ModelContext) -> Bool {
        var isUnScheduled = false
        
        // 1. Resolve plist URL (either stored or inferred by name)
        let targetPlistURL: URL = plistURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/", isDirectory: true)
            .appendingPathComponent("\(name).plist", isDirectory: false)
        
        // 2. Attempt unregistration from launchd if file exists
        if FileManager.default.fileExists(atPath: targetPlistURL.path) {
            do {
                isUnScheduled = try LaunchAgentManager.unregister(
                    plistURL: targetPlistURL,
                    deletePlistFile: false
                )
            } catch {
                print("Warning: Could not unregister launchd agent at \(targetPlistURL.path): \(error.localizedDescription)")
            }
        }
        
        // 3. Reset the task from SwiftData
        self.lastDuration = nil
        self.scheduleDescription = "Not scheduled"
        self.nextRunDate = nil
        
        
        // 4. Save SwiftData changes
        do {
            try context.save()
            // print("Successfully reset ScriptTask '\(name)' from SwiftData.")
        } catch {
            print("Failed to update context after unscheduling ScriptTask: \(error.localizedDescription)")
        }
        
        return isUnScheduled
    }
    
    /// Toggles the paused state and persists to SwiftData
    func togglePause(in context: ModelContext) {
        self.isPaused.toggle()
        try? context.save()
    }

    /// Enqueues an immediate execution via Launchd / Scheduler
    /// Triggers immediate execution via launchctl kickstart and updates task status/logs.
    @MainActor
    func runNow(in context: ModelContext? = nil) async {
        let targetContext = context ?? self.modelContext
        
        guard let plistURL = self.plistURL else {
            // print("Cannot run task: plistURL is missing.")
            return
        }
        
        // Set in-flight flag
        self.isManuallyExecuting = true
        defer {
            self.isManuallyExecuting = false
        }
        
        do {
            // 1. Extract metadata (Synchronous throw)
            let config = try LaunchAgentManager.extractConfig(from: plistURL)
            
            // 2. Check if the LaunchAgent is registered in launchd
            let isRegistered = LaunchAgentManager.isLoaded(label: config.label)

            if isRegistered {
                // Managed run via launchd kickstart
                let startDate = Date()
                
                // Managed run via launchd kickstart
                let result = try await LaunchAgentManager.runTask(
                    label: config.label,
                    stdoutPath: config.stdoutPath,
                    stderrPath: config.stderrPath
                )
                
                // 2. Poll until the task finishes executing
                let exitCode = await LaunchAgentManager.waitForCompletion(label: config.label) ?? result.exitCode
                let duration = Date().timeIntervalSince(startDate)
                            
                let finalStatus: TaskStatus = exitCode == 0
                    ? .succeeded
                    : .failed(exitCode: Int(exitCode))
                
                // 3. Persist run metadata
                self.lastRunDate = startDate
                self.status = finalStatus
                
                let runRecord = RunRecord(
                    taskName: self.name,
                    startedAt: startDate,
                    duration: duration,
                    status: finalStatus,
                    task: self
                )
                self.runs.append(runRecord)
                
                if let targetContext {
                    try? targetContext.save()
                }
                
                self.syncOSLogs(in: targetContext)
            } else {
                // Unscheduled / Direct execution via Process
                    let startDate = Date()
                    
                    // Map process exit code to TaskStatus
                    let result = try await LaunchAgentManager.runDirectly(
                        program: config.program,
                        arguments: config.arguments,
                        workingDirectory: config.workingDirectory,
                        environment: config.environment,
                        stdoutPath: config.stdoutPath,
                        stderrPath: config.stderrPath
                    )
                    let duration = Date().timeIntervalSince(startDate)
                    
                    let finalStatus: TaskStatus = result.exitCode == 0
                        ? .succeeded
                        : .failed(exitCode: Int(result.exitCode))
                    
                    // Update SwiftData model state on the MainActor
                    self.lastRunDate = startDate
                    self.status = finalStatus
                    
                    let runRecord = RunRecord(
                        taskName: self.name,
                        startedAt: startDate,
                        duration: duration,
                        status: finalStatus,
                        task: self
                    )
                    self.runs.append(runRecord)
                    
                    if let targetContext {
                        try? targetContext.save()
                    }
                    // print("Direct run finished with exit code: \(result.exitCode), duration: \(result.duration)s")
            }
        } catch {
            print("Failed to run task immediately: \(error.localizedDescription)")
        }
    }
    
    /// Stops the currently running instance of this task and updates its status.
    func stopNow(in context: ModelContext? = nil) async {
        guard let plistURL = self.plistURL else {
            // print("Cannot stop task: plistURL is missing.")
            return
        }

        do {
            // Extract the job label safely
            let config = try await MainActor.run {
                try LaunchAgentManager.extractConfig(from: plistURL)
            }

            // Kill the active process (SIGKILL = 9)
            let success = await LaunchAgentManager.stopTask(label: config.label, signal: 9)

            if success {
                self.status = .failed(exitCode: -1) // -1 indicates terminated/cancelled
                self.lastErrorExcerpt = "Task was manually stopped by user."
                try? context?.save()
            }
        } catch {
            print("Failed to extract config for stopping task: \(error.localizedDescription)")
        }
    }
}

extension ScriptTask {
    /// Opens the directory containing the shell script and selects the file in Finder.
        func revealScriptInFinder() {
            guard !self.scriptPath.isEmpty else { return }
            let url = URL(fileURLWithPath: scriptPath)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }

        /// Opens `~/Library/LaunchAgents/` and selects the task's plist file in Finder.
        func revealPlistInFinder() {
            guard let plistURL = self.plistURL else { return }
            NSWorkspace.shared.activateFileViewerSelecting([plistURL])
        }

        /// Opens `/tmp/` (or custom log directory) and selects the STDOUT/STDERR log files in Finder.
        func revealLogsInFinder() async {
            guard let plistURL = self.plistURL else { return }
                
                do {
                    // 1. Extract metadata
                    let config = try await MainActor.run {
                        try LaunchAgentManager.extractConfig(from: plistURL)
                    }
                    
                    // 2. Get the directory containing the stdout log file
                    let logFolderURL = URL(fileURLWithPath: config.stdoutPath).deletingLastPathComponent()
                    
                    // 3. Open the containing directory in Finder
                    NSWorkspace.shared.open(logFolderURL)
                    
                } catch {
                    // Fallback: Open /tmp if plist parsing fails
                    let fallbackURL = URL(fileURLWithPath: "/tmp")
                    NSWorkspace.shared.open(fallbackURL)
                }
        }
}





extension Sequence where Element == ScriptTask {
    
    var successCount: Int {
        filter { if case .succeeded = $0.status { return true} else { return false} }.count
    }
    var failingCount: Int {
        filter { if case .failed = $0.status { return true } else { return false } }.count
    }

    var dueSoonCount: Int {
        filter { $0.status == .overdue }.count
    }

    var pausedCount: Int {
        filter { $0.isPaused }.count
    }
}

