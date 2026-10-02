//
//  LaunchctlLogEntry.swift
//  LaunchBrew
//
//  Created by Yuki Suzuki on 9/11/26.
//

import Foundation

struct LaunchctlLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
}
struct LaunchdStatus {
    let label: String
    let runs: Int
    let lastExitCode: Int?
    let isSuccess: Bool
    let hasRun: Bool
    let isRunning: Bool
    let isPaused: Bool
    let pid: Int?
    let errorMessage: String?
}

extension LaunchAgentManager {
    
    enum LogPredicateType {
        case exe
        case shellScript
        case error
        case log
    }
    
    /// Queries the macOS Unified Logging system for launchd logs associated with a label or process name.
    static func fetchLaunchdLogs(for label: String, timeWindow: String = "1h", logPredicateType: LogPredicateType = .log) -> [LaunchctlLogEntry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        
        
        let predicate: String
        switch logPredicateType {
        case .shellScript:
            // Catches initial spawn events for long-running scripts/daemons
            predicate = "process == \"launchd\" AND eventMessage CONTAINS \"Successfully spawned\" AND eventMessage CONTAINS \"\(label)\""
            
        case .exe:
            // Catches process completion / inactive transitions for standalone binaries
            predicate = "process == \"launchd\" AND eventMessage CONTAINS \"service inactive:\" AND eventMessage CONTAINS \"\(label)\""
            
        case .error:
            // Catches abnormal termination, crash loops, and missing job errors
            predicate = "process == \"launchd\" AND (eventMessage CONTAINS \"exited abnormally\" OR eventMessage CONTAINS \"respawning too quickly\" OR eventMessage CONTAINS \"Could not find job\") AND eventMessage CONTAINS \"\(label)\""
            
        case .log:
            // General query for all events mentioning the job label
            predicate = "process == \"launchd\" AND eventMessage CONTAINS \"\(label)\""
        }
        
        
        process.arguments = [
            "show",
            "--predicate", predicate,
            "--last", timeWindow,
            "--style", "syslog"
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            
            return parseSyslogOutput(output)
        } catch {
            print("Failed to execute log command: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Queries launchctl print for a specific LaunchAgent and returns execution status.
    static func fetchLaunchdStatus(for label: String) -> LaunchdStatus? {
        let uid = getuid()
        let serviceTarget = "gui/\(uid)/\(label)"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", serviceTarget]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                return nil
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            
            var runs: Int?
            var lastExitCode: Int?
            var isPaused = false
            var isRunning = false
            var pid: Int?
            
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                if trimmed.hasPrefix("runs =") {
                    let parts = trimmed.components(separatedBy: "=")
                    if parts.count == 2, let count = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                        runs = count
                    }
                } else if trimmed.hasPrefix("last exit code =") {
                    let parts = trimmed.components(separatedBy: "=")
                    if parts.count == 2 {
                        let codeString = parts[1].trimmingCharacters(in: .whitespaces)
                        if codeString == "(never exited)" {
                            lastExitCode = nil
                        } else if let code = Int(codeString) {
                            lastExitCode = code
                        }
                    }
                } else if trimmed.hasPrefix("state =") {
                    let parts = trimmed.components(separatedBy: "=")
                    if parts.count == 2 {
                        let stateString = parts[1].trimmingCharacters(in: .whitespaces)
                        if stateString == "running" {
                            isRunning = true
                        } else if stateString == "disabled" {
                            isPaused = true
                        }
                    }
                } else if trimmed.hasPrefix("pid =") {
                    let parts = trimmed.components(separatedBy: "=")
                    if parts.count == 2, let processID = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                        pid = processID
                        isRunning = true // Having an active PID confirms it is running
                    }
                } else if trimmed == "disabled = true" || trimmed == "disabled = 1" {
                    isPaused = true
                }
            }
            
            let totalRuns = runs ?? 0
            let hasRun = totalRuns > 0 && lastExitCode != nil
            let hasFailed = (lastExitCode != nil && lastExitCode != 0)
            let isSuccess = (totalRuns > 0 && lastExitCode == 0)
            
            let errorMessage: String? = isPaused
                ? "The task is paused (disabled in launchd)."
                : (hasFailed ? descriptiveErrorMessage(for: lastExitCode ?? -1) : nil)
            
            return LaunchdStatus(
                label: label,
                runs: totalRuns,
                lastExitCode: lastExitCode,
                isSuccess: isSuccess,
                hasRun: hasRun,
                isRunning: isRunning,
                isPaused: isPaused,
                pid: pid,
                errorMessage: errorMessage
            )
            
        } catch {
            print("Failed to run launchctl print: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Maps POSIX and shell exit status codes to human-readable error descriptions.
    private static func descriptiveErrorMessage(for exitCode: Int) -> String {
        switch exitCode {
        case 1:
            return "Process exited with general error (Code 1)."
        case 2:
            return "Misuse of shell built-ins or invalid arguments (Code 2)."
        case 126:
            return "Command invoked cannot execute / permission denied (Code 126)."
        case 127:
            return "Executable file or command not found (Code 127)."
        case 137: // 128 + 9
            return "Process killed forcefully (SIGKILL / Code 137)."
        case 143: // 128 + 15
            return "Process terminated (SIGTERM / Code 143)."
        default:
            return "Process terminated with exit code \(exitCode)."
        }
    }
    
    
    private static func parseSyslogOutput(_ output: String) -> [LaunchctlLogEntry] {
        var entries: [LaunchctlLogEntry] = []
        let lines = output.components(separatedBy: .newlines)
        
        // Date formatter for Unified Log syslog format: "2026-09-11 15:30:20.123456-0700"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("Filtering"), !trimmed.hasPrefix("Timestamp") else {
                continue
            }
            
            // Extract date (first 19 characters) and message
            if trimmed.count > 19 {
                let dateString = String(trimmed.prefix(19))
                let timestamp = formatter.date(from: dateString) ?? Date()
                let message = String(trimmed.dropFirst(19)).trimmingCharacters(in: .whitespaces)
                
                entries.append(LaunchctlLogEntry(timestamp: timestamp, message: message))
            }
        }
        
        return entries
    }
}
