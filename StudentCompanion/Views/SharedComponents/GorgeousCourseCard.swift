import SwiftUI

struct GorgeousCourseCard: View {
    let course: Course
    let courseManager: UnifiedCourseManager
    let bulkSelectionManager: BulkCourseSelectionManager
    let themeManager: ThemeManager
    let usePercentageGrades: Bool
    let animationDelay: Double
    let onDelete: () -> Void
    
    @State private var isPressed = false
    @State private var animationOffset: CGFloat = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var showingEditSheet = false
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("gradeDecimalPrecision") private var decimalPrecision: Int = 1

    /// Format grade with user-selected decimal precision
    private func formatGrade(_ value: Double) -> String {
        String(format: "%.\(decimalPrecision)f", value)
    }
    
    // Access ScheduleManager through environment
    @EnvironmentObject private var scheduleManager: ScheduleManager
    
    private var isSelected: Bool {
        bulkSelectionManager.isSelected(course.id)
    }
    
    private var gradePercentage: Double {
        guard let grade = course.calculateCurrentGrade() else { return 0 }
        return max(0, min(100, grade))
    }
    
    private var progressRingColor: Color {
        switch gradePercentage {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        case 60..<70: return .red
        default: return .red
        }
    }
    
    var body: some View {
        if bulkSelectionManager.selectionContext == .courses {
            cardContent
                .contentShape(Rectangle())
                .onTapGesture {
                    bulkSelectionManager.toggleSelection(course.id)
                }
                .contextMenu {
                    contextMenuContent
                }
                .sheet(isPresented: $showingEditSheet) {
                    EnhancedAddCourseWithMeetingsView(existingCourse: course)
                        .environmentObject(themeManager)
                        .environmentObject(scheduleManager)
                        .environmentObject(courseManager)
                }
                .onAppear {
                    startAnimations()
                }
        } else {
            cardContent
                .contentShape(Rectangle())
                .contextMenu {
                    contextMenuContent
                }
                .sheet(isPresented: $showingEditSheet) {
                    EnhancedAddCourseWithMeetingsView(existingCourse: course)
                        .environmentObject(themeManager)
                        .environmentObject(scheduleManager)
                        .environmentObject(courseManager)
                }
                .onAppear {
                    startAnimations()
                }
        }
    }
    
    private var cardContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(
                            course.color.opacity(0.2),
                            lineWidth: 4
                        )
                        .frame(width: 60, height: 60)
                    
                    if course.calculateCurrentGrade() != nil {
                        Circle()
                            .trim(from: 0, to: gradePercentage / 100)
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
                            .animation(.spring(response: 1.0, dampingFraction: 0.85).delay(animationDelay), value: gradePercentage)
                    }
                    
                    Image(systemName: course.iconName)
                        .font(.forma(.title3, weight: .semibold))
                        .foregroundColor(course.color)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                }
                
                VStack(alignment: .leading, spacing: 6) {
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
                
                let isSelectionMode = bulkSelectionManager.selectionContext == .courses
                ZStack(alignment: .trailing) {
                    // Grade view
                    VStack(alignment: .trailing, spacing: 4) {
                        if let grade = course.calculateCurrentGrade() {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(usePercentageGrades ? "\(formatGrade(grade))%" : course.letterGrade)
                                    .font(.forma(.title2, weight: .bold))
                                    .foregroundColor(progressRingColor)
                                
                                if !usePercentageGrades, let gpa = course.gpaPoints {
                                    Text(String(format: "%.2f GPA", gpa))
                                        .font(.forma(.caption, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
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
                    .opacity(isSelectionMode ? 0 : 1)
                    .scaleEffect(isSelectionMode ? 0.98 : 1.0)
                    
                    // Selection indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.forma(.title2))
                        .foregroundColor(isSelected ? themeManager.currentTheme.primaryColor : .secondary.opacity(0.6))
                        .scaleEffect(isSelectionMode ? 1.0 : 0.95)
                        .opacity(isSelectionMode ? 1 : 0)
                }
                .frame(minWidth: 96, alignment: .trailing)
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isSelected)
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isSelectionMode)
            }
            .padding(20)
            
            if !bulkSelectionManager.isSelecting {
                HStack(spacing: 16) {
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
                // PERFORMANCE FIX: Removed expensive .regularMaterial
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground).opacity(0.95))

                // Simplified color accent
                RoundedRectangle(cornerRadius: 24)
                    .fill(course.color.opacity(colorScheme == .dark ? 0.1 : 0.05))

                // PERFORMANCE FIX: Removed shimmer effect with expensive dynamic gradients

                // Simplified border - single color instead of gradient
                RoundedRectangle(cornerRadius: 24)
                    .stroke(course.color.opacity(isSelected ? 0.5 : 0.2), lineWidth: isSelected ? 2 : 1)
            }
            .scaleEffect(isSelected ? 0.98 : (isPressed ? 0.99 : 1.0))
            // PERFORMANCE FIX: Single shadow, reduced radius from 12-26 to 6
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
                showingEditSheet = true
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
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(animationDelay)) {
            animationOffset = 0
        }
    }
}