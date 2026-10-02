import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var store: TaskStore
    @State private var filter: Filter = .all
    @State private var query = ""

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All", succeeded = "Succeeded", failed = "Failed", running = "Running"
        var id: String { rawValue }
    }

    private var filtered: [RunRecord] {
        var result = store.history
        switch filter {
        case .all: break
        case .succeeded: result = result.filter { $0.status == .succeeded }
        case .failed: result = result.filter { if case .failed = $0.status { return true }; return false }
        case .running: result = result.filter { $0.status == .running }
        }
        guard !query.isEmpty else { return result }
        return result.filter { $0.taskName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { f in
                    Button(f.rawValue) { filter = f }
                        .buttonStyle(.bordered)
                        .tint(filter == f ? .primary : .secondary)
                }
                Spacer()
                TextField("Search history…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
            }
            .padding(12)

            Divider()

            Table(filtered) {
                TableColumn("Status") { run in
                    Text(run.status.label)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(run.status.color.opacity(0.15))
                        .foregroundStyle(run.status.color)
                        .clipShape(Capsule())
                }
                .width(140)
                TableColumn("Task") { run in Text(run.taskName) }
                TableColumn("Started") { run in
                    Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, design: .monospaced))
                }
                TableColumn("Duration") { run in
                    Text(run.duration > 0 ? String(format: "%.1fs", run.duration) : "—")
                        .font(.system(size: 12, design: .monospaced))
                }
                TableColumn("Exit") { run in
                    Text(run.exitCode.map(String.init) ?? "—")
                        .font(.system(size: 12, design: .monospaced))
                }
            }
        }
        .navigationTitle("Activity")
    }
}

#Preview {
    ActivityView()
        .environmentObject(TaskStore())
        .frame(width: 900, height: 600)
}
