import SwiftUI

struct SemesterDetailView: View {
    let semesterAverage: Double?
    let semesterGPA: Double?
    let courses: [Course]
    let usePercentageGrades: Bool
    let themeManager: ThemeManager
    let activeSchedule: ScheduleCollection?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var animationOffset: CGFloat = 0
    @AppStorage("gradeDecimalPrecision") private var decimalPrecision: Int = 1

    /// Format grade with user-selected decimal precision
    private func formatGrade(_ value: Double) -> String {
        String(format: "%.\(decimalPrecision)f", value)
    }
    
    private var coursesWithGrades: [(course: Course, grade: Double, creditHours: Double)] {
        courses.compactMap { course in
            guard let grade = course.calculateCurrentGrade() else { return nil }
            return (course, grade, course.creditHours)
        }
    }
    
    private var totalCreditHours: Double {
        coursesWithGrades.reduce(0) { $0 + $1.creditHours }
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
                        semesterOverviewCard
                        
                        // Statistics cards
                        statisticsGrid
                        
                        // Course breakdown
                        if !coursesWithGrades.isEmpty {
                            courseBreakdownSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Semester Statistics")
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
    
    private var semesterOverviewCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Semester")
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
                    
                    if let activeSchedule = activeSchedule {
                        Text(activeSchedule.displayName)
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let average = semesterAverage {
                        Text(usePercentageGrades ? String(format: "%.1f%%", average) : (semesterGPA.map { String(format: "%.2f GPA", $0) } ?? String(format: "%.1f%%", average)))
                            .font(.forma(.largeTitle, weight: .bold))
                            .foregroundColor(gradeColor(for: average))
                    } else {
                        Text("No Data")
                            .font(.forma(.title, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(courses.count) course\(courses.count == 1 ? "" : "s")")
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
                    radius: 12, x: 0, y: 6
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
                value: String(format: "%.0f", totalCreditHours),
                icon: "graduationcap.fill",
                color: themeManager.currentTheme.primaryColor,
                themeManager: themeManager
            )
            
            StatisticCard(
                title: "Courses with Grades",
                value: "\(coursesWithGrades.count)",
                icon: "checkmark.circle.fill",
                color: themeManager.currentTheme.secondaryColor,
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
    
    private var courseBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Course Breakdown")
                .font(.forma(.title3, weight: .bold))
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 12) {
                ForEach(coursesWithGrades.sorted { $0.grade > $1.grade }, id: \.course.id) { item in
                    CourseGradeRow(
                        course: item.course,
                        grade: item.grade,
                        usePercentageGrades: usePercentageGrades,
                        themeManager: themeManager
                    )
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
struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.forma(.title2))
                .foregroundColor(color)
            
            Text(value)
                .font(.forma(.title2, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.forma(.caption, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
                .shadow(
                    color: color.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.2 : 0.1),
                    radius: 6, x: 0, y: 3
                )
        )
    }
}

struct CourseGradeRow: View {
    let course: Course
    let grade: Double
    let usePercentageGrades: Bool
    let themeManager: ThemeManager
    @AppStorage("gradeDecimalPrecision") private var decimalPrecision: Int = 1

    private func formatGrade(_ value: Double) -> String {
        String(format: "%.\(decimalPrecision)f", value)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Course color indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(course.color)
                .frame(width: 4, height: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if !course.courseCode.isEmpty {
                        Text(course.courseCode)
                            .font(.forma(.caption, weight: .medium))
                            .foregroundColor(course.color)
                    }
                    
                    Text("\(course.creditHours, specifier: "%.0f") credits")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(usePercentageGrades ? "\(formatGrade(grade))%" : course.letterGrade)
                    .font(.forma(.subheadline, weight: .bold))
                    .foregroundColor(gradeColor(for: grade))
                
                if !usePercentageGrades, let gpa = course.gpaPoints {
                    Text(String(format: "%.1f GPA", gpa))
                        .font(.forma(.caption2))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(course.color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(course.color.opacity(0.15), lineWidth: 1)
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
    PreviewWrapper()
}

private struct PreviewWrapper: View {
    var body: some View {
        let themeManager = ThemeManager()
        let sampleCourse = Course(
            scheduleId: UUID(),
            name: "Advanced iOS Development",
            assignments: [
                Assignment(courseId: UUID(), name: "Project 1", grade: "95", weight: "30"),
                Assignment(courseId: UUID(), name: "Midterm", grade: "88", weight: "40")
            ],
            courseCode: "CS 4820",
            section: "A"
        )
        
        SemesterDetailView(
            semesterAverage: 91.5,
            semesterGPA: 3.7,
            courses: [sampleCourse],
            usePercentageGrades: true,
            themeManager: themeManager,
            activeSchedule: nil
        )
        .environmentObject(themeManager)
    }
}