import SwiftUI

// MARK: - Mini Average Pill Component
struct MiniAveragePill: View {
    let title: String
    let value: Double?
    let gpa: Double?
    let usePercentage: Bool
    let color: Color
    let themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.forma(.caption2, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.8))
                .tracking(0.2)

            if let value = value {
                Text(displayValue)
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(.primary)
            } else {
                Text("--")
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 60)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(
                    color: color.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.2 : 0.05),
                    radius: 3 + (colorScheme == .dark ? themeManager.darkModeHueIntensity * 2 : 0),
                    x: 0,
                    y: 1 + (colorScheme == .dark ? themeManager.darkModeHueIntensity * 1 : 0)
                )
        )
    }

    private var displayValue: String {
        guard let value = value else { return "--" }

        if usePercentage {
            return String(format: "%.0f%%", value)
        } else if let gpaValue = gpa {
            return String(format: "%.1f", gpaValue)
        } else {
            return String(format: "%.0f%%", value)
        }
    }

    private var gradeColor: Color {
        guard let value = value else { return .secondary.opacity(0.3) }

        let percentage = usePercentage ? value : (gpa ?? 0) * 25

        switch percentage {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        case 60..<70: return .red
        default: return .red
        }
    }
}
