import SwiftUI
import Foundation

// MARK: - Schedule Collection Model (Simplified)
struct ScheduleCollection: Identifiable, Codable {
    var id = UUID()
    var name: String
    var semester: String // e.g., "Fall 2025", "Spring 2024"
    var isActive: Bool = false
    var isArchived: Bool = false // NEW: For archived schedules
    var color: Color = .blue
    var scheduleItems: [ScheduleItem] = []
    var createdDate: Date = Date()
    var lastModified: Date = Date()
    var semesterStartDate: Date?
    var semesterEndDate: Date?

    // Enhanced properties for new schedule system (traditional only)
    var scheduleType: ScheduleType = .traditional
    var academicCalendarID: UUID? // NEW: Reference to academic calendar by ID
    var enhancedScheduleItems: [EnhancedScheduleItem] = []

    // DEPRECATED: Keep for backward compatibility, will be migrated
    var academicCalendar: AcademicCalendar?

    enum CodingKeys: String, CodingKey {
        case id, name, semester, isActive, isArchived, color, scheduleItems, createdDate, lastModified
        case scheduleType, academicCalendar, academicCalendarID, enhancedScheduleItems
        case semesterStartDate, semesterEndDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(semester, forKey: .semester)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encode(UIColor(color).cgColor.components ?? [0,0,0,1], forKey: .color)
        try container.encode(scheduleItems, forKey: .scheduleItems)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(scheduleType, forKey: .scheduleType)
        try container.encodeIfPresent(academicCalendar, forKey: .academicCalendar)
        try container.encodeIfPresent(academicCalendarID, forKey: .academicCalendarID)
        try container.encode(enhancedScheduleItems, forKey: .enhancedScheduleItems)
        try container.encodeIfPresent(semesterStartDate, forKey: .semesterStartDate)
        try container.encodeIfPresent(semesterEndDate, forKey: .semesterEndDate)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        semester = try container.decode(String.self, forKey: .semester)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        let components = try container.decode([CGFloat].self, forKey: .color)
        if components.count == 4 {
            color = Color(UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3]))
        } else {
            color = Color.blue
        }
        scheduleItems = try container.decode([ScheduleItem].self, forKey: .scheduleItems)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        lastModified = try container.decode(Date.self, forKey: .lastModified)

        // Enhanced properties with defaults for backward compatibility
        scheduleType = try container.decodeIfPresent(ScheduleType.self, forKey: .scheduleType) ?? .traditional
        academicCalendar = try container.decodeIfPresent(AcademicCalendar.self, forKey: .academicCalendar)
        academicCalendarID = try container.decodeIfPresent(UUID.self, forKey: .academicCalendarID)
        enhancedScheduleItems = try container.decodeIfPresent([EnhancedScheduleItem].self, forKey: .enhancedScheduleItems) ?? []
        semesterStartDate = try container.decodeIfPresent(Date.self, forKey: .semesterStartDate)
        semesterEndDate = try container.decodeIfPresent(Date.self, forKey: .semesterEndDate)
    }

    init(name: String, semester: String, color: Color = .blue, scheduleType: ScheduleType = .traditional) {
        self.id = UUID()
        self.name = name
        self.semester = semester
        self.color = color
        self.scheduleType = scheduleType
        self.scheduleItems = []
        self.enhancedScheduleItems = []
        self.createdDate = Date()
        self.lastModified = Date()
        self.semesterStartDate = nil
        self.semesterEndDate = nil
    }

    var displayName: String {
        if name.isEmpty {
            return semester
        }
        return "\(name) - \(semester)"
    }

    var totalClasses: Int {
        return scheduleItems.count + enhancedScheduleItems.count
    }

    var weeklyHours: Double {
        // If an item has no daysOfWeek, count it as occurring once to avoid zeroing out.
        let fromLegacy = scheduleItems.reduce(0) { acc, item in
            let duration = item.endTime.timeIntervalSince(item.startTime) / 3600.0
            let daysCount = max(1, item.daysOfWeek.count)
            return acc + (duration * Double(daysCount))
        }
        let fromEnhanced = enhancedScheduleItems.reduce(0) { acc, item in
            let duration = item.endTime.timeIntervalSince(item.startTime) / 3600.0
            let daysCount = max(1, item.daysOfWeek.count)
            return acc + (duration * Double(daysCount))
        }
        return fromLegacy + fromEnhanced
    }

    func getScheduleItems(for date: Date, usingCalendar calendar: AcademicCalendar? = nil) -> [ScheduleItem] {
        let dateCalendar = Calendar.current
        let dayStart = dateCalendar.startOfDay(for: date)

        // 1) Skip weekends outright
        let weekday = dateCalendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 {
            return []
        }

        // 2) Enforce schedule's own start/end bounds, if set
        if let start = semesterStartDate, let end = semesterEndDate {
            let startOfStart = dateCalendar.startOfDay(for: start)
            // Compare using end of day for inclusive range
            let endOfEnd = dateCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
            if dayStart < startOfStart || dayStart > endOfEnd {
                return []
            }
        }

        // 3) Respect academic calendar bounds and breaks (legacy or provided)
        var effectiveCalendar: AcademicCalendar?
        if let providedCalendar = calendar {
            effectiveCalendar = providedCalendar
        } else if let legacyCalendar = academicCalendar {
            effectiveCalendar = legacyCalendar
        }

        if let calendar = effectiveCalendar {
            // Check if date is within semester bounds
            let withinSemester = calendar.isDateWithinSemester(date)
            if !withinSemester {
                return []
            }
            // Check if date is a break day
            if calendar.isBreakDay(date) {
                return []
            }
        }

        // 4) Filter by the schedule item's days of week
        let dayOfWeek = DayOfWeek.from(weekday: weekday)
        let filteredItems = scheduleItems.filter { item in
            item.daysOfWeek.contains(dayOfWeek)
        }

        return filteredItems
    }
}
