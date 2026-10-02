//
//  LaunchAgentTestRunner.swift
//  LaunchBrew
//
//  Created by Yuki Suzuki on 9/10/26.
//

import Foundation
import SwiftData

struct ScriptTestResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let duration: TimeInterval // 👈 Measured execution time in seconds
        
        /// Formatted string helper (e.g. "4.1s" or "350ms")
        var formattedDuration: String {
            if duration < 1.0 {
                return String(format: "%.0fms", duration * 1000)
            } else {
                return String(format: "%.1fs", duration)
            }
        }
}

enum TestRunnerError: LocalizedError {
    case plistNotFound(String)
    case invalidPlistFormat
    case missingLabel
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .plistNotFound(let path):
            return "Plist file not found at: \(path)"
        case .invalidPlistFormat:
            return "Unable to parse property list data."
        case .missingLabel:
            return "The plist is missing a valid 'Label' string."
        case .executionFailed(let reason):
            return "Launchctl execution failed: \(reason)"
        }
    }
}

enum UnregisterError: LocalizedError {
    case plistNotFound(String)
    case unregisterFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .plistNotFound(let path):
            return "Plist file not found at path: \(path)"
        case .unregisterFailed(let reason):
            return "Failed to unregister LaunchAgent: \(reason)"
        }
    }
}
/// Internal launchd configuration extracted from a .plist file.
struct LaunchdPlistConfig {
    let label: String
    let stdoutPath: String
    let stderrPath: String
    let rawDict: [String: Any]
    
    // Additional fields for direct process execution
    let program: String?
    let arguments: [String]?
    let workingDirectory: String?
    let environment: [String: String]?
}

final class LaunchAgentManager {

    /// Reads an existing plist file, extracts its internal configuration, and triggers a test run via launchctl.
    static func registerWithTest(plistURL: URL) async throws -> ScriptTestResult {
        let fileManager = FileManager.default
        let currentUID = getuid()

        // 1. Extract plist configuration metadata
        let config = try extractConfig(from: plistURL)

        // 2. Clear previous test log output files
        try? fileManager.removeItem(atPath: config.stdoutPath)
        try? fileManager.removeItem(atPath: config.stderrPath)

        // 3. Unload previous service instance if currently loaded
        _ = runProcess("/bin/launchctl", args: ["bootout", "gui/\(currentUID)", plistURL.path])

        // 4. Bootstrap fresh plist into launchd
        let bootstrapStatus = runProcess("/bin/launchctl", args: ["bootstrap", "gui/\(currentUID)", plistURL.path])
        if bootstrapStatus.exitCode != 0 && !bootstrapStatus.output.isEmpty {
            print("Bootstrap notice: \(bootstrapStatus.output)")
        }

        // 5. Execute and return results using the standalone test runner
        return try await runTask(
            label: config.label,
            stdoutPath: config.stdoutPath,
            stderrPath: config.stderrPath
        )
    }
    
    /// Reads and parses a launchd plist file, returning its extracted configuration metadata.
    static func extractConfig(from plistURL: URL) throws -> LaunchdPlistConfig {
        let fileManager = FileManager.default

        // 1. Verify file existence
        guard fileManager.fileExists(atPath: plistURL.path) else {
            throw TestRunnerError.plistNotFound(plistURL.path)
        }

        // 2. Read and parse property list
        let plistData = try Data(contentsOf: plistURL)
        guard let plistDict = try PropertyListSerialization.propertyList(
            from: plistData,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw TestRunnerError.invalidPlistFormat
        }

        // 3. Extract required Label
        guard let label = plistDict["Label"] as? String, !label.isEmpty else {
            throw TestRunnerError.missingLabel
        }

        // 4. Extract stdout and stderr paths with fallback defaults
        let stdoutPath = plistDict["StandardOutPath"] as? String ?? "/tmp/\(label).out"
        let stderrPath = plistDict["StandardErrorPath"] as? String ?? "/tmp/\(label).err"

        // 5. Extract process execution keys
        let program = plistDict["Program"] as? String
        let arguments = plistDict["ProgramArguments"] as? [String]
        let workingDirectory = plistDict["WorkingDirectory"] as? String
        let environment = plistDict["EnvironmentVariables"] as? [String: String]

        return LaunchdPlistConfig(
            label: label,
            stdoutPath: stdoutPath,
            stderrPath: stderrPath,
            rawDict: plistDict,
            program: program,
            arguments: arguments,
            workingDirectory: workingDirectory,
            environment: environment
        )
    }
    
    /// Triggers an immediate test run (-k kickstart) for an already loaded service, measures execution time, and reads output logs.
    static func runTask(
        label: String,
        stdoutPath: String? = nil,
        stderrPath: String? = nil
    ) async throws -> ScriptTestResult {
        let currentUID = getuid()
        let resolvedStdoutPath = stdoutPath ?? "/tmp/\(label).out"
        let resolvedStderrPath = stderrPath ?? "/tmp/\(label).err"

        // --- Start Timing Execution ---
        let clock = ContinuousClock()
        let startTime = clock.now

        // Force immediate execution (-k kickstart)
        let kickstartStatus = runProcess("/bin/launchctl", args: ["kickstart", "-k", "gui/\(currentUID)/\(label)"])
        guard kickstartStatus.exitCode == 0 else {
            throw TestRunnerError.executionFailed(kickstartStatus.output)
        }

        // Allow time for script execution and file system buffer flushing
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // --- Stop Timing Execution ---
        let elapsedTime = startTime.duration(to: clock.now)
        let durationInSeconds = Double(elapsedTime.components.seconds) + (Double(elapsedTime.components.attoseconds) / 1e18)

        // Read logs from standard output/error file paths
        let stdoutContent = (try? String(contentsOfFile: resolvedStdoutPath, encoding: .utf8)) ?? ""
        let stderrContent = (try? String(contentsOfFile: resolvedStderrPath, encoding: .utf8)) ?? ""

        return ScriptTestResult(
            stdout: stdoutContent,
            stderr: stderrContent,
            exitCode: kickstartStatus.exitCode,
            duration: durationInSeconds
        )
    }
    /// Polls `launchctl print` until the specified label is no longer running.
    /// - Parameters:
    ///   - label: The launchd job label.
    ///   - timeout: Timeout in seconds (default is 300 seconds / 5 minutes).
    static func waitForCompletion(label: String, timeout: TimeInterval = 300) async -> Int32? {
        let startTime = Date()
        let pollInterval: UInt64 = 200_000_000 // 200 ms in nanoseconds
        
        // Give launchd a brief instant to transition into the running state after kickstart
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms grace period
        
        while Date().timeIntervalSince(startTime) < timeout {
            guard let status = fetchLaunchdStatus(for: label) else {
                // Service not found or no longer loaded in launchd
                return nil
            }
            
            // Return exit code once service state transitions out of running
            if !status.isRunning {
                return status.lastExitCode.map { Int32($0) }
            }
            
            try? await Task.sleep(nanoseconds: pollInterval)
        }
        
        return nil // Timed out after `timeout` seconds
    }
    
    static func runDirectly(
        program: String?,
        arguments: [String]?,
        workingDirectory: String? = nil,
        environment: [String: String]? = nil,
        stdoutPath: String? = nil,
        stderrPath: String? = nil
    ) async throws -> (exitCode: Int32, duration: TimeInterval) {
        let start = Date()
        
        // Resolve target executable and args
        guard let execPath = program ?? arguments?.first else {
            throw NSError(domain: "LaunchAgentManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "No executable or arguments found in plist."])
        }
        
        let processArgs = program != nil ? (arguments ?? []) : Array(arguments?.dropFirst() ?? [])
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: execPath)
        process.arguments = processArgs
        
        if let directory = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: directory)
        }
        
        if let env = environment {
            var currentEnv = ProcessInfo.processInfo.environment
            currentEnv.merge(env) { _, new in new }
            process.environment = currentEnv
        }
        
        // Wire up stdout / stderr redirection if log files are specified
        if let stdoutPath = stdoutPath, let stdoutURL = URL(string: stdoutPath) ?? URL(fileURLWithPath: stdoutPath) as URL? {
            if !FileManager.default.fileExists(atPath: stdoutURL.path) {
                FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
            }
            process.standardOutput = try? FileHandle(forWritingTo: stdoutURL)
        }
        
        if let stderrPath = stderrPath, let stderrURL = URL(string: stderrPath) ?? URL(fileURLWithPath: stderrPath) as URL? {
            if !FileManager.default.fileExists(atPath: stderrURL.path) {
                FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
            }
            process.standardError = try? FileHandle(forWritingTo: stderrURL)
        }
        
        try process.run()
        process.waitUntilExit()
        
        let duration = Date().timeIntervalSince(start)
        return (process.terminationStatus, duration)
    }
    
    /// Checks whether a LaunchAgent label is currently loaded/registered in launchd.
    /// - Parameter label: The reverse-domain label of the target job (e.g., "com.yuzu.myagent").
    /// - Returns: `true` if the job is active/registered in launchd, `false` otherwise.
    static func isLoaded(label: String) -> Bool {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        // Target the current user's GUI domain (gui/<uid>) or launchctl list directly
        let uid = getuid()
        process.arguments = ["print", "gui/\(uid)/\(label)"]
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            // Exit code 0 means the service is loaded and recognized by launchd
            return process.terminationStatus == 0
        } catch {
            print("Failed to check launchctl status for \(label): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Forcefully stops a running launchd service by sending a SIGKILL signal.
    /// Works for both scheduled executions and manual `kickstart` runs.
    @discardableResult
    static func stopTask(label: String, signal: Int32 = 9) -> Bool {
        let currentUID = getuid()
        let targetService = "gui/\(currentUID)/\(label)"
        
        // launchctl kill <signal> <target-service>
        let result = runProcess("/bin/launchctl", args: ["kill", "\(signal)", targetService])
        
        if result.exitCode == 0 {
            print("Successfully sent signal \(signal) to service: \(label)")
            return true
        } else {
            print("Failed to stop service \(label): \(result.output)")
            return false
        }
    }
    
    /// Registers/schedules a launchd agent from its plist URL without performing an immediate test execution.
    /// - Parameter plistURL: Local URL pointing to the .plist file in ~/Library/LaunchAgents/
    /// - Returns: `true` if the agent was successfully bootstrapped into launchd.
    @discardableResult
    static func register(plistURL: URL) throws -> Bool {
        let fileManager = FileManager.default
        let currentUID = getuid()

        // 1. Verify plist existence
        guard fileManager.fileExists(atPath: plistURL.path) else {
            throw TestRunnerError.plistNotFound(plistURL.path)
        }

        // 2. Read and parse the plist contents
        let plistData = try Data(contentsOf: plistURL)
        guard let plistDict = try PropertyListSerialization.propertyList(
            from: plistData,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw TestRunnerError.invalidPlistFormat
        }

        // 3. Extract required Label
        guard let label = plistDict["Label"] as? String, !label.isEmpty else {
            throw TestRunnerError.missingLabel
        }

        // 4. Unload previous service instance if currently loaded in launchd
        _ = runProcess("/bin/launchctl", args: ["bootout", "gui/\(currentUID)", plistURL.path])

        // 5. Bootstrap fresh plist into launchd (registers the schedule)
        let bootstrapStatus = runProcess("/bin/launchctl", args: ["bootstrap", "gui/\(currentUID)", plistURL.path])
        
        if bootstrapStatus.exitCode != 0 {
            // If bootstrap failed and output exists, throw or log warning
            if !bootstrapStatus.output.isEmpty {
                print("Bootstrap error for \(label): \(bootstrapStatus.output)")
            }
            throw TestRunnerError.executionFailed(bootstrapStatus.output)
        }

        print("Successfully scheduled \(label) without running a test.")
        return true
    }
    
    /// Reloads a launchd agent by unregistering the existing service and re-registering it.
    @discardableResult
    static func reloadLaunchdAgent(plistURL: URL) throws -> Bool {
        // 1. Unregister existing service instance (keeping the plist file on disk)
        _ = try unregister(plistURL: plistURL, deletePlistFile: false)
        
        // 2. Bootstrap the updated plist back into launchd
        return try register(plistURL: plistURL)
    }
    
    /// Unregisters a LaunchAgent service from launchd using bootout.
    /// - Parameters:
    ///   - plistURL: The URL of the .plist file in ~/Library/LaunchAgents/
    ///   - deletePlistFile: If true, deletes the .plist file from disk after unregistering. Default is false.
    @discardableResult
    static func unregister(plistURL: URL, deletePlistFile: Bool = false) throws -> Bool {
        let fileManager = FileManager.default
        let currentUID = getuid()
        
        // 1. Verify plist existence before attempting bootout
        guard fileManager.fileExists(atPath: plistURL.path) else {
            throw UnregisterError.plistNotFound(plistURL.path)
        }
        
        // 2. Run launchctl bootout gui/<UID> <plistURL>
        let result = runProcess(
            "/bin/launchctl",
            args: ["bootout", "gui/\(currentUID)", plistURL.path]
        )
        
        // Exit code 0 (success) or 3 (ESRCH / not running) are both valid success states
        let isBootoutSuccessful = (result.exitCode == 0 || result.exitCode == 3)
        
        if !isBootoutSuccessful && !result.output.contains("No such process") {
            print("Bootout notice: \(result.output)")
        }
        
        // 3. Optionally remove the .plist file from ~/Library/LaunchAgents/
        var isFileDeleted = true
        if deletePlistFile {
            do {
                try fileManager.removeItem(at: plistURL)
                print("Successfully deleted plist at: \(plistURL.path)")
            } catch {
                isFileDeleted = false
                print("Warning: Failed to delete plist file: \(error.localizedDescription)")
            }
        }
        
        // Return true only if launchctl bootout succeeded and file deletion (if requested) succeeded
        return isBootoutSuccessful && isFileDeleted
    }
    
    
    /// Syncs real-time launchd status and creates new RunRecord entries when runs increment.
//    @MainActor
//    static func syncExecutionHistory(for task: ScriptTask, modelContext: ModelContext){
//        
//        guard let launchStatus = fetchLaunchdStatus(for: task.name) else { return }
//        
//        let latestLogs = fetchLaunchdLogs(for: task.name, timeWindow: "1m", logPredicateType: .log)
//                
//        // 1. Determine the highest run number recorded so far
//        let lastRecordedRun = task.runs.count
//        
//        
//        if launchStatus.runs > lastRecordedRun {
//            
//            let newRecordCount = launchStatus.runs - lastRecordedRun
//            
//            
//            for _ in 1...newRecordCount {
//                
//                let startedAt = latestLogs.last?.timestamp ?? Date()
//                
//                // Determine the task status cleanly without overwriting
//                let taskStatus: TaskStatus
//                if launchStatus.isPaused {
//                    taskStatus = .paused
//                } else if !launchStatus.isSuccess {
//                    taskStatus = .failed(exitCode: launchStatus.lastExitCode ?? 1)
//                } else {
//                    taskStatus = .succeeded
//                }
//                        
//                
//                let newRecord = RunRecord(taskName: task.name,
//                                          startedAt: startedAt,
//                                          status: taskStatus,
//                                          task: task)
//                
//                task.runs.append(newRecord)
//                
//            }
//            
//            try? modelContext.save()
//        }
//    }
    @MainActor
    static func syncExecutionHistory(for task: ScriptTask, modelContext: ModelContext) {
        // ✋ Skip background sync if runNow is actively controlling and tracking execution duration
        guard !task.isManuallyExecuting else { return }
        
        guard let launchStatus = fetchLaunchdStatus(for: task.name) else { return }
        let latestLogs = fetchLaunchdLogs(for: task.name, timeWindow: "1m", logPredicateType: .log)
        let logTimestamp = latestLogs.last?.timestamp ?? Date()

        // Find the latest record if one exists
        let latestRecord = task.runs.last

        // 1. Task is actively running
        if launchStatus.isRunning {
            if let existing = latestRecord, existing.status == .running {
                // Already tracking this active run
                return
            }
            
            // New run started: create an active record
            let runningRecord = RunRecord(
                taskName: task.name,
                startedAt: logTimestamp,
                status: .running,
                task: task
            )
            task.runs.append(runningRecord)
            try? modelContext.save()
            return
        }

        // 2. Determine final status when not running
        let finalStatus: TaskStatus
        if launchStatus.isPaused {
            finalStatus = .paused
        } else if launchStatus.hasRun && (launchStatus.lastExitCode ?? 0) != 0 {
            finalStatus = .failed(exitCode: launchStatus.lastExitCode ?? 1)
        } else if launchStatus.isSuccess {
            finalStatus = .succeeded
        } else {
            return // Unhandled or initial idle state
        }

        // 3. Task completed: update existing running record or create a finished record
        if let existing = latestRecord, existing.status == .running {
            // Overwrite the in-progress record with final outcome
            existing.status = finalStatus
        } else if launchStatus.runs > task.runs.count {
            // Catch up if new runs finished between sync intervals
            let newRecord = RunRecord(
                taskName: task.name,
                startedAt: logTimestamp,
                status: finalStatus,
                task: task
            )
            task.runs.append(newRecord)
        }

        try? modelContext.save()
    }

    /// Helper method to run terminal commands synchronously
    private static func runProcess(_ launchPath: String, args: [String]) -> (exitCode: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, output)
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}
