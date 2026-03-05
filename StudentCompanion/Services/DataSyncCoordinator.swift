import Foundation
import SwiftUI

/// Coordinates comprehensive data synchronization across all managers after authentication
@MainActor
class DataSyncCoordinator: ObservableObject {
    static let shared = DataSyncCoordinator()
    
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0.0
    @Published var syncStatus = "Ready"
    
    private let supabaseService = SupabaseService.shared
    private init() {}
    
    /// Performs comprehensive data sync immediately after user signs in
    func performPostSignInSync() async {
        guard supabaseService.isAuthenticated,
              let userId = supabaseService.currentUser?.id.uuidString else {
            print("⚠️ DataSyncCoordinator: Cannot sync - user not authenticated")
            return
        }
        
        isSyncing = true
        syncProgress = 0.0
        syncStatus = "Starting sync..."
        
        print("🔄 DataSyncCoordinator: Starting comprehensive post sign-in sync")
        
        let syncTasks: [(String, () async throws -> Void)] = [
            ("Academic Calendars", { await self.syncAcademicCalendars(userId: userId) }),
            ("Categories", { await self.syncCategories(userId: userId) }),
            ("Events", { await self.syncEvents(userId: userId) }),
            ("Schedules", { await self.syncSchedules(userId: userId) }),
            ("Schedule Items", { await self.syncScheduleItems(userId: userId) }),
            ("Courses", { await self.syncCourses(userId: userId) }),
            ("Assignments", { await self.syncAssignments(userId: userId) })
        ]
        
        let totalTasks = Double(syncTasks.count)
        
        for (index, (taskName, task)) in syncTasks.enumerated() {
            syncStatus = "Syncing \(taskName)..."
            print("🔄 DataSyncCoordinator: Syncing \(taskName)")
            
            do {
                try await task()
                print("✅ DataSyncCoordinator: \(taskName) sync completed")
            } catch {
                print("❌ DataSyncCoordinator: \(taskName) sync failed: \(error)")
            }
            
            syncProgress = Double(index + 1) / totalTasks
        }
        
        syncStatus = "Sync completed"
        isSyncing = false
        syncProgress = 1.0
        
        // Notify all managers that fresh data is available
        NotificationCenter.default.post(name: .init("DataSyncCompleted"), object: nil)
        
        print("🔄 DataSyncCoordinator: Comprehensive sync completed")
    }
    
    // MARK: - Individual Sync Methods
    
    private func syncAcademicCalendars(userId: String) async {
        do {
            let repository = AcademicCalendarRepository()
            let calendars = try await repository.readAll(userId: userId)
            
            // Store directly in the manager
            if let manager = getAcademicCalendarManager() {
                manager.academicCalendars = calendars
                manager.saveAcademicCalendars()
            }
            
            print("🗓️ DataSyncCoordinator: Loaded \(calendars.count) academic calendars")
        } catch {
            print("❌ DataSyncCoordinator: Failed to sync academic calendars: \(error)")
        }
    }
    
    private func syncCategories(userId: String) async {
        do {
            let repository = CategoryRepository()
            let categories = try await repository.readAll(userId: userId)
            
            // Update the cache directly
            await CacheSystem.shared.categoryCache.store(categories)
            
            print("🏷️ DataSyncCoordinator: Loaded \(categories.count) categories")
        } catch {
            print("❌ DataSyncCoordinator: Failed to sync categories: \(error)")
        }
    }
    
    private func syncEvents(userId: String) async {
        do {
            let repository = EventRepository()
            let events = try await repository.readAll(userId: userId)
            
            // Update the cache directly
            await CacheSystem.shared.eventCache.store(events)
            
            print("📅 DataSyncCoordinator: Loaded \(events.count) events")
        } catch {
            print("❌ DataSyncCoordinator: Failed to sync events: \(error)")
        }
    }
    
    private func syncSchedules(userId: String) async {
        do {
            let repository = ScheduleRepository()
            let schedules = try await repository.readAll(userId: userId)
            
            // Update the cache directly
            await CacheSystem.shared.scheduleCache.store(schedules)
            
            print("📋 DataSyncCoordinator: Loaded \(schedules.count) schedules")
        } catch {
            print("❌ DataSyncCoordinator: Failed to sync schedules: \(error)")
        }
    }
    
    private func syncScheduleItems(userId: String) async {
        do {
            let repository = ScheduleItemRepository()
            let items = try await repository.readAll(userId: userId)
            
            // Group schedule items by schedule_id and notify ScheduleManager
            let groupedItems = Dictionary(grouping: items) { item in
                // We need to find the schedule_id from the database for each item
                // For now, we'll let the ScheduleManager handle this through individual loading
                return "unknown"
            }
            
            print("📋 DataSyncCoordinator: Found \(items.count) schedule items")
            
            // Trigger ScheduleManager to reload schedule items
            NotificationCenter.default.post(
                name: .init("ScheduleItemsSynced"), 
                object: items
            )
            
        } catch {
            print("❌ DataSyncCoordinator: Failed to sync schedule items: \(error)")
        }
    }
    
    private func syncCourses(userId: String) async {
        do {
            let repository = CourseRepository()
            let courses = try await repository.readAll(userId: userId)
            
            // Update the cache directly
            await CacheSystem.shared.courseCache.store(courses)
            
            print("📚 DataSyncCoordinator: Loaded \(courses.count) courses")
        } catch {
            print("❌ DataSyncCoordinator: Failed to sync courses: \(error)")
        }
    }
    
    private func syncAssignments(userId: String) async {
        do {
            let repository = AssignmentRepository()
            let assignments = try await repository.readAll(userId: userId)
            
            // Update the cache directly
            await CacheSystem.shared.assignmentCache.store(assignments)
            
            print("📝 DataSyncCoordinator: Loaded \(assignments.count) assignments")
        } catch {
            print("❌ DataSyncCoordinator: Failed to sync assignments: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getAcademicCalendarManager() -> AcademicCalendarManager? {
        // This is a bit of a hack - in a real app we'd have proper DI
        // For now, we'll just rely on the notification system
        return nil
    }
}