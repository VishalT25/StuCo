import SwiftUI

@MainActor
class GPAViewModel: ObservableObject {
    @Published var cachedCourses: [Course] = []
    @Published var cachedSemesterAverage: Double? = nil
    @Published var cachedSemesterGPA: Double? = nil
    private(set) var lastCacheUpdate: Date = .distantPast

    /// PERFORMANCE FIX: Compute analytics once and cache them
    func refreshCachedAnalytics(courseManager: UnifiedCourseManager, scheduleManager: ScheduleManager) {
        guard let activeSchedule = scheduleManager.activeSchedule else {
            cachedCourses = []
            cachedSemesterAverage = nil
            cachedSemesterGPA = nil
            return
        }

        let coursesInSchedule = courseManager.courses.filter { $0.scheduleId == activeSchedule.id }

        // Pre-compute grades once per course to avoid multiple calculateCurrentGrade() calls
        let coursesWithCachedGrades = coursesInSchedule.map { course -> (course: Course, grade: Double?) in
            (course: course, grade: course.calculateCurrentGrade())
        }

        // Separate and sort
        let withGrades = coursesWithCachedGrades.filter { $0.grade != nil }
            .sorted { ($0.grade ?? 0) > ($1.grade ?? 0) }
            .map { $0.course }

        let withoutGrades = coursesWithCachedGrades.filter { $0.grade == nil }
            .sorted { $0.course.name.localizedCaseInsensitiveCompare($1.course.name) == .orderedAscending }
            .map { $0.course }

        cachedCourses = withGrades + withoutGrades

        // Compute semester average
        let gradesForAverage = coursesWithCachedGrades.compactMap { item -> (grade: Double, creditHours: Double)? in
            guard let grade = item.grade else { return nil }
            return (grade: grade, creditHours: item.course.creditHours)
        }

        if !gradesForAverage.isEmpty {
            let totalWeighted = gradesForAverage.reduce(0) { $0 + ($1.grade * $1.creditHours) }
            let totalCredits = gradesForAverage.reduce(0) { $0 + $1.creditHours }
            cachedSemesterAverage = totalCredits > 0 ? totalWeighted / totalCredits : nil
        } else {
            cachedSemesterAverage = nil
        }

        // Compute semester GPA
        let gpaData = cachedCourses.compactMap { course -> (gpaPoints: Double, creditHours: Double)? in
            guard let gpaPoints = course.gpaPoints else { return nil }
            return (gpaPoints: gpaPoints, creditHours: course.creditHours)
        }

        if !gpaData.isEmpty {
            let totalQuality = gpaData.reduce(0) { $0 + ($1.gpaPoints * $1.creditHours) }
            let totalCredits = gpaData.reduce(0) { $0 + $1.creditHours }
            cachedSemesterGPA = totalCredits > 0 ? totalQuality / totalCredits : nil
        } else {
            cachedSemesterGPA = nil
        }

        lastCacheUpdate = Date()
    }

    func yearAverage(courseManager: UnifiedCourseManager, selectedScheduleIDs: Set<UUID>) -> Double? {
        let selectedCourses = courseManager.courses.filter { selectedScheduleIDs.contains($0.scheduleId) }
        let allCoursesWithGrades = selectedCourses.compactMap { course -> (grade: Double, creditHours: Double)? in
            guard let grade = course.calculateCurrentGrade() else { return nil }
            return (grade: grade, creditHours: course.creditHours)
        }

        guard !allCoursesWithGrades.isEmpty else { return nil }

        let totalWeightedGrade = allCoursesWithGrades.reduce(0) { $0 + ($1.grade * $1.creditHours) }
        let totalCredits = allCoursesWithGrades.reduce(0) { $0 + $1.creditHours }

        return totalCredits > 0 ? totalWeightedGrade / totalCredits : nil
    }

    func refreshData(courseManager: UnifiedCourseManager) async {
        courseManager.loadCourses()
        await courseManager.refreshCourseData()
    }

    func loadYearSelection(from storage: String, scheduleManager: ScheduleManager) -> Set<UUID> {
        let availableIDs = Set(scheduleManager.scheduleCollections.map { $0.id })
        if storage.isEmpty {
            return availableIDs
        }
        let stored = storage
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
        let parsed = Set(stored).intersection(availableIDs)
        return parsed.isEmpty ? availableIDs : parsed
    }

    func syncSelectionWithAvailableSchedules(_ ids: Set<UUID>, scheduleManager: ScheduleManager) -> Set<UUID> {
        let availableIDs = Set(scheduleManager.scheduleCollections.map { $0.id })
        let updated = ids.intersection(availableIDs)
        return updated.isEmpty ? availableIDs : updated
    }
}
