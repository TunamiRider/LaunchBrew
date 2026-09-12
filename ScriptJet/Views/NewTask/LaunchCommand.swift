//
//  LaunchCommand.swift
//  ScriptJet
//
//  Created by Yuki Suzuki on 9/7/26.
//

import Foundation
import SwiftUI

struct LaunchCommand: Hashable {
    var executableURL: URL
    var kind: Kind
    var arguments: [String]
    
    
    var startTime:Date?
    var hour: Int?
    var minute: Int?
    var isRepeating: Bool?
    var intervalMinutes: Int?
    var selectedDays: Set<Weekday>?

    enum Kind: Hashable {
        case unixExecutable
        case shellScript(interpreter: String)
        case matchO
    }

    /// Value for the LaunchAgent plist's `ProgramArguments` array.
    var programArguments: [String] {
        switch kind {
        case .unixExecutable:
            return [executableURL.path] + arguments

        case .shellScript(let interpreter):
            return [interpreter, executableURL.path] + arguments
            
        case .matchO:
             return [executableURL.path] + arguments
        }
    
    }

    var isShellScript: Bool {
        if case .shellScript = kind {
            return true
        }

        return false
    }

    var interpreter: String? {
        guard case .shellScript(let interpreter) = kind else {
            return nil
        }

        return interpreter
    }

    var displayCommand: String {
        programArguments
            .map(shellEscaped)
            .joined(separator: " ")
    }

    var description: String {
        switch kind {
        case .unixExecutable:
            return "Unix executable — runs directly"

        case .shellScript(let interpreter):
            return "Shell script — runs using \(interpreter)"
            
        case .matchO:
            return "MatchO executable - run directly"
        }
    }

    var iconName: String {
        isShellScript ? "terminal" : "gearshape.2"
    }

    var tintColor: Color {
        isShellScript ? .orange : .blue
    }
    
    var executableName: String {
            executableURL.deletingPathExtension().lastPathComponent.lowercased()
    }
    
    var sheduleSummary: String? {
        /// Returns a user-friendly summary of the scheduled days/frequency.
        if isRepeating ?? false, let interval = intervalMinutes , interval > 0 {
            return " every \(interval) min"
        }
        
        guard let days = selectedDays, !days.isEmpty else {
            return nil
        }
        
        if days.count == 7 {
            return " every day"
        }
        
        let dayNames = days.sorted{ $0.rawValue < $1.rawValue }.map{ $0.fullName }
        let daysDescription: String
        
        if dayNames.count <= 1 {
            daysDescription = dayNames.joined()
        } else {
            daysDescription =
            dayNames.dropLast().joined(separator: ", ")
            + (dayNames.count == 2 ? " and " : ", and ")
            + dayNames.last!
        }
        
        //let daysDescription = " on " + sortedDays.map{ $0.fullName }.joined(separator: sortedDays.count == 7 ? ", and " : ", ")
        
        return " " + daysDescription
    }

    private func shellEscaped(_ argument: String) -> String {
        if argument.isEmpty {
            return "''"
        }

        let safeCharacters = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-./"
        )

        if argument.unicodeScalars.allSatisfy(safeCharacters.contains) {
            return argument
        }

        return "'\(argument.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
    
}




extension LaunchCommand {
    // MARK: - Error Types
    enum ExportError: LocalizedError {
        case serializationFailed(Error)
        case writeFailed(Error)

        var errorDescription: String? {
            switch self {
            case .serializationFailed(let err):
                return "Failed to serialize launchd plist data: \(err.localizedDescription)"
            case .writeFailed(let err):
                return "Failed to write plist file to disk: \(err.localizedDescription)"
            }
        }
    }

    // MARK: - 1. Dictionary Generator
    
    func makePlistDictionary(
        label: String? = nil,
        stdoutPath: String? = nil,
        stderrPath: String? = nil
    ) -> [String: Any] {
        let name = executableName
        let finalLabel = label ?? "defaultLabel"
        let finalStdout = stdoutPath ?? "/tmp/\(name).out"
        let finalStderr = stderrPath ?? "/tmp/\(name).err"

        // Set working directory to the executable's folder
        //let workingDir = executableURL.deletingLastPathComponent().path
        

        let targetURL: URL

        if self.isShellScript {
            // Shell scripts are copied into Application Support workspace to avoid TCC issues
            do {
                targetURL = try prepareScriptInWorkspace(sourceURL: executableURL)
            } catch {
                print("Error creating workspace for shell script: \(error). Falling back to original URL.")
                targetURL = executableURL
            }
        } else {
            // Non-shell scripts / Unix binaries use the original URL directly
            targetURL = executableURL
        }

        // Set working directory and program arguments from targetURL
        let workingDir = targetURL.deletingLastPathComponent().path
        
        
        let programArguments: [String]
        
//        if self.isShellScript {
//            // Open Terminal UI via osascript and pass arguments safely
//            var args: [String] = [
//                "osascript",
//                "-e", "on run argv",
//                "-e", "set userArg to item 1 of argv",
//                "-e", "tell application \"Terminal\" to do script \"\(executableURL.path) \" & quoted form of userArg",
//                "-e", "end run",
//                "--"
//            ]
//            
//            // Pass user arguments or empty string if none provided
//            let combinedUserArgs = arguments.joined(separator: " ")
//            args.append(combinedUserArgs)
//            
//            programArguments = args
//        } else {
//            // Standard binary/executable execution (runs in background)
//            programArguments = [executableURL.path] + arguments
//        }
        
//        if self.isShellScript {
//            // Combine path and arguments into a single shell execution string
//            let escapedPath = executableURL.path.replacingOccurrences(of: "\"", with: "\\\"")
//            
//            // Safely wrap each user argument in single quotes for shell safety
//            let escapedUserArgs = arguments.map { "'\($0.replacingOccurrences(of: "'", with: "'\\''"))'" }.joined(separator: " ")
//            
//            // Command that executes script with args and keeps Terminal open
//            let inlineCommand = "\"\(escapedPath)\" \(escapedUserArgs); exec zsh"
//
//            programArguments = [
//                "open",
//                "-a", "Terminal",
//                "--args",
//                "zsh",
//                "-c",
//                inlineCommand
//            ]
//        } else {
//            // Standard binary/executable execution (background)
//            programArguments = [executableURL.path] + arguments
//        }
        // Trim spaces/newlines and drop empty results
        let cleanArguments = arguments.map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter{ !$0.isEmpty }
        
        if self.isShellScript {
                // Run directly via /bin/zsh in the background
            programArguments = [targetURL.path] + cleanArguments // "/bin/zsh",
        } else {
            // Standard binary/executable execution
            programArguments = [targetURL.path] + cleanArguments
        }

        var plist: [String: Any] = [
            "Label": finalLabel,
            "ProgramArguments": programArguments,
            "WorkingDirectory": workingDir,
            "StandardOutPath": finalStdout,
            "StandardErrorPath": finalStderr
        ]

        if let isRepeating = isRepeating, isRepeating, let intervalMinutes = intervalMinutes {
            plist["StartInterval"] = intervalMinutes * 60
        } else if let hour = hour, let minute = minute {
            if let days = selectedDays, !days.isEmpty {
                let calendarArray: [[String: Int]] = days.sorted { $0.rawValue < $1.rawValue }.map { day in
                    let launchDay = day.rawValue //day == .sunday ? 1 : day.rawValue + 1
                    return [
                        "Weekday": launchDay,
                        "Hour": hour,
                        "Minute": minute
                    ]
                }
                plist["StartCalendarInterval"] = calendarArray
            } else {
                plist["StartCalendarInterval"] = [
                    "Hour": hour,
                    "Minute": minute
                ]
            }
        }

        return plist
    }
    
    private func generateLaunchLabel(serviceName: String) -> String {
        // NSUserName() returns short username (e.g., "yukisuzuki" or "yuki")
        let username = NSUserName().lowercased()
        
        // Sanitize to alphanumeric characters only
        let cleanUser = username.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        
        return "com.\(cleanUser).\(serviceName)"
    }
    
    private func prepareScriptInWorkspace(sourceURL: URL) throws -> URL {
        let fileManager = FileManager.default
        
        // 1. Get/Create ~/Library/Application Support/YourAppName/Scripts
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ScriptJet/Scripts", isDirectory: true)
        
        try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        
        let destinationURL = appSupportURL.appendingPathComponent(sourceURL.lastPathComponent)
        
        // 2. Overwrite file if it already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        // 3. Set executable permissions (chmod +x / 0o755)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationURL.path)
        
        // 4. Strip extended attributes (xattr -c equivalent)
        removexattr(destinationURL.path, nil, 0)
        
        return destinationURL
    }

    // MARK: - 2. Data Serializer
    func generatePlistData(label: String) throws -> Data {
        let dict = makePlistDictionary(label: label)
        //stdoutPath: "/tmp/\(self.executableName).out", stderrPath: "/tmp/\(self.executableName).err"
        return try PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .xml,
            options: 0
        )
    }

    // MARK: - 3. File Saver
    @discardableResult
    func saveLaunchAgent() throws -> URL {
        let plistData: Data
        do {
            plistData = try generatePlistData(label: self.executableName)
        } catch {
            throw ExportError.serializationFailed(error)
        }

        let fileManager = FileManager.default
        let launchAgentsDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)

        do {
            try fileManager.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)
        } catch {
            throw ExportError.writeFailed(error)
        }

        let destinationURL = launchAgentsDirectory.appendingPathComponent("\(self.executableName).plist")
        do {
            try plistData.write(to: destinationURL, options: .atomic)
            print("Successfully saved LaunchAgent to: \(destinationURL.path)")
            return destinationURL
        } catch {
            throw ExportError.writeFailed(error)
        }
    }
    
    func getPlist() -> URL{
        let fileManager = FileManager.default
        let launchAgentsDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/", isDirectory: true)
            .appendingPathComponent("\(self.executableName).plist", isDirectory: false)
        
        return launchAgentsDirectory
    }
}
