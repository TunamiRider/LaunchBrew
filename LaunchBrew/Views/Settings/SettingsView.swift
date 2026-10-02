import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }

            NotificationsSettingsTab()
                .tabItem { Label("Notifications", systemImage: "bell") }

            ScriptsAndLogsSettingsTab()
                .tabItem { Label("Scripts & Logs", systemImage: "folder") }

            AdvancedSettingsTab()
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 480, height: 360)
    }
}

private struct GeneralSettingsTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = true
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("retryOnFailure") private var retryOnFailure = false

    var body: some View {
        Form {
            Toggle("Launch ScriptJet at login", isOn: $launchAtLogin)
            Toggle("Show menu-bar icon", isOn: $showMenuBarIcon)
            Toggle("Retry once on failure after 5 minutes", isOn: $retryOnFailure)
        }
        .padding(20)
    }
}

private struct NotificationsSettingsTab: View {
    @AppStorage("notifyOnFailure") private var notifyOnFailure = true
    @AppStorage("notifyOnOverdue") private var notifyOnOverdue = true

    var body: some View {
        Form {
            Toggle("Notify when a task fails", isOn: $notifyOnFailure)
            Toggle("Notify when a task becomes overdue", isOn: $notifyOnOverdue)
        }
        .padding(20)
    }
}

private struct ScriptsAndLogsSettingsTab: View {
    @AppStorage("scriptsFolder") private var scriptsFolder = "~/Scripts"
    @AppStorage("logsFolder") private var logsFolder = "~/Library/Logs/ScriptJet"
    @AppStorage("retentionDays") private var retentionDays = 30

    var body: some View {
        Form {
            LabeledContent("Default scripts folder") {
                HStack {
                    TextField("", text: $scriptsFolder).textFieldStyle(.roundedBorder)
                    Button("Choose…") {}
                }
            }
            LabeledContent("Logs folder") {
                HStack {
                    TextField("", text: $logsFolder).textFieldStyle(.roundedBorder)
                    Button("Choose…") {}
                }
            }
            Picker("Keep run history for", selection: $retentionDays) {
                Text("7 days").tag(7)
                Text("30 days").tag(30)
                Text("90 days").tag(90)
                Text("Forever").tag(0)
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
    }
}

private struct AdvancedSettingsTab: View {
    var body: some View {
        Form {
            Text("Generated LaunchAgent identifiers, environment defaults, and diagnostic export live here.")
                .foregroundStyle(.secondary)
            Button("Reset ScriptJet…", role: .destructive) {}
        }
        .padding(20)
    }
}

#Preview {
    SettingsView()
}
