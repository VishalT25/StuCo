import Foundation
import SwiftUI

struct ScheduleImportParser {
    static func parseScheduleText(_ text: String) -> [ScheduleItem] {
        let lines = text.components(separatedBy: .newlines)
        var scheduleItems: [ScheduleItem] = []
        
        for line in lines {
            if let item = parseScheduleLine(line.trimmingCharacters(in: .whitespacesAndNewlines)) {
                scheduleItems.append(item)
            }
        }
        
        return scheduleItems
    }
    
    static func parseScheduleJSON(_ jsonString: String) throws -> [ScheduleItem] {
        // Clean the JSON string (remove any markdown formatting or extra text)
        let cleanedJson = cleanJsonString(jsonString)
        
        guard let jsonData = cleanedJson.data(using: .utf8) else {
            throw ImportError.invalidJSON
        }
        
        // Try both the new format (with "items") and old format (with "scheduleItems")
        var scheduleItems: [ScheduleItem] = []
        
        // First try the new format that matches the AI prompt
        if let newFormatData = try? JSONDecoder().decode(NewScheduleImportData.self, from: jsonData) {
            guard newFormatData.version == 1 else {
                throw ImportError.unsupportedVersion
            }
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            
            // Process schedule items from new JSON format
            for itemData in newFormatData.items {
                // Parse days of week
                var daysOfWeek: [DayOfWeek] = []
                for dayString in itemData.days {
                    if let day = parseDayOfWeek(dayString) {
                        daysOfWeek.append(day)
                    }
                }
                
                // Parse start and end times
                guard let startTime = timeFormatter.date(from: itemData.start),
                      let endTime = timeFormatter.date(from: itemData.end) else {
                    throw ImportError.invalidTimeFormat
                }
                
                // Create color from string
                let color = colorFromString(itemData.color) ?? .blue
                
                let scheduleItem = ScheduleItem(
                    title: itemData.title,
                    startTime: startTime,
                    endTime: endTime,
                    daysOfWeek: daysOfWeek,
                    location: "",
                    instructor: "",
                    color: color,
                        isLiveActivityEnabled: itemData.liveActivity ?? true,
                    reminderTime: reminderTimeFromString(itemData.reminder) ?? .tenMinutes
                )
                
                scheduleItems.append(scheduleItem)
            }
        } else {
            // Fall back to old format
            let importData = try JSONDecoder().decode(ScheduleImportData.self, from: jsonData)
            
            guard importData.version == 1 else {
                throw ImportError.unsupportedVersion
            }
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            
            // Process schedule items from old JSON format
            for itemData in importData.scheduleItems {
                // Parse days of week
                var daysOfWeek: [DayOfWeek] = []
                for dayString in itemData.daysOfWeek {
                    if let day = parseDayOfWeek(dayString) {
                        daysOfWeek.append(day)
                    }
                }
                
                // Parse start and end times
                guard let startTime = timeFormatter.date(from: itemData.startTime),
                      let endTime = timeFormatter.date(from: itemData.endTime) else {
                    throw ImportError.invalidTimeFormat
                }
                
                // Create color from hex if provided
                let color = Color(hex: itemData.color ?? "007AFF") ?? .blue
                
                let scheduleItem = ScheduleItem(
                    title: itemData.title,
                    startTime: startTime,
                    endTime: endTime,
                    daysOfWeek: daysOfWeek,
                    location: itemData.location ?? "",
                    instructor: itemData.instructor ?? "",
                    color: color,
                        isLiveActivityEnabled: true,
                    reminderTime: .tenMinutes
                )
                
                scheduleItems.append(scheduleItem)
            }
        }
        
        return scheduleItems
    }
    
    private static func cleanJsonString(_ input: String) -> String {
        var cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        }
        if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        // Find the JSON object (starts with { and ends with })
        if let startIndex = cleaned.firstIndex(of: "{"),
           let endIndex = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[startIndex...endIndex])
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func parseDayOfWeek(_ dayString: String) -> DayOfWeek? {
        switch dayString.lowercased() {
        case "sunday", "sun", "su":
            return .sunday
        case "monday", "mon", "m":
            return .monday
        case "tuesday", "tue", "tu", "t":
            return .tuesday
        case "wednesday", "wed", "w":
            return .wednesday
        case "thursday", "thu", "th", "r":
            return .thursday
        case "friday", "fri", "f":
            return .friday
        case "saturday", "sat", "s":
            return .saturday
        default:
            return nil
        }
    }
    
    private static func parseScheduleLine(_ line: String) -> ScheduleItem? {
        // Skip empty lines or lines that don't look like schedule entries
        guard !line.isEmpty,
              line.contains(":") || line.contains("-") else {
            return nil
        }
        
        // Basic parsing - look for patterns like:
        // "Math 101: MWF 9:00-10:00"
        // "Physics Lab: Tuesday 2:00-4:00"
        
        let components = line.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }
        
        let title = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let scheduleInfo = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse days and times from the schedule info
        let (days, startTime, endTime) = parseScheduleInfo(scheduleInfo)
        
        guard !days.isEmpty,
              let start = startTime,
              let end = endTime else {
            return nil
        }
        
        return ScheduleItem(
            title: title,
            startTime: start,
            endTime: end,
            daysOfWeek: days,
            location: "",
            instructor: "",
            color: .blue,
            isLiveActivityEnabled: true,
            reminderTime: .tenMinutes
        )
    }
    
    private static func parseScheduleInfo(_ info: String) -> ([DayOfWeek], Date?, Date?) {
        var days: [DayOfWeek] = []
        var startTime: Date?
        var endTime: Date?
        
        // Look for day patterns
        let dayPatterns: [(String, DayOfWeek)] = [
            ("Monday", .monday), ("Mon", .monday), ("M", .monday),
            ("Tuesday", .tuesday), ("Tue", .tuesday), ("T", .tuesday),
            ("Wednesday", .wednesday), ("Wed", .wednesday), ("W", .wednesday),
            ("Thursday", .thursday), ("Thu", .thursday), ("Th", .thursday), ("R", .thursday),
            ("Friday", .friday), ("Fri", .friday), ("F", .friday),
            ("Saturday", .saturday), ("Sat", .saturday), ("S", .saturday),
            ("Sunday", .sunday), ("Sun", .sunday), ("Su", .sunday)
        ]
        
        // Parse combined day patterns like "MWF", "TR", etc.
        if info.contains("MWF") || info.contains("mwf") {
            days = [.monday, .wednesday, .friday]
        } else if info.contains("TR") || info.contains("tr") {
            days = [.tuesday, .thursday]
        } else if info.contains("MW") || info.contains("mw") {
            days = [.monday, .wednesday]
        } else if info.contains("WF") || info.contains("wf") {
            days = [.wednesday, .friday]
        } else {
            // Look for individual day names
            for (pattern, day) in dayPatterns {
                if info.lowercased().contains(pattern.lowercased()) {
                    if !days.contains(day) {
                        days.append(day)
                    }
                }
            }
        }
        
        // Parse time ranges like "9:00-10:00", "2:00-4:00", etc.
        let timeRegex = try! NSRegularExpression(pattern: "(\\d{1,2}):?(\\d{2})?\\s*([AaPp][Mm])?\\s*-\\s*(\\d{1,2}):?(\\d{2})?\\s*([AaPp][Mm])?", options: [])
        let matches = timeRegex.matches(in: info, options: [], range: NSRange(location: 0, length: info.count))
        
        if let match = matches.first {
            let startHour = extractNumber(from: info, range: match.range(at: 1))
            let startMinute = extractNumber(from: info, range: match.range(at: 2)) ?? 0
            let startAmPm = extractString(from: info, range: match.range(at: 3))
            
            let endHour = extractNumber(from: info, range: match.range(at: 4))
            let endMinute = extractNumber(from: info, range: match.range(at: 5)) ?? 0
            let endAmPm = extractString(from: info, range: match.range(at: 6))
            
            if let startH = startHour, let endH = endHour {
                let calendar = Calendar.current
                let today = Date()
                
                // Convert to 24-hour format
                var finalStartHour = startH
                var finalEndHour = endH
                
                if let ampm = startAmPm?.lowercased() {
                    if ampm == "pm" && startH != 12 {
                        finalStartHour += 12
                    } else if ampm == "am" && startH == 12 {
                        finalStartHour = 0
                    }
                }
                
                if let ampm = endAmPm?.lowercased() {
                    if ampm == "pm" && endH != 12 {
                        finalEndHour += 12
                    } else if ampm == "am" && endH == 12 {
                        finalEndHour = 0
                    }
                }
                
                startTime = calendar.date(bySettingHour: finalStartHour, minute: startMinute, second: 0, of: today)
                endTime = calendar.date(bySettingHour: finalEndHour, minute: endMinute, second: 0, of: today)
            }
        }
        
        return (days, startTime, endTime)
    }
    
    private static func extractNumber(from string: String, range: NSRange) -> Int? {
        guard range.location != NSNotFound else { return nil }
        let substring = (string as NSString).substring(with: range)
        return Int(substring)
    }
    
    private static func extractString(from string: String, range: NSRange) -> String? {
        guard range.location != NSNotFound else { return nil }
        return (string as NSString).substring(with: range)
    }
    
    private static func colorFromString(_ colorString: String) -> Color? {
        switch colorString.lowercased() {
        case "blue":
            return .blue
        case "green":
            return .green
        case "orange":
            return .orange
        case "red":
            return .red
        case "purple":
            return .purple
        case "gray", "grey":
            return .gray
        case "yellow":
            return .yellow
        case "pink":
            return .pink
        case "teal":
            return .teal
        case "indigo":
            return .indigo
        case "mint":
            return .mint
        case "cyan":
            return .cyan
        default:
            // Try to parse as hex color
            return Color(hex: colorString)
        }
    }
    
    private static func reminderTimeFromString(_ reminderString: String?) -> ReminderTime? {
        guard let reminder = reminderString?.lowercased() else { return nil }
        
        switch reminder {
        case "none", "0", "0m":
            return .none
        case "5m", "5":
            return .fiveMinutes
        case "10m", "10":
            return .tenMinutes
        case "15m", "15":
            return .fifteenMinutes
        case "30m", "30":
            return .thirtyMinutes
        case "1h", "60m", "60":
            return .oneHour
        default:
            return .tenMinutes
        }
    }
}

// MARK: - Import Data Models
struct ScheduleImportData: Codable {
    let version: Int
    let scheduleItems: [ScheduleItemImportData]
}

struct ScheduleItemImportData: Codable {
    let title: String
    let startTime: String // HH:mm format
    let endTime: String   // HH:mm format
    let daysOfWeek: [String] // e.g., ["Monday", "Wednesday", "Friday"]
    let location: String?
    let instructor: String?
    let color: String? // hex color
}

// New format to match AI prompt
struct NewScheduleImportData: Codable {
    let version: Int
    let timezone: String?
    let items: [NewScheduleItemImportData]
}

struct NewScheduleItemImportData: Codable {
    let title: String
    let days: [String] // e.g., ["Mon", "Wed", "Fri"]
    let start: String // HH:mm format
    let end: String   // HH:mm format
    let color: String // color name or hex
    let reminder: String? // e.g., "10m"
    let liveActivity: Bool?
}