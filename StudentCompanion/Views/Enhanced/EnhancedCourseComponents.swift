import SwiftUI

// MARK: - Credit Hour Stepper

struct ModernCreditStepper: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let courseColor: Color

    var body: some View {
        HStack {
            Button(action: {
                if value > range.lowerBound {
                    value -= step
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.forma(.title2))
                    .foregroundColor(value > range.lowerBound ? courseColor : .secondary)
            }
            .disabled(value <= range.lowerBound)

            Spacer()

            VStack(spacing: 4) {
                Text(String(format: value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", value))
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.primary)

                Text("credits")
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                if value < range.upperBound {
                    value += step
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.forma(.title2))
                    .foregroundColor(value < range.upperBound ? courseColor : .secondary)
            }
            .disabled(value >= range.upperBound)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Icon Button

struct ModernIconButton: View {
    let symbolName: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.forma(.callout))
                .foregroundColor(isSelected ? .white : color)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? color : color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(color.opacity(isSelected ? 0.3 : 0.3), lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(
                            color: isSelected ? color.opacity(0.3) : .clear,
                            radius: isSelected ? 6 : 0,
                            x: 0,
                            y: isSelected ? 3 : 0
                        )
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Color Button

struct ModernColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: isSelected ? 3 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 2)
                )
                .scaleEffect(isSelected ? 1.2 : 1.0)
                .shadow(color: isSelected ? color.opacity(0.4) : color.opacity(0.2), radius: isSelected ? 8 : 4, x: 0, y: isSelected ? 4 : 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meeting Row

struct ModernMeetingRow: View {
    let meeting: CourseMeeting
    let courseColor: Color
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(meeting.meetingType.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(meeting.meetingType.color.opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: meeting.meetingType.iconName)
                        .font(.forma(.title3, weight: .semibold))
                        .foregroundColor(meeting.meetingType.color)
                }
                .scaleEffect(1.1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.displayName)
                        .font(.forma(.headline, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("\(String(format: meeting.meetingLabel ?? ""))")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(courseColor)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                                    .overlay(
                                        Circle()
                                            .stroke(courseColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)

                    Text(meeting.timeRange)
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }

                if !meeting.daysString.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                            .frame(width: 16)

                        Text(meeting.daysString)
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Course Preview Card

struct ModernCoursePreviewCard: View {
    let courseName: String
    let courseCode: String
    let section: String
    let creditHours: Double
    let iconName: String
    let emoji: String?
    let color: Color
    let meetings: [CourseMeeting]

    private func calculateTotalWeeklyHours(for meetings: [CourseMeeting]) -> Double {
        let totalHours = meetings.reduce(0) { total, meeting in
            let duration = meeting.endTime.timeIntervalSince(meeting.startTime) / 3600.0

            let weeklyOccurrences: Double
            if meeting.isRotating {
                weeklyOccurrences = 0.5
            } else if meeting.daysOfWeek.isEmpty {
                weeklyOccurrences = 1.0
            } else {
                weeklyOccurrences = Double(meeting.daysOfWeek.count)
            }

            let weeklyHours = duration * weeklyOccurrences
            print("Meeting: \(meeting.displayName), Duration: \(duration)h, Days: \(meeting.daysOfWeek.count), Weekly: \(weeklyHours)h")

            return total + weeklyHours
        }

        print("Total weekly hours calculated: \(totalHours)")
        return totalHours
    }

    private func calculateUniqueDays(for meetings: [CourseMeeting]) -> Int {
        let rotatingMeetings = meetings.filter { $0.isRotating }
        let regularMeetings = meetings.filter { !$0.isRotating }

        let regularDays = Set(regularMeetings.flatMap { $0.daysOfWeek }).count
        let rotatingCount = rotatingMeetings.count > 0 ? 2 : 0

        let totalDays = regularDays + rotatingCount
        print("Regular days: \(regularDays), Rotating days: \(rotatingCount), Total: \(totalDays)")

        return max(totalDays, 0)
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.3), lineWidth: 2)
                        )

                    Group {
                        if let emoji = emoji, !emoji.isEmpty {
                            Text(emoji)
                                .font(.system(size: 36))
                        } else {
                            Image(systemName: iconName)
                                .font(.forma(.title, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                // PERF FIX: Reduced shadow radius
                .shadow(color: color.opacity(0.25), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 6) {
                    Text(courseName)
                        .font(.forma(.title2, weight: .bold))
                        .foregroundColor(.primary)

                    if !courseCode.isEmpty {
                        Text("\(courseCode)\(!section.isEmpty ? " - Section \(section)" : "")")
                            .font(.forma(.headline, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Text("\(String(format: creditHours.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", creditHours)) credit hours")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            if !meetings.isEmpty {
                VStack(spacing: 12) {
                    Divider()
                        .overlay(color.opacity(0.3))

                    HStack {
                        VStack(spacing: 4) {
                            Text("\(meetings.count)")
                                .font(.forma(.title2, weight: .bold))
                                .foregroundColor(.primary)

                            Text("Meetings")
                                .font(.forma(.caption))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(spacing: 4) {
                            Text(String(format: "%.1f", calculateTotalWeeklyHours(for: meetings)))
                                .font(.forma(.title2, weight: .bold))
                                .foregroundColor(.primary)

                            Text("Hours/Week")
                                .font(.forma(.caption))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(spacing: 4) {
                            Text("\(calculateUniqueDays(for: meetings))")
                                .font(.forma(.title2, weight: .bold))
                                .foregroundColor(.primary)

                            Text("Days")
                                .font(.forma(.caption))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.2), lineWidth: 2)
                )
        )
        // PERF FIX: Reduced shadow radius
        .shadow(color: color.opacity(0.12), radius: 6, x: 0, y: 3)
    }
}
