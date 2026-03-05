import SwiftUI

/// Beautifully redesigned weekly grid schedule view with generous spacing and intuitive design
struct WeeklyGridScheduleView: View {
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject private var courseManager: UnifiedCourseManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var academicCalendarManager: AcademicCalendarManager

    // MARK: - State
    @State private var selectedDetail: SelectedScheduleDetail?

    // MARK: - Constants
    private let timeSlotHeight: CGFloat = 85 // Increased to fit all info in 1-hour blocks
    private let hourLabelWidth: CGFloat = 26
    private let dayHeaderHeight: CGFloat = 55
    private let blockPadding: CGFloat = 3
    private let blockCornerRadius: CGFloat = 14
    private let blockInternalPadding: CGFloat = 10

    // MARK: - Computed Properties

    /// Dynamic time range based on actual class schedule
    private var timeRange: (start: Int, end: Int, hours: Int) {
        guard let activeSchedule = scheduleManager.activeSchedule else {
            return (7, 22, 15) // Default: 7 AM to 10 PM
        }

        let courses = courseManager.courses.filter { $0.scheduleId == activeSchedule.id }
        var earliestHour = 23
        var latestHour = 0

        for course in courses {
            for meeting in course.meetings {
                let calendar = Calendar.current
                let startComponents = calendar.dateComponents([.hour], from: meeting.startTime)
                let endComponents = calendar.dateComponents([.hour, .minute], from: meeting.endTime)

                if let startHour = startComponents.hour {
                    earliestHour = min(earliestHour, startHour)
                }
                if let endHour = endComponents.hour, let endMinute = endComponents.minute {
                    // Round up if there are minutes
                    let adjustedEndHour = endMinute > 0 ? endHour + 1 : endHour
                    latestHour = max(latestHour, adjustedEndHour)
                }
            }
        }

        // No classes found, use defaults
        if earliestHour == 23 || latestHour == 0 {
            return (7, 22, 15)
        }

        // Add 1 hour buffer before and after, with reasonable bounds
        let startHour = max(6, earliestHour - 1)
        let endHour = min(23, latestHour + 1)
        let hours = endHour - startHour

        return (startHour, endHour, hours)
    }

    private var startHour: Int { timeRange.start }
    private var endHour: Int { timeRange.end }
    private var hoursInDay: Int { timeRange.hours }

    /// Get active schedule courses grouped by day of week
    private var coursesByDay: [Int: [CourseBlockInfo]] {
        guard let activeSchedule = scheduleManager.activeSchedule else { return [:] }

        let courses = courseManager.courses.filter { $0.scheduleId == activeSchedule.id }
        var result: [Int: [CourseBlockInfo]] = [:]

        // Weekdays only (Mon=2, Tue=3, Wed=4, Thu=5, Fri=6)
        for dayIndex in 2...6 {
            var dayCourses: [CourseBlockInfo] = []

            for course in courses {
                let meetings = course.meetings
                guard !meetings.isEmpty else { continue }

                for meeting in meetings where meeting.daysOfWeek.contains(dayIndex) {
                    // Convert to ScheduleItem to reuse existing detail view
                    let scheduleItem = meeting.toScheduleItem(using: course)
                    let blockInfo = CourseBlockInfo(
                        scheduleItem: scheduleItem,
                        course: course,
                        meeting: meeting,
                        dayIndex: dayIndex
                    )
                    dayCourses.append(blockInfo)
                }
            }

            // Sort by start time
            dayCourses.sort { $0.startMinutes < $1.startMinutes }
            result[dayIndex] = dayCourses
        }

        return result
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Day headers
                dayHeadersRow

                // Time grid
                GeometryReader { geometry in
                    let availableWidth = geometry.size.width
                    let dayColumnWidth = (availableWidth - hourLabelWidth) / 5

                    ZStack(alignment: .topLeading) {
                        // Grid lines
                        gridBackground(dayColumnWidth: dayColumnWidth)

                        // Time labels
                        timeLabelsColumn()

                        // Course blocks
                        HStack(spacing: 0) {
                            Spacer().frame(width: hourLabelWidth)

                            ForEach(2...6, id: \.self) { dayIndex in
                                dayColumn(
                                    dayIndex: dayIndex,
                                    width: dayColumnWidth
                                )
                            }
                        }
                    }
                }
                .frame(height: CGFloat(hoursInDay) * timeSlotHeight)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .background(Color.clear)
        .sheet(item: $selectedDetail) { detail in
            EnhancedCourseDetailView(
                scheduleItem: detail.item,
                scheduleID: detail.scheduleID
            )
            .environmentObject(themeManager)
            .environmentObject(scheduleManager)
            .environmentObject(courseManager)
            .environmentObject(academicCalendarManager)
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var dayHeadersRow: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let dayColumnWidth = (availableWidth - hourLabelWidth) / 5

            HStack(spacing: 0) {
                Spacer().frame(width: hourLabelWidth)

                ForEach(2...6, id: \.self) { dayIndex in
                    let isToday = Calendar.current.component(.weekday, from: Date()) == dayIndex

                    Text(getShortDayName(for: dayIndex))
                        .font(.forma(.subheadline, weight: .bold))
                        .foregroundColor(isToday ? themeManager.currentTheme.primaryColor : .primary)
                        .frame(width: dayColumnWidth, height: 36)
                        .background(
                            ZStack {
                                if isToday {
                                    // Liquid glass effect
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                        )
                }
            }
        }
        .frame(height: 36)
    }

    @ViewBuilder
    private func gridBackground(dayColumnWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<hoursInDay, id: \.self) { hourOffset in
                HStack(spacing: 0) {
                    Spacer().frame(width: hourLabelWidth)

                    ForEach(2...6, id: \.self) { _ in
                        Rectangle()
                            .stroke(Color(.systemGray5).opacity(0.3), lineWidth: 0.5)
                            .frame(width: dayColumnWidth, height: timeSlotHeight)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func timeLabelsColumn() -> some View {
        VStack(spacing: 0) {
            ForEach(0..<hoursInDay, id: \.self) { hourOffset in
                let hour = startHour + hourOffset
                HStack {
                    Text(formatHour(hour))
                        .font(.forma(.caption2, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: hourLabelWidth - 4, alignment: .trailing)
                    Spacer()
                }
                .frame(height: timeSlotHeight, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private func dayColumn(dayIndex: Int, width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            if let courses = coursesByDay[dayIndex] {
                // Render course blocks
                ForEach(courses) { blockInfo in
                    courseBlock(
                        blockInfo: blockInfo,
                        width: width - (blockPadding * 2)
                    )
                }

                // Render breaks between consecutive classes
                ForEach(Array(zip(courses.indices.dropLast(), courses.indices.dropFirst())), id: \.0) { index, nextIndex in
                    let currentBlock = courses[index]
                    let nextBlock = courses[nextIndex]

                    breakIndicator(
                        from: currentBlock.endMinutes,
                        to: nextBlock.startMinutes,
                        width: width - (blockPadding * 2)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func breakIndicator(from endMinutes: Int, to startMinutes: Int, width: CGFloat) -> some View {
        let breakDuration = startMinutes - endMinutes

        // Only show if there's actually a break (more than 5 minutes gap)
        if breakDuration > 5 {
            let offsetY = calculateYOffset(startMinutes: endMinutes)
            let height = calculateHeight(durationMinutes: breakDuration)

            VStack(spacing: 2) {
                // Top arrow
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 6))
                    .foregroundColor(.secondary.opacity(0.4))

                // Dotted line
                Rectangle()
                    .fill(.clear)
                    .frame(height: max(0, height - 28))
                    .overlay(
                        GeometryReader { geo in
                            Path { path in
                                let dashLength: CGFloat = 3
                                let gapLength: CGFloat = 3
                                var currentY: CGFloat = 0

                                while currentY < geo.size.height {
                                    path.move(to: CGPoint(x: geo.size.width / 2, y: currentY))
                                    path.addLine(to: CGPoint(x: geo.size.width / 2, y: min(currentY + dashLength, geo.size.height)))
                                    currentY += dashLength + gapLength
                                }
                            }
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        }
                    )

                // Duration text
                Text(formatBreakDuration(breakDuration))
                    .font(.forma(.caption2, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color(.systemBackground).opacity(0.9))
                    )

                // Bottom arrow
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 6))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .frame(width: width)
            .offset(y: offsetY)
            .padding(.horizontal, blockPadding)
        }
    }

    @ViewBuilder
    private func courseBlock(blockInfo: CourseBlockInfo, width: CGFloat) -> some View {
        let offsetY = calculateYOffset(startMinutes: blockInfo.startMinutes)
        let height = calculateHeight(durationMinutes: blockInfo.durationMinutes)

        Button {
            selectedDetail = SelectedScheduleDetail(
                item: blockInfo.scheduleItem,
                scheduleID: scheduleManager.activeSchedule?.id ?? UUID()
            )
        } label: {
            VStack(spacing: 2) {
                // Line 1: Course code/name with wrapping
                Text(blockInfo.course.courseCode.isEmpty ? blockInfo.course.name : blockInfo.course.courseCode)
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Line 2: Meeting type - Location (smaller, with wrapping)
                if !blockInfo.scheduleItem.location.isEmpty {
                    Text("\(blockInfo.meetingTypeAbbreviation) · \(blockInfo.scheduleItem.location)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(blockInfo.meetingTypeAbbreviation)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }

                Spacer(minLength: 1)

                // Line 3: Time (wrapped - start and end on separate lines)
                VStack(spacing: 0) {
                    Text(blockInfo.startTimeString)
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))

                    Text(blockInfo.endTimeString)
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
                .lineLimit(1)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 5)
            .padding(.vertical, 8)
            .frame(width: width, height: height, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: blockCornerRadius)
                    .fill(blockInfo.course.color)
                    .shadow(color: blockInfo.course.color.opacity(0.3), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .offset(y: offsetY)
        .padding(.horizontal, blockPadding)
    }

    // MARK: - Helper Functions

    private func calculateYOffset(startMinutes: Int) -> CGFloat {
        let startOfDay = startHour * 60
        let minutesFromStart = startMinutes - startOfDay
        return (CGFloat(minutesFromStart) / 60.0) * timeSlotHeight
    }

    private func calculateHeight(durationMinutes: Int) -> CGFloat {
        let baseHeight = (CGFloat(durationMinutes) / 60.0) * timeSlotHeight
        return max(55, baseHeight - (blockPadding * 2)) // Minimum for 3 lines of text
    }

    private func formatHour(_ hour: Int) -> String {
        // Ultra-compact format for space efficiency
        if hour == 12 {
            return "12p"
        } else if hour > 12 {
            return "\(hour - 12)p"
        } else {
            return "\(hour)a"
        }
    }

    private func getShortDayName(for dayIndex: Int) -> String {
        switch dayIndex {
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        default: return ""
        }
    }

    private func formatBreakDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Types

struct CourseBlockInfo: Identifiable {
    let id = UUID()
    let scheduleItem: ScheduleItem
    let course: Course
    let meeting: CourseMeeting
    let dayIndex: Int

    var startMinutes: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: scheduleItem.startTime)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        return hours * 60 + minutes
    }

    var endMinutes: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: scheduleItem.endTime)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        return hours * 60 + minutes
    }

    var durationMinutes: Int {
        return endMinutes - startMinutes
    }

    var compactTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        let start = formatter.string(from: scheduleItem.startTime)

        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "h:mm a"
        let end = endFormatter.string(from: scheduleItem.endTime)

        return "\(start)-\(end)"
    }

    var startTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: scheduleItem.startTime)
    }

    var endTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: scheduleItem.endTime)
    }

    var meetingTypeAbbreviation: String {
        switch meeting.meetingType {
        case .lecture: return "LEC"
        case .tutorial: return "TUT"
        case .lab: return "LAB"
        case .seminar: return "SEM"
        case .workshop: return "WRK"
        case .practicum: return "PRC"
        case .recitation: return "REC"
        case .studio: return "STU"
        case .fieldwork: return "FLD"
        case .clinic: return "CLN"
        case .other: return "OTH"
        }
    }
}

// Reuse existing detail type from ScheduleView
private struct SelectedScheduleDetail: Identifiable {
    let item: ScheduleItem
    let scheduleID: UUID
    var id: ScheduleItem.ID { item.id }
}

// MARK: - Preview

#Preview {
    NavigationView {
        WeeklyGridScheduleView()
            .environmentObject(ScheduleManager())
            .environmentObject(UnifiedCourseManager())
            .environmentObject(ThemeManager())
            .environmentObject(AcademicCalendarManager())
    }
}
