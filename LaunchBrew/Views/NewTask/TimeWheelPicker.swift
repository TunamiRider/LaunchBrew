//
//  TimeWheelPicker.swift
//  LaunchBrew
//
//  Created by Yuki Suzuki on 9/8/26.
//

import SwiftUI

/// A single vertically-scrolling wheel of values that snaps to the centered
/// item — the macOS equivalent of iOS's `.wheel` picker style, which doesn't
/// exist on this platform. Requires macOS 14+ (uses `scrollPosition`/
/// `scrollTargetBehavior`).
struct WheelColumn: View {
    let values: [Int]
    @Binding var selection: Int
    var format: (Int) -> String = { String(format: "%02d", $0) }

    private let rowHeight: CGFloat = 34
    private let visibleRows: CGFloat = 3

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(values, id: \.self) { value in
                    Text(format(value))
                        .font(.system(size: 17, weight: value == selection ? .semibold : .regular, design: .monospaced))
                        .foregroundStyle(value == selection ? Color.primary : .secondary)
                        .frame(height: rowHeight)
                        .id(value)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(
            id: Binding<Int?>(
                get: { selection },
                set: { newValue in if let newValue { selection = newValue } }
            ),
            anchor: .center
        )
        .scrollTargetBehavior(.viewAligned)
        .frame(width: 52, height: rowHeight * visibleRows)
        .safeAreaPadding(.vertical, rowHeight) // lets first/last values reach center
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
                .frame(height: rowHeight)
                .allowsHitTesting(false)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.25),
                    .init(color: .black, location: 0.75),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}

/// Pairs an hour wheel (0–23) with a minute wheel restricted to 15-minute
/// steps (00 / 15 / 30 / 45), bound to a single `Date`. Matches the 24-hour
/// "HH:mm" format already used elsewhere in LaunchBrew (e.g. "Daily · 02:00").
struct TimeWheelPicker: View {
    @Binding var date: Date

    @State private var hour: Int = 2
    @State private var minute: Int = 0

    private let hours = Array(0...23)
    private let minutes = [0, 15, 30, 45]

    var body: some View {
        HStack(spacing: 6) {
            WheelColumn(values: hours, selection: $hour)
            Text(":")
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            WheelColumn(values: minutes, selection: $minute)
        }
        .onAppear { syncWheelsFromDate() }
        .onChange(of: hour) { _, _ in syncDateFromWheels() }
        .onChange(of: minute) { _, _ in syncDateFromWheels() }
    }

    private func syncWheelsFromDate() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        hour = comps.hour ?? 2
        // Snap whatever minute the incoming date has to the nearest 15-minute step.
        minute = minutes.min(by: { abs($0 - (comps.minute ?? 0)) < abs($1 - (comps.minute ?? 0)) }) ?? 0
    }

    private func syncDateFromWheels() {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
        date = Calendar.current.date(from: comps) ?? date
    }
}

//#Preview {
//    @Previewable @State var date = Date()
//    TimeWheelPicker(date: $date)
//        .padding()
//}
