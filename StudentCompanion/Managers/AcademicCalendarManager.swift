import Foundation
import SwiftUI

@MainActor
class AcademicCalendarManager: ObservableObject, RealtimeSyncDelegate {
    @Published var academicCalendars: [AcademicCalendar] = []
    
    private let calendarsKey = "savedAcademicCalendars"
    private let supabaseService = SupabaseService.shared
    private let calendarRepository = AcademicCalendarRepository()
    private let authPromptHandler = AuthenticationPromptHandler.shared
    private let realtimeSyncManager = RealtimeSyncManager.shared

    init() {
        loadAcademicCalendars()
        
        // Set up real-time sync delegate
        realtimeSyncManager.academicCalendarDelegate = self
        
        // Setup authentication observer
        setupAuthenticationObserver()
        
        Task { await syncFromSupabaseIfPossible() }
    }
    
    private func setupAuthenticationObserver() {
        // Listen for authentication state changes
        NotificationCenter.default.addObserver(
            forName: .init("SupabaseAuthStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let isAuthenticated = notification.object as? Bool {
                if isAuthenticated {
                    Task { await self?.syncFromSupabaseIfPossible() }
                } else {
                    // Data will be cleared by UserDataCleared notification
                }
            }
        }
        
        // CRITICAL: Listen for data clearing when user signs out
        NotificationCenter.default.addObserver(
            forName: .init("UserDataCleared"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🧹 AcademicCalendarManager: Received UserDataCleared notification")
            self?.clearData()
        }
        
        // Listen for post sign-in data refresh notification
        NotificationCenter.default.addObserver(
            forName: .init("UserSignedInDataRefresh"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📢 AcademicCalendarManager: Received post sign-in data refresh notification")
            Task { await self?.syncFromSupabaseIfPossible() }
        }
        
        // Listen for data sync completed notification - reload from local storage
        NotificationCenter.default.addObserver(
            forName: .init("DataSyncCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📢 AcademicCalendarManager: Received data sync completed notification")
            self?.loadAcademicCalendars()  // Reload from UserDefaults
        }
    }
    
    private func clearData() {
        academicCalendars.removeAll()
        UserDefaults.standard.removeObject(forKey: calendarsKey)
    }
    
    func loadAcademicCalendars() {
        if let data = UserDefaults.standard.data(forKey: calendarsKey) {
            do {
                let decoder = JSONDecoder()
                academicCalendars = try decoder.decode([AcademicCalendar].self, from: data)
            } catch {
                 ("Error loading academic calendars: \(error)")
                academicCalendars = []
            }
        }
    }
    
    func saveAcademicCalendars() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(academicCalendars)
            UserDefaults.standard.set(data, forKey: calendarsKey)
        } catch {
             ("Error saving academic calendars: \(error)")
        }
    }
    
    func addCalendar(_ calendar: AcademicCalendar) {
        // Check authentication first
        guard supabaseService.isAuthenticated else {
            authPromptHandler.promptForSignIn(
                title: "Add Calendar",
                description: "add your academic calendar"
            ) { [weak self] in
                self?.addCalendar(calendar)
            }
            return
        }
        
        academicCalendars.append(calendar)
        saveAcademicCalendars()
        Task {
            guard let userId = supabaseService.currentUser?.id.uuidString else {
                print("🗓️ AcademicCalendarManager: Not authenticated, skipping cloud insert")
                return
            }
            do {
                let saved = try await calendarRepository.create(calendar, userId: userId)
                if let idx = academicCalendars.firstIndex(where: { $0.id == calendar.id }) {
                    academicCalendars[idx] = saved
                    saveAcademicCalendars()
                }
                print("🗓️ AcademicCalendarManager: Synced calendar '\(calendar.name)' to Supabase")
            } catch {
                print("🛑 AcademicCalendarManager: Failed to sync calendar insert: \(error)")
            }
        }
    }
    
    func updateCalendar(_ calendar: AcademicCalendar) {
        guard let index = academicCalendars.firstIndex(where: { $0.id == calendar.id }) else { return }
        academicCalendars[index] = calendar
        saveAcademicCalendars()
        Task {
            guard let userId = supabaseService.currentUser?.id.uuidString else {
                print("🗓️ AcademicCalendarManager: Not authenticated, skipping cloud update")
                return
            }
            do {
                let saved = try await calendarRepository.update(calendar, userId: userId)
                if let idx = academicCalendars.firstIndex(where: { $0.id == calendar.id }) {
                    academicCalendars[idx] = saved
                    saveAcademicCalendars()
                }
                print("🗓️ AcademicCalendarManager: Synced calendar update for '\(calendar.name)'")
            } catch {
                print("🛑 AcademicCalendarManager: Failed to sync calendar update: \(error)")
            }
        }
    }
    
    func deleteCalendar(_ calendar: AcademicCalendar) {
        academicCalendars.removeAll { $0.id == calendar.id }
        saveAcademicCalendars()
        Task {
            do {
                try await calendarRepository.delete(id: calendar.id.uuidString)
                print("🗓️ AcademicCalendarManager: Deleted calendar '\(calendar.name)' from Supabase")
            } catch {
                print("🛑 AcademicCalendarManager: Failed to delete calendar from Supabase: \(error)")
            }
        }
    }

    func syncFromSupabaseIfPossible() async {
        guard supabaseService.isAuthenticated, let userId = supabaseService.currentUser?.id.uuidString else {
            return
        }
        do {
            let remote = try await calendarRepository.readAll(userId: userId)
            if !remote.isEmpty {
                academicCalendars = remote
                saveAcademicCalendars()
                print("🗓️ AcademicCalendarManager: Loaded \(remote.count) calendars from Supabase")
            } else {
                print("🗓️ AcademicCalendarManager: No calendars in Supabase for user")
            }
        } catch {
            print("🛑 AcademicCalendarManager: Failed to load calendars from Supabase: \(error)")
        }
    }
    
    func calendar(withID id: UUID) -> AcademicCalendar? {
        return academicCalendars.first { $0.id == id }
    }
    
    func createDefaultCalendar(for year: String) -> AcademicCalendar {
        let components = year.split(separator: "-")
        let startYear = Int(components.first ?? "2024") ?? 2024
        
        let startDate = Calendar.current.date(from: DateComponents(year: startYear, month: 8, day: 15)) ?? Date()
        let endDate = Calendar.current.date(from: DateComponents(year: startYear + 1, month: 6, day: 15)) ?? Date()
        
        return AcademicCalendar(
            name: "Academic Year \(year)",
            academicYear: year,
            termType: .semester,
            startDate: startDate,
            endDate: endDate
        )
    }
    
    func getUsageCount(for calendar: AcademicCalendar, in scheduleManager: ScheduleManager) -> Int {
        return scheduleManager.scheduleCollections.filter { schedule in
            schedule.academicCalendarID == calendar.id
        }.count
    }
    
    func getSchedulesUsing(_ calendar: AcademicCalendar, from scheduleManager: ScheduleManager) -> [ScheduleCollection] {
        return scheduleManager.scheduleCollections.filter { schedule in
            schedule.academicCalendarID == calendar.id
        }
    }
    
    func canDelete(_ calendar: AcademicCalendar, in scheduleManager: ScheduleManager) -> (canDelete: Bool, reason: String?) {
        let usageCount = getUsageCount(for: calendar, in: scheduleManager)
        if usageCount > 0 {
            return (false, "Calendar is being used by \(usageCount) schedule\(usageCount == 1 ? "" : "s")")
        }
        return (true, nil)
    }
    
    // MARK: - RealtimeSyncDelegate
    
    func didReceiveRealtimeUpdate(_ data: [String: Any], action: String, table: String) {
        switch (table, action) {
        case ("academic_calendars", "SYNC"):
            if let calendarsData = data["academic_calendars"] as? [DatabaseAcademicCalendar] {
                syncAcademicCalendarsFromDatabase(calendarsData)
            }
        case ("academic_calendars", "INSERT"):
            if let calendarData = try? JSONSerialization.data(withJSONObject: data),
               let dbCalendar = try? JSONDecoder().decode(DatabaseAcademicCalendar.self, from: calendarData) {
                handleAcademicCalendarInsert(dbCalendar)
            }
        case ("academic_calendars", "UPDATE"):
            if let calendarData = try? JSONSerialization.data(withJSONObject: data),
               let dbCalendar = try? JSONDecoder().decode(DatabaseAcademicCalendar.self, from: calendarData) {
                handleAcademicCalendarUpdate(dbCalendar)
            }
        case ("academic_calendars", "DELETE"):
            if let calendarId = data["id"] as? String {
                handleAcademicCalendarDelete(calendarId)
            }
        default:
            break
        }
    }
    
    private func syncAcademicCalendarsFromDatabase(_ calendars: [DatabaseAcademicCalendar]) {
        let currentUserId = supabaseService.currentUser?.id.uuidString
        let ownCalendars = calendars.filter { calendar in
            guard let uid = currentUserId else { return false }
            return calendar.user_id == uid
        }
        
        let localCalendars = ownCalendars.map { $0.toLocal() }
        academicCalendars = localCalendars
        saveAcademicCalendars()
        
        print("🗓️ AcademicCalendarManager: Synced \(localCalendars.count) calendars from database")
    }
    
    private func handleAcademicCalendarInsert(_ dbCalendar: DatabaseAcademicCalendar) {
        let currentUserId = supabaseService.currentUser?.id.uuidString
        guard let uid = currentUserId, dbCalendar.user_id == uid else {
            print("🗓️ AcademicCalendarManager: Ignoring calendar insert for another user")
            return
        }
        
        let localCalendar = dbCalendar.toLocal()
        if !academicCalendars.contains(where: { $0.id == localCalendar.id }) {
            academicCalendars.append(localCalendar)
            saveAcademicCalendars()
            print("🗓️ AcademicCalendarManager: Added calendar from real-time: \(localCalendar.name)")
        }
    }
    
    private func handleAcademicCalendarUpdate(_ dbCalendar: DatabaseAcademicCalendar) {
        let currentUserId = supabaseService.currentUser?.id.uuidString
        guard let uid = currentUserId, dbCalendar.user_id == uid else {
            print("🗓️ AcademicCalendarManager: Ignoring calendar update for another user")
            return
        }
        
        let localCalendar = dbCalendar.toLocal()
        if let index = academicCalendars.firstIndex(where: { $0.id == localCalendar.id }) {
            academicCalendars[index] = localCalendar
            saveAcademicCalendars()
            print("🗓️ AcademicCalendarManager: Updated calendar from real-time: \(localCalendar.name)")
        }
    }
    
    private func handleAcademicCalendarDelete(_ calendarId: String) {
        guard let uuid = UUID(uuidString: calendarId) else { return }
        
        if let index = academicCalendars.firstIndex(where: { $0.id == uuid }) {
            let removedCalendar = academicCalendars.remove(at: index)
            saveAcademicCalendars()
            print("🗓️ AcademicCalendarManager: Deleted calendar from real-time: \(removedCalendar.name)")
        }
    }
}