import Foundation
import SwiftUI

// MARK: - Meeting Type Enumeration
enum MeetingType: String, CaseIterable, Codable {
    case lecture = "lecture"
    case lab = "lab"
    case tutorial = "tutorial"
    case seminar = "seminar"
    case workshop = "workshop"
    case practicum = "practicum"
    case recitation = "recitation"
    case studio = "studio"
    case fieldwork = "fieldwork"
    case clinic = "clinic"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .lecture: return "Lecture"
        case .lab: return "Lab"
        case .tutorial: return "Tutorial"
        case .seminar: return "Seminar"
        case .workshop: return "Workshop"
        case .practicum: return "Practicum"
        case .recitation: return "Recitation"
        case .studio: return "Studio"
        case .fieldwork: return "Fieldwork"
        case .clinic: return "Clinic"
        case .other: return "Other"
        }
    }
    
    var iconName: String {
        switch self {
        case .lecture: return "person.3.sequence.fill"
        case .lab: return "flask.fill"
        case .tutorial: return "person.2.fill"
        case .seminar: return "bubble.left.and.bubble.right.fill"
        case .workshop: return "hammer.fill"
        case .practicum: return "stethoscope"
        case .recitation: return "book.pages.fill"
        case .studio: return "paintbrush.fill"
        case .fieldwork: return "location.fill"
        case .clinic: return "cross.case.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .lecture: return .blue
        case .lab: return .green
        case .tutorial: return .orange
        case .seminar: return .purple
        case .workshop: return .brown
        case .practicum: return .pink
        case .recitation: return .indigo
        case .studio: return .red
        case .fieldwork: return .mint
        case .clinic: return .teal
        case .other: return .gray
        }
    }
}

// MARK: - Enhanced Course Meeting Model
struct CourseMeeting: Identifiable, Codable, Hashable, Equatable {
    var id = UUID()
    var userId: UUID?
    var courseId: UUID
    var scheduleId: UUID?
    
    // Meeting metadata
    var meetingType: MeetingType = .lecture
    var meetingLabel: String? // Optional custom label like "CS 101 - Section A Lab"
    
    // Rotation properties
    var isRotating: Bool = false
    var rotationLabel: String? // e.g., "Day 1", "Day 2", "Week A"
    var rotationPattern: [String: Any]? // JSON pattern for complex rotations
    var rotationIndex: Int? // 1-based index (1, 2, 3, etc.)
    
    // Schedule details
    var startTime: Date
    var endTime: Date
    var daysOfWeek: [Int] = [] // Days this meeting occurs on (1=Sunday, 7=Saturday)
    var location: String
    var instructor: String
    
    // Settings
    var reminderTime: ReminderTime
    var isLiveActivityEnabled: Bool

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        courseId: UUID,
        scheduleId: UUID? = nil,
        meetingType: MeetingType = .lecture,
        meetingLabel: String? = nil,
        isRotating: Bool = false,
        rotationLabel: String? = nil,
        rotationPattern: [String: Any]? = nil,
        rotationIndex: Int? = nil,
        startTime: Date,
        endTime: Date,
        daysOfWeek: [Int] = [],
        location: String = "",
        instructor: String = "",
        reminderTime: ReminderTime = .none,
        isLiveActivityEnabled: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.courseId = courseId
        self.scheduleId = scheduleId
        self.meetingType = meetingType
        self.meetingLabel = meetingLabel
        self.isRotating = isRotating
        self.rotationLabel = rotationLabel
        self.rotationPattern = rotationPattern
        self.rotationIndex = rotationIndex
        self.startTime = startTime
        self.endTime = endTime
        self.daysOfWeek = daysOfWeek
        self.location = location
        self.instructor = instructor
        self.reminderTime = reminderTime
        self.isLiveActivityEnabled = isLiveActivityEnabled
    }
    
    // MARK: - Convenience Properties
    
    var displayName: String {
        if let customLabel = meetingLabel, !customLabel.isEmpty {
            return customLabel
        }
        
        if let rotationLabel = rotationLabel {
            return "\(meetingType.displayName) (\(rotationLabel))"
        }
        
        return meetingType.displayName
    }
    
    var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    var duration: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: startTime, to: endTime)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    var daysString: String {
        if daysOfWeek.isEmpty && !isRotating {
            return "No specific days"
        } else if isRotating {
            return rotationLabel ?? "Rotating schedule"
        }
        
        let dayNames = daysOfWeek.compactMap { dayNumber in
            DayOfWeek(rawValue: dayNumber)?.short
        }
        return dayNames.joined(separator: ", ")
    }
    
    // MARK: - Schedule Integration
    
    func toScheduleItem(using course: Course) -> ScheduleItem {
        ScheduleItem(
            id: id,
            title: "\(course.name) - \(displayName)",
            startTime: startTime,
            endTime: endTime,
            daysOfWeek: daysOfWeek.compactMap { DayOfWeek(rawValue: $0) },
            location: location.isEmpty ? course.location : location,
            instructor: instructor.isEmpty ? course.instructor : instructor,
            color: course.color,
            isLiveActivityEnabled: isLiveActivityEnabled,
            reminderTime: reminderTime
        )
    }
    
    func shouldAppear(on date: Date, in schedule: ScheduleCollection, calendar: AcademicCalendar?) -> Bool {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        
        // Skip weekends unless explicitly scheduled
        if weekday == 1 || weekday == 7 {
            return daysOfWeek.contains(weekday)
        }
        
        // Check semester bounds
        if let start = schedule.semesterStartDate, let end = schedule.semesterEndDate {
            let day = cal.startOfDay(for: date)
            let s = cal.startOfDay(for: start)
            let e = cal.startOfDay(for: end)
            if day < s || day > e {
                return false
            }
        }
        
        // Check academic calendar
        if let academicCalendar = calendar {
            if !academicCalendar.isDateWithinSemester(date) { return false }
            if academicCalendar.isBreakDay(date) { return false }
        }
        
        // Check rotation or regular schedule
        if isRotating {
            return checkRotationPattern(for: date, in: schedule)
        } else {
            // For regular meetings, ONLY appear if this weekday is explicitly included
            // Don't default to all weekdays if daysOfWeek is empty
            return daysOfWeek.contains(weekday)
        }
    }
    
    private func checkRotationPattern(for date: Date, in schedule: ScheduleCollection) -> Bool {
        guard let rotationIndex = rotationIndex else { return false }
        
        let calendar = Calendar.current
        
        if schedule.scheduleType == .rotating {
            let day = calendar.component(.day, from: date)
            // Basic 2-day rotation: odd days = Day 1, even days = Day 2
            return (day % 2 == 1 && rotationIndex == 1) || (day % 2 == 0 && rotationIndex == 2)
        }
        
        // For non-rotating schedules with rotation meetings, 
        // still require explicit days to be set
        let weekday = calendar.component(.weekday, from: date)
        return daysOfWeek.contains(weekday)
    }

    // MARK: - Validation
    
    var isValid: Bool {
        guard startTime < endTime else { return false }
        guard !isRotating || rotationIndex != nil else { return false }
        guard isRotating || !daysOfWeek.isEmpty else { return false }
        return true
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if startTime >= endTime {
            errors.append("End time must be after start time")
        }
        
        if isRotating && rotationIndex == nil {
            errors.append("Rotation meetings must have a rotation index")
        }
        
        if !isRotating && daysOfWeek.isEmpty {
            errors.append("Regular meetings must specify days of the week")
        }
        
        return errors
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, userId, courseId, scheduleId
        case meetingType, meetingLabel
        case isRotating, rotationLabel, rotationPattern, rotationIndex
        case startTime, endTime, daysOfWeek, location, instructor
        case reminderTime, isLiveActivityEnabled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        courseId = try container.decode(UUID.self, forKey: .courseId)
        scheduleId = try container.decodeIfPresent(UUID.self, forKey: .scheduleId)
        
        meetingType = try container.decodeIfPresent(MeetingType.self, forKey: .meetingType) ?? .lecture
        meetingLabel = try container.decodeIfPresent(String.self, forKey: .meetingLabel)
        
        isRotating = try container.decodeIfPresent(Bool.self, forKey: .isRotating) ?? false
        rotationLabel = try container.decodeIfPresent(String.self, forKey: .rotationLabel)
        rotationIndex = try container.decodeIfPresent(Int.self, forKey: .rotationIndex)
        
        // Handle rotation pattern - decode from JSON if present
        if let patternData = try container.decodeIfPresent(Data.self, forKey: .rotationPattern) {
            rotationPattern = try JSONSerialization.jsonObject(with: patternData) as? [String: Any]
        } else {
            rotationPattern = nil
        }
        
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        daysOfWeek = try container.decodeIfPresent([Int].self, forKey: .daysOfWeek) ?? []
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        instructor = try container.decodeIfPresent(String.self, forKey: .instructor) ?? ""
        
        reminderTime = try container.decodeIfPresent(ReminderTime.self, forKey: .reminderTime) ?? .none
        isLiveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .isLiveActivityEnabled) ?? true
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(courseId, forKey: .courseId)
        try container.encodeIfPresent(scheduleId, forKey: .scheduleId)
        
        try container.encode(meetingType, forKey: .meetingType)
        try container.encodeIfPresent(meetingLabel, forKey: .meetingLabel)
        
        try container.encode(isRotating, forKey: .isRotating)
        try container.encodeIfPresent(rotationLabel, forKey: .rotationLabel)
        try container.encodeIfPresent(rotationIndex, forKey: .rotationIndex)
        
        // Encode rotation pattern as JSON data
        if let pattern = rotationPattern {
            let patternData = try JSONSerialization.data(withJSONObject: pattern)
            try container.encode(patternData, forKey: .rotationPattern)
        }
        
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(daysOfWeek, forKey: .daysOfWeek)
        try container.encode(location, forKey: .location)
        try container.encode(instructor, forKey: .instructor)
        
        try container.encode(reminderTime, forKey: .reminderTime)
        try container.encode(isLiveActivityEnabled, forKey: .isLiveActivityEnabled)
    }
    
    // MARK: - Equatable
    static func == (lhs: CourseMeeting, rhs: CourseMeeting) -> Bool {
        return lhs.id == rhs.id &&
               lhs.courseId == rhs.courseId &&
               lhs.meetingType == rhs.meetingType &&
               lhs.rotationIndex == rhs.rotationIndex &&
               lhs.rotationLabel == rhs.rotationLabel &&
               lhs.startTime == rhs.startTime &&
               lhs.endTime == rhs.endTime &&
               lhs.daysOfWeek == rhs.daysOfWeek
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(courseId)
        hasher.combine(meetingType)
        hasher.combine(rotationIndex)
        hasher.combine(rotationLabel)
    }
    
    // MARK: - Debug Description
    var debugDescription: String {
        let typeStr = meetingType.displayName
        let rotationStr = rotationLabel ?? "nil"
        let timeStr = "\(startTime.formatted(date: .omitted, time: .shortened))-\(endTime.formatted(date: .omitted, time: .shortened))"
        let daysStr = daysOfWeek.isEmpty ? "no-days" : daysOfWeek.map(String.init).joined(separator: ",")
        
        return "CourseMeeting(id: \(id.uuidString.prefix(8)), type: \(typeStr), rotation: '\(rotationStr)', time: \(timeStr), days: [\(daysStr)])"
    }
}

// MARK: - Helper Extensions
extension Array where Element == CourseMeeting {
    var debugDescription: String {
        return "[\n" + self.map { "  \($0.debugDescription)" }.joined(separator: ",\n") + "\n]"
    }
    
    // Get meetings by type
    func meetings(ofType type: MeetingType) -> [CourseMeeting] {
        return self.filter { $0.meetingType == type }
    }
    
    // Get rotation meetings
    var rotationMeetings: [CourseMeeting] {
        return self.filter { $0.isRotating }.sorted { ($0.rotationIndex ?? 0) < ($1.rotationIndex ?? 0) }
    }
    
    // Get regular meetings
    var regularMeetings: [CourseMeeting] {
        return self.filter { !$0.isRotating }
    }
    
    // Total weekly hours
//    var totalWeeklyHours: Double {
//        return self.reduce(0) { total, meeting in
//            let duration = meeting.endTime.timeIntervalSince(meeting.startTime) / 3600.0
//            return total + duration
//        }
//    }
    
    // Meeting types summary
    var typeSummary: String {
        let grouped = Dictionary(grouping: self, by: { $0.meetingType })
        let summaries = grouped.map { type, meetings in
            "\(meetings.count) \(type.displayName.lowercased())\(meetings.count > 1 ? "s" : "")"
        }
        return summaries.joined(separator: ", ")
    }
}
