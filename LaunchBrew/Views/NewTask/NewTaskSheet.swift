import SwiftUI
import UniformTypeIdentifiers
import SwiftData

private enum NewTaskStep: Int, CaseIterable {
    case script, schedule, test, confirm

    var label: String {
        switch self {
        case .script: return "exe or shell script"
        case .schedule: return "Schedule"
        case .test: return "Test"
        case .confirm: return "Confirm"
        }
    }
}

struct NewTaskSheet: View {
    init() {
        let now = Date()
        let calendar = Calendar.current
        
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        // Round to nearest 15-minute interval (0, 15, 30, 45, or 60)
        let roundedMinute = Int((Double(currentMinute) / 15.0).rounded()) * 15
        
        if roundedMinute == 60 {
            _hour = State(initialValue: (currentHour + 1) % 24)
            _minute = State(initialValue: 0)
        } else {
            _hour = State(initialValue: currentHour)
            _minute = State(initialValue: roundedMinute)
        }
    }
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var step: NewTaskStep = .script // starts on Schedule to mirror the design walkthrough
    // 1. Key for storing the saved path in UserDefaults
    let lastDirKey = "LastOpenedDirectoryPath"
    
    @State private var launchCommand: LaunchCommand?
    @State private var scriptPath = ""
    @State private var arguments = "" //--source ~/Pictures --dest /Volumes/Backup
    @State private var frequency = ScheduleFrequency.weekly
    @State private var timeOfDay = Date()
    @State private var selectedDays: Set<Weekday> = []
    @State private var hour: Int
    @State private var minute: Int
    @State private var isRepeating: Bool = false
    @State private var intervalMinutes: Int = 15
    @State private var interpreterPath: String = ""
    
    
    @State private var isRunningTest: Bool = false
    @State private var isRunningTestPassed: Bool = false
    @State private var isTested: Bool = false
    @State private var isSkippingTest: Bool = false
    
    @State private var isCancelling: Bool = false
    @State private var isCanceled: Bool = false
    @State private var showCancelAlert = false
    
    @State private var errorMessage: String?
    @State private var testDuration: String?
    
    
    var fileAbbreviation: String {
        guard launchCommand != nil else {
            return ""
        }
        guard launchCommand?.executableURL.absoluteString.isEmpty != true else {
            return ""
        }
        return launchCommand?.isShellScript ?? false ? "sh" : "exe"
    }
    
    var fileName: String {
        guard scriptPath.isEmpty == false else {
            return "File Not Selected."
        }

        return (scriptPath as NSString).lastPathComponent
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                content
                    .padding(24)
            }
            Divider()
            footer
        }
        .frame(width: 520, height: 480)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Task")
                .font(.system(size: 15, weight: .semibold))

            HStack(spacing: 6) {
                ForEach(NewTaskStep.allCases, id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Color.accentJet : Color.secondary.opacity(0.25))
                        .frame(height: 4)
                }
            }

            HStack {
                ForEach(NewTaskStep.allCases, id: \.self) { s in
                    Text(s.label)
                        .font(.system(size: 10.5, weight: s == step ? .semibold : .regular))
                        .foregroundStyle(s == step ? Color.accentJet : .secondary)
                    if s != .confirm { Spacer() }
                }
            }
        }
        .padding(EdgeInsets(top: 20, leading: 24, bottom: 14, trailing: 24))
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .script: scriptStep
        case .schedule: scheduleStep
        case .test: testStep
        case .confirm: confirmStep
        }
    }
    
    private func chooseScript() {
        let panel = NSOpenPanel()
        panel.title = "Choose an Executable or a Shell Script"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        //panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        // 2. Restore last directory or fallback to home directory
        if let savedPath = UserDefaults.standard.string(forKey: lastDirKey) {
            panel.directoryURL = URL(fileURLWithPath: savedPath)
        } else {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }
        panel.allowedContentTypes = [.shellScript, .unixExecutable]

        if panel.runModal() == .OK, let url = panel.url {
            // 4. Save chosen directory (or its parent directory if a file was selected)
            let selectedDir = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
            UserDefaults.standard.set(selectedDir.path, forKey: lastDirKey)
            
            selectLaunchCommand(at: url)
        }
        

    }
    
    private func selectLaunchCommand(at url: URL) {
        var errorMessage = ""

        let gotAccess = url.startAccessingSecurityScopedResource()

        defer {
            if gotAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let values = try url.resourceValues(
                forKeys: [
                    .isRegularFileKey,
                    .isExecutableKey,
                    .contentTypeKey
                ]
            )

            guard values.isRegularFile == true else {
                errorMessage = "Please select a file, not a folder."
                return
            }

            let shellExtensions: Set<String> = [
                "sh", "bash", "zsh", "fish", "ksh", "command"
            ]

            let isShellScript =
                values.contentType?.conforms(to: .shellScript) == true ||
                shellExtensions.contains(url.pathExtension.lowercased())

            if isShellScript {
                let interpreter = detectInterpreter(at: url)
                self.interpreterPath = interpreter
                launchCommand = LaunchCommand(
                    executableURL: url,
                    kind: .shellScript(interpreter: interpreter),
                    arguments: [],
                    interpreterPath: interpreter
                )
                scriptPath = url.path.replacingOccurrences(
                    of: FileManager.default.homeDirectoryForCurrentUser.path,
                    with: "~"
                )
                return
            }

            
            
            if detectMachO(at: url) == .notMachO {
                return
            }
            // This is where your PhotoGenerator executable should arrive.
            launchCommand = LaunchCommand(
                executableURL: url,
                kind: .matchO,
                arguments: []
            )

            scriptPath = url.path.replacingOccurrences(
                of: FileManager.default.homeDirectoryForCurrentUser.path,
                with: "~"
            )

        } catch {
            errorMessage = "Could not inspect the selected file: \(error.localizedDescription)"
        }
    }
    private func detectInterpreter(at url: URL) -> String {
        // 1. Try reading the first line of the file for a shebang
        if let fileHandle = try? FileHandle(forReadingFrom: url) {
            defer { try? fileHandle.close() }
            
            let data = fileHandle.readData(ofLength: 256)
            if let line = String(data: data, encoding: .utf8)?.components(separatedBy: .newlines).first,
               line.hasPrefix("#!") {
                
                // Extract the string after "#!" and trim whitespace
                let rawInterpreter = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
                
                // Handle "#!/usr/bin/env zsh" vs "#!/bin/zsh"
                if rawInterpreter.hasPrefix("/usr/bin/env") {
                    let parts = rawInterpreter.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count > 1 {
                        return "/bin/\(parts[1])" // e.g. "/bin/zsh"
                    }
                } else if !rawInterpreter.isEmpty {
                    return rawInterpreter // e.g. "/bin/bash" or "/bin/zsh"
                }
            }
        }
        
        // 2. Fallback based on extension
        switch url.pathExtension.lowercased() {
        case "bash":
            return "/bin/bash"
        case "py":
            return "/usr/bin/python3"
        case "rb":
            return "/usr/bin/ruby"
        default:
            return "/bin/zsh" // Modern macOS default
        }
    }
    

    

    private var scriptStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            fieldBlock("What to run") {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 32, height: 32)
                        .overlay(Text("\(fileAbbreviation)").font(.system(size: 11, design: .monospaced)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(fileName)
                            .font(.system(size: 12.5, design: .monospaced))
                        Text(scriptPath)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Choose…") {
                        chooseScript()
                    }
                        .buttonStyle(.bordered)
                }
                .padding(12)
                //.background(Color.panelSunken)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.secondary.opacity(0.4)))
                Text("Choose a script, or paste a shell command — LaunchBrew treats both the same way.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

//    private var scheduleStep: some View {
////        Form {
////
////                }
//        VStack(alignment: .leading, spacing: 18) {
//            fieldBlock("Run") {
//                Picker("", selection: $frequency) {
//                    ForEach(ScheduleFrequency.displayFrequency, id: \.self) { Text($0.rawValue) }
//                }
//                .pickerStyle(.segmented)
//                .labelsHidden()
//            }
//            
//            
//            if frequency == .weekly {
//                Text("Run on")
//                    .font(.headline)
//                
//                WeekdayPicker(selectedDays: $selectedDays)
////                Text("Selected day indices: \(selectedDays.sorted{$0.rawValue < $1.rawValue} .map(\.fullName).joined(separator: ", "))")
////                            .font(.caption)
////                            .foregroundColor(.secondary)
//            }
//            fieldBlock("At time") {
//                //TimeWheelPicker(date: $timeOfDay)
//                FifteenMinuteTimePicker(selectedHour: $hour, selectedMinute: $minute)
//            }
//            
//            if frequency == .interval {
//                RepeatTaskPicker(
//                    isRepeating: $isRepeating,
//                    intervalMinutes: $intervalMinutes
//                )
//            }
//
////                    .padding()
////                    .frame(width: 300)
//
//
//            fieldBlock("Arguments (optional)") {
//                TextField("", text: $arguments)
//                    .textFieldStyle(.roundedBorder)
//                    .font(.system(size: 12.5, design: .monospaced))
//            }
//        }
//    }
    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // 1. Frequency Switcher
            fieldBlock("Schedule Mode") {
                Picker("", selection: $frequency.animation(.easeInOut(duration: 0.2))) {
                    ForEach(ScheduleFrequency.displayFrequency, id: \.self) { freq in
                        Text(freq.rawValue).tag(freq)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            Divider()
                .opacity(0.6)
            
            // 2. Dynamic Settings Section
            VStack(alignment: .leading, spacing: 18) {
                if frequency == .weekly {
                    // WEEKLY CONFIGURATION
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Run on")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        WeekdayPicker(selectedDays: $selectedDays)
                            .padding(.vertical, 4)
                    }
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)),
                                            removal: .opacity))
                    
                    fieldBlock("At time") {
                        FifteenMinuteTimePicker(selectedHour: $hour, selectedMinute: $minute)
                    }
                    .transition(.opacity)
                    
                } else if frequency == .interval {
                    // INTERVAL CONFIGURATION
                    RepeatTaskPicker(
                        isRepeating: $isRepeating,
                        intervalMinutes: $intervalMinutes
                    )
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)),
                                            removal: .opacity))
                }
            }
            
            Divider()
                .opacity(0.6)
            
            // 3. Optional Arguments Field
            fieldBlock("Arguments (optional)") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "terminal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("--verbose --output /tmp/log", text: $arguments)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                    
                    Text("Separate multiple arguments with spaces.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
        )
        .onChange(of: frequency){
            if frequency == .interval {
                isRepeating = true
            }
            if frequency == .weekly {
                isRepeating = false
            }
        }
    }
    private var isScheduleValid: Bool {
        switch frequency {
        case .weekly:
            // Ensures at least one day is selected
            return !selectedDays.isEmpty
        case .interval:
            // Valid if repetition is enabled and the interval is greater than 0
            return isRepeating && intervalMinutes > 0
        }
    }

    private var testStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Run once now to confirm it works before scheduling.")
                .foregroundStyle(.secondary)
            
        // MARK: - Command Info Card
        if let command = launchCommand {
            
            VStack(alignment: .leading, spacing: 10) {
                // Header: Type & Executable Name
                HStack(spacing: 8) {
                    Image(systemName: command.iconName)
                        .foregroundStyle(command.tintColor)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(command.executableURL.lastPathComponent)
                            .font(.system(size: 13, weight: .semibold))
                        
                        
                        HStack {
                            Text("\(command.description)\(command.sheduleSummary ?? "")")
                        }
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    }
                    
                    Spacer()
                    
                    Text(command.executableURL.pathExtension.uppercased())
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                
                Divider()
                
                // Full Escaped Invocation String
                VStack(alignment: .leading, spacing: 4) {
                    Text("FULL COMMAND")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                    
                    Text(command.displayCommand)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(.primary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.panelSunken.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(12)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
            
            // Status indicator (shown while testing)
            if isRunningTest {
                HStack(spacing: 8) {
                    AnimatedStatusBanner(
                            title: "Running test…",
                            themeColor: .orange
                        )
                }
            }
            if isSkippingTest {
                HStack(spacing: 8) {
                    AnimatedStatusBanner(
                            title: "Skipping test…",
                            themeColor: .cyan
                        )
                }
            }
            
            if isCancelling {
                HStack(spacing: 8) {
                    AnimatedStatusBanner(
                        title: "Cancelling \(launchCommand?.executableName ?? "")…",
                            themeColor: .pink
                        )
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: runTest) {
                    Label("Test Task", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunningTest || isSkippingTest)

                Button("Skip Test", action: skipTest)
                    .buttonStyle(.bordered)
                    .disabled(isRunningTest || isSkippingTest)
            }
            
            if isTested {
                if isRunningTestPassed {
                    StatusBanner(status: .succeeded, title: "Test run succeeded", subtitle: "Finished in \(testDuration ?? "0s") with exit code 0")
                } else {
                    StatusBanner(status: .failed(exitCode: 1), title: "Test run Failed", subtitle: "\(errorMessage ?? "")")
                }
            }

        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions (Placeholder logic)
    private func runTest() {
        isRunningTest = true
        
        
        Task { @MainActor in
            
            try? await Task.sleep(for: .seconds(10))
            //Task {
                do {
                    // Retrieve plist URL saved by model
                    guard let plistURL = launchCommand?.getPlist() else {
                        errorMessage = "Failed to retrieve the plist."
                        isTested = true
                        isRunningTest = false
                        isRunningTestPassed = false
                        return
                    }
                    
                    // Execute test run directly using the saved plist
                    let result = try await LaunchAgentManager.registerWithTest(plistURL: plistURL)
                    
                    isTested = true
                    testDuration = result.formattedDuration
                    if result.exitCode == 0 {
                        isRunningTest = false
                        isRunningTestPassed = true
                    }else {
                        isRunningTest = false
                        isRunningTestPassed = false
                    }
                    
                    // print("STDOUT Logs:\n\(result.stdout)")
                    // print("STDERR Logs:\n\(result.stderr)")
                    return
                } catch let error as LaunchCommand.ExportError {
                    errorMessage = error.errorDescription
                    isTested = true
                    isRunningTestPassed = false
                    isRunningTest = false
                    // print("Test Run Failed: \(error.localizedDescription)")
                    return
                } catch {
                    errorMessage = error.localizedDescription
                    isTested = true
                    isRunningTestPassed = false
                    isRunningTest = false
                    // print("Test Run Failed: \(error.localizedDescription)")
                    return
                }
            //}
            //isRunningTest = false
            //isRunningTestPassed = false
        }

        // Perform launchd command execution test
    }

    private func skipTest() {
        // Proceed directly to saving/scheduling task
        // Clear any previous error and update state
        errorMessage = nil
        isSkippingTest = true
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            do {
                // 1. Retrieve plist URL saved by model
                guard let plistURL = launchCommand?.getPlist() else {
                    errorMessage = "Failed to retrieve the plist."
                    isTested = false
                    isRunningTestPassed = false
                    isSkippingTest = false
                    return
                }
                
                // 2. Register with launchd directly without kickstarting execution
                try LaunchAgentManager.register(plistURL: plistURL)
                
                // 3. Set UI state to indicate test was skipped but task is registered successfully
                isTested = false
                testDuration = nil
                isRunningTestPassed = true
                isSkippingTest = false
                
            } catch let error as LaunchCommand.ExportError {
                errorMessage = error.errorDescription
                isTested = false
                isRunningTestPassed = false
                isSkippingTest = false
                print("Skip Test / Registration Failed: \(error.localizedDescription)")
                
            } catch {
                errorMessage = error.localizedDescription
                isTested = false
                isRunningTestPassed = false
                isSkippingTest = false
                print("Skip Test / Registration Failed: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
        private func cancel() async {
            guard isRunningTestPassed else {
                dismiss()
                return
            }
            
            isCancelling = true
            
            defer {
                isCancelling = false
                isRunningTestPassed = false
            }
            
            try? await Task.sleep(for: .seconds(10))
            
            guard let plistURL = launchCommand?.getPlist() else {
                print("Failed to retrieve the plist.")
                dismiss()
                return
            }
            
            do {
                // Unregister from launchd AND delete plist
                isCanceled = try LaunchAgentManager.unregister(plistURL: plistURL, deletePlistFile: true)
                
                if isCanceled {
                    // print("Test agent unregistered and plist deleted.")
                    showCancelAlert = true // 👈 Triggers popup
                } else {
                    dismiss()
                }
            } catch {
                print("Failed to unregister test agent: \(error.localizedDescription)")
                dismiss()
            }
        }

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            StatusBanner(status: .succeeded, title: "Confirmed", subtitle: "Below is the description.")

            // MARK: - Command Info Card
            if let command = launchCommand {
                
                VStack(alignment: .leading, spacing: 10) {
                    // Header: Type & Executable Name
                    HStack(spacing: 8) {
                        Image(systemName: command.iconName)
                            .foregroundStyle(command.tintColor)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(command.executableURL.lastPathComponent)
                                .font(.system(size: 13, weight: .semibold))
                            
                            
                            HStack {
                                Text("\(command.description)\(command.sheduleSummary ?? "")")
                            }
                            .foregroundStyle(.secondary)
                            .font(.caption)

                        }
                        
                        Spacer()
                        
                        Text(command.executableURL.pathExtension.uppercased())
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Divider()
                    
                    // Full Escaped Invocation String
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FULL COMMAND")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                        
                        Text(command.displayCommand)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(.primary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.panelSunken.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                confirmRow("Script", scriptPath)
                confirmRow("Arguments", arguments.isEmpty ? "—" : arguments)
                confirmRow("Schedule", frequency.rawValue)
            }
        }
    }

    private func confirmRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            Text(value).font(.system(size: 12, design: .monospaced))
        }
        .font(.system(size: 12.5))
    }

    private func fieldBlock<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private var footer: some View {
        HStack {
            if step != .script {
                Button("Back") { step = NewTaskStep(rawValue: step.rawValue - 1) ?? .script }
                    .buttonStyle(.bordered)
            }
            Spacer()
            
            if [.test, .script, .schedule].contains(step) {
                
                Button(role: .cancel){
                    
                    if step == .test {
                        Task{
                            await cancel()
                        }
                    }else {
                        dismiss()
                    }

                } label: {
                    Label("Cancel", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.bordered)
            }

            if step == .confirm {
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentJet)
            } else {
                Button(step == .test ? "Confirm →" : "Next →") {
                    
                    //Schedule
                    if step == .schedule, var command = self.launchCommand {
                        command.hour = self.hour
                        command.minute = self.minute
                        command.isRepeating = self.isRepeating
                        command.intervalMinutes = self.intervalMinutes
                        command.selectedDays = self.selectedDays
                        command.arguments = [self.arguments]
                        command.interpreterPath = self.interpreterPath
                        
                        self.launchCommand = command
                        
                        if let command = self.launchCommand {
                            do {
                                let savedURL = try command.saveLaunchAgent()
                                // print("savedURL : \(savedURL)")
                            } catch {
                                print("Error saving agent: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    //Confirm
                    if step == .test && isRunningTestPassed {
                        //Create ScriptTask
                        if let command = self.launchCommand {
                            let executableName = command.executableName
                            do {
                                let scriptTask = try ScriptTask.createFromPlist(executableName: executableName)
                                scriptTask.interpreterPath = command.interpreterPath
                                modelContext.insert(scriptTask)
                                try modelContext.save()
                                
                                // print("Successfully saved ScriptTask: \(scriptTask.name)")
                            } catch {
                                print("Failed to create or save ScriptTask from plist: \(error.localizedDescription)")
                                            // Optionally handle error in UI (e.g., show alert)
                            }
                        }
                    }
            
                    //Script
                    if step == .script && scriptPath.isEmpty {
                        //return
                    }
                    // Test
                    if step == .test && !isRunningTestPassed {
                        //return
                    }
                    step = NewTaskStep(rawValue: step.rawValue + 1) ?? .confirm
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentJet)
                .disabled(step == .script && scriptPath.isEmpty)
                .disabled(step == .schedule && !isScheduleValid)
                .disabled(step == .test && !isRunningTestPassed)
                
            }
        }
        .padding(14)
        // Alert confirming unregistration
        .alert("Test Agent Revoked", isPresented: $showCancelAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("The scheduled task '\(launchCommand?.executableName ?? "agent")' was successfully unregistered and removed from launchd.")
        }
    }
}

//#Preview {
//    NewTaskSheet()
//}
