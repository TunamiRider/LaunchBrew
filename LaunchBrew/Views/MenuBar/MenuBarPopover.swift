import SwiftUI

struct MenuBarPopover: View {
    @EnvironmentObject var store: TaskStore

    private var failingTasks: [ScriptTask] {
        store.tasks.filter {
            if case .failed = $0.status { return true }
            return $0.status == .overdue
        }
    }

    private var upcomingTasks: [ScriptTask] {
        store.tasks
            .filter { $0.status == .succeeded }
            .sorted { $0.nextRunDate < $1.nextRunDate }
            .prefix(2)
            .map { $0 }
    }

    private var nextTask: ScriptTask? {
        store.tasks.sorted { $0.nextRunDate < $1.nextRunDate }.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ScriptJet")
                .font(.system(size: 13, weight: .semibold))
                .padding(EdgeInsets(top: 14, leading: 16, bottom: 10, trailing: 16))

            if let nextTask {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEXT RUN").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        Text(nextTask.nextRunDate.formattedRelativeShort())
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(nextTask.name).font(.system(size: 11.5, weight: .medium))
                        Text(nextTask.nextRunDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.separator))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            if !failingTasks.isEmpty {
                sectionLabel("CURRENT FAILURES")
                ForEach(failingTasks) { task in
                    HStack(spacing: 9) {
                        StatusDot(status: task.status)
                        Text(task.name).font(.system(size: 12.5, weight: .medium))
                        Text(task.status.label.lowercased())
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Run Now") { store.runNow(task) }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentJet)
                            .controlSize(.small)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 4)
                }
            }

            sectionLabel("UP NEXT")
            ForEach(upcomingTasks) { task in
                HStack(spacing: 9) {
                    StatusDot(status: task.status)
                    Text(task.name).font(.system(size: 12.5))
                    Spacer()
                    Text("in \(task.nextRunDate.formattedRelativeShort())")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 4)
            }

            Divider().padding(.top, 8)

            HStack {
                Button("Open ScriptJet") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentJet)
                .font(.system(size: 11.5))

                Spacer()

                Button("Pause All") {}
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentJet)
                    .font(.system(size: 11.5))
            }
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
        }
        .frame(width: 300)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }
}

#Preview {
    MenuBarPopover()
        .environmentObject(TaskStore())
}
