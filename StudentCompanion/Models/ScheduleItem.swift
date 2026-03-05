import SwiftUI
import Foundation

struct ScheduleItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var startTime: Date
    var endTime: Date
    var daysOfWeek: [DayOfWeek] = []
    var location: String = ""
    var instructor: String = ""
    var color: Color = .blue
    var isLiveActivityEnabled: Bool = true
    var reminderTime: ReminderTime = .none

    var weeklyHours: Double {
        let duration = endTime.timeIntervalSince(startTime) / 3600.0
        let daysCount = Double(daysOfWeek.count)
        return duration * daysCount
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
        return "\(hours)h \(minutes)m"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, startTime, endTime, daysOfWeek, location, instructor, color, isLiveActivityEnabled, reminderTime
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(daysOfWeek, forKey: .daysOfWeek)
        try container.encode(location, forKey: .location)
        try container.encode(instructor, forKey: .instructor)
        try container.encode(UIColor(color).cgColor.components ?? [0,0,0,1], forKey: .color)
        try container.encode(isLiveActivityEnabled, forKey: .isLiveActivityEnabled)
        try container.encode(reminderTime, forKey: .reminderTime)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        daysOfWeek = try container.decode([DayOfWeek].self, forKey: .daysOfWeek)
        location = try container.decode(String.self, forKey: .location)
        instructor = try container.decode(String.self, forKey: .instructor)
        let components = try container.decode([CGFloat].self, forKey: .color)
        if components.count == 4 {
            color = Color(UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3]))
        } else {
            color = Color.blue
        }
        isLiveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .isLiveActivityEnabled) ?? true
        reminderTime = try container.decodeIfPresent(ReminderTime.self, forKey: .reminderTime) ?? .none
    }

    init(
        id: UUID = UUID(),
        title: String,
        startTime: Date,
        endTime: Date,
        daysOfWeek: [DayOfWeek],
        location: String = "",
        instructor: String = "",
        color: Color = .blue,
        isLiveActivityEnabled: Bool = true,
        reminderTime: ReminderTime = .none
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.daysOfWeek = daysOfWeek
        self.location = location
        self.instructor = instructor
        self.color = color
        self.isLiveActivityEnabled = isLiveActivityEnabled
        self.reminderTime = reminderTime
    }
}
