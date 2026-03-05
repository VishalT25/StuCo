import SwiftUI

struct ScheduleImportSheet: View {
    let shareId: String

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var courseManager: UnifiedCourseManager
    @Environment(\.dismiss) var dismiss

    @State private var importedSchedule: ScheduleCollection?
    @State private var importedCourses: [Course] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var isImporting = false

    var body: some View {
        ZStack {
            // Glassmorphic background
            themeManager.currentTheme.darkModeBackgroundFill
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        loadingSection
                    } else if let error = error {
                        errorSection(error: error)
                    } else if let schedule = importedSchedule {
                        headerSection
                        schedulePreviewSection(schedule: schedule)
                        courseListSection
                        importButtonSection
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
        .task {
            await loadSharedSchedule()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.primaryColor,
                            themeManager.currentTheme.darkModeAccentHue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Import Schedule")
                .font(.title.bold())
                .foregroundColor(.primary)

            Text("Review the shared schedule before importing")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Schedule Preview Section

    private func schedulePreviewSection(schedule: ScheduleCollection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                Text("Schedule Details")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(schedule.name)
                        .font(.title3.bold())
                    Spacer()
                    Circle()
                        .fill(schedule.color)
                        .frame(width: 20, height: 20)
                }

                Text(schedule.semester)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                HStack {
                    Label("\(importedCourses.count) courses", systemImage: "book.fill")
                    Spacer()
                    Label("\(totalMeetings) meetings", systemImage: "clock.fill")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
        }
    }

    // MARK: - Course List Section

    private var courseListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "books.vertical.fill")
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                Text("Courses (\(importedCourses.count))")
                    .font(.headline)
            }

            VStack(spacing: 8) {
                ForEach(importedCourses) { course in
                    CoursePreviewCard(course: course)
                }
            }
        }
    }

    // MARK: - Import Button Section

    private var importButtonSection: some View {
        VStack(spacing: 16) {
            Button {
                Task {
                    await importSchedule()
                }
            } label: {
                HStack {
                    if isImporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Import Schedule")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.primaryColor,
                            themeManager.currentTheme.darkModeAccentHue
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isImporting)

            Text("This will add the schedule and courses to your library")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading shared schedule...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 60)
    }

    // MARK: - Error Section

    private func errorSection(error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Unable to Load Schedule")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await loadSharedSchedule()
                }
            } label: {
                Text("Try Again")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(themeManager.currentTheme.primaryColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private var totalMeetings: Int {
        importedCourses.reduce(0) { $0 + $1.meetings.count }
    }

    private func loadSharedSchedule() async {
        isLoading = true
        error = nil

        do {
            let result = try await ShareableScheduleBuilder.shared.importSharedSchedule(shareId: shareId)
            await MainActor.run {
                self.importedSchedule = result.0
                self.importedCourses = result.1
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }

    private func importSchedule() async {
        guard let schedule = importedSchedule else { return }

        isImporting = true

        do {
            // Add schedule to manager
            scheduleManager.addSchedule(schedule)

            // Add courses to manager
            for course in importedCourses {
                try await courseManager.createCourseWithMeetings(course, meetings: course.meetings)
            }

            await MainActor.run {
                isImporting = false
                dismiss()

                // Show success feedback
                NotificationCenter.default.post(
                    name: NSNotification.Name("ScheduleImported"),
                    object: nil,
                    userInfo: ["scheduleName": schedule.name]
                )
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isImporting = false
            }
        }
    }
}

// MARK: - Course Preview Card

struct CoursePreviewCard: View {
    let course: Course

    var body: some View {
        HStack(spacing: 12) {
            // Course icon/emoji
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(course.color.opacity(0.2))
                    .frame(width: 44, height: 44)

                if let emoji = course.emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.title3)
                } else {
                    Image(systemName: course.iconName)
                        .foregroundColor(course.color)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.subheadline.bold())

                if !course.courseCode.isEmpty {
                    Text(course.courseCode)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("\(course.meetings.count) meeting\(course.meetings.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }
}
