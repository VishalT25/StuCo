//
//  AppEnums.swift
//  StudentCompanion
//
//  Created by Vishal Thamaraimanalan on 2025-06-30.
//

import Foundation
import SwiftUI

// MARK: - ParseContext Enum
/// Context for follow-up questions in the natural language processing pipeline
enum ParseContext: String, CaseIterable, Codable, Identifiable {
    case grade = "grade"
    case event = "event"
    case schedule = "schedule"
    
    var id: String { self.rawValue }
    
    /// Human-readable description of the context
    var displayName: String {
        switch self {
        case .grade:
            return "Grade Entry"
        case .event:
            return "Event Creation"
        case .schedule:
            return "Schedule Item"
        }
    }
    
    /// Icon for the context type
    var icon: String {
        switch self {
        case .grade:
            return "chart.bar.fill"
        case .event:
            return "calendar.badge.plus"
        case .schedule:
            return "calendar.badge.clock"
        }
    }
    
    /// Required fields for each context type
    var requiredFields: [String] {
        switch self {
        case .grade:
            return ["COURSE", "ASSIGNMENT", "SCORE_VALUE"]
        case .event:
            return ["EVENT", "TIME", "DATE"]
        case .schedule:
            return ["EVENT", "DAY_OF_WEEK", "TIME"]
        }
    }
    
    /// Generate appropriate follow-up questions for missing fields
    func questionForMissingField(_ field: String) -> String {
        switch (self, field) {
        // Grade context questions
        case (.grade, "COURSE"):
            return "What course is this for?"
        case (.grade, "ASSIGNMENT"):
            return "What's the assignment name?"
        case (.grade, "SCORE_VALUE"):
            return "What score did you get?"
        case (.grade, "WEIGHT"):
            return "What percentage is this assignment worth?"
            
        // Event context questions
        case (.event, "EVENT"):
            return "What's the event name?"
        case (.event, "TIME"):
            return "What time does it start?"
        case (.event, "DATE"):
            return "When does it occur?"
        case (.event, "CATEGORY"):
            return "What category should this event be in?"
            
        // Schedule context questions
        case (.schedule, "EVENT"):
            return "What's the recurring activity?"
        case (.schedule, "DAY_OF_WEEK"):
            return "Which days does this occur? (e.g., Monday, Tuesday)"
        case (.schedule, "TIME"):
            return "What time does it start?"
        case (.schedule, "DURATION"):
            return "How long does it last?"
            
        default:
            return "Can you provide more details about \(field.lowercased())?"
        }
    }
}

// MARK: - ReminderTime Enum
/// Time intervals for event reminders
enum ReminderTime: Int, CaseIterable, Identifiable, Codable {
    case none = 0
    case atTime = 1
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case sixHours = 360
    case twelveHours = 720
    case oneDay = 1440
    case twoDays = 2880
    case oneWeek = 10080
    case twoWeeks = 20160
    
    var id: Int { self.rawValue }
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .none:
            return "No reminder"
        case .atTime:
            return "At time of event"
        case .fiveMinutes:
            return "5 minutes before"
        case .tenMinutes:
            return "10 minutes before"
        case .fifteenMinutes:
            return "15 minutes before"
        case .thirtyMinutes:
            return "30 minutes before"
        case .oneHour:
            return "1 hour before"
        case .twoHours:
            return "2 hours before"
        case .sixHours:
            return "6 hours before"
        case .twelveHours:
            return "12 hours before"
        case .oneDay:
            return "1 day before"
        case .twoDays:
            return "2 days before"
        case .oneWeek:
            return "1 week before"
        case .twoWeeks:
            return "2 weeks before"
        }
    }
    
    /// Short display name for compact UI
    var shortDisplayName: String {
        switch self {
        case .none:
            return "None"
        case .atTime:
            return "At time"
        case .fiveMinutes:
            return "5 min"
        case .tenMinutes:
            return "10 min"
        case .fifteenMinutes:
            return "15 min"
        case .thirtyMinutes:
            return "30 min"
        case .oneHour:
            return "1 hr"
        case .twoHours:
            return "2 hrs"
        case .sixHours:
            return "6 hrs"
        case .twelveHours:
            return "12 hrs"
        case .oneDay:
            return "1 day"
        case .twoDays:
            return "2 days"
        case .oneWeek:
            return "1 week"
        case .twoWeeks:
            return "2 weeks"
        }
    }
    
    /// Time interval in seconds for notification scheduling
    var timeInterval: TimeInterval {
        return TimeInterval(self.rawValue * 60) // Convert minutes to seconds
    }
    
    /// Emoji icon for the reminder time
    var icon: String {
        switch self {
        case .none:
            return "🔕"
        case .atTime:
            return "⏰"
        case .fiveMinutes, .tenMinutes, .fifteenMinutes:
            return "⏱️"
        case .thirtyMinutes, .oneHour, .twoHours:
            return "🕐"
        case .sixHours, .twelveHours:
            return "🕕"
        case .oneDay, .twoDays:
            return "📅"
        case .oneWeek, .twoWeeks:
            return "🗓️"
        }
    }
    
    /// Color associated with the reminder time
    var color: Color {
        switch self {
        case .none:
            return .gray
        case .atTime, .fiveMinutes, .tenMinutes:
            return .red
        case .fifteenMinutes, .thirtyMinutes:
            return .orange
        case .oneHour, .twoHours:
            return .yellow
        case .sixHours, .twelveHours:
            return .green
        case .oneDay, .twoDays:
            return .blue
        case .oneWeek, .twoWeeks:
            return .purple
        }
    }
    
    /// Check if this reminder time is considered "urgent" (less than 1 hour)
    var isUrgent: Bool {
        return self.rawValue > 0 && self.rawValue < 60
    }
    
    /// Check if this reminder time is considered "advance notice" (more than 1 day)
    var isAdvanceNotice: Bool {
        return self.rawValue >= 1440
    }
    
    /// Create a ReminderTime from a string description
    static func from(string: String) -> ReminderTime? {
        let lowercased = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch lowercased {
        case "none", "no reminder", "no":
            return .none
        case "at time", "at event time", "when it starts":
            return .atTime
        case "5 minutes", "5 min", "five minutes":
            return .fiveMinutes
        case "10 minutes", "10 min", "ten minutes":
            return .tenMinutes
        case "15 minutes", "15 min", "fifteen minutes":
            return .fifteenMinutes
        case "30 minutes", "30 min", "thirty minutes", "half hour":
            return .thirtyMinutes
        case "1 hour", "one hour", "hour":
            return .oneHour
        case "2 hours", "two hours":
            return .twoHours
        case "6 hours", "six hours":
            return .sixHours
        case "12 hours", "twelve hours", "half day":
            return .twelveHours
        case "1 day", "one day", "day", "day before":
            return .oneDay
        case "2 days", "two days":
            return .twoDays
        case "1 week", "one week", "week", "week before":
            return .oneWeek
        case "2 weeks", "two weeks":
            return .twoWeeks
        default:
            return nil
        }
    }
    
    /// Common reminder times for quick selection
    static let common: [ReminderTime] = [
        .none, .fiveMinutes, .fifteenMinutes, .thirtyMinutes, .oneHour, .oneDay
    ]
    
    /// All reminder times except none
    static let withReminders: [ReminderTime] = {
        return ReminderTime.allCases.filter { $0 != .none }
    }()
}

// MARK: - Extensions for SwiftUI
extension ParseContext {
    /// SwiftUI Color for the context
    var color: Color {
        switch self {
        case .grade:
            return .blue
        case .event:
            return .green
        case .schedule:
            return .orange
        }
    }
}

// MARK: - Extensions for Convenience
extension ReminderTime {
    /// Initialize from minutes
    init?(minutes: Int) {
        self.init(rawValue: minutes)
    }
    
    /// Initialize from hours
    init?(hours: Int) {
        self.init(rawValue: hours * 60)
    }
    
    /// Initialize from days
    init?(days: Int) {
        self.init(rawValue: days * 1440)
    }
}
extension ReminderTime {
    /// Total minutes (alias for rawValue for clarity)
    var totalMinutes: Int {
        return self.rawValue
    }
    
    /// Minutes component (for display purposes)
    var minutes: Int {
        return self.rawValue % 60
    }
    
    /// Hours component (for display purposes)
    var hours: Int {
        return self.rawValue / 60
    }
    
    /// Days component (for display purposes)
    var days: Int {
        return self.rawValue / 1440
    }
    
    /// Weeks component (for display purposes)
    var weeks: Int {
        return self.rawValue / 10080
    }
    
    /// Create ReminderTime from total minutes
    static func fromMinutes(_ minutes: Int) -> ReminderTime? {
        return ReminderTime(rawValue: minutes)
    }
}


// MARK: - CustomStringConvertible
extension ParseContext: CustomStringConvertible {
    var description: String {
        return displayName
    }
}

extension ReminderTime: CustomStringConvertible {
    var description: String {
        return displayName
    }
}

// MARK: - Comparable
extension ReminderTime: Comparable {
    static func < (lhs: ReminderTime, rhs: ReminderTime) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// Add this to your ReminderTime enum
extension ReminderTime {
    /// Common reminder times for quick selection
    static let commonPresets: [ReminderTime] = [
        .none, .fiveMinutes, .fifteenMinutes, .thirtyMinutes, .oneHour, .oneDay
    ]
}


