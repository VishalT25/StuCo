import SwiftUI

struct YearDetailView: View {
    let allSchedules: [ScheduleCollection]
    let allCourses: [Course]
    @Binding var selectedScheduleIDs: Set<UUID>
    let usePercentageGrades: Bool
    let themeManager: ThemeManager
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var animationOffset: CGFloat = 0
    @AppStorage("gradeDecimalPrecision") private var decimalPrecision: Int = 1

    /// Format grade with user-selected decimal precision
    private func formatGrade(_ value: Double) -> String {
        String(format: "%.\(decimalPrecision)f", value)
    }
    
    private var selectedCourses: [Course] {
        allCourses.filter { selectedScheduleIDs.contains($0.scheduleId) }
    }
    
    private var coursesWithGrades: [(course: Course, grade: Double, creditHours: Double)] {
        selectedCourses.compactMap { course in
            guard let grade = course.calculateCurrentGrade() else { return nil }
            return (course, grade, course.creditHours)
        }
    }
    
    private var yearAverage: Double? {
        guard !coursesWithGrades.isEmpty else { return nil }
        
        let totalWeightedGrade = coursesWithGrades.reduce(0) { $0 + ($1.grade * $1.creditHours) }
        let totalCredits = coursesWithGrades.reduce(0) { $0 + $1.creditHours }
        
        return totalCredits > 0 ? totalWeightedGrade / totalCredits : nil
    }
    
    private var yearGPA: Double? {
        let coursesWithGPA = selectedCourses.compactMap { course -> (Double, Double)? in
            guard let gpaPoints = course.gpaPoints else { return nil }
            return (gpaPoints, course.creditHours)
        }
        
        guard !coursesWithGPA.isEmpty else { return nil }
        
        let totalQualityPoints = coursesWithGPA.reduce(0) { $0 + ($1.0 * $1.1) }
        let totalCredits = coursesWithGPA.reduce(0) { $0 + $1.1 }
        
        return totalCredits > 0 ? totalQualityPoints / totalCredits : nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Beautiful background
                LinearGradient(
                    colors: colorScheme == .dark ? [
                        Color.black,
                        Color(red: 0.02, green: 0.02, blue: 0.05),
                        themeManager.currentTheme.darkModeBackgroundFill.opacity(0.3)
                    ] : [
                        Color(.systemGroupedBackground),
                        themeManager.currentTheme.quaternaryColor.opacity(0.3),
                        Color(.systemBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header card
                        yearOverviewCard
                        
                        // Schedule selection
                        scheduleSelectionSection
                        
                        // Statistics
                        if !coursesWithGrades.isEmpty {
                            statisticsGrid
                            
                            // Schedule breakdown
                            scheduleBreakdownSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Year Statistics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private var yearOverviewCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Academic Year")
                        .font(.forma(.title2, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.secondaryColor,
                                    themeManager.currentTheme.tertiaryColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("\(selectedScheduleIDs.count) of \(allSchedules.count) schedules selected")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let average = yearAverage {
                        Text(usePercentageGrades ? String(format: "%.1f%%", average) : (yearGPA.map { String(format: "%.2f GPA", $0) } ?? String(format: "%.1f%%", average)))
                            .font(.forma(.largeTitle, weight: .bold))
                            .foregroundColor(gradeColor(for: average))
                    } else {
                        Text("No Data")
                            .font(.forma(.title, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(selectedCourses.count) course\(selectedCourses.count == 1 ? "" : "s")")
                        .font(.forma(.caption, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.secondaryColor.opacity(0.3),
                                    themeManager.currentTheme.tertiaryColor.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.secondaryColor.opacity(0.1),
                    radius: 12, x: 0, y: 6
                )
        )
    }
    
    private var scheduleSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Include Schedules")
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("All") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedScheduleIDs = Set(allSchedules.map { $0.id })
                        }
                    }
                    .font(.forma(.caption, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Button("None") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedScheduleIDs.removeAll()
                        }
                    }
                    .font(.forma(.caption, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            
            LazyVStack(spacing: 8) {
                ForEach(allSchedules, id: \.id) { schedule in
                    ScheduleSelectionRow(
                        schedule: schedule,
                        isSelected: selectedScheduleIDs.contains(schedule.id),
                        courseCount: allCourses.filter { $0.scheduleId == schedule.id }.count,
                        themeManager: themeManager
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedScheduleIDs.contains(schedule.id) {
                                selectedScheduleIDs.remove(schedule.id)
                            } else {
                                selectedScheduleIDs.insert(schedule.id)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 8, x: 0, y: 4
                )
        )
    }
    
    private var statisticsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatisticCard(
                title: "Total Credits",
                value: String(format: "%.0f", coursesWithGrades.reduce(0) { $0 + $1.creditHours }),
                icon: "graduationcap.fill",
                color: themeManager.currentTheme.secondaryColor,
                themeManager: themeManager
            )
            
            StatisticCard(
                title: "Courses with Grades",
                value: "\(coursesWithGrades.count)",
                icon: "checkmark.circle.fill",
                color: themeManager.currentTheme.tertiaryColor,
                themeManager: themeManager
            )
            
            if let highest = coursesWithGrades.max(by: { $0.grade < $1.grade }) {
                StatisticCard(
                    title: "Highest Grade",
                    value: usePercentageGrades ? "\(formatGrade(highest.grade))%" : highest.course.letterGrade,
                    icon: "star.fill",
                    color: .green,
                    themeManager: themeManager
                )
            }

            if let lowest = coursesWithGrades.min(by: { $0.grade < $1.grade }) {
                StatisticCard(
                    title: "Lowest Grade",
                    value: usePercentageGrades ? "\(formatGrade(lowest.grade))%" : lowest.course.letterGrade,
                    icon: "arrow.down.circle.fill",
                    color: .orange,
                    themeManager: themeManager
                )
            }
        }
    }
    
    private var scheduleBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule Breakdown")
                .font(.forma(.title3, weight: .bold))
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 12) {
                ForEach(allSchedules.filter { selectedScheduleIDs.contains($0.id) }, id: \.id) { schedule in
                    let scheduleCourses = coursesWithGrades.filter { $0.course.scheduleId == schedule.id }
                    if !scheduleCourses.isEmpty {
                        ScheduleBreakdownCard(
                            schedule: schedule,
                            courses: scheduleCourses,
                            usePercentageGrades: usePercentageGrades,
                            themeManager: themeManager
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 8, x: 0, y: 4
                )
        )
    }
    
    private func gradeColor(for grade: Double) -> Color {
        switch grade {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        case 60..<70: return .red
        default: return .red
        }
    }
    
    private func startAnimations() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
    }
}

// MARK: - Supporting Components
struct ScheduleSelectionRow: View {
    let schedule: ScheduleCollection
    let isSelected: Bool
    let courseCount: Int
    let themeManager: ThemeManager
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.forma(.subheadline))
                    .foregroundColor(isSelected ? themeManager.currentTheme.primaryColor : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(schedule.displayName)
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("\(courseCount) course\(courseCount == 1 ? "" : "s")")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if schedule.isActive {
                    Text("Active")
                        .font(.forma(.caption2, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? themeManager.currentTheme.primaryColor.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? themeManager.currentTheme.primaryColor.opacity(0.3) : Color.secondary.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct ScheduleBreakdownCard: View {
    let schedule: ScheduleCollection
    let courses: [(course: Course, grade: Double, creditHours: Double)]
    let usePercentageGrades: Bool
    let themeManager: ThemeManager
    
    private var scheduleAverage: Double {
        let totalWeightedGrade = courses.reduce(0) { $0 + ($1.grade * $1.creditHours) }
        let totalCredits = courses.reduce(0) { $0 + $1.creditHours }
        return totalCredits > 0 ? totalWeightedGrade / totalCredits : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(schedule.displayName)
                        .font(.forma(.subheadline, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("\(courses.count) course\(courses.count == 1 ? "" : "s")")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(usePercentageGrades ? String(format: "%.1f%%", scheduleAverage) : String(format: "%.1f%%", scheduleAverage))
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(gradeColor(for: scheduleAverage))
            }
            
            // Mini course list
            HStack(spacing: 8) {
                ForEach(Array(courses.prefix(3)), id: \.course.id) { item in
                    Text(item.course.courseCode.isEmpty ? String(item.course.name.prefix(3)).uppercased() : item.course.courseCode)
                        .font(.forma(.caption2, weight: .semibold))
                        .foregroundColor(item.course.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(item.course.color.opacity(0.15))
                        )
                }
                
                if courses.count > 3 {
                    Text("+\(courses.count - 3)")
                        .font(.forma(.caption2, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func gradeColor(for grade: Double) -> Color {
        switch grade {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        case 60..<70: return .red
        default: return .red
        }
    }
}

#Preview {
    let themeManager = ThemeManager()
    @State var selectedIDs: Set<UUID> = []
    
    YearDetailView(
        allSchedules: [],
        allCourses: [],
        selectedScheduleIDs: $selectedIDs,
        usePercentageGrades: true,
        themeManager: themeManager
    )
    .environmentObject(themeManager)
}