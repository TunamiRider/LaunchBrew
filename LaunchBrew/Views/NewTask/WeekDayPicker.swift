//
//  WeekDayPicker.swift
//  LaunchBrew
//
//  Created by Yuki Suzuki on 9/8/26.
//

import SwiftUI

struct WeekdayPicker: View {
    // Stores selected weekday indices (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
    @Binding var selectedDays: Set<Weekday>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            
            HStack(spacing: 8) {
                ForEach(Weekday.displayOrder, id: \.id) { day in
                    let isSelected = selectedDays.contains(day.id)
                    
                    Button(action: {
                        toggleDay(day)
                    }) {
                        Text(day.shortName)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                            .foregroundColor(isSelected ? .white : .primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(day.fullName) // Displays tooltip on hover
                    // Instant color/style transition for the button itself
                    .animation(.none, value: isSelected)
                }
            }
            // Warning message when no days are selected
            if selectedDays.isEmpty {
                Text("Please select at least one day")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        //.animation(.default, value: selectedDays.isEmpty)
    }

    private func toggleDay(_ dayID: Weekday) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if selectedDays.contains(dayID) {
                selectedDays.remove(dayID)
            } else {
                selectedDays.insert(dayID)
            }
            
        }
    }
}


//#Preview{
//    @Previewable @State var selectedDays: Set<Weekday> = []
//    
//    VStack(alignment: .leading, spacing: 12) {
//                Text("Repeat Schedule")
//                    .font(.headline)
//                
//                WeekdayPicker(selectedDays: $selectedDays)
//
//        Text("Selected day indices: \(selectedDays.map(\.fullName).joined(separator: ", "))")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//        
//            }
//            .padding()
//}
