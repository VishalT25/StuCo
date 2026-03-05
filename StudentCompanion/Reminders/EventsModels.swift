import SwiftUI

struct Category: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var color: Color
    var scheduleId: UUID?  // Link to schedule
    var courseId: UUID?    // Direct link to course

    enum CodingKeys: String, CodingKey {
        case id, name, color, scheduleId, courseId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(UIColor(color).cgColor.components ?? [0,0,0,1], forKey: .color)
        try container.encodeIfPresent(scheduleId, forKey: .scheduleId)
        try container.encodeIfPresent(courseId, forKey: .courseId)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let components = try container.decode([CGFloat].self, forKey: .color)
        if components.count == 4 {
            color = Color(UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3]))
        } else {
            color = Color(UIColor(red: components[0], green: components[0], blue: components[0], alpha: components.count > 1 ? components[1] : 1.0))
        }
        scheduleId = try container.decodeIfPresent(UUID.self, forKey: .scheduleId)
        courseId = try container.decodeIfPresent(UUID.self, forKey: .courseId)
    }

    init(name: String, color: Color, scheduleId: UUID? = nil, courseId: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.scheduleId = scheduleId
        self.courseId = courseId
    }
}

// MARK: - Category Grouping for UI

struct CategoryGroup: Identifiable {
    let id = UUID()
    let scheduleName: String
    let scheduleId: UUID
    let categories: [Category]
    var isExpanded: Bool = false
}

enum DayOfWeek: Int, Codable, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    
    var short: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
    
    var full: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
    
    static func from(weekday: Int) -> DayOfWeek {
        return DayOfWeek(rawValue: weekday) ?? .sunday
    }
}