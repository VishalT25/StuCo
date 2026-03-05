import SwiftUI

struct SpectacularCourseCard: View {
    let course: Course
    let courseManager: UnifiedCourseManager
    let bulkSelectionManager: BulkCourseSelectionManager
    let themeManager: ThemeManager
    let usePercentageGrades: Bool
    let animationDelay: Double
    let onDelete: () -> Void
    let onLongPress: () -> Void
    
    @State private var isPressed = false
    @State private var animationOffset: CGFloat = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var showingEditCourseSheet = false
    @State private var showingGradeCurvePopup = false
    @State private var displayedGradePercentage: Double = 0
    @State private var gradeUpdateTask: Task<Void, Never>?
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("gradeDecimalPrecision") private var decimalPrecision: Int = 1

    // Access ScheduleManager through environment
    @EnvironmentObject private var scheduleManager: ScheduleManager

    private var isSelected: Bool {
        bulkSelectionManager.isSelected(course.id)
    }

    private var currentGradePercentage: Double {
        guard let grade = course.calculateCurrentGrade() else { return 0 }
        return max(0, min(100, grade))
    }
    
    private var progressRingColor: Color {
        switch displayedGradePercentage {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        case 60..<70: return .red
        default: return .red
        }
    }

    /// Format grade with user-selected decimal precision
    private func formatGrade(_ value: Double) -> String {
        String(format: "%.\(decimalPrecision)f", value)
    }

    /// Debounced grade update to prevent animation glitches
    private func updateDisplayedGrade() {
        gradeUpdateTask?.cancel()
        gradeUpdateTask = Task {
            // Small delay to debounce rapid updates
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            guard !Task.isCancelled else { return }
            await MainActor.run {
                let newGrade = currentGradePercentage
                if abs(displayedGradePercentage - newGrade) > 0.01 {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        displayedGradePercentage = newGrade
                    }
                }
            }
        }
    }
    
    var body: some View {
        if bulkSelectionManager.selectionContext == .courses {
            // In selection mode: Add tap gesture for selection
            cardContent
                .contentShape(Rectangle())
                .onTapGesture {
                    bulkSelectionManager.toggleSelection(course.id)
                }
                .onLongPressGesture(minimumDuration: 0.6) {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    onLongPress()
                }
                .contextMenu {
                    contextMenuContent
                }
                .sheet(isPresented: $showingEditCourseSheet) {
                    EnhancedAddCourseWithMeetingsView(existingCourse: course)
                        .environmentObject(themeManager)
                        .environmentObject(scheduleManager)
                        .environmentObject(courseManager)
                }
                .sheet(isPresented: $showingGradeCurvePopup) {
                    GradeCurvePopup(course: course)
                        .environmentObject(themeManager)
                        .environmentObject(courseManager)
                        .presentationDetents([.height(500)])
                        .presentationDragIndicator(.visible)
                        .presentationBackground(.clear)
                }
                .onAppear {
                    startAnimations()
                }
                .onChange(of: course.assignments.count) { _, _ in
                    updateDisplayedGrade()
                }
                .onChange(of: course.assignments.map { "\($0.grade)-\($0.weight)" }) { _, _ in
                    updateDisplayedGrade()
                }
                .onChange(of: course.gradeCurve) { _, _ in
                    updateDisplayedGrade()
                }
        } else {
            // Not in selection mode: No tap gesture - let NavigationLink handle taps
            cardContent
                .onLongPressGesture(minimumDuration: 0.6) {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    onLongPress()
                }
                .contextMenu {
                    contextMenuContent
                }
                .sheet(isPresented: $showingEditCourseSheet) {
                    EnhancedAddCourseWithMeetingsView(existingCourse: course)
                        .environmentObject(themeManager)
                        .environmentObject(scheduleManager)
                        .environmentObject(courseManager)
                }
                .sheet(isPresented: $showingGradeCurvePopup) {
                    GradeCurvePopup(course: course)
                        .environmentObject(themeManager)
                        .environmentObject(courseManager)
                        .presentationDetents([.height(500)])
                        .presentationDragIndicator(.visible)
                        .presentationBackground(.clear)
                }
                .onAppear {
                    startAnimations()
                }
                .onChange(of: course.assignments.count) { _, _ in
                    updateDisplayedGrade()
                }
                .onChange(of: course.assignments.map { "\($0.grade)-\($0.weight)" }) { _, _ in
                    updateDisplayedGrade()
                }
                .onChange(of: course.gradeCurve) { _, _ in
                    updateDisplayedGrade()
                }
        }
    }
    
    private var cardContent: some View {
        VStack(spacing: 0) {
            // Main content area
            HStack(spacing: 16) {
                // Left side: Course icon and progress ring
                ZStack {
                    // Progress ring background
                    Circle()
                        .stroke(
                            course.color.opacity(0.2),
                            lineWidth: 4
                        )
                        .frame(width: 60, height: 60)
                    
                    // Progress ring foreground - uses stable displayedGradePercentage to prevent glitches
                    if course.calculateCurrentGrade() != nil {
                        Circle()
                            .trim(from: 0, to: displayedGradePercentage / 100)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        progressRingColor,
                                        progressRingColor.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(
                                    lineWidth: 4,
                                    lineCap: .round
                                )
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                    }
                    
                    // Course icon
                    Image(systemName: course.iconName)
                        .font(.forma(.title3, weight: .semibold))
                        .foregroundColor(course.color)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                }
                
                // Center: Course information
                VStack(alignment: .leading, spacing: 6) {
                    // Course name and code
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.name)
                            .font(.forma(.headline, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        if !course.courseCode.isEmpty {
                            HStack(spacing: 6) {
                                Text(course.courseCode)
                                    .font(.forma(.caption, weight: .medium))
                                    .foregroundColor(course.color)
                                
                                // Show instructor instead of section
                                if !course.instructor.isEmpty {
                                    Text("• \(course.instructor)")
                                        .font(.forma(.caption))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Right side: Grade display and selection
                VStack(alignment: .trailing, spacing: 8) {
                    if bulkSelectionManager.selectionContext == .courses {
                        // Selection indicator
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.forma(.title2))
                            .foregroundColor(isSelected ? themeManager.currentTheme.primaryColor : .secondary.opacity(0.6))
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                    } else {
                        // Grade display - tappable to show curve popup
                        VStack(alignment: .trailing, spacing: 4) {
                            if let grade = course.calculateCurrentGrade() {
                                VStack(alignment: .trailing, spacing: 2) {
                                    // Main grade
                                    HStack(spacing: 4) {
                                        Text(usePercentageGrades ? "\(formatGrade(grade))%" : course.letterGrade)
                                            .font(.forma(.title2, weight: .bold))
                                            .foregroundColor(progressRingColor)

                                        // Show curve indicator if curve is applied
                                        if course.gradeCurve != 0 {
                                            Image(systemName: "arrow.up.right")
                                                .font(.caption2)
                                                .foregroundColor(course.gradeCurve > 0 ? .green : .red)
                                        }
                                    }

                                    // GPA points (if not using percentage)
                                    if !usePercentageGrades, let gpa = course.gpaPoints {
                                        Text(String(format: "%.2f GPA", gpa))
                                            .font(.forma(.caption, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    showingGradeCurvePopup = true
                                }
                            } else {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("No Grade")
                                        .font(.forma(.subheadline, weight: .medium))
                                        .foregroundColor(.secondary)

                                    Text("Add assignments")
                                        .font(.forma(.caption))
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
            
            // Bottom bar: Assignment info only
            if !bulkSelectionManager.isSelecting {
                HStack(spacing: 16) {
                    // Assignment count with icon
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.forma(.caption2))
                            .foregroundColor(course.color.opacity(0.8))
                        
                        Text("\(course.assignments.count) assignment\(course.assignments.count == 1 ? "" : "s")")
                            .font(.forma(.caption, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .background(
            ZStack {
                // PERFORMANCE FIX: Simplified background - removed expensive material
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground).opacity(0.95))

                // Course color accent - simplified gradient
                RoundedRectangle(cornerRadius: 24)
                    .fill(course.color.opacity(colorScheme == .dark ? 0.1 : 0.05))

                // PERFORMANCE FIX: Removed shimmer effect - was causing expensive gradient recalculations

                // Simplified border - single color instead of gradient
                RoundedRectangle(cornerRadius: 24)
                    .stroke(course.color.opacity(isSelected ? 0.5 : 0.2), lineWidth: isSelected ? 2 : 1)
            }
            .scaleEffect(isSelected ? 0.98 : (isPressed ? 0.99 : 1.0))
            // PERFORMANCE FIX: Single shadow with reduced radius (was 12-26, now 6)
            .shadow(
                color: course.color.opacity(0.15),
                radius: 6,
                x: 0,
                y: 3
            )
        )
        .animation(.easeOut(duration: 0.2), value: isSelected)
        .scaleEffect(isPressed ? 0.98 : 1.0)
    }
    
    private var contextMenuContent: some View {
        Group {
            Button("Edit Course", systemImage: "pencil") {
                showingEditCourseSheet = true
            }
            
            Divider()
            
            Button("Select Multiple", systemImage: "checkmark.circle") {
                bulkSelectionManager.startSelection(.courses, initialID: course.id)
            }
            
            Divider()
            
            Button("Delete Course", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
    }
    
    private func startAnimations() {
        // Offset animation for staggered entrance
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(animationDelay)) {
            animationOffset = 0
        }

        // Initialize grade with animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                displayedGradePercentage = currentGradePercentage
            }
        }
    }
}

#Preview {
    PreviewWrapper()
}

private struct PreviewWrapper: View {
    var body: some View {
        let themeManager = ThemeManager()
        let sampleCourse = Course(
            scheduleId: UUID(),
            name: "Advanced iOS Development",
            iconName: "iphone",
            colorHex: "007AFF",
            assignments: [
                Assignment(courseId: UUID(), name: "Project 1", grade: "95", weight: "20"),
                Assignment(courseId: UUID(), name: "Midterm", grade: "88", weight: "30")
            ],
            instructor: "Dr. Smith",
            courseCode: "CS 4820"
        )

        NavigationView {
            VStack {
                SpectacularCourseCard(
                    course: sampleCourse,
                    courseManager: UnifiedCourseManager(),
                    bulkSelectionManager: BulkCourseSelectionManager(),
                    themeManager: themeManager,
                    usePercentageGrades: true,
                    animationDelay: 0.0,
                    onDelete: {},
                    onLongPress: {}
                )
                .padding()
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
        }
        .environmentObject(themeManager)
    }
}