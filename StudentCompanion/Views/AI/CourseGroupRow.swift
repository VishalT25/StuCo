import SwiftUI

// MARK: - Course Group Row + Meetings (List-optimized)
struct CourseGroupRow: View {
    @EnvironmentObject private var themeManager: ThemeManager

    let group: CourseGroup
    let scheduleType: ScheduleType
    @Binding var importData: AIImportData?
    let onColorChange: (Color) -> Void
    let onTitleChange: (String) -> Void
    let onAddMeeting: () -> Void
    let onRemoveMeeting: (Int) -> Void
    let onUpdateMeeting: (Int, ScheduleItem) -> Void
    let onEditMeeting: (ScheduleItem) -> Void

    @State private var isExpanded = true
    @State private var courseName: String
    @State private var courseColor: Color

    init(
        group: CourseGroup,
        scheduleType: ScheduleType,
        importData: Binding<AIImportData?>,
        onColorChange: @escaping (Color) -> Void,
        onTitleChange: @escaping (String) -> Void,
        onAddMeeting: @escaping () -> Void,
        onRemoveMeeting: @escaping (Int) -> Void,
        onUpdateMeeting: @escaping (Int, ScheduleItem) -> Void,
        onEditMeeting: @escaping (ScheduleItem) -> Void
    ) {
        self.group = group
        self.scheduleType = scheduleType
        self._importData = importData
        self.onColorChange = onColorChange
        self.onTitleChange = onTitleChange
        self.onAddMeeting = onAddMeeting
        self.onRemoveMeeting = onRemoveMeeting
        self.onUpdateMeeting = onUpdateMeeting
        self.onEditMeeting = onEditMeeting

        self._courseName = State(initialValue: group.name)
        self._courseColor = State(initialValue: group.color)
    }

    var body: some View {
        VStack(spacing: 8) {
            header

            if isExpanded {
                ForEach(group.indices, id: \.self) { idx in
                    if let item = importData?.parsedItems[safe: idx] {
                        MeetingRowSummaryWithRotation(
                            meeting: item,
                            scheduleType: scheduleType,
                            rotationDay: importData?.rotationAssignmentByItemID[item.id] ?? 1,
                            onEdit: { onEditMeeting(item) },
                            onRemove: { onRemoveMeeting(idx) }
                        )
                        .environmentObject(themeManager)
                        .id(item.id)
                    }
                }

                Button(action: onAddMeeting) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.forma(.subheadline, weight: .semibold))
                        Text("Add Meeting")
                            .font(.forma(.subheadline, weight: .semibold))
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.25), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .onChange(of: courseName) { old, new in
            if new != old && new != group.name { onTitleChange(new) }
        }
        .onChange(of: courseColor) { old, new in
            if new != old { onColorChange(new) }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ColorPicker("", selection: $courseColor)
                .labelsHidden()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Course Name", text: $courseName)
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(.primary)
                    .textFieldStyle(.plain)

                Text("\(group.indices.count) meeting\(group.indices.count == 1 ? "" : "s")")
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                isExpanded.toggle()
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Updated Meeting Row with Rotation Support
struct MeetingRowSummaryWithRotation: View {
    @EnvironmentObject private var themeManager: ThemeManager

    let meeting: ScheduleItem
    let scheduleType: ScheduleType
    let rotationDay: Int
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title.isEmpty ? "Untitled Meeting" : meeting.title)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("\(meeting.startTime.formatted(date: .omitted, time: .shortened)) - \(meeting.endTime.formatted(date: .omitted, time: .shortened))")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if scheduleType == .rotating {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                                .font(.forma(.caption2))
                                .foregroundColor(rotationDay == 1 ? .blue : .purple)

                            Text("Day \(rotationDay)")
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(rotationDay == 1 ? .blue : .purple)
                                )
                        }
                    } else if !meeting.daysOfWeek.isEmpty {
                        Text("• \(meeting.daysOfWeek.map { $0.abbreviation }.joined(separator: " "))")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.forma(.caption, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(themeManager.currentTheme.primaryColor.opacity(0.12)))
                }
                .buttonStyle(.plain)

                Button(action: onRemove) {
                    Image(systemName: "trash.fill")
                        .font(.forma(.caption, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(.red))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6).opacity(0.6))
        )
    }
}
