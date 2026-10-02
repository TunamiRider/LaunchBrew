import SwiftUI

struct TaskDetailView: View {
    let task: ScriptTask
    @State private var tab: Tab = .overview

    private enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview", schedule = "Schedule", logs = "Logs", advanced = "Advanced"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))

            Divider()

            ScrollView {
                Group {
                    switch tab {
                    case .overview: OverviewTab(task: task)
                    case .schedule: ScheduleTab(task: task)
                    case .logs: LogsTab(task: task)
                    case .advanced: AdvancedTab(task: task)
                    }
                }
                .padding(22)
            }
            .background(Color.panelSunken)
        }
        .navigationTitle(task.name)
    }
}

private struct OverviewTab: View {
    let task: ScriptTask

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                StatusBanner(
                    status: task.status,
                    title: bannerTitle,
                    subtitle: task.lastRunDate.map { "\($0.formatted(date: .abbreviated, time: .shortened)) · ran for \(task.lastDuration.map { String(format: "%.1fs", $0) } ?? "—")" } ?? "Has not run yet"
                )

                if let excerpt = task.lastErrorExcerpt {
                    GroupBox {
                        Text(excerpt)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color(red: 0.94, green: 0.76, blue: 0.75))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } label: {
                        Text("Error excerpt").font(.caption).foregroundStyle(.secondary)
                    }
                }

                GroupBox {
                    Text("/bin/sh \(task.scriptPath) \(task.arguments)")
                        .font(.system(size: 12.5, design: .monospaced))
                        .padding(.top, 4)
                } label: {
                    Text("Command").font(.caption).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                GroupBox {
                    HStack(spacing: 10) {
                        chip("Countdown", CountdownText)
                        chip("At", task.scheduleDescription)
                    }
                    .padding(.top, 4)
                } label: {
                    Text("Next run").font(.caption).foregroundStyle(.secondary)
                }

                GroupBox {
                    ReliabilityStrip(runs: task.runs)
                        .padding(.top, 4)
                } label: {
                    Text("Reliability, recent runs").font(.caption).foregroundStyle(.secondary)
                }

                GroupBox {
                    HStack(spacing: 8) {
                        Button("Run Now", systemImage: "play.fill") {}
                            .buttonStyle(.borderedProminent).tint(.accentJet)
                        Button("Reveal Plist") {}.buttonStyle(.bordered)
                        Button("Open Logs") {}.buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                } label: {
                    Text("Actions").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var bannerTitle: String {
        if case .failed(let code) = task.status { return "Failed on last run — exit code \(code)" }
        return task.status.label
    }

    private func chip(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 10.5)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
        .padding(10)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    private var CountdownText: String {
        guard let nextRunDate = task.nextRunDate else { return "-" }
        return nextRunDate > Date() ? "in \(nextRunDate.formattedRelativeShort())" : "overdue"
    }
}

private struct ReliabilityStrip: View {
    let runs: [RunRecord]

    var body: some View {
        let sample = runs.isEmpty ? Array(repeating: RunRecord(id: UUID(), taskName: "", startedAt: Date(), duration: 0, status: .succeeded), count: 13) + [RunRecord(id: UUID(), taskName: "", startedAt: Date(), duration: 0, status: .failed(exitCode: 1))] : runs

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                ForEach(sample) { run in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(run.status.color)
                        .frame(width: 14, height: 20)
                }
            }
            let failed = sample.filter { if case .failed = $0.status { return true }; return false }.count
            let succeeded = sample.count - failed
            let rate = sample.isEmpty ? 0 : Double(succeeded) / Double(sample.count) * 100
            Text("\(succeeded) succeeded · \(failed) failed · \(String(format: "%.1f", rate))% success rate")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ScheduleTab: View {
    let task: ScriptTask
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frequency: \(task.scheduleDescription)")
            Text("Next run: \(nextRunDateText)")
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var nextRunDateText: String {
        guard let nextRunDate = task.nextRunDate else { return "-" }
        
        return nextRunDate.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct LogsTab: View {
    let task: ScriptTask
    var body: some View {
        if task.runs.isEmpty {
            ContentUnavailableView("No Runs Yet", systemImage: "doc.text.magnifyingglass")
        } else {
            Table(task.runs) {
                TableColumn("Status") { run in Text(run.status.label).foregroundStyle(run.status.color) }
                TableColumn("Started") { run in Text(run.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 12, design: .monospaced)) }
                TableColumn("Duration") { run in Text(String(format: "%.1fs", run.duration)).font(.system(size: 12, design: .monospaced)) }
                TableColumn("Exit") { run in Text(run.exitCode.map(String.init) ?? "—").font(.system(size: 12, design: .monospaced)) }
            }
            .frame(minHeight: 220)
        }
    }
}

private struct AdvancedTab: View {
    let task: ScriptTask
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environment variables, working directory, retry policy, and the raw generated LaunchAgent plist live here.")
                .foregroundStyle(.secondary)
            Button("Reveal Plist in Finder") {}
                .buttonStyle(.bordered)
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

//#Preview {
//    TaskDetailView(task: SampleData.tasks[0])
//        .frame(width: 760, height: 560)
//}
