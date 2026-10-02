//
//  ScheduleFrequency.swift
//  LaunchBrew
//
//  Created by Yuki Suzuki on 9/10/26.
//

enum ScheduleFrequency: String, CaseIterable, Identifiable {
    //case daily = "Daily"         // StartCalendarInterval: { Hour, Minute }
    case weekly = "Weekly"       // StartCalendarInterval: [{ Weekday, Hour, Minute }]
    // case monthly = "Monthly"     // StartCalendarInterval: { Day, Hour, Minute }
    case interval = "Interval"   // StartInterval: Seconds
    
    var id: String { rawValue }
    
    
    static var displayFrequency: [ScheduleFrequency] {
        [.weekly,  .interval] // .daily,  .monthly,
    }
}
