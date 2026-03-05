import Foundation
import SwiftUI

struct AppTask: Identifiable {
    var id = UUID()
    var title: String
    var dueDate: Date
    var priority: Priority
    var isCompleted: Bool = false
    var notes: String?
    var course: Course?
}

enum Priority: Int, CaseIterable {
    case none = 0, low, medium, high
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .gray
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}

struct Grade {
    var assignment: String
    var score: Double
    var total: Double
    var weight: Double
}

struct Note: Identifiable {
    var id = UUID()
    var title: String
    var content: String
    var timestamp: Date
    var relatedCourse: Course?
}

struct StudySession {
    var startTime: Date
    var endTime: Date
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    var goals: [String]
    var summary: String?
}

struct Exam: Identifiable {
    var id = UUID()
    var course: Course
    var date: Date
    var location: String?
    var topics: [String]
}

struct Announcement {
    var title: String
    var content: String
    var date: Date
    var source: String // e.g., "D2L", "Email"
}