import SwiftUI

struct GradeCurvePopup: View {
    @ObservedObject var course: Course
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var courseManager: UnifiedCourseManager
    @Environment(\.dismiss) private var dismiss

    @State private var curveValue: Double
    @State private var isEditing = false
    @State private var targetGradeText: String = ""
    @FocusState private var isTargetGradeFocused: Bool

    @AppStorage("gradeDecimalPrecision") private var decimalPrecision: Int = 1

    init(course: Course) {
        self.course = course
        _curveValue = State(initialValue: course.gradeCurve)
    }

    private var rawGrade: Double? {
        course.calculateRawGrade()
    }

    private var curvedGrade: Double? {
        guard let raw = rawGrade else { return nil }
        return max(0, raw + curveValue)
    }

    private var gradeColor: Color {
        guard let grade = curvedGrade else { return .gray }
        switch grade {
        case 90...200: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        case 60..<70: return .red
        default: return .red
        }
    }

    private func formatGrade(_ value: Double) -> String {
        String(format: "%.\(decimalPrecision)f", value)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Grade Curve")
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }

            // Grade Display
            VStack(spacing: 8) {
                if let curved = curvedGrade {
                    Text("\(formatGrade(curved))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(gradeColor)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: curved)
                } else {
                    Text("N/A")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }

                if let raw = rawGrade {
                    HStack(spacing: 4) {
                        Text("Raw:")
                            .foregroundColor(.secondary)
                        Text("\(formatGrade(raw))%")
                            .foregroundColor(.secondary)

                        if curveValue != 0 {
                            Text(curveValue > 0 ? "+" : "")
                                .foregroundColor(curveValue > 0 ? .green : .red) +
                            Text(formatGrade(curveValue))
                                .foregroundColor(curveValue > 0 ? .green : .red)
                        }
                    }
                    .font(.forma(.subheadline, weight: .medium))
                }
            }
            .padding(.vertical, 8)

            // Target Grade Input
            if rawGrade != nil {
                HStack(spacing: 12) {
                    Text("Set Final Grade:")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    HStack(spacing: 4) {
                        TextField("", text: $targetGradeText)
                            .font(.forma(.body, weight: .semibold))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                            .focused($isTargetGradeFocused)
                            .onChange(of: targetGradeText) { _, newValue in
                                calculateCurveFromTarget(newValue)
                            }

                        Text("%")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }

            // Curve Slider
            VStack(spacing: 12) {
                HStack {
                    Text("Curve Adjustment")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(curveValue >= 0 ? "+\(formatGrade(curveValue))" : formatGrade(curveValue))
                        .font(.forma(.body, weight: .bold))
                        .foregroundColor(curveValue > 0 ? .green : (curveValue < 0 ? .red : .secondary))
                        .monospacedDigit()
                }

                HStack(spacing: 16) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            curveValue = max(-50, curveValue - 0.5)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red.opacity(0.8))
                    }

                    Slider(value: $curveValue, in: -50...50, step: 0.5)
                        .tint(curveValue >= 0 ? .green : .red)

                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            curveValue = min(50, curveValue + 0.5)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green.opacity(0.8))
                    }
                }

                // Quick buttons
                HStack(spacing: 8) {
                    ForEach([-5.0, -2.0, 0.0, 2.0, 5.0], id: \.self) { value in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                curveValue = value
                            }
                        } label: {
                            Text(value >= 0 ? "+\(Int(value))" : "\(Int(value))")
                                .font(.forma(.caption, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(curveValue == value ?
                                              (value >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2)) :
                                              Color.secondary.opacity(0.1))
                                )
                                .foregroundColor(curveValue == value ?
                                                 (value >= 0 ? .green : .red) :
                                                 .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )

            // Save Button
            Button {
                saveCurve()
            } label: {
                Text("Save Curve")
                    .font(.forma(.body, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.currentTheme.primaryColor)
                    )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 20)
    }

    private func calculateCurveFromTarget(_ targetText: String) {
        guard let targetGrade = Double(targetText),
              let raw = rawGrade else { return }

        // Calculate the curve needed: curve = target - raw
        let neededCurve = targetGrade - raw

        // Clamp to valid range
        let clampedCurve = max(-50, min(50, neededCurve))

        withAnimation(.spring(response: 0.3)) {
            curveValue = clampedCurve
        }
    }

    private func saveCurve() {
        course.gradeCurve = curveValue
        Task {
            do {
                try await courseManager.updateCourse(course)
                print("GradeCurvePopup: Successfully saved curve: \(curveValue)")
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("GradeCurvePopup: Failed to save curve: \(error)")
                // Still dismiss even on error since local change was made
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    let course = Course(
        scheduleId: UUID(),
        name: "Computer Science",
        assignments: [
            Assignment(courseId: UUID(), name: "Midterm", grade: "85", weight: "30"),
            Assignment(courseId: UUID(), name: "Final", grade: "90", weight: "40")
        ],
        gradeCurve: 2.0
    )

    return ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()

        GradeCurvePopup(course: course)
            .environmentObject(ThemeManager())
            .environmentObject(UnifiedCourseManager())
    }
}
