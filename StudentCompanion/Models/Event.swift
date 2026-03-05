import Foundation
import SwiftUI

struct Event: Identifiable, Codable, Hashable {
    var id = UUID()
    var courseId: UUID?
    var title: String
    var description: String?
    var date: Date
    var isCompleted: Bool = false
    var notes: String?
    var eventType: EventType = .generic
    var reminderTime: ReminderTime = .none
    var categoryId: UUID?
    var appleCalendarIdentifier: String?
    var googleCalendarIdentifier: String?
    var externalIdentifier: String?
    var sourceName: String?
    var syncToAppleCalendar: Bool = false
    var syncToGoogleCalendar: Bool = false

    enum EventType: String, Codable, CaseIterable {
        case generic = "Generic"
        case assignment = "Assignment"
        case exam = "Exam"
        case project = "Project"
        case presentation = "Presentation"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Event, rhs: Event) -> Bool {
        lhs.id == rhs.id
    }
    
    init(title: String, date: Date, courseId: UUID? = nil, categoryId: UUID? = nil, reminderTime: ReminderTime = .none, isCompleted: Bool = false, externalIdentifier: String? = nil, sourceName: String? = nil, syncToAppleCalendar: Bool = false, syncToGoogleCalendar: Bool = false) {
        self.title = title
        self.date = date
        self.courseId = courseId
        self.categoryId = categoryId
        self.reminderTime = reminderTime
        self.isCompleted = isCompleted
        self.externalIdentifier = externalIdentifier
        self.sourceName = sourceName
        self.syncToAppleCalendar = syncToAppleCalendar
        self.syncToGoogleCalendar = syncToGoogleCalendar
    }
}

// Extension to get category from categories array
extension Event {
    func category(from categories: [Category]) -> Category {
        return categories.first { $0.id == categoryId } ?? Category(name: "Unknown", color: .gray)
    }
    
    // NEW: Get course from courses array
    func course(from courses: [Course]) -> Course? {
        guard let courseId = courseId else { return nil }
        return courses.first { $0.id == courseId }
    }
}