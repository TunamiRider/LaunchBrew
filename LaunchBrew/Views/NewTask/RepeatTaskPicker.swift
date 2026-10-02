//
//  RepeatTaskPicker.swift
//  LaunchBrew
//
//  Created by Yuki Suzuki on 9/8/26.
//

import SwiftUI

struct RepeatTaskPicker: View {
    @Binding var isRepeating: Bool
    @Binding var intervalMinutes: Int // Default value should be >= 5

    var body: some View {
        HStack(spacing: 10) {//alignment: .leading,
            // MARK: Toggle Switch
//            Toggle("Repeat Task", isOn: $isRepeating)
//                .toggleStyle(.switch)

            // MARK: Interval Selection (Shown only when enabled)
            if isRepeating {
                HStack(spacing: 8) {
                    Text("Repeat Task Every")
                        .foregroundColor(.secondary)

                    Stepper(
                        value: $intervalMinutes,
                        in: 5...1440, // Range: 5 mins up to 24 hours (1440 mins)
                        step: 5       // Increments in 5-minute steps
                    ) {
                        Text("\(intervalMinutes) minutes")
                            .font(.system(.body, design: .monospaced))
                            .bold()
                    }
                    .frame(width: 170)
                }
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.default, value: isRepeating)
        .onChange(of: isRepeating) { oldValue, newValue in
            // Enforce minimum of 5 minutes when enabled
            if newValue && intervalMinutes < 5 {
                intervalMinutes = 5
            }
        }
    }
}
