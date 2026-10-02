import SwiftUI
import SwiftData
import Combine
struct ActivityView: View {
    //@EnvironmentObject var store: TaskStore
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScriptTask.name) private var scriptTaskList: [ScriptTask]
    @State private var filter: Filter = .all
    @State private var query = ""
    @State private var showingClearConfirmation = false
    
    let symcTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All", succeeded = "Succeeded", failed = "Failed", running = "Running"
        var id: String { rawValue }
    }

    private var filtered: [RunRecord] {
        var result = scriptTaskList.flatMap{ $0.runs }.sorted{ $0.startedAt > $1.startedAt }
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
                
                // Clear History Button
                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(filtered.isEmpty && scriptTaskList.allSatisfy { $0.runs.isEmpty })
                
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
        .alert("Clear Activity History?", isPresented: $showingClearConfirmation) {
                    Button("Clear All", role: .destructive) {
                        clearAllRunRecords()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will permanently delete all run history logs across all tasks.")
                }
        .onReceive(symcTimer){ _ in
            for task in scriptTaskList {
                LaunchAgentManager.syncExecutionHistory(for: task, modelContext: modelContext)
            }
        }
    }
    
    private func clearAllRunRecords(){
        for task in scriptTaskList {
            
            for record in task.runs {
                modelContext.delete(record)
            }
            
            task.runs.removeAll()
        }
        
        try? modelContext.save()
    }
}

//#Preview {
//    ActivityView()
//        //.environmentObject(TaskStore())
//        .frame(width: 900, height: 600)
//}
