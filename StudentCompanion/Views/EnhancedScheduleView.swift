import SwiftUI

// MARK: - Simplified Schedule View (Traditional Only)
struct EnhancedScheduleView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var courseManager: UnifiedCourseManager
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    
    private var activeSchedule: ScheduleCollection? {
        let schedule = scheduleManager.activeSchedule
        print("🔍 SCHEDULE: Active schedule: \(schedule?.displayName ?? "none")")
        return schedule
    }
    
    private var academicCalendar: AcademicCalendar? {
        let calendar = activeSchedule?.academicCalendar
        if let calendar = calendar {
            print("🔍 CALENDAR: Academic calendar: \(calendar.name) with \(calendar.breaks.count) breaks")
            for breakItem in calendar.breaks {
                print("🔍 BREAK: '\(breakItem.name)' from \(breakItem.startDate.formatted(date: .abbreviated, time: .omitted)) to \(breakItem.endDate.formatted(date: .abbreviated, time: .omitted))")
            }
        } else {
            print("🔍 CALENDAR: No academic calendar found")
        }
        return calendar
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with date
            headerView
            
            // Schedule content
            if let schedule = activeSchedule {
                scheduleContentView(for: schedule)
            } else {
                noScheduleView
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
        }
        .onAppear {
            print("🔍 SCHEDULE: View appeared for date \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 12) {
            // Date selector
            Button(action: { showingDatePicker = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dateFormatter.string(from: selectedDate))
                            .font(.system(.title2, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(headerSubtitle)
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "calendar")
                        .font(.system(.title2))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Week view for quick navigation
            weekNavigationView
        }
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    // MARK: - Enhanced Week Navigation with Break Tooltips
    @ViewBuilder
    private var weekNavigationView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(weekDates, id: \.self) { date in
                    WeekDayButton(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        onTap: { selectedDate = date }
                    )
                    .environmentObject(scheduleManager)
                    .environmentObject(themeManager)
                    .overlay(alignment: .bottom) {
                        // Break tooltip
                        if let schedule = activeSchedule,
                           let calendar = schedule.academicCalendar,
                           let breakInfo = calendar.breakForDate(date) {
                            BreakTooltip(breakInfo: breakInfo, date: date)
                                .offset(y: 45)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
    }
    
    private var weekDates: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfWeek)
        }
    }
    
    @ViewBuilder
    private func scheduleContentView(for schedule: ScheduleCollection) -> some View {
        let scheduleItems = getScheduleItems(for: schedule)
        
        if scheduleItems.isEmpty {
            emptyScheduleView
        } else {
            scheduleListView(items: scheduleItems, schedule: schedule)
        }
    }
    
    @ViewBuilder
    private var emptyScheduleView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Break day visualization or regular empty state
            if isBreakDay {
                breakDayEmptyState
            } else {
                regularEmptyState
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Break Day Empty State
    private var breakDayEmptyState: some View {
        VStack(spacing: 20) {
            // Animated break icon with beautiful effects
            ZStack {
                // Pulsing background circles
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (getBreakInfo()?.type.color ?? .gray).opacity(0.1 - Double(index) * 0.03),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60 + CGFloat(index * 30)
                            )
                        )
                        .frame(width: 120 + CGFloat(index * 60), height: 120 + CGFloat(index * 60))
                        .scaleEffect(1.0 + Double(index) * 0.1)
                        .animation(.easeInOut(duration: 2.0 + Double(index) * 0.5).repeatForever(autoreverses: true), value: 1.0)
                }
                
                // Main break icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    getBreakInfo()?.type.color ?? .gray,
                                    (getBreakInfo()?.type.color ?? .gray).opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(
                            color: (getBreakInfo()?.type.color ?? .gray).opacity(0.4),
                            radius: 20, x: 0, y: 10
                        )
                    
                    Image(systemName: getBreakInfo()?.type.icon ?? "calendar.badge.minus")
                        .font(.system(.largeTitle, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Break information
            VStack(spacing: 12) {
                Text(getBreakMessage())
                    .font(.system(.title2, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("No classes scheduled during this break period")
                    .font(.system(.body, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Break details card
                if let breakInfo = getBreakInfo() {
                    breakDetailsCard(breakInfo)
                }
            }
        }
    }
    
    // MARK: - Regular Empty State
    private var regularEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(.largeTitle))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Classes Today")
                    .font(.system(.title2, weight: .bold))
                
                Text("Enjoy your free day!")
                    .font(.system(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Break Details Card
    private func breakDetailsCard(_ breakInfo: AcademicBreak) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: breakInfo.type.icon)
                    .font(.system(.title3, weight: .semibold))
                    .foregroundColor(breakInfo.type.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(breakInfo.type.displayName)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(formatBreakDuration(breakInfo))
                        .font(.system(.caption, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if !breakInfo.description.isEmpty {
                HStack {
                    Text(breakInfo.description)
                        .font(.system(.caption))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(breakInfo.type.color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(
            color: breakInfo.type.color.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Helper Methods for Break Information
    private func getBreakInfo() -> AcademicBreak? {
        guard let schedule = activeSchedule,
              let calendar = schedule.academicCalendar else {
            return nil
        }
        return calendar.breakForDate(selectedDate)
    }
    
    private func formatBreakDuration(_ breakInfo: AcademicBreak) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        if Calendar.current.isDate(breakInfo.startDate, inSameDayAs: breakInfo.endDate) {
            return dateFormatter.string(from: breakInfo.startDate)
        } else {
            return "\(dateFormatter.string(from: breakInfo.startDate)) - \(dateFormatter.string(from: breakInfo.endDate))"
        }
    }
    
    @ViewBuilder
    private func scheduleListView(items: [ScheduleItem], schedule: ScheduleCollection) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(items.sorted { $0.startTime < $1.startTime }) { item in
                    EnhancedScheduleItemCard(
                        item: item,
                        date: selectedDate,
                        schedule: schedule
                    )
                    .environmentObject(scheduleManager)
                    .environmentObject(themeManager)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    @ViewBuilder
    private var noScheduleView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Active Schedule")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Create a schedule to see your classes here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button("Create Schedule") {
                // Handle schedule creation
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Fixed Schedule Logic with Course Integration
    private func getScheduleItems(for schedule: ScheduleCollection) -> [ScheduleItem] {
        print("🔍 SCHEDULE: Getting schedule items for \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
        
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: selectedDate)
        if weekday == 1 || weekday == 7 {
            print("🔍 SCHEDULE: Weekend, returning empty")
            return []
        }
        
        if let start = schedule.semesterStartDate,
           let end = schedule.semesterEndDate {
            let d = cal.startOfDay(for: selectedDate)
            let s = cal.startOfDay(for: start)
            let e = cal.startOfDay(for: end)
            if d < s || d > e {
                print("🔍 SCHEDULE: Date outside schedule's semester bounds, returning empty")
                return []
            }
        }
        
        if let calendar = schedule.academicCalendar {
            if !calendar.isDateWithinSemester(selectedDate) {
                print("🔍 SCHEDULE: Date outside academic calendar bounds, returning empty")
                return []
            }
            if calendar.isBreakDay(selectedDate) {
                print("🔍 SCHEDULE: Date is a break day, returning empty")
                return []
            }
        }
        
        let coursesInSchedule = courseManager.courses.filter { $0.scheduleId == schedule.id }
        print("🔍 SCHEDULE: Found \(coursesInSchedule.count) courses in schedule")
        
        var scheduleItems: [ScheduleItem] = []
        
        for course in coursesInSchedule {
            print("🔍 SCHEDULE: Checking course '\(course.name)'")
            
            // FIX: Use toScheduleItems (plural) instead of toScheduleItem (singular)
            let courseItems = course.toScheduleItems(for: selectedDate, in: schedule, calendar: schedule.academicCalendar)
            scheduleItems.append(contentsOf: courseItems)
            
            if !courseItems.isEmpty {
                print("🔍 SCHEDULE: ✅ Added \(courseItems.count) items for '\(course.name)'")
                for item in courseItems {
                    print("🔍 SCHEDULE:   - Item at \(item.startTime.formatted(date: .omitted, time: .shortened))")
                }
            } else {
                print("🔍 SCHEDULE: ❌ Course '\(course.name)' should not appear today")
            }
        }
        
        let traditionalItems = getTraditionalScheduleItems(for: schedule)
        scheduleItems.append(contentsOf: traditionalItems)
        
        print("🔍 SCHEDULE: Total schedule items: \(scheduleItems.count)")
        return scheduleItems
    }
    
    // Legacy support for traditional schedule items
    private func getTraditionalScheduleItems(for schedule: ScheduleCollection) -> [ScheduleItem] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: selectedDate)
        let dayOfWeek = DayOfWeek.from(weekday: weekday)

        return schedule.scheduleItems.filter { item in
            item.daysOfWeek.contains(dayOfWeek)
        }
    }
    
    // MARK: - Helper Methods
    private var isBreakDay: Bool {
        guard let schedule = activeSchedule,
              let calendar = schedule.academicCalendar else {
            return false
        }
        return calendar.isBreakDay(selectedDate)
    }
    
    private func getBreakMessage() -> String {
        guard let schedule = activeSchedule,
              let calendar = schedule.academicCalendar,
              let breakInfo = calendar.breakForDate(selectedDate) else {
            return "No classes scheduled"
        }
        return breakInfo.name
    }
    
    private var headerSubtitle: String {
        if let schedule = activeSchedule {
            return schedule.scheduleType == .rotating ? "Day 1 / Day 2 Schedule" : "Weekly Schedule"
        }
        return "Weekly Schedule"
    }
    
    private func rotatingDayLabel(for date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return day % 2 == 1 ? "Day 1" : "Day 2"
    }
}

// MARK: - Enhanced WeekDayButton with Better Break Visualization
struct WeekDayButton: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let date: Date
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var pulseAnimation: Double = 1.0
    @State private var shimmerOffset: CGFloat = -1.0
    @State private var breakIconScale: Double = 0.8
    
    private var activeSchedule: ScheduleCollection? {
        scheduleManager.activeSchedule
    }
    
    private var academicCalendar: AcademicCalendar? {
        activeSchedule?.academicCalendar
    }
    
    private var isBreakDay: Bool {
        guard let calendar = academicCalendar else { 
            print("🔍 BREAK: No academic calendar found for date \(date.formatted(date: .abbreviated, time: .omitted))")
            return false 
        }
        
        let dateOnly = Calendar.current.startOfDay(for: date)
        print("🔍 BREAK: Checking if \(dateOnly.formatted(date: .abbreviated, time: .omitted)) is a break day")
        
        for breakItem in calendar.breaks {
            let breakStart = Calendar.current.startOfDay(for: breakItem.startDate)
            let breakEnd = Calendar.current.startOfDay(for: breakItem.endDate)
            print("🔍 BREAK: Comparing with '\(breakItem.name)': \(breakStart.formatted(date: .abbreviated, time: .omitted)) to \(breakEnd.formatted(date: .abbreviated, time: .omitted))")
            
            if dateOnly >= breakStart && dateOnly <= breakEnd {
                print("🔍 BREAK: ✅ Date \(dateOnly.formatted(date: .abbreviated, time: .omitted)) IS in break '\(breakItem.name)'")
                return true
            }
        }
        
        print("🔍 BREAK: ❌ Date \(dateOnly.formatted(date: .abbreviated, time: .omitted)) is NOT a break day")
        return false
    }
    
    private var breakInfo: AcademicBreak? {
        guard let calendar = academicCalendar else { 
            print("🔍 BREAK: No academic calendar for break info")
            return nil 
        }
        let info = calendar.breakForDate(date)
        print("🔍 BREAK: Break info for \(date.formatted(date: .abbreviated, time: .omitted)): \(info?.name ?? "none")")
        return info
    }
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }
    
    private var dayNumberFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Day abbreviation
                Text(dayFormatter.string(from: date))
                    .font(.system(.caption, weight: .semibold))
                    .foregroundColor(dayTextColor)
                    .padding(.top, 8)
                
                Spacer()
                
                // Main content area with break visualization
                ZStack {
                    // Day number
                    Text(dayNumberFormatter.string(from: date))
                        .font(.system(.title3, weight: .bold))
                        .foregroundColor(numberTextColor)
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                    
                    // Break overlay effects
                    if isBreakDay {
                        breakOverlayEffects
                    }
                    
                    // Today indicator
                    if isToday && !isSelected {
                        todayIndicator
                    }
                }
                .frame(height: 32)
                
                Spacer()
                
                // Break indicator at bottom
                if isBreakDay {
                    breakIndicatorBottom
                        .padding(.bottom, 8)
                } else {
                    Spacer()
                        .frame(height: 16)
                }
            }
            .frame(width: 50, height: 80)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(isSelected ? 1.08 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isBreakDay)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
    }
    
    // MARK: - Background View
    @ViewBuilder
    private var backgroundView: some View {
        ZStack {
            if isBreakDay {
                // Break day background with beautiful gradient
                breakDayBackground
            } else if isSelected {
                // Selected day background
                selectedDayBackground
            } else if isToday {
                // Today background (subtle)
                todayBackground
            } else {
                // Default background
                defaultBackground
            }
        }
    }
    
    // MARK: - Break Day Background
    private var breakDayBackground: some View {
        ZStack {
            // Base gradient using break type color
            LinearGradient(
                colors: [
                    (breakInfo?.type.color ?? .gray).opacity(isSelected ? 0.9 : 0.7),
                    (breakInfo?.type.color ?? .gray).opacity(isSelected ? 0.7 : 0.5),
                    (breakInfo?.type.color ?? .gray).opacity(isSelected ? 0.5 : 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated shimmer effect for breaks
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(isSelected ? 0.4 : 0.25),
                    Color.white.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: shimmerOffset * 100)
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: false), value: shimmerOffset)
            
            // Pulse overlay for selected break days
            if isSelected {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.15))
                    .scaleEffect(pulseAnimation)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
            }
        }
    }
    
    // MARK: - Other Backgrounds
    private var selectedDayBackground: some View {
        LinearGradient(
            colors: [
                themeManager.currentTheme.primaryColor,
                themeManager.currentTheme.primaryColor.opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var todayBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.5), lineWidth: 2)
            )
    }
    
    @ViewBuilder
    private var defaultBackground: some View {
        if isWeekend {
            AnyView(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.clear)
                    .opacity(0.5)
            )
        } else {
            AnyView(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }
    
    // MARK: - Break Overlay Effects
    private var breakOverlayEffects: some View {
        ZStack {
            // Diagonal strike-through line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.8),
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.8)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 40, height: 2)
                .rotationEffect(.degrees(-25))
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            
            // Break type icon (subtle overlay)
            if let breakInfo = breakInfo {
                Image(systemName: breakInfo.type.icon)
                    .font(.system(.caption2, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .scaleEffect(breakIconScale)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).repeatForever(autoreverses: true), value: breakIconScale)
                    .offset(x: 12, y: -12)
            }
        }
    }
    
    // MARK: - Today Indicator
    private var todayIndicator: some View {
        Circle()
            .fill(themeManager.currentTheme.primaryColor)
            .frame(width: 6, height: 6)
            .offset(x: 15, y: -15)
            .scaleEffect(pulseAnimation * 0.2 + 0.8)
    }
    
    // MARK: - Break Indicator Bottom
    private var breakIndicatorBottom: some View {
        HStack(spacing: 2) {
            if let breakInfo = breakInfo {
                // Break type color dot
                Circle()
                    .fill(breakInfo.type.color)
                    .frame(width: 4, height: 4)
                    .shadow(color: breakInfo.type.color.opacity(0.6), radius: 2, x: 0, y: 1)
                
                // Mini break icon
                Image(systemName: breakInfo.type.icon)
                    .font(.system(.caption2, weight: .bold))
                    .foregroundColor(breakInfo.type.color)
                    .scaleEffect(0.7)
                
                // Another color dot for symmetry
                Circle()
                    .fill(breakInfo.type.color)
                    .frame(width: 4, height: 4)
                    .shadow(color: breakInfo.type.color.opacity(0.6), radius: 2, x: 0, y: 1)
            }
        }
        .scaleEffect(breakIconScale)
    }
    
    // MARK: - Text Colors
    private var dayTextColor: Color {
        if isBreakDay {
            return isSelected ? .white : .white.opacity(0.9)
        } else if isSelected {
            return .white
        } else if isToday {
            return themeManager.currentTheme.primaryColor
        } else if isWeekend {
            return .secondary.opacity(0.7)
        } else {
            return .secondary
        }
    }
    
    private var numberTextColor: Color {
        if isBreakDay {
            return .white
        } else if isSelected {
            return .white
        } else if isToday {
            return themeManager.currentTheme.primaryColor
        } else if isWeekend {
            return .primary.opacity(0.6)
        } else {
            return .primary
        }
    }
    
    // MARK: - Animation Methods
    private func startAnimations() {
        // Shimmer animation
        withAnimation(.linear(duration: 0)) {
            shimmerOffset = -1.0
        }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: false)) {
            shimmerOffset = 1.0
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.2
        }
        
        // Break icon scale animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).repeatForever(autoreverses: true)) {
            breakIconScale = 1.0
        }
    }
    
    private func stopAnimations() {
        withAnimation(.linear(duration: 0)) {
            shimmerOffset = -1.0
            pulseAnimation = 1.0
            breakIconScale = 0.8
        }
    }
}

struct EnhancedScheduleItemCard: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    let item: ScheduleItem
    let date: Date
    let schedule: ScheduleCollection
    
    @State private var showingOptions = false
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var duration: String {
        let interval = item.endTime.timeIntervalSince(item.startTime)
        let hours = Int(interval) / 3600
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var isCurrentClass: Bool {
        let now = Date()
        let calendar = Calendar.current
        
        guard calendar.isDate(date, inSameDayAs: now) else { return false }
        
        let startComponents = calendar.dateComponents([.hour, .minute], from: item.startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: item.endTime)
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
        
        return nowMinutes >= startMinutes && nowMinutes <= endMinutes
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Time indicator
            VStack(alignment: .center, spacing: 4) {
                Text(timeFormatter.string(from: item.startTime))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(isCurrentClass ? .white : .primary)
                
                Text(duration)
                    .font(.caption)
                    .foregroundColor(isCurrentClass ? .white.opacity(0.8) : .secondary)
                
                Rectangle()
                    .fill(isCurrentClass ? .white.opacity(0.3) : item.color.opacity(0.3))
                    .frame(width: 2, height: 20)
            }
            .frame(width: 60)
            
            // Class info
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(isCurrentClass ? .white : .primary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label(timeFormatter.string(from: item.endTime), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(isCurrentClass ? .white.opacity(0.8) : .secondary)
                    
                    if !item.location.isEmpty {
                        Label(item.location, systemImage: "location")
                            .font(.caption)
                            .foregroundColor(isCurrentClass ? .white.opacity(0.8) : .secondary)
                            .lineLimit(1)
                    }
                    
                    if item.reminderTime != .none {
                        Label(item.reminderTime.shortDisplayName, systemImage: "bell")
                            .font(.caption)
                            .foregroundColor(isCurrentClass ? .white.opacity(0.8) : .secondary)
                    }
                }
            }
            
            Spacer()
            
            // Options menu
            Menu {
                Button("Edit Class", systemImage: "pencil") {
                    // Handle edit
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(isCurrentClass ? .white.opacity(0.8) : .secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isCurrentClass ? item.color : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isCurrentClass ? Color.clear : item.color.opacity(0.2), lineWidth: 1)
                )
                .shadow(
                    color: isCurrentClass ? item.color.opacity(0.3) : .black.opacity(0.05),
                    radius: isCurrentClass ? 8 : 2,
                    x: 0,
                    y: isCurrentClass ? 4 : 1
                )
        )
        .scaleEffect(isCurrentClass ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isCurrentClass)
    }
}

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    
    var body: some View {
        NavigationView {
            DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Enhanced Break Tooltip Component
struct BreakTooltip: View {
    @EnvironmentObject var themeManager: ThemeManager
    let breakInfo: AcademicBreak
    let date: Date
    
    @State private var showTooltip = false
    @State private var glowAnimation: Double = 0.5
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }
    
    private var isMultiDayBreak: Bool {
        !Calendar.current.isDate(breakInfo.startDate, inSameDayAs: breakInfo.endDate)
    }
    
    private var breakDateRange: String {
        if isMultiDayBreak {
            return "\(dateFormatter.string(from: breakInfo.startDate)) - \(dateFormatter.string(from: breakInfo.endDate))"
        } else {
            return dateFormatter.string(from: breakInfo.startDate)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tooltip content
            VStack(spacing: 8) {
                // Break type icon and name
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(breakInfo.type.color.opacity(0.2))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(breakInfo.type.color.opacity(0.4), lineWidth: 1)
                            )
                        
                        Image(systemName: breakInfo.type.icon)
                            .font(.system(.caption, weight: .bold))
                            .foregroundColor(breakInfo.type.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(breakInfo.name)
                            .font(.system(.caption, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(breakInfo.type.displayName)
                            .font(.system(.caption2, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Date range (if multi-day)
                if isMultiDayBreak {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(.caption2))
                            .foregroundColor(.secondary)
                        
                        Text(breakDateRange)
                            .font(.system(.caption2, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                
                // Description (if available)
                if !breakInfo.description.isEmpty {
                    Text(breakInfo.description)
                        .font(.system(.caption2))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    // Base background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(breakInfo.type.color.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Animated glow effect
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(breakInfo.type.color.opacity(glowAnimation * 0.6), lineWidth: 2)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glowAnimation)
                }
                .shadow(
                    color: breakInfo.type.color.opacity(0.2),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            )
            .frame(width: 200)
            
            // Tooltip arrow
            TooltipArrow(color: breakInfo.type.color)
        }
        .opacity(showTooltip ? 1 : 0)
        .scaleEffect(showTooltip ? 1 : 0.8)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showTooltip)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showTooltip = true
            }
            startGlowAnimation()
        }
        .onDisappear {
            showTooltip = false
        }
    }
    
    private func startGlowAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowAnimation = 1.0
        }
    }
}

// MARK: - Tooltip Arrow Component
struct TooltipArrow: View {
    let color: Color
    
    var body: some View {
        Triangle()
            .fill(.regularMaterial)
            .frame(width: 12, height: 8)
            .overlay(
                Triangle()
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .shadow(
                color: color.opacity(0.1),
                radius: 2,
                x: 0,
                y: 2
            )
    }
}

// MARK: - Triangle Shape for Tooltip Arrow
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    EnhancedScheduleView()
        .environmentObject(ScheduleManager())
        .environmentObject(ThemeManager())
        .environmentObject(UnifiedCourseManager())
}