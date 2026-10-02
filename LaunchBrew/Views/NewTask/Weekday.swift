//
//  Weekday.swift
//  ScriptJet
//
//  Created by Yuki Suzuki on 9/8/26.
//

enum Weekday: Int, CaseIterable, Identifiable, Hashable {
    
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6
    case sunday = 7
    

    var id: Self { self }

    var shortName: String {
        switch self {
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        case .sunday: return "S"
        }
    }

    var fullName: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }

    // Custom display order starting on Monday
    static var displayOrder: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }
}





/**
 
 # 1. Unload the service from launchd
 launchctl bootout gui/$(id -u)/[program]


 # 2. Delete the plist file so it doesn't reload on restart
 rm ~/Library/LaunchAgents/com.yuki.myscript.plist

 #3. Check if Unloaded getting “Bad request. ”
 launchctl print gui/$(id -u)/photogenerator

 #4. This opens up folder in Finder
 open -R /tmp/photogenerator.err



 #5.
 top -s 1 -pid $(pgrep photogenerator)
 (Refreshes every 1 second, scoped strictly to your process ID).



 Using pgrep loop (Lightweight terminal watch):
 If you want a minimal terminal display that updates every second:
 while true; do clear; pgrep -fl photogenerator || echo "Task is currently idle/not running"; sleep 1; done



 3. Real-Time launchd Service Inspector (watch)
 If you want to observe launchd's internal metadata state changing (such as state, runs, last exit code, or pid), use the watch utility (installable via Homebrew brew install watch) or a native shell loop:
 while true; do clear; launchctl print gui/$(id -u)/com.yuki.photogenerator | grep -E "(state =|pid =|last exit code =|runs =)"; sleep 1; done





  

 */


/**
 LOAD:
 launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/hello.plist
 
 CHECK
 launchctl print gui/$(id -u)/hello | grep -E "last exit code|runs"
 
 
 IMMIDIATE EXE
 launchctl kickstart -k gui/$(id -u)/hello
 
 
 
 
 
 LOG
 log show --predicate 'process == "launchd" AND eventMessage CONTAINS "hello"' --last 1h
 
 
 
 
 
 
 # 1. Unregister the old schedule
 launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/hello.plist 2>/dev/null

 # 2. Register the updated 15:45 schedule
 launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/hello.plist
 
 
 Step 2: Confirm launchd Has Queued 15:45
 launchctl print gui/$(id -u)/hello | grep -A 6 "descriptor"
 
 
 # Check if the execution counter incremented from 0 to 1
 launchctl print gui/$(id -u)/hello | grep -E "runs|last exit code"

 # Print the script output
 cat /tmp/hello.out
 
 
 
 
 launchctl print gui/$(id -u)/hello | grep -A 8 "event triggers" 
 launchctl print gui/$(id -u)/hello | grep -E "runs|last exit code"
 
 */
