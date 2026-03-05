import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var eventViewModel: EventViewModel
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var liveActivities: [LiveActivityInfo] = []
    @State private var upcomingReminders: [Event] = []
    @State private var recentNotifications: [NotificationItem] = []
    @State private var isRefreshing = false
    
    var body: some View {
        ZStack {
            SpectacularBackground(themeManager: themeManager)
            
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                
                if isRefreshing && recentNotifications.isEmpty && upcomingReminders.isEmpty && liveActivities.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if liveActivities.isEmpty && upcomingReminders.isEmpty && recentNotifications.isEmpty {
                    Spacer()
                    emptyStateView
                    Spacer()
                    Spacer()
                } else {
                    contentScrollView
                }
            }
            .padding(.top, 10)
        }
        .onAppear {
            Task {
                await loadInitialNotifications()
            }
        }
    }

    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.forma(.subheadline, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .frame(width: 36, height: 36)
                    .background(themeManager.currentTheme.primaryColor.opacity(0.2))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Notifications")
                .font(.forma(.title, weight: .bold))
            
            Spacer()
            
            Button {
                Task {
                    await refreshNotifications()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.forma(.subheadline, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .frame(width: 36, height: 36)
                    .background(themeManager.currentTheme.primaryColor.opacity(0.2))
                    .clipShape(Circle())
            }
            .disabled(isRefreshing)
        }
        .padding(.horizontal)
    }

    private var contentScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 28, pinnedViews: .sectionHeaders) {
                if !liveActivities.isEmpty {
                    Section {
                        LazyVStack(spacing: 16) {
                            ForEach(liveActivities) { activity in
                                LiveActivityCard(activity: activity)
                            }
                        }
                    } header: {
                        NotificationSectionHeader(title: "Live Activities", icon: "sparkles", color: .pink)
                    }
                }
                
                if !upcomingReminders.isEmpty {
                    Section {
                        LazyVStack(spacing: 16) {
                            ForEach(upcomingReminders.prefix(5)) { reminder in
                                ReminderNotificationCard(reminder: reminder)
                            }
                        }
                    } header: {
                        NotificationSectionHeader(title: "Upcoming Reminders", icon: "clock.badge.exclamationmark", color: .cyan)
                    }
                }
                
                if !recentNotifications.isEmpty {
                    Section {
                        LazyVStack(spacing: 16) {
                            ForEach(recentNotifications) { notification in
                                SystemNotificationCard(notification: notification)
                            }
                        }
                    } header: {
                        NotificationSectionHeader(title: "Recent", icon: "bell.badge", color: .purple)
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .refreshable {
            await refreshNotifications()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 120, height: 120)
                    .adaptiveFabDarkModeHue(using: themeManager.currentTheme, intensity: 0.8)
                
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 50, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            }
            
            VStack(spacing: 8) {
                Text("No Notifications Yet")
                    .font(.forma(.title3, weight: .bold))
                
                Text("Reminders, updates, and other alerts will appear here once they're available.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(32)
        .background(
            ZStack {
                if colorScheme == .light {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.regularMaterial)
                } else {
                    EmptyView()
                }
            }
        )
        .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: 1.0, cornerRadius: 24)
        .padding(.horizontal, 20)
    }

    @MainActor
    private func loadInitialNotifications() async {
        if liveActivities.isEmpty && upcomingReminders.isEmpty && recentNotifications.isEmpty {
            await loadNotifications(isRefresh: false)
        }
    }

    @MainActor
    private func refreshNotifications() async {
        await loadNotifications(isRefresh: true)
    }
    
    @MainActor
    private func loadNotifications(isRefresh: Bool) async {
        isRefreshing = true
        
        async let liveActivitiesTask = loadLiveActivities()
        async let upcomingRemindersTask = loadUpcomingReminders()
        async let recentNotificationsTask = loadRecentNotifications()
        
        let (loadedLive, loadedUpcoming, loadedRecent) = await (liveActivitiesTask, upcomingRemindersTask, recentNotificationsTask)
        
        withAnimation(.spring()) {
            self.liveActivities = loadedLive
            self.upcomingReminders = loadedUpcoming
            self.recentNotifications = loadedRecent
        }
        
        isRefreshing = false
    }
    
    private func loadLiveActivities() async -> [LiveActivityInfo] {
        return LiveActivityManager.shared.getCurrentActivities()
    }
    
    private func loadUpcomingReminders() async -> [Event] {
        let now = Date()
        let next24Hours = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        
        return eventViewModel.events
            .filter { event in
                guard event.reminderTime != .none, !event.isCompleted else { return false }
                let reminderDate = event.date.addingTimeInterval(-event.reminderTime.timeInterval)
                return reminderDate >= now && reminderDate <= next24Hours
            }
            .sorted {
                let date1 = $0.date.addingTimeInterval(-$0.reminderTime.timeInterval)
                let date2 = $1.date.addingTimeInterval(-$1.reminderTime.timeInterval)
                return date1 < date2
            }
    }
    
    private func loadRecentNotifications() async -> [NotificationItem] {
        let center = UNUserNotificationCenter.current()
        
        do {
            let deliveredNotifications = try await center.deliveredNotifications()
            let last24Hours = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            
            return deliveredNotifications
                .filter { $0.date >= last24Hours }
                .compactMap { notification -> NotificationItem? in
                    let request = notification.request
                    let content = request.content
                    
                    return NotificationItem(
                        id: request.identifier,
                        title: content.title,
                        body: content.body,
                        date: notification.date,
                        categoryIdentifier: content.categoryIdentifier,
                        userInfo: content.userInfo
                    )
                }
                .sorted { $0.date > $1.date }
        } catch {
             ("Failed to load recent notifications: \(error)")
            return []
        }
    }
}

// MARK: - Section Header
private struct NotificationSectionHeader: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.forma(.title3, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            
            Text(title)
                .font(.forma(.headline, weight: .bold))
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color.clear)
    }
}


// MARK: - Live Activity Card
private struct LiveActivityCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let activity: LiveActivityInfo
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(activity.title)
                        .font(.forma(.headline, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("LIVE")
                        .font(.forma(.caption, weight: .heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
                
                Text(activity.subtitle)
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 16) {
                    Label(activity.timeRange, systemImage: "clock.fill")
                    if let location = activity.location {
                        Label(location, systemImage: "location.fill")
                    }
                }
                .font(.forma(.caption))
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
            
            Button {
                LiveActivityManager.shared.endActivity(activityId: activity.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.regularMaterial)
        .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: 1.0)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Reminder Notification Card
private struct ReminderNotificationCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var eventViewModel: EventViewModel
    let reminder: Event
    
    private var reminderDate: Date? {
        guard reminder.reminderTime != .none else { return nil }
        return reminder.date.addingTimeInterval(-reminder.reminderTime.timeInterval)
    }
    
    private var timeUntilReminder: String {
        guard let reminderDate else { return "" }
        let now = Date()
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: reminderDate, relativeTo: now)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(reminder.title)
                        .font(.forma(.headline, weight: .bold))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if !timeUntilReminder.isEmpty {
                        Text(timeUntilReminder)
                            .font(.forma(.caption, weight: .semibold))
                            .foregroundColor(themeManager.currentTheme.secondaryColor)
                    }
                }
                
                HStack(spacing: 12) {
                    Label(reminder.date.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                    Text(reminder.reminderTime.shortDisplayName)
                        .font(.forma(.caption, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(reminder.reminderTime.color.opacity(0.2))
                        .foregroundColor(reminder.reminderTime.color)
                        .clipShape(Capsule())
                }
                .font(.forma(.caption))
                .foregroundColor(.secondary)
            }
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    eventViewModel.markEventCompleted(reminder)
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .padding(8)
                    .background(themeManager.currentTheme.primaryColor.opacity(0.2))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.regularMaterial)
        .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: 1.0)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}


// MARK: - System Notification Card
private struct SystemNotificationCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let notification: NotificationItem
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.date, relativeTo: Date())
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconForCategory(notification.categoryIdentifier))
                .font(.forma(.headline, weight: .semibold))
                .foregroundColor(themeManager.currentTheme.tertiaryColor)
                .frame(width: 44, height: 44)
                .background(themeManager.currentTheme.tertiaryColor.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.forma(.subheadline, weight: .bold))
                        .lineLimit(1)
                    Spacer()
                    Text(timeAgo)
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                }
                
                if !notification.body.isEmpty {
                    Text(notification.body)
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: 1.0)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "REMINDER_CATEGORY": return "bell.fill"
        case "SCHEDULE_CATEGORY": return "calendar"
        case "GRADE_CATEGORY": return "graduationcap.fill"
        default: return "app.badge"
        }
    }
}


// MARK: - Supporting Models
struct LiveActivityInfo: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let timeRange: String
    let location: String?
    let color: Color
}

struct NotificationItem: Identifiable {
    let id: String
    let title: String
    let body: String
    let date: Date
    let categoryIdentifier: String
    let userInfo: [AnyHashable: Any]
}

// MARK: - Mock Extensions
extension LiveActivityManager {
    // NOTE: This should be implemented based on your live activity system.
    func getCurrentActivities() -> [LiveActivityInfo] {
        // This will be replaced with a real implementation
        return []
    }
    
    func endActivity(activityId: String) {
         ("Ending activity: \(activityId)")
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
    }
    .sheet(isPresented: .constant(true)) {
        NotificationsView()
            .environmentObject(ThemeManager())
            .environmentObject(EventViewModel())
            .environmentObject(NotificationManager.shared)
    }
}
