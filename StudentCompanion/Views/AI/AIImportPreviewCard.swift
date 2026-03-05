import SwiftUI

// MARK: - AI Import Preview Card
struct AIImportPreviewCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let importData: AIImportData
    let onReviewTap: () -> Void

    private var groupedCourses: [(String, Color, Int)] {
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

    private var issuesCount: Int {
        importData.missingFields.count
    }

    private func baseCourseName(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: " - ") {
            return String(trimmed[..<range.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    var body: some View {
        Button(action: onReviewTap) {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                statsSection
                coursesSection
                reviewButton
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor.opacity(0.3),
                                        themeManager.currentTheme.secondaryColor.opacity(0.2),
                                        themeManager.currentTheme.primaryColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(
                color: themeManager.currentTheme.primaryColor.opacity(0.2),
                radius: 20, x: 0, y: 10
            )
        }
        .buttonStyle(PreviewCardButtonStyle())
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
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
                    .frame(width: 36, height: 36)

                Image(systemName: "sparkles")
                    .font(.forma(.body, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("AI Import Complete")
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(.primary)

                Text("Tap to review and customize")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.7))
        }
    }

    private var statsSection: some View {
        HStack(spacing: 16) {
            StatPill(
                icon: "book.closed.fill",
                value: "\(groupedCourses.count)",
                label: "Courses",
                color: .indigo
            )

            StatPill(
                icon: "calendar.badge.plus",
                value: "\(importData.parsedItems.count)",
                label: "Classes",
                color: .teal
            )

            if issuesCount > 0 {
                StatPill(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(issuesCount)",
                    label: "Issues",
                    color: .red
                )
            }
        }
    }

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected Courses")
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(.primary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(Array(groupedCourses.prefix(6).enumerated()), id: \.offset) { index, course in
                    CourseChip(
                        name: course.0,
                        color: course.1,
                        count: course.2
                    )
                }

                if groupedCourses.count > 6 {
                    MoreCoursesChip(count: groupedCourses.count - 6)
                        .environmentObject(themeManager)
                }
            }
        }
    }

    private var reviewButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.rays")
                .font(.forma(.subheadline, weight: .semibold))

            Text("Review & Customize")
                .font(.forma(.subheadline, weight: .semibold))

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.forma(.caption, weight: .bold))
                .opacity(0.7)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor,
                    themeManager.currentTheme.secondaryColor
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .shadow(
            color: themeManager.currentTheme.primaryColor.opacity(0.4),
            radius: 8, x: 0, y: 4
        )
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(color)

                Text(value)
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(.primary)
            }

            Text(label)
                .font(.forma(.caption2, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct CourseChip: View {
    let name: String
    let color: Color
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.forma(.caption, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text("\(count) meeting\(count == 1 ? "" : "s")")
                    .font(.forma(.caption2))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct MoreCoursesChip: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.forma(.caption2, weight: .bold))
                .foregroundColor(themeManager.currentTheme.primaryColor)

            Text("\(count) more")
                .font(.forma(.caption, weight: .semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct PreviewCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
