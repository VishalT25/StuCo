//
//  NotificationManager.swift
//  StudentCompanion
//

import Foundation
import UserNotifications
import UIKit

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var notificationAuthorisation: UNAuthorizationStatus = .denied
    @Published var isAuthorized: Bool = false
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task {
            await requestAuthorization()
            checkAuthorizationStatus()
        }
    }
    
    // MARK: - Computed Properties
    var authorizationStatusText: String {
        switch notificationAuthorisation {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Determined"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Authorization Methods
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.notificationAuthorisation = granted ? .authorized : .denied
                self.isAuthorized = granted
                 (granted ? "✅ Notifications enabled" : "❌ Notifications denied")
            }
        } catch {
            await MainActor.run {
                 ("❌ Notification authorization error: \(error)")
                self.notificationAuthorisation = .denied
                self.isAuthorized = false
            }
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationAuthorisation = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
                
                 ("🔔 Notification authorization status: \(settings.authorizationStatus.rawValue)")
            }
        }
    }
    
    func openNotificationSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Pending Notifications
    func getPendingNotifications() async -> [UNNotificationRequest] {
        let center = UNUserNotificationCenter.current()
        return await center.pendingNotificationRequests()
    }
    
    func getPendingNotificationsCount() async -> Int {
        let requests = await getPendingNotifications()
        return requests.count
    }
    
    // MARK: - Event Notifications
    func scheduleEventNotification(for event: Event) {
        guard event.reminderTime != .none else { return }
        
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Event"
        content.body = event.title
        content.sound = .default
        
        guard let triggerDate = Calendar.current.date(
            byAdding: .minute,
            value: -event.reminderTime.totalMinutes,
            to: event.date
        ), triggerDate > Date() else {
             ("❌ Invalid trigger date for event: \(event.title)")
            return
        }
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "event-\(event.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                 ("❌ Failed to schedule event notification: \(error)")
            } else {
                 ("✅ Scheduled notification for \(event.title)")
            }
        }
    }
    
    // MARK: - Schedule Item Notifications
    func scheduleScheduleItemNotification(for item: ScheduleItem) {
        guard item.reminderTime != .none else { return }
        
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Class"
        content.body = item.title
        content.sound = .default
        
        guard let triggerDate = Calendar.current.date(
            byAdding: .minute,
            value: -item.reminderTime.totalMinutes,
            to: item.startTime
        ), triggerDate > Date() else {
             ("❌ Invalid trigger date for schedule item: \(item.title)")
            return
        }
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "schedule-\(item.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                 ("❌ Failed to schedule schedule notification: \(error)")
            } else {
                 ("✅ Scheduled notification for \(item.title)")
            }
        }
    }
    
    // MARK: - Grade Notifications
    func scheduleGradeNotification(for grade: Grade, assignment: String, courseName: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "New Grade Added"
        let percentage = (grade.score / grade.total) * 100
        content.body = "Grade: \(String(format: "%.1f", percentage))% (\(grade.score)/\(grade.total)) for \(assignment) in \(courseName)"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let identifier = "grade-\(assignment)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                 ("❌ Failed to schedule grade notification: \(error)")
            } else {
                 ("✅ Scheduled notification for new grade")
            }
        }
    }
    
    // MARK: - Cancel Notifications
    func cancelNotification(for eventId: UUID) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["event-\(eventId.uuidString)"])
         ("✅ Cancelled notification for event \(eventId)")
    }
    
    func cancelScheduleNotification(for scheduleId: UUID) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["schedule-\(scheduleId.uuidString)"])
         ("✅ Cancelled notification for schedule item \(scheduleId)")
    }
    
    func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
         ("✅ Cancelled all notifications")
    }
    
    // MARK: - Utility Methods
    func formatReminderTimeForDisplay(_ reminderTime: ReminderTime) -> String {
        return reminderTime.displayName
    }
    
    func getReminderOptions() -> [ReminderTime] {
        return ReminderTime.allCases
    }
    
    func isValidReminderTime(_ reminderTime: ReminderTime?) -> Bool {
        guard let reminderTime = reminderTime else { return false }
        return reminderTime != .none
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
         ("✅ User tapped notification: \(response.notification.request.identifier)")
        completionHandler()
    }
    
    func scheduleEventNotification(for event: Event, reminderTime: ReminderTime, categories: [Category]) {
        guard reminderTime != .none else { return }
        
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Event"
        content.body = event.title
        content.sound = .default
        
        // Get category name for better notification content
        if let category = categories.first(where: { $0.id == event.categoryId }) {
            content.subtitle = "Category: \(category.name)"
        }
        
        guard let triggerDate = Calendar.current.date(
            byAdding: .minute,
            value: -reminderTime.totalMinutes,
            to: event.date
        ), triggerDate > Date() else {
             ("❌ Invalid trigger date for event: \(event.title)")
            return
        }
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "event-\(event.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                 ("❌ Failed to schedule event notification: \(error)")
            } else {
                 ("✅ Scheduled notification for \(event.title)")
            }
        }
    }

    func removeAllEventNotifications(for event: Event) {
        let center = UNUserNotificationCenter.current()
        let identifiers = [
            "event-\(event.id.uuidString)",
            "reminder-\(event.id.uuidString)" // Alternative identifier format
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
         ("✅ Removed all notifications for event: \(event.title)")
    }

    // MARK: - Schedule Item Notification Methods
    func scheduleScheduleItemNotifications(for item: ScheduleItem, reminderTime: ReminderTime) {
        guard reminderTime != .none else { return }
        
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()
        
        // Schedule notifications for the next 4 weeks for recurring items
        for week in 0..<4 {
            for dayOfWeek in item.daysOfWeek {
                guard let baseDate = calendar.date(byAdding: .weekOfYear, value: week, to: now),
                      let scheduleDate = calendar.nextDate(after: baseDate, matching: DateComponents(weekday: dayOfWeek.rawValue), matchingPolicy: .nextTime) else {
                    continue
                }
                
                // Create the actual time for this schedule item on this date
                let scheduleComponents = calendar.dateComponents([.hour, .minute], from: item.startTime)
                guard let actualDateTime = calendar.date(bySettingHour: scheduleComponents.hour ?? 0,
                                                       minute: scheduleComponents.minute ?? 0,
                                                       second: 0,
                                                       of: scheduleDate) else {
                    continue
                }
                
                // Skip if this time has already passed
                guard actualDateTime > now else { continue }
                
                // Calculate reminder time
                guard let reminderDateTime = calendar.date(
                    byAdding: .minute,
                    value: -reminderTime.totalMinutes,
                    to: actualDateTime
                ), reminderDateTime > now else {
                    continue
                }
                
                let content = UNMutableNotificationContent()
                content.title = "Upcoming Class"
                content.body = item.title
                content.sound = .default
                
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDateTime),
                    repeats: false
                )
                
                let identifier = "schedule-\(item.id.uuidString)-\(week)-\(dayOfWeek.rawValue)"
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )
                
                center.add(request) { error in
                    if let error = error {
                         ("❌ Failed to schedule schedule notification: \(error)")
                    } else {
                         ("✅ Scheduled notification for \(item.title) on \(scheduleDate)")
                    }
                }
            }
        }
    }

    func removeAllScheduleItemNotifications(for item: ScheduleItem) {
        let center = UNUserNotificationCenter.current()

        // Remove notifications for all possible weeks and days
        var identifiers: [String] = []
        for week in 0..<4 {
            for dayOfWeek in DayOfWeek.allCases {
                identifiers.append("schedule-\(item.id.uuidString)-\(week)-\(dayOfWeek.rawValue)")
            }
        }

        // Also remove with the simple identifier format
        identifiers.append("schedule-\(item.id.uuidString)")

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
         ("✅ Removed all notifications for schedule item: \(item.title)")
    }

    // MARK: - Course Meeting Notifications
    func scheduleCourseMeetingNotifications(for meeting: CourseMeeting, courseName: String) {
        guard meeting.reminderTime != .none else { return }

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()

        // Schedule notifications for the next 4 weeks for recurring meetings
        for week in 0..<4 {
            for dayOfWeek in meeting.daysOfWeek {
                guard let baseDate = calendar.date(byAdding: .weekOfYear, value: week, to: now),
                      let scheduleDate = calendar.nextDate(after: baseDate, matching: DateComponents(weekday: dayOfWeek), matchingPolicy: .nextTime) else {
                    continue
                }

                // Create the actual time for this meeting on this date
                let scheduleComponents = calendar.dateComponents([.hour, .minute], from: meeting.startTime)
                guard let actualDateTime = calendar.date(bySettingHour: scheduleComponents.hour ?? 0,
                                                       minute: scheduleComponents.minute ?? 0,
                                                       second: 0,
                                                       of: scheduleDate) else {
                    continue
                }

                // Skip if this time has already passed
                guard actualDateTime > now else { continue }

                // Calculate reminder time
                guard let reminderDateTime = calendar.date(
                    byAdding: .minute,
                    value: -meeting.reminderTime.totalMinutes,
                    to: actualDateTime
                ) else {
                    continue
                }

                // Create notification content
                let content = UNMutableNotificationContent()
                content.title = "Upcoming Class"
                content.body = courseName
                content.subtitle = "\(meeting.displayName) at \(meeting.location)"
                content.sound = .default

                // Create trigger
                let triggerComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: reminderDateTime
                )
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: triggerComponents,
                    repeats: false
                )

                // Create unique identifier for this specific occurrence
                let identifier = "meeting-\(meeting.id.uuidString)-\(week)-\(dayOfWeek)"
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )

                center.add(request) { error in
                    if let error = error {
                         ("❌ Failed to schedule meeting notification: \(error)")
                    } else {
                         ("✅ Scheduled notification for \(courseName) - \(meeting.displayName) on \(scheduleDate)")
                    }
                }
            }
        }
    }

    func removeAllCourseMeetingNotifications(for meeting: CourseMeeting) {
        let center = UNUserNotificationCenter.current()

        // Remove notifications for all possible weeks and days
        var identifiers: [String] = []
        for week in 0..<4 {
            for dayOfWeek in 1...7 { // All days of week
                identifiers.append("meeting-\(meeting.id.uuidString)-\(week)-\(dayOfWeek)")
            }
        }

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
         ("✅ Removed all notifications for meeting: \(meeting.displayName)")
    }

    // MARK: - Alias methods for backward compatibility
    func scheduleScheduleItemNotification(for item: ScheduleItem, reminderTime: ReminderTime) {
        scheduleScheduleItemNotifications(for: item, reminderTime: reminderTime)
    }

    func removeAllScheduleItemNotification(for item: ScheduleItem) {
        removeAllScheduleItemNotifications(for: item)
    }
}

// MARK: - Helper Extensions
extension NotificationManager {
    func scheduleMultipleNotifications(for events: [Event]) {
        for event in events {
            scheduleEventNotification(for: event)
        }
    }
    
    func scheduleMultipleScheduleNotifications(for items: [ScheduleItem]) {
        for item in items {
            scheduleScheduleItemNotification(for: item)
        }
    }
}
