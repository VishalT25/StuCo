import SwiftUI

struct TodayScheduleView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject private var courseManager: UnifiedCourseManager
    @State private var showingAddSchedule = false
    @State private var selectedSchedule: ScheduleItem?
    var onNavigateToSchedule: (() -> Void)? = nil

    // PERFORMANCE FIX: Cache the schedule items to prevent expensive recomputation on every render
    @State private var cachedScheduleItems: [ScheduleItem] = []
    @State private var lastScheduleUpdateDate: Date = .distantPast
    @State private var lastActiveScheduleID: UUID?
    @State private var lastCourseCount: Int = 0

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private var currentTime: Date {
        Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Schedule")
                            .font(.forma(.title2, weight: .bold))
                            .foregroundColor(.white)

                        if !cachedScheduleItems.isEmpty {
                            Text("\(cachedScheduleItems.count) \(cachedScheduleItems.count == 1 ? "class" : "classes") today")
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Spacer()

                    Group {
                        if let onNavigateToSchedule {
                            Button(action: onNavigateToSchedule) {
                                Image(systemName: "arrow.right")
                                    .font(.forma(.body, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(.white.opacity(0.2))
                                    )
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(value: AppRoute.schedule) {
                                Image(systemName: "arrow.right")
                                    .font(.forma(.body, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(.white.opacity(0.2))
                                    )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Content Section
            if cachedScheduleItems.isEmpty {
                emptyStateView
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            } else {
                scheduleListView
                    .padding(.bottom, 12)
            }
        }
        .background(
            ZStack {
                // Base gradient
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.primaryColor.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Glass morphism overlay
                RoundedRectangle(cornerRadius: 28)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.2),
                                        .white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }
        )
        .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.3), radius: 20, x: 0, y: 8)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            refreshCacheIfNeeded()
        }
        .onChange(of: scheduleManager.activeScheduleID) { _, _ in
            refreshCacheIfNeeded()
        }
        .onChange(of: courseManager.courses.count) { _, _ in
            // Only refresh if course count changed - avoid recomputing for grade/assignment changes
            refreshCacheIfNeeded()
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }

            VStack(spacing: 6) {
                Text("All clear today")
                    .font(.forma(.title3, weight: .semibold))
                    .foregroundColor(.white)

                Text("No classes scheduled. Time to relax!")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Schedule List View
    private var scheduleListView: some View {
        VStack(spacing: 0) {
            ForEach(Array(cachedScheduleItems.enumerated()), id: \.element.id) { index, item in
                CompactScheduleItemView(
                    item: item,
                    scheduleID: activeScheduleID()
                )
                .environmentObject(themeManager)
                .environmentObject(scheduleManager)
            }
        }
    }

    /// PERFORMANCE FIX: Only recompute schedule when actually needed
    private func refreshCacheIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentActiveID = scheduleManager.activeScheduleID
        let currentCourseCount = courseManager.courses.count

        // Check if we need to refresh: new day, different schedule, or course count changed
        let needsRefresh = !calendar.isDate(lastScheduleUpdateDate, inSameDayAs: today) ||
                          lastActiveScheduleID != currentActiveID ||
                          lastCourseCount != currentCourseCount

        if needsRefresh {
            cachedScheduleItems = computeTodaysScheduleItems()
            lastScheduleUpdateDate = today
            lastActiveScheduleID = currentActiveID
            lastCourseCount = currentCourseCount
        }
    }
    
    /// PERFORMANCE FIX: Renamed from todaysScheduleItems and removed debug prints
    /// This is called only when cache needs refreshing, not on every render
    private func computeTodaysScheduleItems() -> [ScheduleItem] {
        guard let activeSchedule = scheduleManager.activeSchedule else {
            return []
        }

        let today = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: today)

        // Skip weekends
        if weekday == 1 || weekday == 7 {
            return []
        }

        // Check semester bounds
        if let start = activeSchedule.semesterStartDate,
           let end = activeSchedule.semesterEndDate {
            let d = cal.startOfDay(for: today)
            let s = cal.startOfDay(for: start)
            let e = cal.startOfDay(for: end)
            if d < s || d > e {
                return []
            }
        }

        let academicCalendar = scheduleManager.getAcademicCalendar(for: activeSchedule, from: academicCalendarManager)

        // Check if today is a break day
        if let calendar = academicCalendar, calendar.isBreakDay(today) {
            return []
        }

        // Get schedule items from course meetings
        var allItems: [ScheduleItem] = []
        let coursesInSchedule = courseManager.courses.filter { $0.scheduleId == activeSchedule.id }

        for course in coursesInSchedule {
            for meeting in course.meetings {
                if meeting.shouldAppear(on: today, in: activeSchedule, calendar: academicCalendar) {
                    let item = ScheduleItem(
                        id: meeting.id,
                        title: "\(course.name) - \(meeting.displayName)",
                        startTime: meeting.startTime,
                        endTime: meeting.endTime,
                        daysOfWeek: meeting.daysOfWeek.compactMap { DayOfWeek(rawValue: $0) },
                        location: meeting.location.isEmpty ? course.location : meeting.location,
                        instructor: meeting.instructor.isEmpty ? course.instructor : meeting.instructor,
                        color: course.color,
                        isLiveActivityEnabled: meeting.isLiveActivityEnabled,
                        reminderTime: meeting.reminderTime
                    )
                    allItems.append(item)
                }
            }
        }

        // Filter out invalid items and sort by start time
        return allItems
            .filter { $0.endTime > $0.startTime }
            .sorted { $0.startTime < $1.startTime }
    }
    
    private func activeScheduleID() -> UUID? {
        return scheduleManager.activeScheduleID
    }
}

struct CompactScheduleItemView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let item: ScheduleItem
    let scheduleID: UUID?
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeFormatter.string(from: item.startTime))
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: true, vertical: false)

                if let endTime = timeFormatter.string(from: item.endTime) != timeFormatter.string(from: item.startTime) ? timeFormatter.string(from: item.endTime) : nil {
                    Text(endTime)
                        .font(.forma(.caption))
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.forma(.body, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if item.reminderTime != .none {
                        Image(systemName: "bell.fill")
                            .font(.forma(.caption2))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                if !item.location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.forma(.caption2))
                            .foregroundColor(.white.opacity(0.6))

                        Text(item.location)
                            .font(.forma(.caption))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

struct CompactEventItemView: View {
    @EnvironmentObject var viewModel: EventViewModel
    let event: Event
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(timeFormatter.string(from: event.date))
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 60, alignment: .leading)
            
            HStack(spacing: 8) {
                Text(event.title)
                    .font(.forma(.body))
                    .foregroundColor(.white)
                
                if event.reminderTime != .none {
                    Image(systemName: "bell.fill")
                        .font(.forma(.caption2))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            Button(action: {
                viewModel.markEventCompleted(event)
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.forma(.title3))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

extension ScheduleItem {
    private func daysString(for item: ScheduleItem) -> String {
        let sortedDays = Array(item.daysOfWeek).sorted { $0.rawValue < $1.rawValue }
        
        switch sortedDays.count {
        case 0:
            return "No days"
        case 1:
            return Array(item.daysOfWeek).first?.full ?? ""
        case 2...4:
            return sortedDays.map { $0.short }.joined(separator: ", ")
        default:
            return "Multiple days"
        }
    }
}
