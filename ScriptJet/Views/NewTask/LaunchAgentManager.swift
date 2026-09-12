//
//  LaunchAgentTestRunner.swift
//  ScriptJet
//
//  Created by Yuki Suzuki on 9/10/26.
//

import Foundation

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

class LaunchAgentManager {

    /// Reads an existing plist file, extracts its internal configuration, and triggers a test run via launchctl.
    static func runTest(plistURL: URL) async throws -> ScriptTestResult {
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

        // 3. Extract required Label and output paths
        guard let label = plistDict["Label"] as? String, !label.isEmpty else {
            throw TestRunnerError.missingLabel
        }

        let stdoutPath = plistDict["StandardOutPath"] as? String ?? "/tmp/\(label).out"
        let stderrPath = plistDict["StandardErrorPath"] as? String ?? "/tmp/\(label).err"

        // 4. Clear previous test log output files
        try? fileManager.removeItem(atPath: stdoutPath)
        try? fileManager.removeItem(atPath: stderrPath)

        // 5. Unload previous service instance if currently loaded
        _ = runProcess("/bin/launchctl", args: ["bootout", "gui/\(currentUID)", plistURL.path])

        // 6. Bootstrap fresh plist into launchd
        let bootstrapStatus = runProcess("/bin/launchctl", args: ["bootstrap", "gui/\(currentUID)", plistURL.path])
        if bootstrapStatus.exitCode != 0 && !bootstrapStatus.output.isEmpty {
            print("Bootstrap notice: \(bootstrapStatus.output)")
        }
        
        // --- Start Timing Execution ---
            let clock = ContinuousClock()
            let startTime = clock.now

        // 7. Force immediate execution (-k kickstart)
        let kickstartStatus = runProcess("/bin/launchctl", args: ["kickstart", "-k", "gui/\(currentUID)/\(label)"])
        guard kickstartStatus.exitCode == 0 else {
            throw TestRunnerError.executionFailed(kickstartStatus.output)
        }

        // 8. Allow time for script execution and file system buffer flushing
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        
        // --- Stop Timing Execution ---
        let elapsedTime = startTime.duration(to: clock.now)
        let durationInSeconds = Double(elapsedTime.components.seconds) + (Double(elapsedTime.components.attoseconds) / 1e18)

        // 9. Read logs from standard output/error file paths
        let stdoutContent = (try? String(contentsOfFile: stdoutPath, encoding: .utf8)) ?? ""
        let stderrContent = (try? String(contentsOfFile: stderrPath, encoding: .utf8)) ?? ""

        return ScriptTestResult(
            stdout: stdoutContent,
            stderr: stderrContent,
            exitCode: kickstartStatus.exitCode,
            duration: durationInSeconds
        )
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
