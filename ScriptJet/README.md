# ScriptJet — SwiftUI Source

Implements the six MVP screens as real SwiftUI views, matching the earlier HTML concept 1:1 in structure and the green/amber/red reliability language.

## How to open this

1. In Xcode: **File → New → Project → macOS → App**. Name it `ScriptJet`, interface **SwiftUI**, language **Swift**. Deployment target **macOS 13 (Ventura)** or later (uses `NavigationSplitView`, `Table`, and `MenuBarExtra`).
2. Delete the generated `ContentView.swift` and `ScriptJetApp.swift`.
3. Drag this whole `ScriptJet` folder into the project navigator (check "Copy items if needed").
4. Build and run. The main window opens on the Tasks Workspace; a lightning-bolt icon appears in the menu bar — click it for the popover.

## What's real vs. placeholder

- All views, layout, states, and the status color system are fully implemented and match the design.
- `TaskStore` holds sample data in memory (`SampleData.swift`) standing in for the real scheduler. `runNow(_:)` and `togglePause(_:)` are stubbed — wire these to your LaunchAgent/daemon layer.
- "Reveal Script," "Reveal Plist," and "Open Logs" buttons are stubbed; wire to `NSWorkspace.shared.activateFileViewerSelecting([url])`.
- The New Task sheet collects script path, arguments, frequency, and time, then shows a canned "test succeeded" step — replace with your actual test-run execution and plist generation.

## File map

```
ScriptJetApp.swift              App entry: main window + MenuBarExtra
Models/ScriptTask.swift         Task model + TaskStatus (drives status color everywhere)
Models/RunRecord.swift          One execution record
Support/StatusStyle.swift       Color palette + StatusDot + StatusBanner
Support/SampleData.swift        Mock tasks & history for previews/testing
Support/TaskStore.swift         ObservableObject data layer (swap for real scheduler)
Views/Workspace/                Screen 1 — Tasks Workspace (sidebar, list, inspector)
Views/NewTask/                  Screen 2 — New Task sheet (stepped flow)
Views/Detail/                   Screen 3 — Task Detail (Overview/Schedule/Logs/Advanced)
Views/Activity/                 Screen 4 — Run History (filterable table)
Views/Settings/                 Screen 5 — Settings window
Views/MenuBar/                  Screen 6 — Menu-bar popover
```

Every file has a `#Preview` block, so you can Option-click into any one and iterate on it in Xcode's canvas without running the full app.
