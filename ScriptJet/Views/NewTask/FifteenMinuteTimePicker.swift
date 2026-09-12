import SwiftUI
import AppKit

struct FifteenMinuteTimePicker: View {
    @Binding var selectedHour: Int   // 0...23
    @Binding var selectedMinute: Int // 0, 15, 30, 45

    private let minutes = [0, 15, 30, 45]

    var body: some View {
        HStack(spacing: 8) {
            // MARK: Hour Column
            VStack(spacing: 2) {
                Button(action: incrementHour) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)

                Text(String(format: "%02d", selectedHour))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.accentColor))
                    // Allows trackpad/mouse scroll wheel over the hour circle
                    .onScrollWheel { deltaY in
                        if deltaY < 0 { incrementHour() }
                        else if deltaY > 0 { decrementHour() }
                    }

                Button(action: decrementHour) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
            }

            Text(":")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)

            // MARK: Minute Column
            VStack(spacing: 2) {
                Button(action: incrementMinute) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)

                Text(String(format: "%02d", selectedMinute))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.accentColor))
                    // Allows trackpad/mouse scroll wheel over the minute circle
                    .onScrollWheel { deltaY in
                        if deltaY < 0 { incrementMinute() }
                        else if deltaY > 0 { decrementMinute() }
                    }

                Button(action: decrementMinute) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
    }

    // MARK: - Actions

    private func incrementHour() {
        selectedHour = (selectedHour + 1) % 24
    }

    private func decrementHour() {
        selectedHour = (selectedHour - 1 + 24) % 24
    }

    private func incrementMinute() {
        if let index = minutes.firstIndex(of: selectedMinute) {
            let nextIndex = (index + 1) % minutes.count
            selectedMinute = minutes[nextIndex]
            if nextIndex == 0 { incrementHour() }
        }
    }

    private func decrementMinute() {
        if let index = minutes.firstIndex(of: selectedMinute) {
            let prevIndex = (index - 1 + minutes.count) % minutes.count
            selectedMinute = minutes[prevIndex]
            if prevIndex == minutes.count - 1 { decrementHour() }
        }
    }
}

// MARK: - AppKit Scroll Wheel Handler Modifier
extension View {
    func onScrollWheel(perform action: @escaping (CGFloat) -> Void) -> some View {
        self.overlay(
            ScrollWheelHandler(onScroll: action)
                .allowsHitTesting(true)
        )
    }
}

private struct ScrollWheelHandler: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollView {
        let view = ScrollView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollView, context: Context) {
        nsView.onScroll = onScroll
    }

    class ScrollView: NSView {
        var onScroll: ((CGFloat) -> Void)?

        override func scrollWheel(with event: NSEvent) {
            // Ignore tiny scroll drift
            if abs(event.scrollingDeltaY) > 0.5 {
                onScroll?(event.scrollingDeltaY)
            }
        }
    }
}

#Preview {
    @Previewable @State var hour = 12
    @Previewable @State var minute = 0
    
    FifteenMinuteTimePicker(selectedHour: $hour, selectedMinute: $minute)
}
