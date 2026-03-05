import Foundation
import SwiftUI

struct AIImportData {
    var parsedItems: [ScheduleItem]
    var originalInput: String
    var importType: AIImportType
    var confidence: Double
    var missingFields: [String]
    var rotationLabelsByItemID: [UUID: [String]] = [:]
    var rotationAssignmentByItemID: [UUID: Int] = [:]
}

enum AIImportType {
    case text
    case image
    case pdf
}

// MARK: - AI Academic Calendar Import Models

struct AIAcademicCalendarImportData: Equatable {
    var calendarName: String
    var academicYear: String
    var startDate: Date
    var endDate: Date
    var breaks: [AcademicBreak]
    var originalInput: String
    var importType: AIImportType
    var confidence: Double
    var missingFields: [String]
    
    static func == (lhs: AIAcademicCalendarImportData, rhs: AIAcademicCalendarImportData) -> Bool {
        return lhs.calendarName == rhs.calendarName &&
               lhs.academicYear == rhs.academicYear &&
               lhs.startDate == rhs.startDate &&
               lhs.endDate == rhs.endDate &&
               lhs.breaks == rhs.breaks &&
               lhs.originalInput == rhs.originalInput &&
               lhs.importType == rhs.importType &&
               lhs.confidence == rhs.confidence &&
               lhs.missingFields == rhs.missingFields
    }
}

enum AIImportMethod: String, CaseIterable, Codable {
    case text
    case image
    case pdf
    
    var title: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .pdf: return "PDF"
        }
    }
    
    var subtitle: String {
        switch self {
        case .text: return "Paste text"
        case .image: return "Upload image"
        case .pdf: return "Upload PDF"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        }
    }
}

// MARK: - Syllabus Import Models

struct SyllabusImportData {
    var parsedAssignments: [AIAssignmentItem]
    var originalInput: String
    var importType: AIImportMethod
    var confidence: Double
    var missingFields: [String]
    var courseMetadata: SyllabusCourseMetadata?
    var storedPDFURL: String?
}

struct AIAssignmentItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var dueDate: Date?
    var weight: Double?
    var category: AssignmentCategory
    var notes: String

    enum CodingKeys: String, CodingKey {
        case id, name, dueDate, weight, category, notes
    }

    // Custom decoder to handle ISO8601 date strings from edge function
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode simple fields
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.weight = try? container.decode(Double.self, forKey: .weight)
        self.category = (try? container.decode(AssignmentCategory.self, forKey: .category)) ?? .other
        self.notes = (try? container.decode(String.self, forKey: .notes)) ?? ""

        // Decode ISO8601 date string
        if let dateString = try? container.decode(String.self, forKey: .dueDate) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = formatter.date(from: dateString) {
                self.dueDate = date
                print("📄 AIAssignmentItem: Successfully decoded date: \(dateString) -> \(date)")
            } else {
                // Try without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    self.dueDate = date
                    print("📄 AIAssignmentItem: Successfully decoded date (no fractional seconds): \(dateString) -> \(date)")
                } else {
                    print("📄 AIAssignmentItem: Failed to decode date string: \(dateString)")
                    self.dueDate = nil
                }
            }
        } else {
            self.dueDate = nil
        }
    }

    // Custom encoder for completeness
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encode(category, forKey: .category)
        try container.encode(notes, forKey: .notes)

        if let dueDate = dueDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let dateString = formatter.string(from: dueDate)
            try container.encode(dateString, forKey: .dueDate)
        }
    }
}

enum AssignmentCategory: String, Codable, CaseIterable {
    case homework
    case quiz
    case exam
    case project
    case participation
    case lab
    case other

    var displayName: String {
        switch self {
        case .homework: return "Homework"
        case .quiz: return "Quiz"
        case .exam: return "Exam"
        case .project: return "Project"
        case .participation: return "Participation"
        case .lab: return "Lab"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .homework: return "doc.text.fill"
        case .quiz: return "questionmark.circle.fill"
        case .exam: return "book.fill"
        case .project: return "folder.fill"
        case .participation: return "hand.raised.fill"
        case .lab: return "flask.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .homework: return "#4A90E2"
        case .quiz: return "#F39C12"
        case .exam: return "#E74C3C"
        case .project: return "#9B59B6"
        case .participation: return "#2ECC71"
        case .lab: return "#1ABC9C"
        case .other: return "#95A5A6"
        }
    }
}

struct SyllabusCourseMetadata: Codable {
    var courseName: String?
    var courseCode: String?
    var instructor: String?
    var semester: String?
    var totalWeight: Double?
}