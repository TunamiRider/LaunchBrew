import SwiftUI
import SwiftData
struct TaskInspector: View {
    //@EnvironmentObject var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScriptTask.name) private var scriptTaskList: [ScriptTask]
    
    @State private var showCancelAlert = false
    @State private var unregisterErrorMessage: String?
    let task: ScriptTask?
    
    @State private var isRunningTask: Bool = false
    @State private var isRefreshingLog: Bool = false
    
    //Schedule buttons
    // State variables for alerts
    @State private var showChangeScheduleSheet = false
    @State private var showUnscheduleConfirmation = false
    @State private var showSuccessAlert = false
    @State private var successMessage = ""
    @State private var showFailAlert = false
    @State private var failMessage = ""

    var body: some View {
        if let task {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(for: task)

                    StatusBanner(
                        status: task.status,
                        title: bannerTitle(for: task),
                        subtitle: bannerSubtitle(for: task)
                    )

                    actionRow(for: task)

                    ScheduleCard(task: task)

                    if !task.runs.isEmpty {
                        RecentRunsCard(runs: task.runs)
                    }
                }
                .padding(20)
            }
            //.background(Color.panelSunken)
        } else {
            ContentUnavailableView(
                "No Task Selected",
                systemImage: "cursorarrow.rays",
                description: Text("Choose a task from the list to see its status, schedule, and recent runs.")
            )
        }
    }

    private func header(for task: ScriptTask) -> some View {
        VStack {
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.name)
                        .font(.system(size: 17, weight: .semibold))
                    
                    // Metadata Tag Badges
                    VStack(alignment: .leading) {
                        // Script Location Tag
                        if !task.scriptPath.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                
                                Text("Location:")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                
                                Text(task.scriptPath)
                                    .font(.system(size: 11, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(NSColor.quaternaryLabelColor))
                            )
                        }
                        
                        // Interpreter Tag (e.g. /bin/zsh, /usr/local/bin/python3)
                        if let interpreter = task.interpreterPath, !interpreter.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "terminal.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                
                                Text(interpreter)
                                    .font(.system(size: 11, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(NSColor.quaternaryLabelColor))
                            )
                        }
                    }
                    
                }
                Spacer()
                
                Button {
                    Task {
                        // 1. Set state to true (will trigger UI redraw)
                        isRefreshingLog = true
                        
                        // 2. Yield control briefly so SwiftUI renders the spinner/loading UI frame
                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                        
                        // 3. Run synchronous heavy log fetch
                        task.syncOSLogs(in: modelContext)
                        
                        // 4. Reset state when done
                        isRefreshingLog = false
                    }
                } label: {
                    Label("Refresh Logs", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isRefreshingLog)
                
                Button(role: .destructive) {
                    removeTask(for: task)
                } label: {
                    Label("Delete Task", systemImage: "trash")
                }
                
                // Button("Edit") { }.buttonStyle(.bordered)
            
                Menu("Manage Schedule") {
                    Button("Change Schedule") {
                        //changeSchedule()
                        showChangeScheduleSheet = true
                    }
                    
                    Divider()

                    Button("Unschedule", role: .destructive) {
                        // Show confirmation alert before proceeding
                        showUnscheduleConfirmation = true
                    }
                }
                .buttonStyle(.bordered)
                .menuIndicator(.visible)

                
                
            }
            .alert("Task Removed", isPresented: $showCancelAlert) {
                Button("OK") {
                    dismiss() // 👈 Dismiss view after user acknowledges
                }
            } message: {
                Text("The launchd agent was unregistered, its plist file was deleted, and the task was removed from LaunchBrew.")
            }
            // 1. Confirmation Alert before Unscheduling
            .alert("Are you sure you want to unschedule this task?", isPresented: $showUnscheduleConfirmation) {
                Button("Unschedule", role: .destructive) {
                    performUnschedule(for: task)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action will remove the scheduled time for this task.")
            }
            
            // 2. Alert for Success Messages
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(successMessage)
            }

            // 2. Alert for Fail Messages
            .alert("Failed", isPresented: $showFailAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failMessage)
            }
            
            // 1. Change Schedule Modal Sheet
            .sheet(isPresented: $showChangeScheduleSheet) {
                ChangeScheduleSheetView(task: task) { updatedMessage in
                    successMessage = updatedMessage
                    showSuccessAlert = true
                } onUpdateError: { _ in }
            }
            
            // Status indicator (shown while testing)
            if isRefreshingLog {
                HStack(spacing: 8) {
                    AnimatedStatusBanner(
                        title: "Refreshing status…",
                        themeColor: .yellow
                    )
                }
            }
        }
    }
    // private task actions
    private func removeTask(for task: ScriptTask) {
        let isCanceled = task.unregisterAndDelete(in: modelContext)
        
        if isCanceled {
            // print("Test agent unregistered and plist deleted.")
            showCancelAlert = true // 👈 Triggers popup
        } else {
            dismiss()
        }
    }
    private func changeSchedule() {
        // Handle your logic to change schedule (e.g., open picker or update model)
        
        // Trigger success alert
        successMessage = "Successfully updated the schedule."
        showSuccessAlert = true
    }

    private func performUnschedule(for task: ScriptTask) {
        // Handle your actual unschedule logic here
        let isUnScheduled = task.unregister(in: modelContext)
        
        if isUnScheduled {
            // Trigger success alert
            successMessage = "Successfully unscheduled."
            showSuccessAlert = true
        }else {
            failMessage = "UnScheduling failed."
            showFailAlert = true
        }

    }

    private func bannerTitle(for task: ScriptTask) -> String {
        switch task.status {
        case .succeeded: return "Last run succeeded"
        case .running: return "Currently running"
        case .overdue: return "This task is overdue"
        case .paused: return "Task is paused"
        case .failed: return "Last run failed"
        }
    }

    private func bannerSubtitle(for task: ScriptTask) -> String {
        if case .failed(let code) = task.status {
            let excerpt = task.lastErrorExcerpt?.split(separator: "\n").first.map(String.init) ?? ""
            return "Exit code \(code) · \(excerpt)"
        }
        if let last = task.lastRunDate {
            return "Last ran \(last.formattedRelativeShort()) ago"
        }
        return "Has not run yet"
    }

    private func actionRow(for task: ScriptTask) -> some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
//                Button {
//                    Task {
//                        isRunningTask = true
//                        defer { isRunningTask = false }
//                        await task.runNow(in: modelContext)
//                        
//                    }
//                } label: {
//                    Label("Run Now", systemImage: "play.fill")
//                }
//                .buttonStyle(.borderedProminent)
//                .tint(.accentJet)
//                .disabled(isRunningTask)
                if isRunningTask {
                    Button {
                        Task {
                            await task.stopNow(in: modelContext)
                            isRunningTask = false
                        }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button {
                        Task {
                            isRunningTask = true
                            defer { isRunningTask = false }
                            await task.runNow(in: modelContext)
                        }
                    } label: {
                        Label("Run Now", systemImage: "play.fill")
                    }
                    .disabled(task.status == .running)
                    .buttonStyle(.borderedProminent)
                    .tint(.accentJet)
                    
                }
                

                Button("Reveal Script") { task.revealScriptInFinder() }.buttonStyle(.bordered)
                Button("Reveal Plist") { task.revealPlistInFinder() }.buttonStyle(.bordered)
                Button("Open Logs") { Task { await task.revealLogsInFinder() } }.buttonStyle(.bordered)
            }
            // Status indicator (shown while testing)
            if isRunningTask {
                HStack(spacing: 8) {
                    AnimatedStatusBanner(
                            title: "Running task…",
                            themeColor: .orange
                        )
                    Spacer()
                }
            }
        }

    }
}

//private // MARK: - Change Schedule Sheet View
private struct ChangeScheduleSheetView: View {
    @Environment(\.modelContext) private var modelContext
    let task: ScriptTask?
    var onUpdateSuccess: (String) -> Void
    var onUpdateError: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var plistRawText: String = ""
    @State private var plistDict: [String: Any] = [:]
    @State private var isRawTextExpanded: Bool = false
    @State private var errorMessage: String?

    // Schedule form states
    @State private var frequency: ScheduleFrequency = .weekly
    @State private var selectedDays: Set<Weekday> = [] // Default Sunday / Day 1
    @State private var hour: Int = 9
    @State private var minute: Int = 0
    @State private var isRepeating: Bool = false
    @State private var intervalMinutes: Int = 15
    @State private var arguments: String = ""

    private var isScheduleValid: Bool {
        switch frequency {
        case .weekly:
            return !selectedDays.isEmpty
        case .interval:
            return isRepeating && intervalMinutes > 0
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Change Schedule")
                    .font(.title2.weight(.bold))
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            if let task = task {
                Text("Task: \(task.plistURL?.lastPathComponent ?? "Unknown")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.callout)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // 1. Collapsible Raw XML Preview
                        DisclosureGroup("Raw plist XML", isExpanded: $isRawTextExpanded) {
                            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                                Text(plistRawText)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 180)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .font(.headline)

                        Divider()

                        // 2. Structured Schedule Configuration View
                        scheduleStep
                    }
                }
            }

            Spacer()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Update Schedule") {
                    updateSchedule()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isScheduleValid)
            }
        }
        .padding()
        .frame(width: 620, height: 560)
        .onAppear {
            loadPlistData()
        }
    }

    private func fieldBlock<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
    }
    private func handleFrequencyChange(_ newFreq: ScheduleFrequency) {
        if newFreq == .interval {
            isRepeating = true
        } else if newFreq == .weekly {
            isRepeating = false
        }
        rebuildPlistDict()
    }
    // MARK: - Schedule Form UI
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
                    // StartCalendarInterval configuration
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
                        FifteenMinuteTimePicker(selectedHour: $hour, selectedMinute:$minute)
                    }
                    .transition(.opacity)

                } else if frequency == .interval {
                    // StartInterval configuration
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

            // 3. Program Arguments Field (ProgramArguments array in plist)
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
        .onChange(of: frequency) { _, newFreq in
            handleFrequencyChange(newFreq)
        }
        .onChange(of: selectedDays) { rebuildPlistDict() }
        .onChange(of: hour) { rebuildPlistDict() }
        .onChange(of: minute) { rebuildPlistDict() }
        .onChange(of: intervalMinutes) { rebuildPlistDict() }
        .onChange(of: isRepeating) { rebuildPlistDict() }
        .onChange(of: arguments) { rebuildPlistDict() }
    }

    // MARK: - Data Synchronization & Conversion

    private func loadPlistData() {
        guard let task = task else {
            errorMessage = "No task selected."
            return
        }

        do {
            self.plistDict = try task.readPListContent()
            parsePlistToFormState()
            syncRawText()
        } catch {
            self.errorMessage = "Failed to parse plist content: \(error.localizedDescription)"
        }
    }

    /// Extract existing values from `StartCalendarInterval` or `StartInterval`
    private func parsePlistToFormState() {
        // 1. Check for StartInterval (Interval mode)
        if let intervalSeconds = plistDict["StartInterval"] as? Int {
            self.frequency = .interval
            self.isRepeating = true
            self.intervalMinutes = max(1, intervalSeconds / 60)
        }
        // 2. Check for StartCalendarInterval (Weekly / Calendar mode)
        else if let calendarArray = plistDict["StartCalendarInterval"] as? [[String: Int]] {
            self.frequency = .weekly
            self.isRepeating = false

            var days = Set<Weekday>()

            for item in calendarArray {
                if let day = item["Weekday"] {
                    days.insert(Weekday(rawValue: day)!)
                }
                if let h = item["Hour"] { self.hour = h }
                if let m = item["Minute"] { self.minute = m }
            }
            if !days.isEmpty { self.selectedDays = days }
        } else if let singleDict = plistDict["StartCalendarInterval"] as? [String: Int] {
            self.frequency = .weekly
            self.isRepeating = false

            if let day = singleDict["Weekday"] { self.selectedDays = [Weekday(rawValue: day)!] }
            if let h = singleDict["Hour"] { self.hour = h }
            if let m = singleDict["Minute"] { self.minute = m }
        }

        // 3. Extract arguments if present
        if let argsArray = plistDict["ProgramArguments"] as? [String], argsArray.count > 1 {
            // Drop the first item if it's the executable binary path itself
            self.arguments = argsArray.dropFirst().joined(separator: " ")
        }
    }

    /// Rebuilds `plistDict` whenever UI values change
    private func rebuildPlistDict() {
        // Clear conflicting schedule keys
        plistDict.removeValue(forKey: "StartInterval")
        plistDict.removeValue(forKey: "StartCalendarInterval")

        switch frequency {
        case .interval:
            if isRepeating {
                plistDict["StartInterval"] = intervalMinutes * 60
            }

        case .weekly:
            let calendarIntervals: [[String: Int]] = selectedDays
                .map { $0.rawValue }
                .sorted()
                .map { dayRaw in
                    [
                        "Weekday": dayRaw,
                        "Hour": hour,
                        "Minute": minute
                    ]
                }
            plistDict["StartCalendarInterval"] = calendarIntervals
        }

        // Update arguments if provided
        let parsedArgs = arguments
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }

        if let existingArgs = plistDict["ProgramArguments"] as? [String], let executable = existingArgs.first {
            plistDict["ProgramArguments"] = [executable] + parsedArgs
        }

        syncRawText()
    }

    private func syncRawText() {
        if let data = try? PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0) {
            self.plistRawText = String(data: data, encoding: .utf8) ?? self.plistRawText
        }
    }

    private func updateSchedule() {
        guard let task = task else {
            onUpdateError("Failed to update: No task selected.")
            return
        }

        do {
            rebuildPlistDict()
            _ = try task.updatePlist(plistDict: self.plistDict)
            _ = try task.reloadLaunchdAgent()
            
            // Update the schedule description & save context
            let isSaved = task.updateScheduleDesc(self.plistDict, modelContext: modelContext)
            if !isSaved {
                print("Warning: Plist reloaded, but failed to persist schedule description to SwiftData.")
            }

            dismiss()
            onUpdateSuccess("Successfully updated the schedule.")

        } catch {
            print("Error updating schedule: \(error.localizedDescription)")
            dismiss()
            onUpdateError("Failed to update schedule: \(error.localizedDescription)")
        }
    }
}

// MARK: - Plist Key Row Component

struct PlistKeyRow: View {
    let key: String
    let value: Any?
    var onUpdate: (Any) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if key == "StartInterval", let seconds = value as? Int {
                HStack {
                    VStack(alignment: .leading) {
                        Text("StartInterval")
                            .fontWeight(.semibold)
                        Text("Interval: \(seconds / 60) min (\(seconds) sec)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Stepper("", value: Binding(
                        get: { seconds },
                        set: { onUpdate($0) }
                    ), in: 60...86400, step: 60)
                    .labelsHidden()
                }
            } else if key == "StartCalendarInterval" {
                Text("StartCalendarInterval")
                    .fontWeight(.semibold)

                if let dict = value as? [String: Int] {
                    SingleLineCalendarEditor(dict: dict) { updatedDict in
                        onUpdate(updatedDict)
                    }
                } else if let array = value as? [[String: Int]] {
                    ForEach(Array(array.enumerated()), id: \.offset) { index, itemDict in
                        SingleLineCalendarEditor(dict: itemDict) { updatedDict in
                            var newArray = array
                            newArray[index] = updatedDict
                            onUpdate(newArray)
                        }
                    }
                }
            } else {
                HStack {
                    Text(key)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(String(describing: value ?? ""))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Single Line Calendar Editor (Weekday : Hour : Minute)

struct SingleLineCalendarEditor: View {
    let dict: [String: Int]
    var onUpdate: ([String: Int]) -> Void

    var body: some View {
        HStack(spacing: 12) {
            
            // Weekday Controls (If present)
            if let weekday = dict["Weekday"] {
                HStack(spacing: 4) {
                    Text("Day:")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text(Weekday(rawValue: weekday)?.fullName ?? "")
                        .fontWeight(.medium)
                        .frame(width: 32, alignment: .leading)
                    Stepper("", value: Binding(
                        get: { weekday },
                        set: { newDay in
                            var updated = dict
                            updated["Weekday"] = newDay
                            onUpdate(updated)
                        }
                    ), in: 1...7)
                    .labelsHidden()
                }
            }
            
            Spacer()

            // Hour Controls
            if let hour = dict["Hour"] {
                HStack(spacing: 4) {
                    Text("Hour:")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text(String(format: "%02d", hour))
                        .monospacedDigit()
                        .fontWeight(.medium)
                    Stepper("", value: Binding(
                        get: { hour },
                        set: { newHour in
                            var updated = dict
                            updated["Hour"] = newHour
                            onUpdate(updated)
                        }
                    ), in: 0...23)
                    .labelsHidden()
                }
            }

            // Minute Controls
            if let minute = dict["Minute"] {
                HStack(spacing: 4) {
                    Text("Min:")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text(String(format: "%02d", minute))
                        .monospacedDigit()
                        .fontWeight(.medium)
                    Stepper("", value: Binding(
                        get: { minute },
                        set: { newMinute in
                            var updated = dict
                            updated["Minute"] = newMinute
                            onUpdate(updated)
                        }
                    ), in: 0...59)
                    .labelsHidden()
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(6)
    }

    private func shortWeekdayName(_ day: Int) -> String {
        switch day {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return "\(day)"
        }
    }
}

private struct ScheduleCard: View {
    let task: ScriptTask

    var body: some View {
        GroupBox {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                kv("Frequency", task.scheduleDescription)
                kv("Next run", nextRunText)
                kv("Last run", task.lastRunDate.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "—")
                // kv("Duration", task.lastDuration.map { String(format: "%.1fs", $0) } ?? "—")
            }
            .padding(.top, 4)
        } label: {
            Text("Schedule").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func kv(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, design: .monospaced))
        }
    }
    private var nextRunText: String {
        guard let nextRun = task.nextRunDate else {
            return "-" // Fallback when nextRunDate is nil
        }
        return nextRun > Date()
            ? "in \(nextRun.formattedRelativeShort())"
            : "overdue"
    }
}

private struct RecentRunsCard: View {
    let runs: [RunRecord]

    var body: some View {
        GroupBox {
            VStack(spacing: 0) {
                ForEach(runs) { run in
                    HStack {
                        Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 150, alignment: .leading)
                        Text(run.status.label)
                            .font(.system(size: 12.5))
                            .foregroundStyle(run.status.color)
                        Spacer()
                        Text(String(format: "%.1fs", run.duration))
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    if run.id != runs.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.top, 4)
        } label: {
            Text("Recent runs").font(.caption).foregroundStyle(.secondary)
        }
    }
}
