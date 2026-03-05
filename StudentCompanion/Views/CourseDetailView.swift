import SwiftUI
import Combine

struct CourseDetailView: View {
    @ObservedObject var course: Course
    var courseManager: UnifiedCourseManager?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var calendarSyncManager: CalendarSyncManager
    @ObservedObject private var onboardingManager = GuidedOnboardingManager.shared

    // Use the live course from courseManager if available, otherwise fallback to the passed course
    private var liveCourse: Course {
        if let courseManager = courseManager,
           let managedCourse = courseManager.courses.first(where: { $0.id == course.id }) {
            return managedCourse
        }
        return course
    }

    // Sorted assignments: due date first (earliest to latest), then no due date alphabetically
    private var sortedAssignments: [Assignment] {
        let withDueDate = liveCourse.assignments.filter { $0.dueDate != nil }
            .sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }

        let withoutDueDate = liveCourse.assignments.filter { $0.dueDate == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return withDueDate + withoutDueDate
    }
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var bulkSelectionManager = BulkCourseSelectionManager()
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false
    @State private var showBulkDeleteAlert = false
    @State private var showingAddAssignmentSheet = false
    @State private var selectedAssignment: Assignment? = nil

    // Documents Section
    @State private var showDocumentsView = false

    // Syllabus Import (legacy, keeping for now)
    @State private var showSyllabusImport = false
    @State private var showSyllabusReview = false
    @State private var importedSyllabusData: SyllabusImportData?
    @State private var storedSyllabusURL: String?
    @State private var showPDFViewer = false

    // Google Calendar sync for assignments
    @State private var showingGoogleCalendarPrompt = false
    @State private var importedAssignmentsForSync: [Assignment] = []

    @State private var currentGradeInput: String = ""
    @State private var desiredGradeInput: String = ""
    @State private var finalWorthInput: String = ""
    @State private var neededOnFinalOutput: String = ""
    @State private var showingGradeCurvePopup = false
    @AppStorage("gradeDecimalPrecision") private var gradeDecimalPrecision: Int = 1

    private var weightValidation: (total: Double, isValid: Bool, message: String) {
        var totalWeight = 0.0
        var assignmentsWithWeights = 0

        for assignment in liveCourse.assignments {
            if let weight = assignment.weightValue, weight > 0 {
                totalWeight += weight
                assignmentsWithWeights += 1
            }
        }

        let isValid = totalWeight <= 100.0
        var message = ""

        if assignmentsWithWeights == 0 {
            message = "No assignment weights set"
        } else if totalWeight > 100.0 {
            let excess = totalWeight - 100.0
            message = String(format: "Exceeds 100%% by %.1f%%", excess)
        } else {
            message = ""
        }

        return (total: totalWeight, isValid: isValid, message: message)
    }

    private func requestSave() {
        var allCourses = CourseStorage.load()
        if let index = allCourses.firstIndex(where: { $0.id == course.id }) {
            allCourses[index] = course
            CourseStorage.save(allCourses)
        }
    }

    private func syncAssignmentsToGoogleCalendar() {
        guard !importedAssignmentsForSync.isEmpty else { return }

        Task {
            // TODO: Implement Google Calendar sync for imported assignments
            print("📅 Would sync \(importedAssignmentsForSync.count) assignments to Google Calendar")
            for assignment in importedAssignmentsForSync {
                print("📅   - \(assignment.name)")
            }

            // Clear the imported assignments after attempting sync
            await MainActor.run {
                importedAssignmentsForSync = []
            }
        }
    }

    private var textColor: Color {
        course.color.isDark ? .white : .black
    }

    // Get professor name from the first lecture meeting
    private var professorName: String? {
        // First try to find a lecture meeting with an instructor
        if let lectureMeeting = course.meetings.first(where: { $0.meetingType == .lecture && !$0.instructor.isEmpty }) {
            return lectureMeeting.instructor
        }

        // Fall back to any meeting with an instructor
        if let anyMeetingWithInstructor = course.meetings.first(where: { !$0.instructor.isEmpty }) {
            return anyMeetingWithInstructor.instructor
        }

        // Fall back to the course's default instructor
        return course.instructor.isEmpty ? nil : course.instructor
    }

    private var mainContent: some View {
        ZStack {
            // Spectacular background
            spectacularBackground

            ScrollView {
                VStack(spacing: 24) {
                    spectacularHeaderView
                    assignmentsSection
                    finalGradeCalculatorSection
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }

    var body: some View {
        mainContent
            .navigationTitle(course.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .onboardingTooltip(
                icon: onboardingManager.courseDetailTooltipStep.icon,
                text: onboardingManager.courseDetailTooltipStep.text,
                accentColor: themeManager.currentTheme.primaryColor,
                isVisible: onboardingManager.courseDetailTooltipStep == .gradesIntro || onboardingManager.courseDetailTooltipStep == .documentsTip,
                autoDismissDelay: 4,
                onDismiss: {
                    if onboardingManager.courseDetailTooltipStep == .gradesIntro {
                        onboardingManager.courseDetailTooltipStep = .documentsTip
                    } else {
                        onboardingManager.dismissCourseDetailTooltips()
                    }
                }
            )
            .onDisappear {
                if onboardingManager.isActive && onboardingManager.courseDetailTooltipStep != .none {
                    onboardingManager.dismissCourseDetailTooltips()
                    // Advance to reminders tip after leaving course detail
                    if onboardingManager.currentStep == .coursesTip {
                        onboardingManager.advanceFromCoursesTip()
                    }
                }
            }
        .sheet(isPresented: $showingAddAssignmentSheet) {
            AddAssignmentView(course: course, courseManager: courseManager)
                .environmentObject(themeManager)
        }
        .sheet(item: $selectedAssignment) { assignment in
            EditAssignmentView(assignment: assignment, course: course, courseManager: courseManager)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingGradeCurvePopup) {
            if let courseManager = courseManager {
                GradeCurvePopup(course: liveCourse)
                    .environmentObject(themeManager)
                    .environmentObject(courseManager)
                    .presentationDetents([.height(500)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.clear)
            }
        }
        .sheet(isPresented: $showDocumentsView) {
            NavigationView {
                CourseDocumentsView(course: course, courseManager: courseManager)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showSyllabusImport) {
            SyllabusImportSheet(course: course) { importData in
                print("📋 CourseDetailView: Received import data with \(importData.parsedAssignments.count) assignments")
                importedSyllabusData = importData
                storedSyllabusURL = importData.storedPDFURL
                showSyllabusImport = false
                print("📋 CourseDetailView: Setting showSyllabusReview = true")
                showSyllabusReview = true
            }
        }
        .sheet(isPresented: $showSyllabusReview) {
            if let importData = importedSyllabusData {
                SyllabusReviewModal(
                    course: course,
                    importData: importData,
                    onImport: { assignments in
                        print("📋 CourseDetailView: User confirmed import of \(assignments.count) assignments")
                        print("📋 CourseDetailView: Course ID: \(course.id)")
                        print("📋 CourseDetailView: CourseManager available: \(courseManager != nil)")

                        // Add assignments via courseManager to sync to database
                        for (index, assignment) in assignments.enumerated() {
                            print("📋 CourseDetailView: Importing assignment \(index + 1)/\(assignments.count): '\(assignment.name)'")

                            if let courseManager = courseManager {
                                print("📋 CourseDetailView: Calling courseManager.addAssignment for '\(assignment.name)'")
                                courseManager.addAssignment(assignment, to: course.id)
                                print("📋 CourseDetailView: courseManager.addAssignment completed for '\(assignment.name)'")
                            } else {
                                print("⚠️ CourseDetailView: No courseManager - using fallback for '\(assignment.name)'")
                                // Fallback: add locally only if no courseManager
                                course.addAssignment(assignment)
                                requestSave()
                            }
                        }

                        showSyllabusReview = false

                        // Haptic feedback
                        let successFeedback = UINotificationFeedbackGenerator()
                        successFeedback.notificationOccurred(.success)

                        print("📋 CourseDetailView: Import complete. Total assignments imported: \(assignments.count)")

                        // Check if Google Calendar is connected and show prompt
                        if calendarSyncManager.googleCalendarManager.isSignedIn {
                            importedAssignmentsForSync = assignments
                            showingGoogleCalendarPrompt = true
                        }
                    }
                )
            }
        }
        .toolbar {
            toolbarContent
        }
        .onAppear {
            autoFillCalculatorValues()
            loadAssignmentsIfNeeded()
        }
        .task {
            // Ensure assignments are loaded from database when view appears
            await ensureAssignmentsLoadedInCourseManager()
        }
        .onChange(of: course.assignments) { oldValue, newValue in
            autoFillCalculatorValues()
            requestSave()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            reloadCourseData()
        }
        .alert("Sync to Google Calendar?", isPresented: $showingGoogleCalendarPrompt) {
            Button("Sync") {
                syncAssignmentsToGoogleCalendar()
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("Would you like to sync these \(importedAssignmentsForSync.count) assignments to your Google Calendar?")
        }
        .alert("Delete Selected Assignments?", isPresented: $showBulkDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                bulkDeleteAssignments()
            }
        } message: {
            Text("This will permanently delete \(bulkSelectionManager.selectedCount()) assignment(s).")
        }
    }

    // MARK: - Spectacular Background

    private var spectacularBackground: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                colors: [
                    course.color.opacity(colorScheme == .dark ? 0.15 : 0.08),
                    course.color.opacity(colorScheme == .dark ? 0.08 : 0.04),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // PERFORMANCE FIX: Static decorative circles - removed expensive blur effects
            // Using simple opacity fills instead of RadialGradient + blur (was causing GPU overload)
            Circle()
                .fill(course.color.opacity(colorScheme == .dark ? 0.08 : 0.04))
                .frame(width: 320, height: 320)
                .offset(x: -100, y: -150)

            Circle()
                .fill(course.color.opacity(colorScheme == .dark ? 0.06 : 0.03))
                .frame(width: 280, height: 280)
                .offset(x: 150, y: 200)
        }
    }

    // MARK: - Compact Header

    private var spectacularHeaderView: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                textColor.opacity(0.15),
                                textColor.opacity(0.05)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: 52, height: 52)

                if let emoji = course.emoji {
                    Text(emoji)
                        .font(.system(size: 26))
                } else {
                    Image(systemName: course.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(textColor)
                }
            }

            // Course code and professor
            VStack(alignment: .leading, spacing: 4) {
                Text(!course.courseCode.isEmpty ? course.courseCode : course.name)
                    .font(.forma(.body, weight: .bold))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                if let professorName = professorName, !professorName.isEmpty {
                    Text(professorName)
                        .font(.forma(.caption, weight: .medium))
                        .foregroundColor(textColor.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Documents Button
            documentsButton

            // Grade only (right side)
            gradeDisplay
        }
        .padding(16)
        .background(
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        course.color.opacity(0.95),
                        course.color,
                        course.color.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle overlay gradient
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    Color.white.opacity(colorScheme == .dark ? 0.15 : 0.3),
                    lineWidth: 1
                )
        )
        // PERFORMANCE FIX: Reduced shadow radius from 10 to 6
        .shadow(
            color: course.color.opacity(0.2),
            radius: 6, x: 0, y: 3
        )
    }

    @ViewBuilder
    private var documentsButton: some View {
        Button(action: {
            showDocumentsView = true
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            Image(systemName: "doc.fill")
                .font(.system(size: 20))
                .foregroundColor(textColor)
                .padding(8)
                .background(textColor.opacity(0.15))
                .clipShape(Circle())
        }
    }

    @ViewBuilder
    private var gradeDisplay: some View {
        let grade = calculateCurrentGrade()
        if grade != "N/A" {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(grade)%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(textColor)

                    // Show curve indicator if curve is applied
                    if liveCourse.gradeCurve != 0 {
                        Image(systemName: liveCourse.gradeCurve > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(liveCourse.gradeCurve > 0 ? .green : .red)
                    }
                }

                // Show raw grade and curve value when curve is applied
                if liveCourse.gradeCurve != 0, let rawGrade = liveCourse.calculateRawGrade() {
                    HStack(spacing: 4) {
                        Text(String(format: "%.\(gradeDecimalPrecision)f%%", rawGrade))
                            .foregroundColor(textColor.opacity(0.7))
                        Text(liveCourse.gradeCurve > 0 ? "+" : "")
                            .foregroundColor(liveCourse.gradeCurve > 0 ? .green : .red) +
                        Text(String(format: "%.\(gradeDecimalPrecision)f", liveCourse.gradeCurve))
                            .foregroundColor(liveCourse.gradeCurve > 0 ? .green : .red)
                    }
                    .font(.system(size: 11, weight: .medium))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingGradeCurvePopup = true
            }
        }
    }

    // MARK: - Assignments Section

    private var assignmentsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            assignmentsSectionHeader

            if !course.assignments.isEmpty {
                weightValidationView
            }

            assignmentsList
        }
        .padding(20)
        .background(
            ZStack {
                // PERFORMANCE FIX: Replaced expensive .regularMaterial with solid color
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground).opacity(0.95))

                // PERFORMANCE FIX: Simplified gradient border to solid color
                RoundedRectangle(cornerRadius: 20)
                    .stroke(course.color.opacity(0.2), lineWidth: 1)
            }
        )
        // PERFORMANCE FIX: Reduced shadow radius from 12 to 6
        .shadow(
            color: course.color.opacity(colorScheme == .dark ? 0.15 : 0.08),
            radius: 6, x: 0, y: 3
        )
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity : 0,
            cornerRadius: 20
        )
    }

    private var assignmentsSectionHeader: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(course.color.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: "doc.text.fill")
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                course.color,
                                course.color.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Assignments & Exams")
                .font(.forma(.title3, weight: .bold))
                .foregroundColor(.primary)

            Spacer()

            if bulkSelectionManager.isSelecting {
                Text("\(bulkSelectionManager.selectedCount()) selected")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.secondary)
                    .animation(.easeInOut(duration: 0.2), value: bulkSelectionManager.selectedCount())
            } else {
                Button(action: {
                    showingAddAssignmentSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.forma(.subheadline, weight: .bold))
                        Text("Add")
                            .font(.forma(.subheadline, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    // PERFORMANCE FIX: Simplified gradient to solid, reduced shadow
                    .background(
                        Capsule()
                            .fill(course.color)
                            .shadow(
                                color: course.color.opacity(0.3),
                                radius: 4, x: 0, y: 2
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var weightValidationView: some View {
        let validation = weightValidation

        if !validation.isValid && !validation.message.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.forma(.subheadline, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Weight Issue")
                        .font(.forma(.caption, weight: .bold))
                        .foregroundColor(.primary)
                    Text(validation.message)
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(String(format: "%.0f", validation.total))%")
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.orange)
                    )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: validation.isValid)
        }
    }

    @ViewBuilder
    private var assignmentsList: some View {
        if sortedAssignments.isEmpty {
            emptyAssignmentsView
        } else {
            LazyVStack(spacing: 8) {
                ForEach(Array(sortedAssignments.enumerated()), id: \.offset) { index, assignment in
                    let uniqueID = "\(assignment.id.uuidString)-\(index)"

                    if bulkSelectionManager.selectionContext == .assignments(courseID: course.id) {
                        selectionModeAssignmentRow(assignment)
                            .id(uniqueID + "-selection")
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        normalModeAssignmentRow(assignment)
                            .id(uniqueID + "-normal")
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sortedAssignments.count)
        }
    }

    private var emptyAssignmentsView: some View {
        VStack(spacing: 16) {
            ZStack {
                // PERFORMANCE FIX: Simplified decorative background - replaced RadialGradient with solid opacity
                Circle()
                    .fill(course.color.opacity(0.08))
                    .frame(width: 100, height: 100)

                Image(systemName: "doc.text")
                    .font(.system(size: 44, weight: .light))
                    // PERFORMANCE FIX: Replaced gradient with solid color
                    .foregroundColor(course.color.opacity(0.5))
            }

            VStack(spacing: 6) {
                Text("No assignments added yet")
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Add your first assignment to start tracking")
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showingAddAssignmentSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.forma(.subheadline))
                    Text("Add Assignment")
                        .font(.forma(.subheadline, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                // PERFORMANCE FIX: Simplified gradient to solid, reduced shadow
                .background(
                    Capsule()
                        .fill(course.color)
                        .shadow(color: course.color.opacity(0.3), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func selectionModeAssignmentRow(_ assignment: Assignment) -> some View {
        HStack(spacing: 12) {
            SpectacularAssignmentRow(
                assignment: assignment,
                courseColor: course.color,
                onTap: { selectedAssignment = assignment }
            )

            Image(systemName: bulkSelectionManager.isSelected(assignment.id) ? "checkmark.circle.fill" : "circle")
                .font(.forma(.title3, weight: .semibold))
                .foregroundColor(bulkSelectionManager.isSelected(assignment.id) ? course.color : .secondary)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: bulkSelectionManager.isSelected(assignment.id))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            bulkSelectionManager.toggleSelection(assignment.id)
        }
    }

    private func normalModeAssignmentRow(_ assignment: Assignment) -> some View {
        SpectacularAssignmentRow(
            assignment: assignment,
            courseColor: course.color,
            onTap: { selectedAssignment = assignment }
        )
        .contextMenu {
            assignmentContextMenu(assignment)
        }
    }

    @ViewBuilder
    private func assignmentContextMenu(_ assignment: Assignment) -> some View {
        Button(action: {
            selectedAssignment = assignment
        }) {
            Label("Edit Assignment", systemImage: "pencil")
        }

        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            bulkSelectionManager.startSelection(.assignments(courseID: course.id), initialID: assignment.id)
        }) {
            Label("Select Multiple", systemImage: "checkmark.circle")
        }

        Button(role: .destructive, action: {
            deleteAssignment(assignment)
        }) {
            Label("Delete Assignment", systemImage: "trash")
        }
    }

    // MARK: - Final Grade Calculator

    private var finalGradeCalculatorSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(course.color.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "function")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    course.color,
                                    course.color.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Final Grade Calculator")
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(.primary)
            }

            // Input fields
            VStack(spacing: 14) {
                SpectacularCalculatorRow(
                    title: "Your current grade:",
                    value: $currentGradeInput,
                    suffix: "%",
                    placeholder: "e.g. 88",
                    courseColor: course.color
                )

                SpectacularCalculatorRow(
                    title: "Grade you want:",
                    value: $desiredGradeInput,
                    suffix: "%",
                    placeholder: "85",
                    courseColor: course.color
                )

                SpectacularCalculatorRow(
                    title: "Final exam weight:",
                    value: $finalWorthInput,
                    suffix: "%",
                    placeholder: "100",
                    courseColor: course.color
                )
            }

            // Action buttons
            HStack(spacing: 12) {
                Button("Clear") {
                    currentGradeInput = ""
                    desiredGradeInput = ""
                    finalWorthInput = ""
                    neededOnFinalOutput = ""
                    autoFillCalculatorValues()
                }
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(course.color)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                // PERFORMANCE FIX: Replaced .ultraThinMaterial with solid color, simplified stroke
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemBackground).opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(course.color.opacity(0.3), lineWidth: 1)
                        )
                )
                .buttonStyle(.plain)

                Button("Calculate") {
                    calculateNeededOnFinal()
                }
                .font(.forma(.subheadline, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                // PERFORMANCE FIX: Simplified to single solid fill, reduced shadow
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(course.color)
                        .shadow(color: course.color.opacity(0.3), radius: 4, x: 0, y: 2)
                )
                .buttonStyle(.plain)
            }

            // Result display
            if !neededOnFinalOutput.isEmpty {
                finalGradeResultView
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: neededOnFinalOutput)
            }
        }
        .padding(20)
        .background(
            ZStack {
                // PERFORMANCE FIX: Replaced expensive .regularMaterial with solid color
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground).opacity(0.95))

                // PERFORMANCE FIX: Simplified gradient stroke to solid color
                RoundedRectangle(cornerRadius: 20)
                    .stroke(course.color.opacity(0.2), lineWidth: 1)
            }
        )
        // PERFORMANCE FIX: Reduced shadow radius from 12 to 6
        .shadow(
            color: course.color.opacity(colorScheme == .dark ? 0.15 : 0.08),
            radius: 6, x: 0, y: 3
        )
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity : 0,
            cornerRadius: 20
        )
    }

    private var finalGradeResultView: some View {
        VStack(spacing: 16) {
            if let neededGrade = Double(neededOnFinalOutput) {
                // Icon and motivational message
                VStack(spacing: 12) {
                    ZStack {
                        // PERFORMANCE FIX: Replaced RadialGradient with solid opacity
                        Circle()
                            .fill(getGradeColor(for: neededGrade).opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: getGradeIcon(for: neededGrade))
                            .font(.system(size: 32, weight: .light))
                            // PERFORMANCE FIX: Replaced gradient with solid color
                            .foregroundColor(getGradeColor(for: neededGrade))
                    }

                    Text(getMotivationalMessage(for: neededGrade))
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }

                // Grade display
                VStack(spacing: 6) {
                    Text("\(neededOnFinalOutput)%")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        // PERFORMANCE FIX: Replaced gradient with solid color
                        .foregroundColor(getGradeColor(for: neededGrade))

                    Text("needed on your final exam")
                        .font(.forma(.caption, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.1)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.forma(.body))
                        .foregroundColor(.orange)
                    Text(neededOnFinalOutput)
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        // PERFORMANCE FIX: Replaced .ultraThinMaterial with solid color
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(course.color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Helper Methods

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if bulkSelectionManager.isSelecting && bulkSelectionManager.selectionContext == .assignments(courseID: course.id) {
                Button(selectionAllButtonTitle()) {
                    toggleSelectAll()
                }
                .foregroundColor(course.color)

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

    private func selectionAllButtonTitle() -> String {
        let total = liveCourse.assignments.count
        let selected = bulkSelectionManager.selectedCount()
        return selected == total && total > 0 ? "Deselect All" : "Select All"
    }

    private func toggleSelectAll() {
        let total = liveCourse.assignments.count
        let selected = bulkSelectionManager.selectedCount()

        if selected == total && total > 0 {
            bulkSelectionManager.deselectAll()
        } else {
            bulkSelectionManager.selectAll(items: liveCourse.assignments)
        }
    }

    private func bulkDeleteAssignments() {
        let assignmentIDsToDelete = bulkSelectionManager.selectedAssignmentIDs

        if let courseManager = courseManager {
            // Let courseManager handle all deletes - it will update local data and sync to database
            for assignmentID in assignmentIDsToDelete {
                courseManager.deleteAssignment(assignmentID, from: course.id)
            }
        } else {
            // Fallback: only if no courseManager available
            course.assignments.removeAll { assignmentIDsToDelete.contains($0.id) }
            requestSave()
        }

        bulkSelectionManager.endSelection()
    }

    func calculateCurrentGrade() -> String {
        var totalWeightedGrade = 0.0
        var totalWeight = 0.0
        for assignment in liveCourse.assignments {
            if let grade = assignment.gradeValue, let weight = assignment.weightValue {
                totalWeightedGrade += grade * weight
                totalWeight += weight
            }
        }
        if totalWeight == 0 { return "N/A" }
        let rawGrade = totalWeightedGrade / totalWeight
        // Apply curve
        let currentGradeVal = max(0, rawGrade + liveCourse.gradeCurve)
        return String(format: "%.\(gradeDecimalPrecision)f", currentGradeVal)
    }

    func calculateNeededOnFinal() {
        guard let current = Double(currentGradeInput),
              let desired = Double(desiredGradeInput),
              let finalWeight = Double(finalWorthInput), finalWeight > 0, finalWeight <= 100 else {
            neededOnFinalOutput = "Please fill in all fields with valid numbers"
            return
        }
        let currentWeightPercentage = (100.0 - finalWeight) / 100.0
        let finalWeightPercentage = finalWeight / 100.0
        let needed = (desired - (current * currentWeightPercentage)) / finalWeightPercentage
        neededOnFinalOutput = String(format: "%.1f", needed)
    }

    private func autoFillCalculatorValues() {
        let calculatedGrade = calculateCurrentGrade()
        if calculatedGrade != "N/A" {
            currentGradeInput = calculatedGrade
        } else if currentGradeInput.isEmpty {
             currentGradeInput = ""
        }

        var totalAssignmentWeight = 0.0
        for assignment in liveCourse.assignments {
            if let weight = assignment.weightValue {
                totalAssignmentWeight += weight
            }
        }
        let remainingWeight = max(0, 100 - totalAssignmentWeight)
        finalWorthInput = String(format: "%.0f", remainingWeight)

        if desiredGradeInput.isEmpty {
            if let currentGradeVal = Double(calculatedGrade), calculatedGrade != "N/A" {
                let suggestedGrade = max(85.0, currentGradeVal + 5.0)
                desiredGradeInput = String(format: "%.0f", min(suggestedGrade, 100.0))
            } else {
                desiredGradeInput = "85"
            }
        }
    }

    private func getMotivationalMessage(for grade: Double) -> String {
        switch grade {
        case ..<0:
            return "🎉 You've already got this! You could skip the final and still pass!"
        case 0..<50:
            return "✨ Very achievable! You're in great shape!"
        case 50..<70:
            return "📚 Totally doable with some solid studying!"
        case 70..<85:
            return "💪 Time to buckle down, but you've got this!"
        case 85..<95:
            return "🔥 Challenge accepted! Time to show what you're made of!"
        case 95..<100:
            return "😅 Yikes! You'll need to channel your inner genius!"
        case 100..<110:
            return "🚀 Technically possible, but you'll need to be absolutely perfect!"
        default:
            return "😬 Hate to break it to you, but this might require a miracle... or extra credit!"
        }
    }

    private func getGradeColor(for grade: Double) -> Color {
        switch grade {
        case ..<50:
            return .green
        case 50..<70:
            return .blue
        case 70..<85:
            return course.color
        case 85..<95:
            return .orange
        default:
            return .red
        }
    }

    private func getGradeIcon(for grade: Double) -> String {
        switch grade {
        case ..<50:
            return "star.fill"
        case 50..<70:
            return "hand.thumbsup.fill"
        case 70..<85:
            return "book.fill"
        case 85..<95:
            return "flame.fill"
        default:
            return "exclamationmark.triangle.fill"
        }
    }

    private func deleteAssignment(_ assignment: Assignment) {
        print("🗑️ CourseDetailView: Delete requested for assignment '\(assignment.name)'")
        print("🔍 DEBUG: Assignment FULL ID: \(assignment.id.uuidString)")
        print("🔍 DEBUG: Course FULL ID: \(course.id.uuidString)")
        print("🗑️ CourseDetailView: CourseManager available: \(courseManager != nil)")

        // DEBUG: Check what liveCourse has
        print("🔍 DEBUG: liveCourse.assignments count: \(liveCourse.assignments.count)")
        print("🔍 DEBUG: liveCourse.assignments IDs:")
        for (index, liveAssignment) in liveCourse.assignments.enumerated() {
            print("  [\(index)] FULL ID: \(liveAssignment.id.uuidString) - Name: '\(liveAssignment.name)'")
            print("      Is this the one we're deleting? \(liveAssignment.id == assignment.id)")
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let courseManager = courseManager {
                print("🗑️ CourseDetailView: Calling courseManager.deleteAssignment()")
                // Let courseManager handle the delete - it will update local data and sync to database
                courseManager.deleteAssignment(assignment.id, from: course.id)
                print("🗑️ CourseDetailView: courseManager.deleteAssignment() called")
            } else {
                print("⚠️ CourseDetailView: No courseManager - using fallback delete")
                // Fallback: only if no courseManager available
                if let index = course.assignments.firstIndex(where: { $0.id == assignment.id }) {
                    course.assignments.remove(at: index)
                    requestSave()
                    print("🗑️ CourseDetailView: Fallback delete completed")
                }
            }
        }
    }

    private func loadAssignmentsIfNeeded() {
        // Load from local storage if courseManager not available
        guard courseManager == nil else { return }

        let allCourses = CourseStorage.load()
        if let updatedCourse = allCourses.first(where: { $0.id == course.id }) {
            course.assignments = updatedCourse.assignments
        }
    }

    private func ensureAssignmentsLoadedInCourseManager() async {
        guard let courseManager = courseManager else { return }

        // Check if this course in courseManager has assignments loaded
        guard let managedCourse = courseManager.courses.first(where: { $0.id == course.id }) else {
            print("⚠️ CourseDetailView: Course not found in courseManager")
            return
        }

        print("🔄 CourseDetailView: Checking assignments for '\(managedCourse.name)'")
        print("🔄 CourseDetailView: CourseManager has \(managedCourse.assignments.count) assignments")

        // If courseManager's course has no assignments but we expect some, reload from database
        if managedCourse.assignments.isEmpty {
            print("🔄 CourseDetailView: No assignments in CourseManager, loading from database...")
            await courseManager.reloadAssignmentsForCourse(course.id)

            if let reloadedCourse = courseManager.courses.first(where: { $0.id == course.id }) {
                print("🔄 CourseDetailView: After reload, CourseManager has \(reloadedCourse.assignments.count) assignments")
            }
        }
    }

    private func reloadCourseData() {
        let allCourses = CourseStorage.load()

        if let updatedCourse = allCourses.first(where: { $0.id == course.id }) {
            DispatchQueue.main.async {
                course.assignments = updatedCourse.assignments
                autoFillCalculatorValues()
            }
        }
    }
}

// MARK: - Spectacular Assignment Row (Redesigned)

struct SpectacularAssignmentRow: View {
    @ObservedObject var assignment: Assignment
    let courseColor: Color
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var eventViewModel: EventViewModel

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left: Category indicator stripe
                categoryStripe
                    .frame(width: 3)

                // Main content
                VStack(alignment: .leading, spacing: 4) {
                    // Top row: Assignment name + Grade
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(assignment.name.isEmpty ? "Untitled Assignment" : assignment.name)
                                .font(.forma(.body, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            // Category badge (if notes contain category info)
                            if !assignment.notes.isEmpty {
                                categoryBadge
                            }
                        }

                        Spacer(minLength: 6)

                        // Grade display - compact and elegant
                        if !assignment.grade.isEmpty {
                            gradeDisplay
                        }
                    }

                    // Bottom row: Metadata chips
                    HStack(spacing: 6) {
                        // Due date chip
                        if let dueDate = assignment.dueDate {
                            dueDateChip(for: dueDate)
                        }

                        // Weight chip
                        if !assignment.weight.isEmpty {
                            weightChip
                        }

                        Spacer(minLength: 0)
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .padding(.vertical, 10)
            }
            // PERFORMANCE FIX: Replaced .ultraThinMaterial with solid color
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground).opacity(0.95))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        categoryColor.opacity(colorScheme == .dark ? 0.25 : 0.15),
                        lineWidth: 0.5
                    )
            )
            // PERFORMANCE FIX: Reduced shadow
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.03),
                radius: 3,
                x: 0,
                y: 1
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    private var categoryStripe: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        categoryColor,
                        categoryColor.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var categoryBadge: some View {
        Text(assignment.notes)
            .font(.forma(.caption2, weight: .medium))
            .foregroundColor(categoryColor)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(categoryColor.opacity(0.1))
            )
    }

    private var gradeDisplay: some View {
        VStack(spacing: 1) {
            Text(assignment.grade)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            gradeIndicatorColor,
                            gradeIndicatorColor.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let gradeValue = assignment.gradeValue {
                Text(gradeLabel(for: gradeValue))
                    .font(.forma(.caption2, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(gradeIndicatorColor.opacity(0.08))
        )
    }

    private func dueDateChip(for dueDate: Date) -> some View {
        let (icon, text, color) = dueDateInfo(for: dueDate)

        return HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.forma(.caption2, weight: .medium))
            Text(text)
                .font(.forma(.caption, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }

    private var weightChip: some View {
        HStack(spacing: 3) {
            Image(systemName: "percent")
                .font(.forma(.caption2, weight: .medium))
            Text(assignment.weight)
                .font(.forma(.caption, weight: .semibold))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.1))
        )
    }

    // MARK: - Helper Methods

    private var categoryColor: Color {
        // Detect category from notes or default to course color
        let notes = assignment.notes.lowercased()

        if notes.contains("exam") || notes.contains("test") || notes.contains("midterm") || notes.contains("final") {
            return .red
        } else if notes.contains("quiz") {
            return .orange
        } else if notes.contains("project") || notes.contains("presentation") {
            return .purple
        } else if notes.contains("homework") || notes.contains("assignment") {
            return .blue
        } else if notes.contains("lab") {
            return .green
        } else if notes.contains("participation") {
            return .teal
        } else {
            return courseColor
        }
    }

    private func dueDateInfo(for dueDate: Date) -> (icon: String, text: String, color: Color) {
        let now = Date()
        let calendar = Calendar.current
        let daysUntilDue = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: dueDate)).day ?? 0

        if daysUntilDue < 0 {
            // Check if there's a matching event that's completed
            let matchingEvent = eventViewModel.events.first { event in
                guard let eventCourseId = event.courseId else { return false }

                // Match by course ID and title (assignment name)
                let titleMatches = event.title.lowercased().contains(assignment.name.lowercased()) ||
                                   assignment.name.lowercased().contains(event.title.lowercased())

                // Check if dates are close (within 1 day) to handle timezone/time differences
                let eventDay = calendar.startOfDay(for: event.date)
                let dueDay = calendar.startOfDay(for: dueDate)
                let daysApart = abs(calendar.dateComponents([.day], from: eventDay, to: dueDay).day ?? 0)

                return eventCourseId == assignment.courseId && titleMatches && daysApart <= 1
            }

            // If event exists and is completed, show "Completed"
            if let event = matchingEvent, event.isCompleted {
                return ("checkmark.circle.fill", "Completed", .green)
            }

            // Otherwise show overdue
            let daysOverdue = abs(daysUntilDue)
            return ("exclamationmark.circle.fill", "\(daysOverdue)d overdue", .red)
        } else if daysUntilDue == 0 {
            return ("flame.fill", "Due today", .orange)
        } else if daysUntilDue == 1 {
            return ("clock.fill", "Due tomorrow", .orange)
        } else if daysUntilDue <= 3 {
            return ("calendar.badge.clock", "\(daysUntilDue)d left", .orange)
        } else if daysUntilDue <= 7 {
            return ("calendar", dueDate.formatted(.dateTime.month(.abbreviated).day()), .secondary)
        } else {
            return ("calendar", dueDate.formatted(.dateTime.month(.abbreviated).day()), .secondary.opacity(0.7))
        }
    }

    private func gradeLabel(for gradeValue: Double) -> String {
        switch gradeValue {
        case 97...100:
            return "A+"
        case 93..<97:
            return "A"
        case 90..<93:
            return "A-"
        case 87..<90:
            return "B+"
        case 83..<87:
            return "B"
        case 80..<83:
            return "B-"
        case 77..<80:
            return "C+"
        case 73..<77:
            return "C"
        case 70..<73:
            return "C-"
        case 67..<70:
            return "D+"
        case 63..<67:
            return "D"
        case 60..<63:
            return "D-"
        default:
            return "F"
        }
    }

    private var gradeIndicatorColor: Color {
        guard let gradeValue = assignment.gradeValue else { return .secondary }

        switch gradeValue {
        case 93...100:
            return .green
        case 85..<93:
            return .blue
        case 77..<85:
            return courseColor
        case 70..<77:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Spectacular Calculator Row

struct SpectacularCalculatorRow: View {
    let title: String
    @Binding var value: String
    let suffix: String
    let placeholder: String
    let courseColor: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.forma(.subheadline))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 6) {
                TextField(placeholder, text: $value)
                    .font(.forma(.body, weight: .semibold))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    // PERFORMANCE FIX: Replaced .ultraThinMaterial with solid color
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground).opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(courseColor.opacity(0.25), lineWidth: 1)
                            )
                    )

                Text(suffix)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(courseColor)
                    .frame(width: 20)
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject var sampleCourse = Course(
            scheduleId: UUID(),
            name: "Applied Logic for Comp Sci",
            iconName: "book.closed.fill",
            colorHex: "007AFF",
            assignments: [
                Assignment(courseId: UUID(), name: "Homework 1", grade: "95", weight: "15", notes: "Chapter 1-3"),
                Assignment(courseId: UUID(), name: "Midterm Exam", grade: "87", weight: "25"),
                Assignment(courseId: UUID(), name: "Final Project", grade: "92", weight: "20")
            ]
        )

        var body: some View {
            NavigationView {
                CourseDetailView(course: sampleCourse)
                    .environmentObject(ThemeManager())
                    .environmentObject(EventViewModel())
            }
        }
    }
    return PreviewWrapper()
}
