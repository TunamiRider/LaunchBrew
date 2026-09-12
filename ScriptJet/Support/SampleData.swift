import Foundation

enum SampleData {
    static let now = Date()

    static func hoursAgo(_ h: Double) -> Date { now.addingTimeInterval(-h * 3600) }
    static func hoursFromNow(_ h: Double) -> Date { now.addingTimeInterval(h * 3600) }

    static let backupRuns: [RunRecord] = [
        RunRecord(id: UUID(), taskName: "Nightly Photo Backup", startedAt: hoursAgo(2), duration: 0.8, status: .failed(exitCode: 1), exitCode: 1),
        RunRecord(id: UUID(), taskName: "Nightly Photo Backup", startedAt: hoursAgo(26), duration: 252, status: .succeeded, exitCode: 0),
        RunRecord(id: UUID(), taskName: "Nightly Photo Backup", startedAt: hoursAgo(50), duration: 238, status: .succeeded, exitCode: 0),
        RunRecord(id: UUID(), taskName: "Nightly Photo Backup", startedAt: hoursAgo(74), duration: 245, status: .succeeded, exitCode: 0)
    ]

    static let tasks: [ScriptTask] = [
        ScriptTask(
            id: UUID(),
            name: "Nightly Photo Backup",
            scriptPath: "~/Scripts/backup_photos.sh",
            arguments: "--source ~/Pictures --dest /Volumes/Backup",
            folder: "Backups",
            scheduleDescription: "Daily · 02:00",
            nextRunDate: hoursFromNow(22),
            lastRunDate: hoursAgo(2),
            lastDuration: 0.8,
            status: .failed(exitCode: 1),
            lastErrorExcerpt: """
            rsync: change_dir "/Volumes/Backup" failed: No such file or directory (2)
            rsync error: some files/attrs were not transferred
            backup_photos.sh: exit code 1
            """,
            isPaused: false,
            runs: backupRuns
        ),
        ScriptTask(
            id: UUID(),
            name: "Postgres Dump → S3",
            scriptPath: "~/Scripts/pg_dump_s3.py",
            arguments: "--bucket nightly-dumps",
            folder: "Backups",
            scheduleDescription: "Daily · 23:00",
            nextRunDate: hoursFromNow(3),
            lastRunDate: hoursAgo(21),
            lastDuration: 42,
            status: .succeeded,
            lastErrorExcerpt: nil,
            isPaused: false,
            runs: []
        ),
        ScriptTask(
            id: UUID(),
            name: "Thumbnail Regeneration",
            scriptPath: "~/Scripts/thumbs.sh",
            arguments: "",
            folder: "Media Pipeline",
            scheduleDescription: "Every 6 hours",
            nextRunDate: hoursAgo(4),
            lastRunDate: hoursAgo(28),
            lastDuration: nil,
            status: .overdue,
            lastErrorExcerpt: nil,
            isPaused: false,
            runs: []
        ),
        ScriptTask(
            id: UUID(),
            name: "Weekly Analytics Export",
            scriptPath: "~/Scripts/export_report.rb",
            arguments: "",
            folder: "Reports",
            scheduleDescription: "Weekly · Mon 09:00",
            nextRunDate: hoursFromNow(96),
            lastRunDate: hoursAgo(48),
            lastDuration: 3.1,
            status: .failed(exitCode: 127),
            lastErrorExcerpt: "export_report.rb: command not found: ruby\nexit code 127",
            isPaused: false,
            runs: []
        ),
        ScriptTask(
            id: UUID(),
            name: "Clear Xcode DerivedData",
            scriptPath: "~/Scripts/clean_xcode.sh",
            arguments: "",
            folder: "Dev Utilities",
            scheduleDescription: "Weekly · Sun 06:00",
            nextRunDate: hoursFromNow(144),
            lastRunDate: hoursAgo(70),
            lastDuration: 11,
            status: .succeeded,
            lastErrorExcerpt: nil,
            isPaused: false,
            runs: []
        ),
        ScriptTask(
            id: UUID(),
            name: "Cloudflare Cache Purge",
            scriptPath: "curl → api.cloudflare.com",
            arguments: "",
            folder: "Dev Utilities",
            scheduleDescription: "Daily · 01:30",
            nextRunDate: hoursFromNow(12),
            lastRunDate: hoursAgo(8),
            lastDuration: 1.2,
            status: .succeeded,
            lastErrorExcerpt: nil,
            isPaused: false,
            runs: []
        )
    ]

    static let history: [RunRecord] = [
        RunRecord(id: UUID(), taskName: "Nightly Photo Backup", startedAt: hoursAgo(2), duration: 0.8, status: .failed(exitCode: 1), exitCode: 1),
        RunRecord(id: UUID(), taskName: "Cloudflare Cache Purge", startedAt: hoursAgo(2.5), duration: 1.2, status: .succeeded, exitCode: 0),
        RunRecord(id: UUID(), taskName: "Thumbnail Regeneration", startedAt: hoursAgo(4), duration: 0, status: .overdue, exitCode: nil),
        RunRecord(id: UUID(), taskName: "Postgres Dump → S3", startedAt: hoursAgo(21), duration: 42, status: .succeeded, exitCode: 0),
        RunRecord(id: UUID(), taskName: "Nightly Photo Backup", startedAt: hoursAgo(26), duration: 252, status: .succeeded, exitCode: 0),
        RunRecord(id: UUID(), taskName: "Weekly Analytics Export", startedAt: hoursAgo(48), duration: 3.1, status: .failed(exitCode: 127), exitCode: 127),
        RunRecord(id: UUID(), taskName: "Clear Xcode DerivedData", startedAt: hoursAgo(70), duration: 11, status: .succeeded, exitCode: 0),
        RunRecord(id: UUID(), taskName: "Nightly Photo Backup", startedAt: hoursAgo(74), duration: 245, status: .succeeded, exitCode: 0)
    ]
}
