import SwiftUI
import Combine

struct EnhancedCourseDetailView: View {
    let scheduleItem: ScheduleItem
    let scheduleID: UUID
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var courseManager: UnifiedCourseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isInteracting = false
    
    @State private var course: Course?
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isViewReady = false
    
    private let headerHeight: CGFloat = 200
    
    // PERFORMANCE: Use let constants instead of computed properties to avoid recalculation
    private let cachedIconForegroundColor: Color
    private let cachedBackgroundGradient: LinearGradient

    private var darkSectionBackground: LinearGradient {
        LinearGradient(
            colors: [
                themeManager.currentTheme.darkModeBackgroundFill.opacity(0.38),
                themeManager.currentTheme.darkModeBackgroundFill.opacity(0.28),
                themeManager.currentTheme.darkModeHue.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    private var darkNavBackground: LinearGradient {
        LinearGradient(
            colors: [
                themeManager.currentTheme.darkModeBackgroundFill.opacity(0.6),
                themeManager.currentTheme.darkModeBackgroundFill.opacity(0.4)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // PERFORMANCE: Initialize cached values in init to avoid state modification during view updates
    init(scheduleItem: ScheduleItem, scheduleID: UUID) {
        self.scheduleItem = scheduleItem
        self.scheduleID = scheduleID
        // Fix: Use white as the default foreground color for better contrast on gradient backgrounds
        self.cachedIconForegroundColor = .white
        self.cachedBackgroundGradient = LinearGradient(
            colors: [
                scheduleItem.color.opacity(0.8),
                scheduleItem.color.opacity(0.6),
                scheduleItem.color.opacity(0.4),
                Color.clear,
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            // PERFORMANCE: Use pre-computed gradient
            cachedBackgroundGradient
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Hero Header with minimal parallax effect
                    heroHeaderSection
                        .offset(y: isViewReady ? max(-scrollOffset * 0.1, -20) : 0) // PERFORMANCE: Even more reduced parallax
                    
                    // Main Content - simplified loading
                    VStack(spacing: 24) {
                        // Quick Stats Cards
                        quickStatsSection
                            .opacity(isViewReady ? 1 : 0)
                        
                        // Schedule Information
                        scheduleInfoSection
                            .opacity(isViewReady ? 1 : 0)
                        
                        // Create Course Prompt (if no course exists)
                        if course == nil {
                            createCoursePrompt
                                .opacity(isViewReady ? 1 : 0)
                        }
                        
                        // Action Buttons
                        actionButtonsSection
                            .opacity(isViewReady ? 1 : 0)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    // PERFORMANCE FIX: Replaced expensive .ultraThinMaterial with solid color
                    .background {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(colorScheme == .dark ? AnyShapeStyle(darkSectionBackground) : AnyShapeStyle(Color(.systemBackground).opacity(0.95)))
                    }
                }
                .background(GeometryReader { geometry in
                    Color.clear
                        .preference(key: EnhancedCourseDetailScrollPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                })
                .onPreferenceChange(EnhancedCourseDetailScrollPreferenceKey.self) { value in
                    if isViewReady && abs(scrollOffset - value) > 5 {
                        scrollOffset = value
                    }
                }
            }
            .coordinateSpace(name: "scroll")
            .scrollBounceBehavior(.basedOnSize)
            .transaction { $0.disablesAnimations = true }
            .simultaneousGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in
                        if !isInteracting { isInteracting = true }
                    }
                    .onEnded { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isInteracting = false
                        }
                    }
            )
            
            // Custom Navigation Bar
            VStack {
                customNavigationBar
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // PERFORMANCE: Load data immediately, animate UI separately
            loadCourseData()
            
            // PERFORMANCE: Single animation for all content
            withAnimation(.easeOut(duration: 0.3)) {
                isViewReady = true
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let existingCourse = course {
                // Use enhanced course editor for full course management
                EnhancedAddCourseWithMeetingsView(existingCourse: existingCourse)
                    .environmentObject(courseManager)
                    .environmentObject(scheduleManager)
                    .environmentObject(themeManager)
            } else {
                // Create a new course from the schedule item
                EnhancedAddCourseWithMeetingsView(existingCourse: createCourseFromScheduleItem())
                    .environmentObject(courseManager)
                    .environmentObject(scheduleManager)
                    .environmentObject(themeManager)
            }
        }
        .alert("Delete Class", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteScheduleItem()
            }
        } message: {
            Text("Are you sure you want to delete \(scheduleItem.title)? This action cannot be undone.")
        }
    }
    
    // MARK: - Custom Navigation Bar
    
    private var customNavigationBar: some View {
        HStack {
            Button(action: { 
                dismiss() 
            }) {
                Image(systemName: "chevron.left")
                    .font(.forma(.body, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    // PERFORMANCE FIX: Replaced .ultraThinMaterial with solid color
                    .background {
                        Circle()
                            .fill(colorScheme == .dark ? AnyShapeStyle(darkSectionBackground) : AnyShapeStyle(Color.black.opacity(0.3)))
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            }
                    }
            }

            Spacer()

            Button(action: { showingDeleteAlert = true }) {
                Image(systemName: "trash")
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    // PERFORMANCE FIX: Replaced .ultraThinMaterial with solid color
                    .background {
                        Circle()
                            .fill(colorScheme == .dark ? AnyShapeStyle(darkSectionBackground) : AnyShapeStyle(Color.black.opacity(0.3)))
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            }
                    }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        // PERFORMANCE FIX: Replaced .ultraThinMaterial with solid color
        .background {
            Rectangle()
                .fill(colorScheme == .dark ? AnyShapeStyle(darkNavBackground) : AnyShapeStyle(Color(.systemBackground).opacity(0.9)))
                .opacity(min(max(scrollOffset / -100, 0), 1))
                .ignoresSafeArea(edges: .top)
        }
    }
    
    // MARK: - Hero Header Section
    
    private var heroHeaderSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 70, height: 70)
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    }
                
                Image(systemName: course?.iconName ?? "book.closed.fill")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }
            .compositingGroup()
            .drawingGroup()
            
            Text(scheduleItem.title)
                .font(.forma(.title2, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            if !scheduleItem.instructor.isEmpty || !scheduleItem.location.isEmpty {
                HStack(spacing: 16) {
                    if !scheduleItem.instructor.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.forma(.caption))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(scheduleItem.instructor)
                                .font(.forma(.subheadline, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    if !scheduleItem.location.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.forma(.caption))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(scheduleItem.location)
                                .font(.forma(.subheadline, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                // PERFORMANCE FIX: Replaced .ultraThinMaterial with solid color
                .background {
                    Capsule()
                        .fill(colorScheme == .dark ? AnyShapeStyle(darkSectionBackground) : AnyShapeStyle(Color.black.opacity(0.25)))
                        .overlay {
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: headerHeight)
        .padding(.top, 20)
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "clock.fill",
                title: "Duration",
                value: scheduleItem.duration,
                color: themeManager.currentTheme.primaryColor
            )
            
            // PERFORMANCE: Show different stats based on schedule type
            if let schedule = scheduleManager.schedule(for: scheduleID), schedule.scheduleType == .rotating {
                StatCard(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Schedule",
                    value: "Rotating",
                    color: themeManager.currentTheme.secondaryColor
                )
                
                StatCard(
                    icon: "calendar.circle.fill",
                    title: "Pattern",
                    value: "Day 1/2",
                    color: themeManager.currentTheme.tertiaryColor
                )
            } else {
                StatCard(
                    icon: "calendar.badge.clock",
                    title: "Days",
                    value: "\(scheduleItem.daysOfWeek.count)",
                    color: themeManager.currentTheme.secondaryColor
                )
                
                StatCard(
                    icon: "calendar.circle.fill",
                    title: "Weekly Hours",
                    value: String(format: "%.1f", scheduleItem.weeklyHours),
                    color: themeManager.currentTheme.tertiaryColor
                )
            }
        }
    }
    
    // MARK: - Schedule Info Section
    
    private var scheduleInfoSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Schedule Details", icon: "calendar")
            
            VStack(spacing: 12) {
                ScheduleDetailRow(
                    icon: "clock.fill",
                    title: "Time",
                    detail: scheduleItem.timeRange,
                    color: scheduleItem.color
                )
                
                // PERFORMANCE: Show different day information based on schedule type
                if let schedule = scheduleManager.schedule(for: scheduleID), schedule.scheduleType == .rotating {
                    ScheduleDetailRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Schedule Type",
                        detail: "Rotating (Day 1/Day 2)",
                        color: scheduleItem.color
                    )
                } else {
                    ScheduleDetailRow(
                        icon: "calendar.badge.checkmark",
                        title: "Days",
                        detail: scheduleItem.daysOfWeek.map { $0.short }.joined(separator: ", "),
                        color: scheduleItem.color
                    )
                }
                
                if !scheduleItem.location.isEmpty {
                    ScheduleDetailRow(
                        icon: "location.fill",
                        title: "Location",
                        detail: scheduleItem.location,
                        color: scheduleItem.color
                    )
                }
                
                if !scheduleItem.instructor.isEmpty {
                    ScheduleDetailRow(
                        icon: "person.fill",
                        title: "Professor",
                        detail: scheduleItem.instructor,
                        color: scheduleItem.color
                    )
                }
                
                if scheduleItem.reminderTime != .none {
                    ScheduleDetailRow(
                        icon: "bell.fill",
                        title: "Reminder",
                        detail: scheduleItem.reminderTime.displayName,
                        color: scheduleItem.color
                    )
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
        }
    }
    
    // MARK: - Create Course Prompt
    
    private var createCoursePrompt: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Grade Tracking", icon: "graduationcap")
            
            VStack(spacing: 14) {
                Image(systemName: "graduationcap.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(scheduleItem.color.opacity(0.8))
                
                VStack(spacing: 6) {
                    Text("Track Your Grades")
                        .font(.forma(.title3, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Create a course profile to track assignments and monitor your academic progress.")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Button("Start Tracking Grades") {
                    // This will trigger the sheet with a new course created from the schedule item
                    course = nil
                    showingEditSheet = true
                }
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(scheduleItem.color)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 14) {
            // Action Buttons
            HStack(spacing: 14) {
                ActionButton(
                    icon: "pencil",
                    title: course != nil ? "Edit Course" : "Edit Class",
                    color: themeManager.currentTheme.primaryColor,
                    action: { showingEditSheet = true }
                )
            }
        }
    }
    
    // MARK: - Helper Properties and Methods

    private func loadCourseData() {
        // Find existing course that matches this schedule item
        course = findMatchingCourse()
        
        print("🔍 DEBUG: Found course for schedule item '\(scheduleItem.title)': \(course?.name ?? "None")")
    }
    
    private func findMatchingCourse() -> Course? {
        // Try to find a course that has a meeting matching this schedule item
        return courseManager.courses.first { course in
            course.scheduleId == scheduleID && course.meetings.contains { meeting in
                // Check if this meeting could generate the current schedule item
                meeting.matchesScheduleItem(scheduleItem)
            }
        }
    }
    
    private func createCourseFromScheduleItem() -> Course {
        // Extract course name from schedule item title
        let courseName = extractCourseNameFromTitle(scheduleItem.title)
        
        // Create a course with a meeting that matches this schedule item
        let course = Course(
            scheduleId: scheduleID,
            name: courseName,
            iconName: "book.closed.fill",
            colorHex: scheduleItem.color.toHex() ?? "007AFF",
            creditHours: 3.0,
            courseCode: "",
            section: "",
            instructor: "", // No longer set at course level
            location: ""    // No longer set at course level
        )
        
        // Create a meeting that matches this schedule item
        let meeting = CourseMeeting(
            courseId: course.id,
            scheduleId: scheduleID,
            meetingType: .lecture,
            meetingLabel: nil,
            isRotating: scheduleManager.schedule(for: scheduleID)?.scheduleType == .rotating,
            rotationLabel: nil,
            rotationIndex: nil,
            startTime: scheduleItem.startTime,
            endTime: scheduleItem.endTime,
            daysOfWeek: scheduleItem.daysOfWeek.map { $0.rawValue },
            location: scheduleItem.location,   // Set at meeting level
            instructor: scheduleItem.instructor, // Set at meeting level
            reminderTime: scheduleItem.reminderTime,
            isLiveActivityEnabled: scheduleItem.isLiveActivityEnabled
        )
        
        var courseWithMeeting = course
        courseWithMeeting.meetings = [meeting]
        
        return courseWithMeeting
    }
    
    private func extractCourseNameFromTitle(_ title: String) -> String {
        // Try to extract course name by removing common suffixes like "- Lecture", "- Lab", etc.
        let patterns = [" - Lecture", " - Lab", " - Tutorial", " - Seminar", " - Workshop"]
        
        for pattern in patterns {
            if title.hasSuffix(pattern) {
                return String(title.dropLast(pattern.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return title.trimmingCharacters(in: .whitespaces)
    }

    private func deleteScheduleItem() {
        scheduleManager.deleteScheduleItem(scheduleItem, from: scheduleID)
        dismiss()
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.forma(.body, weight: .medium))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(color.opacity(0.12))
                        .overlay {
                            Circle()
                                .stroke(color.opacity(0.25), lineWidth: 1)
                        }
                }
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.forma(.subheadline, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.forma(.caption2, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 14)
        }
    }
}

struct ScheduleDetailRow: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(detail)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.forma(.subheadline, weight: .semibold))
                
                Text(title)
                    .font(.forma(.subheadline, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: color.opacity(0.3), radius: 6, x: 0, y: 3)
                    .adaptiveButtonDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 12)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scroll Offset Preference Key

struct EnhancedCourseDetailScrollPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - CourseMeeting Extension

extension CourseMeeting {
    func matchesScheduleItem(_ item: ScheduleItem) -> Bool {
        // Check if this meeting could generate the given schedule item
        let timeMatches = Calendar.current.isDate(startTime, equalTo: item.startTime, toGranularity: .minute) &&
                         Calendar.current.isDate(endTime, equalTo: item.endTime, toGranularity: .minute)
        
        let daysMatch = Set(daysOfWeek) == Set(item.daysOfWeek.map { $0.rawValue })
        
        // Basic location/instructor check (could be empty in meeting but populated in schedule item)
        let locationMatches = location.isEmpty || location == item.location
        let instructorMatches = instructor.isEmpty || instructor == item.instructor
        
        return timeMatches && daysMatch && locationMatches && instructorMatches
    }
}

#Preview {
    NavigationView {
        EnhancedCourseDetailView(
            scheduleItem: ScheduleItem(
                title: "Advanced Swift Programming",
                startTime: Calendar.current.date(from: DateComponents(hour: 10, minute: 0)) ?? Date(),
                endTime: Calendar.current.date(from: DateComponents(hour: 11, minute: 30)) ?? Date(),
                daysOfWeek: [.monday, .wednesday, .friday],
                location: "Engineering Building Room 201",
                instructor: "Dr. Sarah Johnson",
                color: .blue
            ),
            scheduleID: UUID()
        )
        .environmentObject(ScheduleManager())
        .environmentObject(ThemeManager())
        .environmentObject(UnifiedCourseManager())
    }
}