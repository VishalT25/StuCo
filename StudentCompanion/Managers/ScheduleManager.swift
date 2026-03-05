import SwiftUI
import Foundation
import Combine

// MARK: - Enhanced Schedule Manager with Real-time Sync and Course Integration
@MainActor
class ScheduleManager: ObservableObject, RealtimeSyncDelegate {
    @Published var scheduleCollections: [ScheduleCollection] = []
    @Published var activeScheduleID: UUID? = nil
    @Published var isSyncing: Bool = false
    @Published var syncStatus: String = "Ready"
    @Published var lastSyncTime: Date?

    // MARK: - NEW: Course integration
    private var courseManager: UnifiedCourseManager?

    private let schedulesKey = "savedScheduleCollections"
    private let activeScheduleKey = "activeScheduleID"
    private let realtimeSyncManager = RealtimeSyncManager.shared
    private let supabaseService = SupabaseService.shared
    private let authPromptHandler = AuthenticationPromptHandler.shared
    private var cancellables = Set<AnyCancellable>()
    private var isInitialLoad = true

    init() {
        // Set up real-time sync delegate
        realtimeSyncManager.scheduleDelegate = self
        realtimeSyncManager.scheduleItemDelegate = self

        // Load local data first for offline support
        loadSchedules()

        // Setup sync status observation
        setupSyncStatusObservation()

        // Clear data when user signs out
        setupAuthenticationObserver()

        Task {
            await realtimeSyncManager.ensureStarted()
            // FIX: Always perform initial data refresh, regardless of isInitialLoad flag
            await self.refreshScheduleData()
            // FIX: Force initial sync if no data exists and user is authenticated
            if self.scheduleCollections.isEmpty && SupabaseService.shared.isAuthenticated {
                await self.performEmergencyDataSync()
            }
        }
    }

    private func setupAuthenticationObserver() {
        supabaseService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                if !isAuthenticated {
                    // Data will be cleared by UserDataCleared notification
                } else {
                    Task {
                        // Add delay to ensure authentication is fully complete
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        await self?.refreshScheduleData()
                        await self?.backfillUnsyncedSchedules()
                    }
                }
            }
            .store(in: &cancellables)

        // CRITICAL: Listen for data clearing when user signs out
        NotificationCenter.default.addObserver(
            forName: .init("UserDataCleared"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🧹 ScheduleManager: Received UserDataCleared notification")
            self?.clearData()
        }

        // Listen for post sign-in data refresh notification
        NotificationCenter.default.addObserver(
            forName: .init("UserSignedInDataRefresh"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📢 ScheduleManager: Received post sign-in data refresh notification")
            Task {
                await self?.refreshScheduleData()
                await self?.backfillUnsyncedSchedules()
            }
        }

        // Listen for data sync completed notification
        NotificationCenter.default.addObserver(
            forName: .init("DataSyncCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📢 ScheduleManager: Received data sync completed notification")
            Task {
                await self?.reloadFromCache()
                await self?.backfillUnsyncedSchedules()
            }
        }
    }

    private func clearData() {
        scheduleCollections.removeAll()
        activeScheduleID = nil
        UserDefaults.standard.removeObject(forKey: schedulesKey)
        UserDefaults.standard.removeObject(forKey: activeScheduleKey)
    }

    // MARK: - Emergency Data Sync (Fallback)
    private func performEmergencyDataSync() async {
        print("🚨 ScheduleManager: Performing emergency data sync - no local data found")

        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            print("🚨 ScheduleManager: Cannot sync - user not authenticated")
            return
        }

        isSyncing = true

        do {
            // Load schedules directly from repository
            let scheduleRepository = ScheduleRepository()
            let schedules = try await scheduleRepository.readAll(userId: userId)

            print("🚨 ScheduleManager: Emergency sync found \(schedules.count) schedules")

            if !schedules.isEmpty {
                scheduleCollections = schedules

                // Set active schedule
                if let firstActive = schedules.first(where: { $0.isActive }) {
                    activeScheduleID = firstActive.id
                } else {
                    activeScheduleID = schedules.first?.id
                }

                for idx in scheduleCollections.indices {
                    scheduleCollections[idx].scheduleItems = []
                }

                // Save to local storage
                isInitialLoad = false
                saveSchedulesLocally()

                print("🚨 ScheduleManager: Emergency sync completed successfully")
            }
        } catch {
            print("🚨 ScheduleManager: Emergency sync failed: \(error)")
        }

        isSyncing = false
    }

    private func loadScheduleItemsForSchedule(_ scheduleId: String) async {
    }

    // MARK: - Enhanced Refresh with Sync
    func refreshScheduleData() async {
        print("🔄 ScheduleManager: Starting data refresh...")
        isSyncing = true

        await realtimeSyncManager.refreshAllData()

        for idx in scheduleCollections.indices {
            scheduleCollections[idx].scheduleItems = []
        }

        isInitialLoad = false

        lastSyncTime = Date()
        isSyncing = false
        print("🔄 ScheduleManager: Data refresh completed")
    }

    // MARK: - Load Schedule Items

    private func loadAllScheduleItems() async {
        print("ℹ️ ScheduleManager: Skipping loadAllScheduleItems (schedule_items removed)")
    }

    private func loadScheduleItemsForSchedule(_ scheduleId: String, scheduleIndex: Int? = nil) async {
        print("ℹ️ ScheduleManager: Skipping loadScheduleItemsForSchedule (schedule_items removed)")
    }

    // MARK: - Sync Status Observation
    private func setupSyncStatusObservation() {
        realtimeSyncManager.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status.displayName
                self?.isSyncing = status.isActive
            }
            .store(in: &cancellables)
    }

    // MARK: - Fix Real-time Sync Delegate Methods
    func didReceiveRealtimeUpdate(_ data: [String: Any], action: String, table: String) {
        print("🔄 ScheduleManager: Received real-time update for table: \(table), action: \(action)")

        switch (table, action) {
        case ("schedules", "SYNC"):
            if let schedulesData = data["schedules"] as? [DatabaseSchedule] {
                syncSchedulesFromDatabase(schedulesData)
            }
        case ("schedules", "INSERT"):
            if let scheduleData = try? JSONSerialization.data(withJSONObject: data),
               let dbSchedule = try? JSONDecoder().decode(DatabaseSchedule.self, from: scheduleData) {
                handleScheduleInsert(dbSchedule)
            }
        case ("schedules", "UPDATE"):
            if let scheduleData = try? JSONSerialization.data(withJSONObject: data),
               let dbSchedule = try? JSONDecoder().decode(DatabaseSchedule.self, from: scheduleData) {
                handleScheduleUpdate(dbSchedule)
            }
        case ("schedules", "DELETE"):
            if let scheduleId = data["id"] as? String {
                handleScheduleDelete(scheduleId)
            }


        default:
            print("🔄 ScheduleManager: Unhandled real-time update: \(table) - \(action)")
        }
    }

    // MARK: - Database Sync Handlers

    private func syncSchedulesFromDatabase(_ schedules: [DatabaseSchedule]) {
        print("🔄 ScheduleManager: Syncing \(schedules.count) schedules from database")

        let currentUserId = SupabaseService.shared.currentUser?.id.uuidString
        let ownSchedules = schedules.filter { db in
            guard let uid = currentUserId else { return false }
            return db.user_id == uid
        }

        let remoteLocals = ownSchedules.map { $0.toLocal() }
        let remoteIDs = Set(remoteLocals.map { $0.id })

        let localOnly = scheduleCollections.filter { !remoteIDs.contains($0.id) }

        var merged: [ScheduleCollection] = []
        for remote in remoteLocals {
            if let existing = scheduleCollections.first(where: { $0.id == remote.id }) {
                var updated = remote
                updated.scheduleItems = []
                updated.enhancedScheduleItems = existing.enhancedScheduleItems
                updated.academicCalendar = existing.academicCalendar
                merged.append(updated)
            } else {
                var new = remote
                new.scheduleItems = []
                merged.append(new)
            }
        }

        merged.append(contentsOf: localOnly)

        scheduleCollections = merged

        if let active = activeScheduleID, scheduleCollections.contains(where: { $0.id == active }) {
            // keep current active
        } else if let firstActive = scheduleCollections.first(where: { $0.isActive })?.id {
            activeScheduleID = firstActive
        } else {
            activeScheduleID = scheduleCollections.first?.id
        }

        saveSchedulesLocally()

        print("🔄 ScheduleManager: Schedules sync complete. total=\(scheduleCollections.count) active=\(String(describing: activeScheduleID))")
    }

    // MARK: - Real-time Schedule Item Handlers

    private func handleScheduleItemInsert(_ dbScheduleItem: DatabaseScheduleItem) {
        let localScheduleItem = dbScheduleItem.toLocal()

        guard let scheduleId = UUID(uuidString: dbScheduleItem.schedule_id),
              let scheduleIndex = scheduleCollections.firstIndex(where: { $0.id == scheduleId }) else {
            print("🔄 ScheduleManager: Schedule not found for new item: \(dbScheduleItem.schedule_id)")
            return
        }

        // Check if schedule item already exists locally
        if !scheduleCollections[scheduleIndex].scheduleItems.contains(where: { $0.id == localScheduleItem.id }) {
            scheduleCollections[scheduleIndex].scheduleItems.append(localScheduleItem)
            scheduleCollections[scheduleIndex].lastModified = Date()
            saveSchedulesLocally()
            print("🔄 ScheduleManager: Added new schedule item from real-time: \(localScheduleItem.title)")
        }
    }

    private func handleScheduleItemUpdate(_ dbScheduleItem: DatabaseScheduleItem) {
        let localScheduleItem = dbScheduleItem.toLocal()

        guard let scheduleId = UUID(uuidString: dbScheduleItem.schedule_id),
              let scheduleIndex = scheduleCollections.firstIndex(where: { $0.id == scheduleId }),
              let itemIndex = scheduleCollections[scheduleIndex].scheduleItems.firstIndex(where: { $0.id == localScheduleItem.id }) else {
            print("🔄 ScheduleManager: Schedule or item not found for update: \(dbScheduleItem.id)")
            return
        }

        scheduleCollections[scheduleIndex].scheduleItems[itemIndex] = localScheduleItem
        scheduleCollections[scheduleIndex].lastModified = Date()
        saveSchedulesLocally()
        print("🔄 ScheduleManager: Updated schedule item from real-time: \(localScheduleItem.title)")
    }

    private func handleScheduleItemDelete(_ scheduleItemId: String) {
        guard let uuid = UUID(uuidString: scheduleItemId) else { return }

        for scheduleIndex in scheduleCollections.indices {
            if let itemIndex = scheduleCollections[scheduleIndex].scheduleItems.firstIndex(where: { $0.id == uuid }) {
                let removedItem = scheduleCollections[scheduleIndex].scheduleItems.remove(at: itemIndex)
                scheduleCollections[scheduleIndex].lastModified = Date()
                saveSchedulesLocally()
                print("🔄 ScheduleManager: Deleted schedule item from real-time: \(removedItem.title)")
                break
            }
        }
    }

    // MARK: - Schedule CRUD Operations

    private func handleScheduleInsert(_ dbSchedule: DatabaseSchedule) {
        let currentUserId = SupabaseService.shared.currentUser?.id.uuidString
        guard let uid = currentUserId, dbSchedule.user_id == uid else {
            print("🔄 ScheduleManager: Ignoring schedule insert for another user")
            return
        }

        var local = dbSchedule.toLocal()
        local.scheduleItems = []

        if let idx = scheduleCollections.firstIndex(where: { $0.id == local.id }) {
            var updated = local
            updated.scheduleItems = []
            updated.enhancedScheduleItems = scheduleCollections[idx].enhancedScheduleItems
            updated.academicCalendar = scheduleCollections[idx].academicCalendar
            scheduleCollections[idx] = updated
        } else {
            scheduleCollections.append(local)
        }

        if activeScheduleID == nil && local.isActive {
            activeScheduleID = local.id
        }
        saveSchedulesLocally()
        print("🔄 ScheduleManager: Inserted schedule \(local.displayName)")
    }

    private func handleScheduleUpdate(_ dbSchedule: DatabaseSchedule) {
        let currentUserId = SupabaseService.shared.currentUser?.id.uuidString
        guard let uid = currentUserId, dbSchedule.user_id == uid else {
            print("🔄 ScheduleManager: Ignoring schedule update for another user")
            return
        }

        var local = dbSchedule.toLocal()
        local.scheduleItems = []
        if let idx = scheduleCollections.firstIndex(where: { $0.id == local.id }) {
            var updated = local
            updated.scheduleItems = []
            updated.enhancedScheduleItems = scheduleCollections[idx].enhancedScheduleItems
            updated.academicCalendar = scheduleCollections[idx].academicCalendar
            scheduleCollections[idx] = updated

            if updated.isActive {
                activeScheduleID = updated.id
            }
            saveSchedulesLocally()
            print("🔄 ScheduleManager: Updated schedule \(updated.displayName)")
        } else {
            var new = local
            new.scheduleItems = []
            scheduleCollections.append(new)
            if new.isActive {
                activeScheduleID = new.id
            }
            saveSchedulesLocally()
            print("🔄 ScheduleManager: Added schedule from update \(new.displayName)")
        }
    }

    private func handleScheduleDelete(_ scheduleId: String) {
        guard let uuid = UUID(uuidString: scheduleId) else { return }
        let wasActive = (activeScheduleID == uuid)
        scheduleCollections.removeAll { $0.id == uuid }

        if wasActive {
            activeScheduleID = scheduleCollections.first?.id
        }

        saveSchedulesLocally()
        print("🔄 ScheduleManager: Deleted schedule \(scheduleId)")
    }

    // MARK: - Enhanced Schedule Operations with Sync

    func addSchedule(_ schedule: ScheduleCollection) {
        var newSchedule = schedule
        newSchedule.createdDate = Date()
        newSchedule.lastModified = Date()

        scheduleCollections.append(newSchedule)
        saveSchedulesLocally()

        // Only attempt remote sync if authenticated
        if supabaseService.isAuthenticated {
            syncScheduleToDatabase(newSchedule, action: .create)
        } else {
            print("🔒 ScheduleManager: Created schedule locally (offline). Will backfill on sign-in.")
        }
    }

    func updateSchedule(_ schedule: ScheduleCollection) {
        guard let index = scheduleCollections.firstIndex(where: { $0.id == schedule.id }) else { return }
        var updatedSchedule = schedule
        updatedSchedule.lastModified = Date()

        scheduleCollections[index] = updatedSchedule
        saveSchedulesLocally()

        syncScheduleToDatabase(updatedSchedule, action: .update)
    }

    func addScheduleItem(_ item: ScheduleItem, to scheduleID: UUID) {
        // Check authentication first
        guard supabaseService.isAuthenticated else {
            authPromptHandler.promptForSignIn(
                title: "Add Class",
                description: "add your class to the schedule"
            ) { [weak self] in
                self?.addScheduleItem(item, to: scheduleID)
            }
            return
        }

        guard let index = scheduleCollections.firstIndex(where: { $0.id == scheduleID }) else { return }

        scheduleCollections[index].scheduleItems.append(item)
        scheduleCollections[index].lastModified = Date()
        saveSchedulesLocally()

        if let courseManager = courseManager {
            let existingCourse = courseManager.courses.first { $0.id == item.id }
            if existingCourse == nil {
                let course = Course.from(scheduleItem: item, scheduleId: scheduleID)
                courseManager.addCourse(course)
                print("🔄 ScheduleManager: Created course from schedule item: \(item.title)")
            }
        }

        syncScheduleItemToDatabase(item, scheduleId: scheduleID, action: .create)
    }

    func updateScheduleItem(_ item: ScheduleItem, in scheduleID: UUID) {
        guard let scheduleIndex = scheduleCollections.firstIndex(where: { $0.id == scheduleID }),
              let itemIndex = scheduleCollections[scheduleIndex].scheduleItems.firstIndex(where: { $0.id == item.id }) else { return }

        scheduleCollections[scheduleIndex].scheduleItems[itemIndex] = item
        scheduleCollections[scheduleIndex].lastModified = Date()
        saveSchedulesLocally()

        if !isSyncing,
           let courseManager = courseManager,
           let courseIndex = courseManager.courses.firstIndex(where: { $0.id == item.id }) {
            var course = courseManager.courses[courseIndex]
            // Update course with schedule item data
            course.name = item.title
            course.location = item.location
            course.instructor = item.instructor
            course.colorHex = item.color.toHex() ?? course.colorHex

            // Update or create meeting with schedule item data
            if let firstMeeting = course.meetings.first {
                var updatedMeeting = firstMeeting
                updatedMeeting.startTime = item.startTime
                updatedMeeting.endTime = item.endTime
                updatedMeeting.location = item.location
                updatedMeeting.instructor = item.instructor
                updatedMeeting.reminderTime = item.reminderTime
                updatedMeeting.isLiveActivityEnabled = item.isLiveActivityEnabled
                course.updateMeeting(updatedMeeting)
            } else {
                // Create new meeting from schedule item
                let newMeeting = CourseMeeting(
                    courseId: course.id,
                    scheduleId: course.scheduleId,
                    startTime: item.startTime,
                    endTime: item.endTime,
                    daysOfWeek: item.daysOfWeek.map { $0.rawValue },
                    location: item.location,
                    instructor: item.instructor,
                    reminderTime: item.reminderTime,
                    isLiveActivityEnabled: item.isLiveActivityEnabled,
                )
                course.addMeeting(newMeeting)
            }

            // Temporarily set syncing flag to prevent recursive updates
            let wasSyncing = isSyncing
            isSyncing = true

            // Update course asynchronously
            Task {
                do {
                    try await courseManager.updateCourse(course)
                    print("🔄 ScheduleManager: Updated course from schedule item: \(item.title)")
                } catch {
                    print("❌ ScheduleManager: Failed to update course from schedule item: \(error)")
                }
            }

            isSyncing = wasSyncing
        }

        syncScheduleItemToDatabase(item, scheduleId: scheduleID, action: .update)
    }

    func deleteScheduleItem(_ item: ScheduleItem, from scheduleID: UUID) {
        guard let scheduleIndex = scheduleCollections.firstIndex(where: { $0.id == scheduleID }) else { return }

        scheduleCollections[scheduleIndex].scheduleItems.removeAll { $0.id == item.id }
        scheduleCollections[scheduleIndex].lastModified = Date()
        saveSchedulesLocally()

        if let courseManager = courseManager,
           let courseIndex = courseManager.courses.firstIndex(where: { $0.id == item.id }) {
            var course = courseManager.courses[courseIndex]
            // Remove schedule information by clearing meetings
            course.meetings.removeAll()

            // Update course asynchronously
            Task {
                do {
                    try await courseManager.updateCourse(course)
                    print("🔄 ScheduleManager: Removed schedule info from course: \(course.name)")
                } catch {
                    print("❌ ScheduleManager: Failed to remove schedule info from course: \(error)")
                }
            }
        }

        syncScheduleItemToDatabase(item, scheduleId: scheduleID, action: .delete)
    }


    // MARK: - Database Sync Operations

    private func syncScheduleToDatabase(_ schedule: ScheduleCollection, action: SyncAction) {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            print("🔄 ScheduleManager: Cannot sync schedule - user not authenticated")
            return
        }

        var data: [String: Any] = [
            "id": schedule.id.uuidString,
            "user_id": userId,
            "name": schedule.name,
            "semester": schedule.semester,
            "is_active": schedule.isActive,
            "is_archived": schedule.isArchived,
            "is_rotating": (schedule.scheduleType == .rotating),
            "created_date": schedule.createdDate.toISOString(),
            "last_modified": schedule.lastModified.toISOString()
        ]

        if let calendarId = schedule.academicCalendarID?.uuidString {
            data["academic_calendar_id"] = calendarId
        }
        if let startDate = schedule.semesterStartDate?.toDateOnlyString() {
            data["semester_start_date"] = startDate
        }
        if let endDate = schedule.semesterEndDate?.toDateOnlyString() {
            data["semester_end_date"] = endDate
        }

        let operation = SyncOperation(
            type: .schedules,
            action: action,
            data: data
        )

        if action == .create, SupabaseService.shared.isAuthenticated {
            Task { @MainActor in
                do {
                    let repo = ScheduleRepository()
                    let created = try await repo.create(schedule, userId: userId)
                    if let idx = self.scheduleCollections.firstIndex(where: { $0.id == created.id }) {
                        self.scheduleCollections[idx] = created
                    }
                    await CacheSystem.shared.scheduleCache.update(created)
                    print("☁️ ScheduleManager: Created schedule remotely: \(created.displayName)")
                } catch {
                    print("⚠️ ScheduleManager: Direct create failed, enqueueing: \(error)")
                    self.realtimeSyncManager.queueSyncOperation(operation)
                }
            }
        } else {
            realtimeSyncManager.queueSyncOperation(operation)
        }

        Task {
            await CacheSystem.shared.scheduleCache.update(schedule)
        }
    }

    private func syncScheduleItemToDatabase(_ item: ScheduleItem, scheduleId: UUID, action: SyncAction) {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            print("🔄 ScheduleManager: Cannot sync - user not authenticated")
            return
        }

        // NOTE: Schedule items are now managed as part of courses, not as separate entities
        // The sync queue will automatically filter out schedule_items operations
        let operation = SyncOperation(
            type: .scheduleItems,
            action: action,
            data: [
                "id": item.id.uuidString,
                "schedule_id": scheduleId.uuidString,
                "title": item.title,
                "start_time": item.startTime.toTimeString(),
                "end_time": item.endTime.toTimeString(),
                "days_of_week": item.daysOfWeek.map { $0.rawValue },
                "location": item.location,
                "instructor": item.instructor,
                "color_hex": item.color.toHex() ?? "007AFF",
                "reminder_time": item.reminderTime.rawValue,
                "is_live_activity_enabled": item.isLiveActivityEnabled
            ]
        )

        realtimeSyncManager.queueSyncOperation(operation)

        // Update cache asynchronously in a Task
        Task {
            // Note: Schedule items don't have their own cache, they're part of schedules
        }
    }

    // MARK: - Save locally for offline support

    private func saveSchedulesLocally() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(scheduleCollections)
            UserDefaults.standard.set(data, forKey: schedulesKey)

            if let activeID = activeScheduleID {
                UserDefaults.standard.set(activeID.uuidString, forKey: activeScheduleKey)
            }

            print("🔄 ScheduleManager: Saved \(scheduleCollections.count) schedules locally")
        } catch {
            print("🔄 ScheduleManager: Failed to save schedules locally: \(error)")
        }
    }

    var activeSchedule: ScheduleCollection? {
        guard let activeID = activeScheduleID else {
            return nil
        }
        let schedule = scheduleCollections.first { $0.id == activeID && !$0.isArchived }
        return schedule
    }

    var activeSchedules: [ScheduleCollection] {
        return scheduleCollections.filter { !$0.isArchived }
    }

    var archivedSchedules: [ScheduleCollection] {
        return scheduleCollections.filter { $0.isArchived }
    }

    func schedule(for id: UUID) -> ScheduleCollection? {
        return scheduleCollections.first { $0.id == id }
    }

    func getAcademicCalendar(for schedule: ScheduleCollection, from academicCalendarManager: AcademicCalendarManager) -> AcademicCalendar? {
        if let calendarID = schedule.academicCalendarID {
            return academicCalendarManager.calendar(withID: calendarID)
        } else if let legacyCalendar = schedule.academicCalendar {
            return legacyCalendar
        }
        return nil
    }

    func loadSchedules() {
        if let data = UserDefaults.standard.data(forKey: schedulesKey) {
            do {
                let decoder = JSONDecoder()
                scheduleCollections = try decoder.decode([ScheduleCollection].self, from: data)

                // Load active schedule ID
                if let activeIDString = UserDefaults.standard.string(forKey: activeScheduleKey),
                   let activeID = UUID(uuidString: activeIDString) {
                    activeScheduleID = activeID
                }

                // Ensure we have an active schedule
                if activeScheduleID == nil || !scheduleCollections.contains(where: { $0.id == activeScheduleID }) {
                    activeScheduleID = scheduleCollections.first?.id
                }
                print("🔄 ScheduleManager: Loaded \(scheduleCollections.count) schedules from cache")
            } catch {
                setupDefaultSchedule()
            }
        } else {
            setupDefaultSchedule()
        }
    }

    private func setupDefaultSchedule() {
        let defaultSchedule = ScheduleCollection(
            name: "My Schedule",
            semester: getCurrentSemester(),
            color: .blue
        )
        scheduleCollections = [defaultSchedule]
        activeScheduleID = defaultSchedule.id
        saveSchedulesLocally()
    }

    private func getCurrentSemester() -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let year = calendar.component(.year, from: Date())

        if month >= 8 || month <= 1 {
            return "Fall \(year)"
        } else if month >= 2 && month <= 5 {
            return "Spring \(year)"
        } else {
            return "Summer \(year)"
        }
    }

    func archiveSchedule(_ schedule: ScheduleCollection) {
        guard let index = scheduleCollections.firstIndex(where: { $0.id == schedule.id }) else { return }
        scheduleCollections[index].isArchived = true
        scheduleCollections[index].lastModified = Date()

        if activeScheduleID == schedule.id {
            activeScheduleID = activeSchedules.first?.id
        }

        if activeSchedules.isEmpty {
            setupDefaultSchedule()
        } else {
            saveSchedulesLocally()
        }

        syncScheduleToDatabase(scheduleCollections[index], action: .update)
    }

    func unarchiveSchedule(_ schedule: ScheduleCollection) {
        guard let index = scheduleCollections.firstIndex(where: { $0.id == schedule.id }) else { return }
        scheduleCollections[index].isArchived = false
        scheduleCollections[index].lastModified = Date()
        saveSchedulesLocally()

        syncScheduleToDatabase(scheduleCollections[index], action: .update)
    }

    func deleteSchedule(_ schedule: ScheduleCollection) {
        syncScheduleToDatabase(schedule, action: .delete)

        scheduleCollections.removeAll { $0.id == schedule.id }

        if activeScheduleID == schedule.id {
            activeScheduleID = activeSchedules.first?.id
        }

        if activeSchedules.isEmpty {
            setupDefaultSchedule()
        } else {
            saveSchedulesLocally()
        }
    }

    func setActiveSchedule(_ scheduleID: UUID) {
        activeScheduleID = scheduleID
        var changed = false
        for idx in scheduleCollections.indices {
            let shouldBeActive = (scheduleCollections[idx].id == scheduleID)
            if scheduleCollections[idx].isActive != shouldBeActive {
                scheduleCollections[idx].isActive = shouldBeActive
                scheduleCollections[idx].lastModified = Date()
                changed = true
                syncScheduleToDatabase(scheduleCollections[idx], action: .update)
            }
        }
        if changed { saveSchedulesLocally() }

        if supabaseService.isAuthenticated, let userId = supabaseService.currentUser?.id.uuidString {
            Task {
                do {
                    let repo = ScheduleRepository()
                    try await repo.setActive(scheduleId: scheduleID.uuidString, userId: userId)
                    print("☁️ ScheduleManager: Server active schedule set to \(scheduleID)")
                } catch {
                    print("⚠️ ScheduleManager: Failed to set active on server: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Course-Schedule Synchronization

    func setCourseManager(_ courseManager: UnifiedCourseManager) {
        // Skip if already set to the same instance to prevent redundant work on tab switches
        guard self.courseManager !== courseManager else {
            return
        }

        self.courseManager = courseManager

        // The course manager should be the primary source of truth for course data
        // Schedule items will be generated on-demand from course meetings

        print("🔄 ScheduleManager: Course manager reference set (sync disabled to prevent conflicts)")
    }

    private func syncCoursesWithScheduleItems() {
        // DISABLED: This was causing duplication and conflicts
        print("🔄 ScheduleManager: Course sync disabled to prevent conflicts")
    }

    private func syncScheduleItemsWithCourses(_ courses: [Course]) {
        // DISABLED: This was causing circular updates
        print("🔄 ScheduleManager: Schedule item sync disabled to prevent conflicts")
    }

    // MARK: - Cache Reload

    private func reloadFromCache() async {
        print("🔄 ScheduleManager: Reloading data from cache")

        let cachedSchedules = await CacheSystem.shared.scheduleCache.retrieve()
        if !cachedSchedules.isEmpty {
            scheduleCollections = cachedSchedules.map { var s = $0; s.scheduleItems = []; return s }

            if let activeSchedule = scheduleCollections.first(where: { $0.isActive }) {
                activeScheduleID = activeSchedule.id
            } else {
                activeScheduleID = scheduleCollections.first?.id
            }

            saveSchedulesLocally()
            lastSyncTime = Date()

            print("🔄 ScheduleManager: Reloaded \(scheduleCollections.count) schedules from cache")
        }
    }

    private func backfillUnsyncedSchedules() async {
        guard supabaseService.isAuthenticated,
              let userId = supabaseService.currentUser?.id.uuidString else {
            return
        }

        let repo = ScheduleRepository()

        for schedule in scheduleCollections {
            do {
                let remote = try await repo.read(id: schedule.id.uuidString)
                if remote == nil {
                    print("☁️ Backfill: Creating schedule remotely: \(schedule.displayName)")
                    let created = try await repo.create(schedule, userId: userId)

                    if let idx = scheduleCollections.firstIndex(where: { $0.id == created.id }) {
                        scheduleCollections[idx] = created
                    }
                    await CacheSystem.shared.scheduleCache.update(created)
                }
            } catch {
                print("⚠️ Backfill: Failed to backfill schedule \(schedule.displayName): \(error.localizedDescription)")
            }
        }
    }
}
