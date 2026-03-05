import SwiftUI

struct GPAView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var courseManager: UnifiedCourseManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject private var eventViewModel: EventViewModel
    @StateObject private var viewModel = GPAViewModel()
    @StateObject private var bulkSelectionManager = BulkCourseSelectionManager()
    @State private var showingAddCourseSheet = false
    @State private var showConflictResolution = false
    @State private var orphanedData: (courses: [Course], scheduleItems: [ScheduleItem]) = ([], [])
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false
    @AppStorage("lastGradeUpdate") private var lastGradeUpdate: Double = 0
    @State private var showBulkDeleteAlert = false
    @State private var showDeleteCourseAlert = false
    @State private var courseToDelete: Course?
    @State private var showingScheduleManager = false
    // PERFORMANCE FIX: REMOVED repeatForever animations that caused 100% CPU usage
    // These were triggering continuous state changes and view re-renders
    // @State private var animationOffset: CGFloat = 0
    // @State private var pulseAnimation: Double = 1.0
    @Environment(\.colorScheme) var colorScheme
    @State private var isVisible = false
    @ObservedObject private var onboardingManager = GuidedOnboardingManager.shared
    @State private var onboardingCourseNavigation: Course? = nil
    @State private var selectedCourse: Course? = nil

    // New state for average detail sheets
    @State private var showingSemesterDetail = false
    @State private var showingYearDetail = false
    @State private var selectedYearScheduleIDs: Set<UUID> = []
    @AppStorage("YearDetail_SelectedScheduleIDs") private var selectedYearScheduleIDsStorage: String = ""

    // PERFORMANCE FIX: Use viewModel to cache analytics and prevent expensive recalculation on every render
    private var activeScheduleCourses: [Course] { viewModel.cachedCourses }
    private var semesterAverage: Double? { viewModel.cachedSemesterAverage }
    private var semesterGPA: Double? { viewModel.cachedSemesterGPA }

    private func refreshCachedAnalytics() {
        viewModel.refreshCachedAnalytics(courseManager: courseManager, scheduleManager: scheduleManager)
    }

    private var yearAverage: Double? {
        viewModel.yearAverage(courseManager: courseManager, selectedScheduleIDs: selectedYearScheduleIDs)
    }

    var body: some View {
        mainContent
            .applyBaseModifiers(
                showingAddCourseSheet: $showingAddCourseSheet,
                showConflictResolution: $showConflictResolution,
                showingSemesterDetail: $showingSemesterDetail,
                showingYearDetail: $showingYearDetail,
                showingScheduleManager: $showingScheduleManager,
                courseManager: courseManager,
                themeManager: themeManager,
                scheduleManager: scheduleManager,
                orphanedData: orphanedData,
                semesterAverage: semesterAverage,
                semesterGPA: semesterGPA,
                activeScheduleCourses: activeScheduleCourses,
                usePercentageGrades: usePercentageGrades,
                selectedYearScheduleIDs: $selectedYearScheduleIDs,
                onResolution: handleConflictResolution
            )
            .applyLifecycleModifiers(
                courseManager: courseManager,
                scheduleManager: scheduleManager,
                selectedYearScheduleIDs: selectedYearScheduleIDs,
                onAppear: {
                    if courseManager.courses.isEmpty {
                        courseManager.loadCourses()
                    }
                    // PERFORMANCE FIX: Cache analytics on appear
                    refreshCachedAnalytics()
                    loadYearSelectionFromStorage()
                    courseManager.setScheduleManager(scheduleManager)
                    scheduleManager.setCourseManager(courseManager)
                    isVisible = true
                },
                onRefresh: refreshData,
                onYearSelectionChange: saveYearSelectionToStorage,
                onScheduleCollectionsChange: syncSelectionWithAvailableSchedules
            )
            .applyAlertModifiers(
                showDeleteCourseAlert: $showDeleteCourseAlert,
                showBulkDeleteAlert: $showBulkDeleteAlert,
                bulkSelectionManager: bulkSelectionManager,
                deleteAlert: deleteAlert,
                bulkDeleteAlert: bulkDeleteAlert
            )
            .onDisappear {
                // Ensure multi-select and UI ephemera are cleared when leaving this tab
                if bulkSelectionManager.isSelecting {
                    bulkSelectionManager.endSelection()
                }
                showBulkDeleteAlert = false
                showDeleteCourseAlert = false
                showingAddCourseSheet = false
                isVisible = false
            }
            // PERFORMANCE FIX: Only refresh cache when courses actually change
            .onChange(of: courseManager.courses.count) { _, _ in
                refreshCachedAnalytics()
            }
            .onChange(of: scheduleManager.activeScheduleID) { _, _ in
                refreshCachedAnalytics()
            }
            .toolbar {
                // Only contribute toolbar items when this view is actually visible
                if isVisible {
                    toolbarContent
                }
            }
            .fullScreenCover(item: $onboardingCourseNavigation) { course in
                NavigationStack {
                    CourseDetailView(course: course, courseManager: courseManager)
                        .environmentObject(themeManager)
                        .environmentObject(eventViewModel)
                        .environmentObject(CalendarSyncManager.shared)
                }
            }
            .fullScreenCover(item: $selectedCourse) { course in
                NavigationStack {
                    CourseDetailView(course: course, courseManager: courseManager)
                        .environmentObject(themeManager)
                        .environmentObject(eventViewModel)
                        .environmentObject(CalendarSyncManager.shared)
                }
            }
            .onChange(of: onboardingManager.shouldAutoOpenCourse) { _, shouldOpen in
                guard shouldOpen, onboardingManager.isActive else { return }
                // Brief delay to let the tab switch settle
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    refreshCachedAnalytics()
                    if let firstCourse = activeScheduleCourses.first {
                        onboardingCourseNavigation = firstCourse
                        onboardingManager.shouldAutoOpenCourse = false
                        onboardingManager.startCourseDetailGuidance()
                    } else {
                        // No courses: skip course detail guidance
                        onboardingManager.shouldAutoOpenCourse = false
                        onboardingManager.advanceFromCoursesTip()
                    }
                }
            }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            contentView
            
            // Magical floating add button
            if !bulkSelectionManager.isSelecting {
                magicalFloatingAddButton
            }
        }
    }
    
    // MARK: - Content View
    private var contentView: some View {
        VStack(spacing: 0) {
            // Stunning header section with analytics
            spectacularHeaderSection
                .padding(.top, 24)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Beautiful courses grid
                    coursesGridSection
                    
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Spectacular Header Section
    private var spectacularHeaderSection: some View {
        VStack(spacing: 28) {
            // Schedule title with beautiful styling and compact averages
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("My Courses")
                        .font(.forma(.title2, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.secondaryColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    if let activeSchedule = scheduleManager.activeSchedule {
                        Button {
                            showingScheduleManager = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar.badge.checkmark")
                                    .font(.forma(.caption))
                                    .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.8))

                                Text(activeSchedule.displayName)
                                    .font(.forma(.caption, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.forma(.caption))
                                .foregroundColor(.orange)
                            
                            Text("No Active Schedule")
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                
                Spacer()
                
                // Ultra-compact averages horizontally
                HStack(spacing: 6) {
                    Button(action: { showingSemesterDetail = true }) {
                        MiniAveragePill(
                            title: "SEM",
                            value: semesterAverage,
                            gpa: semesterGPA,
                            usePercentage: usePercentageGrades,
                            color: themeManager.currentTheme.primaryColor,
                            themeManager: themeManager
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showingYearDetail = true }) {
                        MiniAveragePill(
                            title: "YR",
                            value: yearAverage,
                            gpa: nil,
                            usePercentage: usePercentageGrades,
                            color: themeManager.currentTheme.secondaryColor,
                            themeManager: themeManager
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Courses Grid Section
    private var coursesGridSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            if activeScheduleCourses.isEmpty {
                spectacularEmptyState
            } else {
                LazyVStack(spacing: 20) {
                    // Use indices instead of enumerated to avoid array recreation on every body evaluation
                    ForEach(activeScheduleCourses.indices, id: \.self) { index in
                        let course = activeScheduleCourses[index]
                        if bulkSelectionManager.selectionContext == .courses {
                            GorgeousCourseCard(
                                course: course,
                                courseManager: courseManager,
                                bulkSelectionManager: bulkSelectionManager,
                                themeManager: themeManager,
                                usePercentageGrades: usePercentageGrades,
                                animationDelay: Double(index) * 0.1,
                                onDelete: { deleteCourse(course) }
                            )
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                selectedCourse = course
                            } label: {
                                GorgeousCourseCard(
                                    course: course,
                                    courseManager: courseManager,
                                    bulkSelectionManager: bulkSelectionManager,
                                    themeManager: themeManager,
                                    usePercentageGrades: usePercentageGrades,
                                    animationDelay: Double(index) * 0.1,
                                    onDelete: { deleteCourse(course) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Spectacular Empty State
    private var spectacularEmptyState: some View {
        VStack(spacing: 32) {
            // Animated illustration
            ZStack {
                // Background circles with animation
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.1 - Double(index) * 0.03),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60 + CGFloat(index * 20)
                            )
                        )
                        .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                        // PERFORMANCE FIX: Removed repeatForever animation that caused 100% CPU
                        .scaleEffect(1.0 + Double(index) * 0.1)
                }
                
                // Main icon
                Image(systemName: "graduationcap")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    // PERFORMANCE FIX: Static scale instead of animated
                    .scaleEffect(1.0)
            }
            
            VStack(spacing: 16) {
                Text("Ready to excel?")
                    .font(.forma(.title, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Add your first course to start tracking grades, schedules, and assignments with beautiful analytics")
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // Gorgeous call-to-action button
            Button("Add Your First Course") {
                showingAddCourseSheet = true
            }
            .font(.forma(.headline, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.secondaryColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.4),
                    radius: 16, x: 0, y: 8
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.2),
                    radius: 8, x: 0, y: 4
                )
            )
            .buttonStyle(EnhancedButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.3),
                                    themeManager.currentTheme.secondaryColor.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.1),
                    radius: 24, x: 0, y: 12
                )
        )
    }
    
    // MARK: - Magical Floating Add Button
    private var magicalFloatingAddButton: some View {
        ExpandableFAB(
            onCreateCourse: { showingAddCourseSheet = true },
            onCreateSchedule: { showingScheduleManager = true }
        )
        .environmentObject(themeManager)
    }
    
    // MARK: - Enhanced Selection Toolbar
    private var enhancedSelectionToolbar: some View {
        HStack {
            Text("\(bulkSelectionManager.selectedCount()) selected")
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Select All") {
                toggleSelectAll()
            }
            .font(.forma(.subheadline, weight: .semibold))
            .foregroundColor(themeManager.currentTheme.primaryColor)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.primaryColor.opacity(0.3),
                            themeManager.currentTheme.secondaryColor.opacity(0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2),
            alignment: .bottom
        )
    }
    
    // MARK: - Helper Methods
    // PERFORMANCE FIX: Removed startAnimations() and stopAnimations()
    // These were using repeatForever animations that caused 100% CPU usage
    // when swiping between tabs. The continuous state changes triggered
    // expensive recomputation of activeScheduleCourses and other computed properties.

    private func deleteCourse(_ course: Course) {
        courseToDelete = course
        showDeleteCourseAlert = true
    }

    private func longPressGesture(for course: Course) -> some Gesture {
        LongPressGesture(minimumDuration: 0.6)
            .onEnded { _ in
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                bulkSelectionManager.startSelection(.courses, initialID: course.id)
            }
    }
    
    private func handleConflictResolution(_ resolution: OrphanResolutionAction) {
        switch resolution {
        case .assignCourseToActiveSchedule(let course):
             ("Assigning course \(course.name) to active schedule")
        case .createScheduleForCourse(let course):
             ("Creating new schedule for course \(course.name)")
        case .createCourseFromScheduleItem(let scheduleItemWrapper):
             ("Creating course from schedule item \(scheduleItemWrapper.scheduleItem.title)")
        case .mergeScheduleItemWithCourse(let scheduleItemWrapper, let course):
             ("Merging schedule item \(scheduleItemWrapper.scheduleItem.title) with course \(course.name)")
        case .deleteOrphanedCourse(let course):
            courseManager.deleteCourse(course.id)
             ("Deleted orphaned course \(course.name)")
        case .deleteOrphanedScheduleItem(let scheduleItemWrapper):
             ("Deleted orphaned schedule item \(scheduleItemWrapper.scheduleItem.title)")
        }
    }
    
    private func refreshData() async {
        await viewModel.refreshData(courseManager: courseManager)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if bulkSelectionManager.isSelecting && bulkSelectionManager.selectionContext == .courses {
                Button(selectionAllButtonTitle()) {
                    toggleSelectAll()
                }
                .foregroundColor(themeManager.currentTheme.primaryColor)
                
                Button(role: .destructive) {
                    showBulkDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(bulkSelectionManager.selectedCount() == 0)
                .foregroundColor(bulkSelectionManager.selectedCount() == 0 ? .secondary : .red)
            }
        }
        
        ToolbarItemGroup(placement: .navigationBarLeading) {
            if bulkSelectionManager.isSelecting {
                Button("Cancel") {
                    bulkSelectionManager.endSelection()
                }
                .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var deleteAlert: some View {
        Button("Cancel", role: .cancel) { courseToDelete = nil }
        Button("Delete", role: .destructive) {
            if let course = courseToDelete {
                courseManager.deleteCourse(course.id)
            }
            courseToDelete = nil
        }
    }
    
    @ViewBuilder
    private var bulkDeleteAlert: some View {
        Button("Cancel", role: .cancel) { }
        Button("Delete", role: .destructive) {
            for courseID in bulkSelectionManager.selectedCourseIDs {
                courseManager.deleteCourse(courseID)
            }
            bulkSelectionManager.endSelection()
        }
    }
    
    private func selectionAllButtonTitle() -> String {
        let total = activeScheduleCourses.count
        let selected = bulkSelectionManager.selectedCount()
        return selected == total && total > 0 ? "Deselect All" : "Select All"
    }
    
    private func toggleSelectAll() {
        let total = activeScheduleCourses.count
        let selected = bulkSelectionManager.selectedCount()
        
        if selected == total && total > 0 {
            bulkSelectionManager.deselectAll()
        } else {
            bulkSelectionManager.selectAll(items: activeScheduleCourses)
        }
    }

    private func loadYearSelectionFromStorage() {
        selectedYearScheduleIDs = viewModel.loadYearSelection(from: selectedYearScheduleIDsStorage, scheduleManager: scheduleManager)
        saveYearSelectionToStorage()
    }

    private func saveYearSelectionToStorage() {
        selectedYearScheduleIDsStorage = selectedYearScheduleIDs.map { $0.uuidString }.joined(separator: ",")
    }

    private func syncSelectionWithAvailableSchedules() {
        selectedYearScheduleIDs = viewModel.syncSelectionWithAvailableSchedules(selectedYearScheduleIDs, scheduleManager: scheduleManager)
        saveYearSelectionToStorage()
    }

}

#Preview {
    NavigationView {
        GPAView()
            .environmentObject(ThemeManager())
    }
}