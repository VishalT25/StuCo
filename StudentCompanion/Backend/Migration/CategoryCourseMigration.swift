import Foundation

@MainActor
class CategoryCourseMigration {
    private let courseManager: UnifiedCourseManager
    private let eventManager: EventManager

    init(courseManager: UnifiedCourseManager, eventManager: EventManager) {
        self.courseManager = courseManager
        self.eventManager = eventManager
    }

    func executeMigration() async {
        print("CategoryCourseMigration: Starting migration...")

        let categories = eventManager.categories
        let courses = courseManager.courses
        var linkedCount = 0

        for category in categories where category.courseId == nil {
            if let matchedCourse = findMatchingCourse(for: category, in: courses) {
                var updatedCategory = category
                updatedCategory.courseId = matchedCourse.id
                updatedCategory.scheduleId = matchedCourse.scheduleId
                updatedCategory.color = matchedCourse.color

                eventManager.updateCategory(updatedCategory)
                linkedCount += 1
                print("CategoryCourseMigration: Linked '\(category.name)' to '\(matchedCourse.name)'")
            }
        }

        print("CategoryCourseMigration: Linked \(linkedCount) categories")
    }

    private func findMatchingCourse(for category: Category, in courses: [Course]) -> Course? {
        // Exact match on course code
        if let match = courses.first(where: {
            !$0.courseCode.isEmpty && $0.courseCode.lowercased() == category.name.lowercased()
        }) {
            return match
        }

        // Exact match on course name
        if let match = courses.first(where: {
            $0.name.lowercased() == category.name.lowercased()
        }) {
            return match
        }

        // Fuzzy match
        if let match = courses.first(where: { course in
            let categoryLower = category.name.lowercased()
            let codeLower = course.courseCode.lowercased()
            let nameLower = course.name.lowercased()

            return (!codeLower.isEmpty && (categoryLower.contains(codeLower) || codeLower.contains(categoryLower))) ||
                   (categoryLower.contains(nameLower) || nameLower.contains(categoryLower))
        }) {
            return match
        }

        return nil
    }
}
