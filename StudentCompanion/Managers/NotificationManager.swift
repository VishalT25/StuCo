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
            }
        } catch {
            await MainActor.run {
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
    func scheduleEventNotification(for event: Event, reminderTime: ReminderTime, categories: [Category]) {
        guard reminderTime != .none else { return }

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Event"
        content.body = event.title
        content.sound = .default

        if let category = categories.first(where: { $0.id == event.categoryId }) {
            content.subtitle = "Category: \(category.name)"
        }

        guard let triggerDate = Calendar.current.date(
            byAdding: .minute,
            value: -reminderTime.totalMinutes,
            to: event.date
        ), triggerDate > Date() else {
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

        center.add(request)
    }

    func removeAllEventNotifications(for event: Event) {
        let center = UNUserNotificationCenter.current()
        let identifiers = [
            "event-\(event.id.uuidString)",
            "reminder-\(event.id.uuidString)"
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
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

        center.add(request)
    }

    // MARK: - Cancel Notifications
    func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
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
        completionHandler()
    }

    // MARK: - Schedule Item Notification Methods
    func scheduleScheduleItemNotifications(for item: ScheduleItem, reminderTime: ReminderTime) {
        guard reminderTime != .none else { return }

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()

        for week in 0..<4 {
            for dayOfWeek in item.daysOfWeek {
                guard let baseDate = calendar.date(byAdding: .weekOfYear, value: week, to: now),
                      let scheduleDate = calendar.nextDate(after: baseDate, matching: DateComponents(weekday: dayOfWeek.rawValue), matchingPolicy: .nextTime) else {
                    continue
                }

                let scheduleComponents = calendar.dateComponents([.hour, .minute], from: item.startTime)
                guard let actualDateTime = calendar.date(bySettingHour: scheduleComponents.hour ?? 0,
                                                       minute: scheduleComponents.minute ?? 0,
                                                       second: 0,
                                                       of: scheduleDate) else {
                    continue
                }

                guard actualDateTime > now else { continue }

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

                center.add(request)
            }
        }
    }

    func removeAllScheduleItemNotifications(for item: ScheduleItem) {
        let center = UNUserNotificationCenter.current()

        var identifiers: [String] = []
        for week in 0..<4 {
            for dayOfWeek in DayOfWeek.allCases {
                identifiers.append("schedule-\(item.id.uuidString)-\(week)-\(dayOfWeek.rawValue)")
            }
        }

        identifiers.append("schedule-\(item.id.uuidString)")

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    // MARK: - Course Meeting Notifications
    func scheduleCourseMeetingNotifications(for meeting: CourseMeeting, courseName: String) {
        guard meeting.reminderTime != .none else { return }

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()

        for week in 0..<4 {
            for dayOfWeek in meeting.daysOfWeek {
                guard let baseDate = calendar.date(byAdding: .weekOfYear, value: week, to: now),
                      let scheduleDate = calendar.nextDate(after: baseDate, matching: DateComponents(weekday: dayOfWeek), matchingPolicy: .nextTime) else {
                    continue
                }

                let scheduleComponents = calendar.dateComponents([.hour, .minute], from: meeting.startTime)
                guard let actualDateTime = calendar.date(bySettingHour: scheduleComponents.hour ?? 0,
                                                       minute: scheduleComponents.minute ?? 0,
                                                       second: 0,
                                                       of: scheduleDate) else {
                    continue
                }

                guard actualDateTime > now else { continue }

                guard let reminderDateTime = calendar.date(
                    byAdding: .minute,
                    value: -meeting.reminderTime.totalMinutes,
                    to: actualDateTime
                ) else {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = "Upcoming Class"
                content.body = courseName
                content.subtitle = "\(meeting.displayName) at \(meeting.location)"
                content.sound = .default

                let triggerComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: reminderDateTime
                )
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: triggerComponents,
                    repeats: false
                )

                let identifier = "meeting-\(meeting.id.uuidString)-\(week)-\(dayOfWeek)"
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )

                center.add(request)
            }
        }
    }

    func removeAllCourseMeetingNotifications(for meeting: CourseMeeting) {
        let center = UNUserNotificationCenter.current()

        var identifiers: [String] = []
        for week in 0..<4 {
            for dayOfWeek in 1...7 {
                identifiers.append("meeting-\(meeting.id.uuidString)-\(week)-\(dayOfWeek)")
            }
        }

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
