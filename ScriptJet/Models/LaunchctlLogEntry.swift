//
//  LaunchctlLogEntry.swift
//  ScriptJet
//
//  Created by Yuki Suzuki on 9/11/26.
//

import Foundation

struct LaunchctlLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
}

extension LaunchAgentManager {
    
    /// Queries the macOS Unified Logging system for launchd logs associated with a label or process name.
    static func fetchLaunchdLogs(for label: String, timeWindow: String = "1h") -> [LaunchctlLogEntry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        
        // Predicate matching process launchd and containing your label
        let predicate = "process == \"launchd\" AND eventMessage CONTAINS \"\(label)\""
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
