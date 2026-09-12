import SwiftUI

extension Color {
    // Brand
    static let accentJet = Color(red: 0.353, green: 0.333, blue: 0.878)   // #5A55E0

    // Status language — used consistently across every screen.
    static let statusGreen     = Color(red: 0.122, green: 0.643, blue: 0.388) // #1FA463
    static let statusGreenSoft = Color(red: 0.906, green: 0.965, blue: 0.933) // #E7F6EE
    static let statusAmber     = Color(red: 0.788, green: 0.541, blue: 0.106) // #C98A1B
    static let statusAmberSoft = Color(red: 0.984, green: 0.945, blue: 0.871) // #FBF1DE
    static let statusRed       = Color(red: 0.839, green: 0.278, blue: 0.235) // #D6473C
    static let statusRedSoft   = Color(red: 0.984, green: 0.918, blue: 0.910) // #FBEAE8

    static let panelSunken = Color(nsColor: .underPageBackgroundColor)
}

/// A small filled dot used everywhere a task's health needs to be scannable
/// at a glance — sidebar rows, list rows, popover rows.
struct StatusDot: View {
    let status: TaskStatus
    var size: CGFloat = 9

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
    }
}

/// The colored banner used in the inspector and Task Detail overview to
/// state, in one glance, whether the task is healthy.
struct StatusBanner: View {
    let status: TaskStatus
    let title: String
    let subtitle: String

    private var softColor: Color {
        switch status {
        case .succeeded, .running: return .statusGreenSoft
        case .overdue, .paused:    return .statusAmberSoft
        case .failed:               return .statusRedSoft
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(status.color)
                Image(systemName: iconName)
                    .foregroundStyle(.white)
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(softColor)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var iconName: String {
        switch status {
        case .succeeded, .running: return "checkmark"
        case .overdue, .paused:    return "clock"
        case .failed:               return "exclamationmark"
        }
    }
}
