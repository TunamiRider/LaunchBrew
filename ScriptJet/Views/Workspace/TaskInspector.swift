import SwiftUI

struct TaskInspector: View {
    @EnvironmentObject var store: TaskStore
    let task: ScriptTask?

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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(.system(size: 17, weight: .semibold))
                Text("\(task.scriptPath) · \(task.scheduleDescription)")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit") {}
                .buttonStyle(.bordered)
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
        HStack(spacing: 8) {
            Button {
                store.runNow(task)
            } label: {
                Label("Run Now", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentJet)

            Button {
                store.togglePause(task)
            } label: {
                Label(task.isPaused ? "Resume" : "Pause", systemImage: task.isPaused ? "play" : "pause")
            }
            .buttonStyle(.bordered)

            Button("Reveal Script") {}.buttonStyle(.bordered)
            Button("Reveal Plist") {}.buttonStyle(.bordered)
            Button("Open Logs") {}.buttonStyle(.bordered)
        }
    }
}

private struct ScheduleCard: View {
    let task: ScriptTask

    var body: some View {
        GroupBox {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                kv("Frequency", task.scheduleDescription)
                kv("Next run", task.nextRunDate > Date() ? "in \(task.nextRunDate.formattedRelativeShort())" : "overdue")
                kv("Last run", task.lastRunDate.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "—")
                kv("Duration", task.lastDuration.map { String(format: "%.1fs", $0) } ?? "—")
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
