import SwiftUI

struct AIReviewStep: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    let scheduleName: String
    let academicYear: String
    let scheduleType: ScheduleType
    let semesterStartDate: Date
    let semesterEndDate: Date
    let linkedAcademicCalendar: AcademicCalendar?
    let aiImportData: AIImportData?
    
    private var groupedCourses: [(String, Color, Int)] {
        guard let importData = aiImportData else { return [] }
        var groups: [String: (Color, Int)] = [:]
        for item in importData.parsedItems {
            let name = baseCourseName(from: item.title)
            if groups[name] != nil {
                groups[name]!.1 += 1
            } else {
                groups[name] = (item.color, 1)
            }
        }
        return groups.map { (name, data) in
            (name, data.0, data.1)
        }.sorted { $0.0 < $1.0 }
    }
    
    private func baseCourseName(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: " - ") {
            return String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection
            scheduleDetailsSection
            aiImportSummarySection
            academicCalendarSection
            
            Spacer()
        }
        .frame(maxWidth: 360)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor.opacity(0.15),
                                themeManager.currentTheme.secondaryColor.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40, weight: .light))
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
            }
            
            VStack(spacing: 8) {
                Text("Ready to Create")
                    .font(.forma(.title, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Review your schedule details below, then create your schedule")
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
    }
    
    private var scheduleDetailsSection: some View {
        ReviewSection(title: "Schedule Details", icon: "textformat.abc") {
            ReviewInfoRow(icon: "textformat.abc", label: "Name", value: scheduleName)
            ReviewInfoRow(icon: scheduleType == .rotating ? "repeat" : "calendar", label: "Type", value: scheduleType == .rotating ? "Day 1 / Day 2" : "Weekly Schedule")
            ReviewInfoRow(icon: "calendar", label: "Semester", value: academicYear)
        }
        .environmentObject(themeManager)
    }
    
    private var aiImportSummarySection: some View {
        ReviewSection(title: "AI Import Summary", icon: "sparkles") {
            if let importData = aiImportData {
                ReviewInfoRow(
                    icon: "book.closed.fill",
                    label: "Courses Detected",
                    value: "\(groupedCourses.count) courses"
                )
                
                ReviewInfoRow(
                    icon: "calendar.badge.plus",
                    label: "Total Classes",
                    value: "\(importData.parsedItems.count) meetings"
                )
                
                ReviewInfoRow(
                    icon: "checkmark.seal.fill",
                    label: "AI Confidence",
                    value: String(format: "%.0f%%", importData.confidence * 100)
                )
                
                if !groupedCourses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Courses")
                            .font(.forma(.caption, weight: .semibold))
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 150), spacing: 6)], spacing: 6) {
                            ForEach(Array(groupedCourses.enumerated()), id: \.offset) { index, course in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(course.1)
                                        .frame(width: 6, height: 6)

                                    Text(course.0)
                                        .font(.forma(.caption2, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray6).opacity(0.5))
                                )
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .environmentObject(themeManager)
    }
    
    private var academicCalendarSection: some View {
        ReviewSection(title: "Academic Calendar", icon: "calendar.badge.plus") {
            if let calendar = linkedAcademicCalendar {
                ReviewInfoRow(icon: "calendar", label: "Calendar", value: calendar.name)
                ReviewInfoRow(icon: "graduationcap", label: "Academic Year", value: calendar.academicYear)
                ReviewInfoRow(icon: "minus.circle", label: "Breaks", value: "\(calendar.breaks.count) configured")
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.forma(.body, weight: .medium))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No calendar linked")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("You can add one later in settings")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("Optional")
                        .font(.forma(.caption, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
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
            }
        }
        .environmentObject(themeManager)
    }
}

// MARK: - Supporting Views
struct ReviewSection<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: icon)
                        .font(.forma(.caption, weight: .bold))
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
                }
                
                Text(title)
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 10) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor.opacity(0.25),
                                        themeManager.currentTheme.secondaryColor.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
}

struct ReviewInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .center)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.forma(.caption, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6).opacity(0.4))
        )
    }
}