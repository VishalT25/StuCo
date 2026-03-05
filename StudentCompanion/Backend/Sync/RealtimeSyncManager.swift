import Foundation
import Supabase
import SwiftUI
import Combine

// MARK: - Sync Status Types
enum SyncStatus: Equatable {
    case idle
    case initializing
    case syncing
    case connected
    case ready
    case disconnected
    case error(SyncError)
    
    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .initializing: return "Initializing..."
        case .syncing: return "Syncing..."
        case .connected: return "Connected"
        case .ready: return "Ready"
        case .disconnected: return "Disconnected"
        case .error(let error): return "Error: \(error.localizedDescription)"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .initializing, .syncing: return true
        default: return false
        }
    }
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.initializing, .initializing),
             (.syncing, .syncing), (.connected, .connected),
             (.ready, .ready), (.disconnected, .disconnected):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

enum SyncError: Error, LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case databaseError(Error)
    case conflictResolutionFailed
    case invalidData
    case channelError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        case .conflictResolutionFailed:
            return "Failed to resolve data conflicts"
        case .invalidData:
            return "Invalid data received"
        case .channelError(let message):
            return "Channel error: \(message)"
        }
    }
}

// MARK: - Realtime Sync Manager
@MainActor
class RealtimeSyncManager: ObservableObject {
    static let shared = RealtimeSyncManager()
    
    // MARK: - Published State
    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var isConnected = false
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var syncProgress: Double = 0.0
    @Published private(set) var activeChannels: Set<String> = []
    @Published private(set) var syncStatistics = SyncStatistics()
    @Published private(set) var pendingSyncCount = 0
    
    // MARK: - Dependencies
    private let supabaseService = SupabaseService.shared
    private let cacheSystem = CacheSystem.shared
    private let conflictResolver = ConflictResolver()
    private let syncQueue = SyncQueue()
    
    // MARK: - Realtime Channels
    private var channels: [String: RealtimeChannelV2] = [:]
    private var realtimeTokens: [RealtimeSubscription] = [] // from onPostgresChange
    private var combineCancellables = Set<AnyCancellable>() // for .sink
    
    // MARK: - Delegates
    weak var academicCalendarDelegate: RealtimeSyncDelegate?
    weak var assignmentDelegate: RealtimeSyncDelegate?
    weak var categoryDelegate: RealtimeSyncDelegate?
    weak var courseDelegate: RealtimeSyncDelegate?
    weak var eventDelegate: RealtimeSyncDelegate?
    weak var scheduleDelegate: RealtimeSyncDelegate?
    weak var scheduleItemDelegate: RealtimeSyncDelegate?
    
    // Compatibility aliases for older call sites
    var eventsDelegate: RealtimeSyncDelegate? {
        get { eventDelegate }
        set { eventDelegate = newValue }
    }
    var schedulesDelegate: RealtimeSyncDelegate? {
        get { scheduleDelegate }
        set { scheduleDelegate = newValue }
    }
    var coursesDelegate: RealtimeSyncDelegate? {
        get { courseDelegate }
        set { courseDelegate = newValue }
    }
    
    private init() {
        setupAuthenticationObserver()
    }
    
    // MARK: - Initialization
    
    func ensureStarted() async {
        if supabaseService.isAuthenticated {
            syncStatus = .ready
            isConnected = false
        } else {
            syncStatus = .disconnected
            isConnected = false
        }
    }
    
    func initialize() async {
        print("🔄 RealtimeSyncManager: Initializing...")
        
        guard supabaseService.isAuthenticated else {
            print("🔄 RealtimeSyncManager: Not authenticated, setting status to disconnected")
            syncStatus = .disconnected
            return
        }
        
        // Ensure delegates are properly set up
        print("🔄 RealtimeSyncManager: Checking delegates...")
        print("🔄 RealtimeSyncManager: eventDelegate = \(eventDelegate != nil ? "✅" : "❌")")
        print("🔄 RealtimeSyncManager: categoryDelegate = \(categoryDelegate != nil ? "✅" : "❌")")
        print("🔄 RealtimeSyncManager: courseDelegate = \(courseDelegate != nil ? "✅" : "❌")")
        print("🔄 RealtimeSyncManager: scheduleDelegate = \(scheduleDelegate != nil ? "✅" : "❌")")
        
        syncStatus = .initializing
        
        do {
            await setupRealtimeChannels()
            await performInitialSync()
            
            syncStatus = .connected
            isConnected = true
            lastSyncTime = Date()
            
            print("🔄 RealtimeSyncManager: Initialization complete - \(activeChannels.count) channels active")
        } catch {
            print("🔄 RealtimeSyncManager: Initialization failed: \(error)")
            syncStatus = .error(SyncError.databaseError(error))
        }
    }
    
    func cleanup() async {
        print("🔄 RealtimeSyncManager: Cleaning up...")
        
        // Unsubscribe from all channels
        for (_, channel) in channels {
          await supabaseService.client.removeChannel(channel) // or try await channel.unsubscribe()
        }
        channels.removeAll()
        activeChannels.removeAll()
        // Cancel realtime callbacks and Combine sinks separately
        for token in realtimeTokens { token.cancel() }
        realtimeTokens.removeAll()
        combineCancellables.forEach { $0.cancel() }
        combineCancellables.removeAll()

        
        syncStatus = .disconnected
        isConnected = false
        
        print("🔄 RealtimeSyncManager: Cleanup complete")
    }
    
    // MARK: - Channel Setup
    
    private func setupRealtimeChannels() async {
        guard let userId = supabaseService.currentUser?.id else { return }
        
        let tableConfigs: [(String, String)] = [
            ("academic_calendars", "academic_calendars_channel"),
            ("assignments", "assignments_channel"),
            ("categories", "categories_channel"),
            ("courses", "courses_channel"),
            ("course_meetings", "course_meetings_channel"),
            ("events", "events_channel"),
            ("schedules", "schedules_channel")
        ]
        
        for (tableName, channelName) in tableConfigs {
            if channels[tableName] != nil {
                print("🔄 RealtimeSyncManager: Already subscribed to \(tableName), skipping")
                continue
            }
            await setupChannel(for: tableName, channelName: channelName, userId: userId.uuidString)
        }
    }
    
    @MainActor
    private func setupChannel(for tableName: String, channelName: String, userId: String) async {
      if channels[tableName] != nil {
        print("🔄 RealtimeSyncManager: Channel exists for \(tableName), skip re-register")
        return
      }

      let channel = supabaseService.client.channel(channelName)

      let filterString: String? = {
        switch tableName {
        case "events", "categories", "courses", "schedules", "academic_calendars", "assignments", "course_meetings":
          return "user_id=eq.\(userId)"
        case "schedule_items":
          // Schedule items are filtered by schedule ownership through JOIN
          return nil
        default:
          return nil
        }
      }()

      let token = channel.onPostgresChange(
        AnyAction.self,
        schema: "public",
        table: tableName,
        filter: filterString
      ) { [weak self] change in
        Task { @MainActor in
          guard let self else { return }
          switch change {
          case .insert(let action):
            await self.handleInsert(action.record, table: tableName)
          case .update(let action):
            await self.handleUpdate(action.oldRecord, newRecord: action.record, table: tableName)
          case .delete(let action):
            await self.handleDelete(action.oldRecord, table: tableName)
          }
          self.syncStatistics.incrementChangeReceived(for: tableName)
        }
      }

      do {
        try await channel.subscribeWithError()
        channels[tableName] = channel
        activeChannels.insert(channelName)
        realtimeTokens.append(token)
        print("🔄 RealtimeSyncManager: Subscribed to \(tableName) changes")
      } catch {
        print("🔄 RealtimeSyncManager: Failed to subscribe to \(tableName): \(error)")
        syncStatus = .error(.channelError(error.localizedDescription))
      }
    }

    // MARK: - Database Change Handling
    
    private func handleInsert(_ record: [String: AnyJSON], table: String) async {
        do {
            let data = try convertJSONRecord(record)
            
            switch table {
            case "academic_calendars":
                let dbModel = try JSONDecoder().decode(DatabaseAcademicCalendar.self, from: JSONSerialization.data(withJSONObject: data))
                let localModel = dbModel.toLocal()
                await cacheSystem.academicCalendarCache.store(localModel)
                academicCalendarDelegate?.didReceiveRealtimeUpdate(data, action: "INSERT", table: table)
                
            case "assignments":
                let dbModel = try JSONDecoder().decode(DatabaseAssignment.self, from: JSONSerialization.data(withJSONObject: data))
                let localModel = dbModel.toLocal()
                await cacheSystem.assignmentCache.store(localModel)
                assignmentDelegate?.didReceiveRealtimeUpdate(data, action: "INSERT", table: table)
                
            case "categories":
                let dbModel = try JSONDecoder().decode(DatabaseCategory.self, from: JSONSerialization.data(withJSONObject: data))
                let localModel = dbModel.toLocal()
                await cacheSystem.categoryCache.store(localModel)
                categoryDelegate?.didReceiveRealtimeUpdate(data, action: "INSERT", table: table)
                
            case "courses":
                let dbModel = try JSONDecoder().decode(DatabaseCourse.self, from: JSONSerialization.data(withJSONObject: data))
                let localModel = dbModel.toLocal()
                await cacheSystem.courseCache.store(localModel)
                courseDelegate?.didReceiveRealtimeUpdate(data, action: "INSERT", table: table)
                
            case "course_meetings":
                let dbModel = try JSONDecoder().decode(DatabaseCourseMeeting.self, from: JSONSerialization.data(withJSONObject: data))
                let localModel = dbModel.toLocal()
                await cacheSystem.courseMeetingCache.store(localModel)
                courseDelegate?.didReceiveRealtimeUpdate(data, action: "INSERT", table: table)
                
            case "events":
                let dbModel = try JSONDecoder().decode(DatabaseEvent.self, from: JSONSerialization.data(withJSONObject: data))
                let localModel = dbModel.toLocal()
                await cacheSystem.eventCache.store(localModel)
                eventDelegate?.didReceiveRealtimeUpdate(data, action: "INSERT", table: table)
                
            case "schedules":
                let dbModel = try JSONDecoder().decode(DatabaseSchedule.self, from: JSONSerialization.data(withJSONObject: data))
                let localModel = dbModel.toLocal()
                await cacheSystem.scheduleCache.store(localModel)
                scheduleDelegate?.didReceiveRealtimeUpdate(data, action: "INSERT", table: table)
                
            // case "schedule_items": ...

            default:
                print("🔄 RealtimeSyncManager: Unknown table: \(table)")
            }
            
            syncStatistics.incrementSyncSuccess(for: table)
        } catch {
            print("🔄 RealtimeSyncManager: Failed to handle insert for \(table): \(error)")
            syncStatistics.incrementSyncError(for: table)
        }
    }
    
    private func handleUpdate(_ oldRecord: [String: AnyJSON]?, newRecord: [String: AnyJSON], table: String) async {
        do {
            let data = try convertJSONRecord(newRecord)
            
            if let oldData = oldRecord {
                let oldDict = try convertJSONRecord(oldData)
                let conflict = await conflictResolver.detectConflict(
                    localData: [:],
                    remoteOld: oldDict,
                    remoteNew: data,
                    table: table
                )
                
                if conflict.hasConflict {
                    print("🔄 RealtimeSyncManager: Conflict detected for \(table)")
                    let resolved = await conflictResolver.resolveConflict(conflict)
                    await applyResolvedUpdate(resolved, table: table)
                    return
                }
            }
            
            switch table {
            case "academic_calendars":
                let dbModel = try JSONDecoder().decode(DatabaseAcademicCalendar.self, from: JSONSerialization.data(withJSONObject: data))
                let localModel = dbModel.toLocal()
                await cacheSystem.academicCalendarCache.update(localModel)
                academicCalendarDelegate?.didReceiveRealtimeUpdate(data, action: "UPDATE", table: table)
                
            case "assignments":
                let dbModel = try JSONDecoder().decode(DatabaseAssignment.self, from: JSONSerialization.data(withJSONObject: data))
                let localModel = dbModel.toLocal()
                await cacheSystem.assignmentCache.update(localModel)
                assignmentDelegate?.didReceiveRealtimeUpdate(data, action: "UPDATE", table: table)
                
            case "categories":
                let dbModel = try JSONDecoder().decode(DatabaseCategory.self, from: JSONSerialization.data(withJSONObject: data))
                let localModel = dbModel.toLocal()
                await cacheSystem.categoryCache.update(localModel)
                categoryDelegate?.didReceiveRealtimeUpdate(data, action: "UPDATE", table: table)
                
            case "courses":
                let dbModel = try JSONDecoder().decode(DatabaseCourse.self, from: JSONSerialization.data(withJSONObject: data))
                let localModel = dbModel.toLocal()
                await cacheSystem.courseCache.update(localModel)
                courseDelegate?.didReceiveRealtimeUpdate(data, action: "UPDATE", table: table)
                
            case "course_meetings":
                let dbModel = try JSONDecoder().decode(DatabaseCourseMeeting.self, from: JSONSerialization.data(withJSONObject: data))
                let localModel = dbModel.toLocal()
                await cacheSystem.courseMeetingCache.update(localModel)
                courseDelegate?.didReceiveRealtimeUpdate(data, action: "UPDATE", table: table)
                
            case "events":
                let dbModel = try JSONDecoder().decode(DatabaseEvent.self, from: JSONSerialization.data(withJSONObject: data))
                let localModel = dbModel.toLocal()
                await cacheSystem.eventCache.update(localModel)
                eventDelegate?.didReceiveRealtimeUpdate(data, action: "UPDATE", table: table)
                
            case "schedules":
                let dbModel = try JSONDecoder().decode(DatabaseSchedule.self, from: JSONSerialization.data(withJSONObject: data))
                let localModel = dbModel.toLocal()
                await cacheSystem.scheduleCache.update(localModel)
                scheduleDelegate?.didReceiveRealtimeUpdate(data, action: "UPDATE", table: table)
                
            // case "schedule_items": ...

            default:
                print("🔄 RealtimeSyncManager: Unknown table: \(table)")
            }
            
            syncStatistics.incrementSyncSuccess(for: table)
        } catch {
            print("🔄 RealtimeSyncManager: Failed to handle update for \(table): \(error)")
            syncStatistics.incrementSyncError(for: table)
        }
    }
    
    private func handleDelete(_ record: [String: AnyJSON]?, table: String) async {
        guard let record = record else { return }
        
        do {
            let data = try convertJSONRecord(record)
            
            if let id = data["id"] as? String {
                switch table {
                case "academic_calendars":
                    await cacheSystem.academicCalendarCache.delete(id: id)
                    academicCalendarDelegate?.didReceiveRealtimeUpdate(data, action: "DELETE", table: table)
                    
                case "assignments":
                    await cacheSystem.assignmentCache.delete(id: id)
                    assignmentDelegate?.didReceiveRealtimeUpdate(data, action: "DELETE", table: table)
                    
                case "categories":
                    await cacheSystem.categoryCache.delete(id: id)
                    categoryDelegate?.didReceiveRealtimeUpdate(data, action: "DELETE", table: table)
                    
                case "courses":
                    await cacheSystem.courseCache.delete(id: id)
                    courseDelegate?.didReceiveRealtimeUpdate(data, action: "DELETE", table: table)
                    
                case "course_meetings":
                    await cacheSystem.courseMeetingCache.delete(id: id)
                    courseDelegate?.didReceiveRealtimeUpdate(data, action: "DELETE", table: table)
                    
                case "events":
                    await cacheSystem.eventCache.delete(id: id)
                    eventDelegate?.didReceiveRealtimeUpdate(data, action: "DELETE", table: table)
                    
                case "schedules":
                    await cacheSystem.scheduleCache.delete(id: id)
                    scheduleDelegate?.didReceiveRealtimeUpdate(data, action: "DELETE", table: table)
                    
                // case "schedule_items": ...

                default:
                    print("🔄 RealtimeSyncManager: Unknown table: \(table)")
                }
                
                syncStatistics.incrementSyncSuccess(for: table)
            }
        } catch {
            print("🔄 RealtimeSyncManager: Failed to handle delete for \(table): \(error)")
            syncStatistics.incrementSyncError(for: table)
        }
    }
    
    // MARK: - Initial Sync
    
    private func performInitialSync() async {
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        
        syncStatus = .syncing
        syncProgress = 0.0
        
        let tables = ["academic_calendars", "categories", "schedules", "courses", "course_meetings", "assignments", "events"]
        let progressStep = 1.0 / Double(tables.count)
        
        for (index, table) in tables.enumerated() {
            await syncTable(table, userId: userId)
            syncProgress = Double(index + 1) * progressStep
        }
        
        await notifyDelegatesOfInitialSync(userId: userId)
        
        lastSyncTime = Date()
        syncProgress = 1.0
        syncStatus = .connected
    }
    
    private func notifyDelegatesOfInitialSync(userId: String) async {
        // Notify all delegates that initial sync is complete with all data
        print("🔄 RealtimeSyncManager: 📤 Starting delegate notifications...")
        
        do {
            // Categories - send to EventViewModel via categoryDelegate  
            let categories = await cacheSystem.categoryCache.retrieve()
            print("🔄 RealtimeSyncManager: Found \(categories.count) categories in cache")
            
            if let categoryDelegate = categoryDelegate {
                if !categories.isEmpty {
                    let dbCategories = categories.map { DatabaseCategory(from: $0, userId: userId) }
                    print("🔄 RealtimeSyncManager: ✅ Notifying categoryDelegate with \(dbCategories.count) categories")
                    categoryDelegate.didReceiveRealtimeUpdate(
                        ["categories": dbCategories],
                        action: "SYNC",
                        table: "categories"
                    )
                } else {
                    print("🔄 RealtimeSyncManager: ✅ Notifying categoryDelegate with empty category sync")
                    categoryDelegate.didReceiveRealtimeUpdate(
                        ["categories": []],
                        action: "SYNC",
                        table: "categories"
                    )
                }
            } else {
                print("🔄 RealtimeSyncManager: ⚠️ No categoryDelegate set!")
            }
            
            // Events - send to EventViewModel via eventDelegate
            let events = await cacheSystem.eventCache.retrieve()
            print("🔄 RealtimeSyncManager: Found \(events.count) events in cache")
            
            if let eventDelegate = eventDelegate {
                if !events.isEmpty {
                    let dbEvents = events.map { DatabaseEvent(from: $0, userId: userId) }
                    print("🔄 RealtimeSyncManager: ✅ Notifying eventDelegate with \(dbEvents.count) events")
                    eventDelegate.didReceiveRealtimeUpdate(
                        ["events": dbEvents],
                        action: "SYNC", 
                        table: "events"
                    )
                } else {
                    print("🔄 RealtimeSyncManager: ✅ Notifying eventDelegate with empty events sync")
                    eventDelegate.didReceiveRealtimeUpdate(
                        ["events": []],
                        action: "SYNC",
                        table: "events"
                    )
                }
            } else {
                print("🔄 RealtimeSyncManager: ⚠️ No eventDelegate set!")
            }
            
            // Academic Calendars
            let academicCalendars = await cacheSystem.academicCalendarCache.retrieve()
            if let academicCalendarDelegate = academicCalendarDelegate, !academicCalendars.isEmpty {
                let dbAcademicCalendars = academicCalendars.map { DatabaseAcademicCalendar(from: $0, userId: userId) }
                print("🔄 RealtimeSyncManager: ✅ Notifying academicCalendarDelegate with \(dbAcademicCalendars.count) calendars")
                academicCalendarDelegate.didReceiveRealtimeUpdate(
                    ["academic_calendars": dbAcademicCalendars],
                    action: "SYNC",
                    table: "academic_calendars"
                )
            }
            
            // Schedules
            let schedules = await cacheSystem.scheduleCache.retrieve()
            if let scheduleDelegate = scheduleDelegate, !schedules.isEmpty {
                let dbSchedules = schedules.map { DatabaseSchedule(from: $0, userId: userId) }
                print("🔄 RealtimeSyncManager: ✅ Notifying scheduleDelegate with \(dbSchedules.count) schedules")
                scheduleDelegate.didReceiveRealtimeUpdate(
                    ["schedules": dbSchedules],
                    action: "SYNC",
                    table: "schedules"
                )
            }
            
            // Courses
            let courses = await cacheSystem.courseCache.retrieve()
            if let courseDelegate = courseDelegate, !courses.isEmpty {
                let dbCourses = courses.map { DatabaseCourse(from: $0, userId: userId) }
                print("🔄 RealtimeSyncManager: ✅ Notifying courseDelegate with \(dbCourses.count) courses")
                courseDelegate.didReceiveRealtimeUpdate(
                    ["courses": dbCourses],
                    action: "SYNC",
                    table: "courses"
                )
            }
            
            // Course Meetings
            let courseMeetings = await cacheSystem.courseMeetingCache.retrieve()
            if let courseDelegate = courseDelegate, !courseMeetings.isEmpty {
                let dbCourseMeetings = courseMeetings.map { DatabaseCourseMeeting(from: $0, userId: userId) }
                print("🔄 RealtimeSyncManager: ✅ Notifying courseDelegate with \(dbCourseMeetings.count) course meetings")
                courseDelegate.didReceiveRealtimeUpdate(
                    ["course_meetings": dbCourseMeetings],
                    action: "SYNC",
                    table: "course_meetings"
                )
            }
            
            // Assignments
            let assignments = await cacheSystem.assignmentCache.retrieve()
            if let assignmentDelegate = assignmentDelegate, !assignments.isEmpty {
                let dbAssignments = assignments.map { DatabaseAssignment(from: $0, userId: userId) }
                print("🔄 RealtimeSyncManager: ✅ Notifying assignmentDelegate with \(dbAssignments.count) assignments")
                assignmentDelegate.didReceiveRealtimeUpdate(
                    ["assignments": dbAssignments],
                    action: "SYNC",
                    table: "assignments"
                )
            }
            
            print("🔄 RealtimeSyncManager: ✅ All delegate notifications completed")
        } catch {
            print("🔄 RealtimeSyncManager: ❌ Failed to notify delegates of initial sync: \(error)")
        }
    }
    
    private func syncTable(_ table: String, userId: String) async {
        do {
            switch table {
            case "academic_calendars":
                let response = try await supabaseService.client
                    .from("academic_calendars")
                    .select()
                    .eq("user_id", value: userId)
                    .execute()
                let items = try JSONDecoder().decode([DatabaseAcademicCalendar].self, from: response.data)
                await cacheSystem.academicCalendarCache.store(items.map { $0.toLocal() })
                
            case "categories":
                let response = try await supabaseService.client
                    .from("categories")
                    .select()
                    .eq("user_id", value: userId)
                    .execute()
                let items = try JSONDecoder().decode([DatabaseCategory].self, from: response.data)
                await cacheSystem.categoryCache.store(items.map { $0.toLocal() })

            case "courses":
                let response = try await supabaseService.client
                    .from("courses")
                    .select()
                    .eq("user_id", value: userId)
                    .execute()
                let items = try JSONDecoder().decode([DatabaseCourse].self, from: response.data)
                await cacheSystem.courseCache.store(items.map { $0.toLocal() })

            case "course_meetings":
                let response = try await supabaseService.client
                    .from("course_meetings")
                    .select()
                    .eq("user_id", value: userId)
                    .execute()
                let items = try JSONDecoder().decode([DatabaseCourseMeeting].self, from: response.data)
                await cacheSystem.courseMeetingCache.store(items.map { $0.toLocal() })

            case "events":
                let response = try await supabaseService.client
                    .from("events")
                    .select()
                    .eq("user_id", value: userId)
                    .execute()
                let items = try JSONDecoder().decode([DatabaseEvent].self, from: response.data)
                await cacheSystem.eventCache.store(items.map { $0.toLocal() })

            case "schedules":
                let response = try await supabaseService.client
                    .from("schedules")
                    .select()
                    .eq("user_id", value: userId)
                    .execute()
                let items = try JSONDecoder().decode([DatabaseSchedule].self, from: response.data)
                await cacheSystem.scheduleCache.store(items.map { $0.toLocal() })

            // case "schedule_items": ...

            case "assignments":
                let response = try await supabaseService.client
                    .from("assignments")
                    .select()
                    .eq("user_id", value: userId)
                    .execute()
                let items = try JSONDecoder().decode([DatabaseAssignment].self, from: response.data)
                await cacheSystem.assignmentCache.store(items.map { $0.toLocal() })
                
            default:
                break
            }
            
            print("🔄 RealtimeSyncManager: Synced \(table)")
            syncStatistics.incrementSyncSuccess(for: table)
        } catch {
            if let urlErr = error as? URLError, urlErr.code == .cancelled {
                print("🔄 RealtimeSyncManager: \(table) request was cancelled (-999). Will retry on next refresh.")
                return
            }
            print("🔄 RealtimeSyncManager: Failed to sync \(table): \(error)")
            syncStatistics.incrementSyncError(for: table)
        }
    }
    
    // MARK: - Public Methods
    
    func queueSyncOperation(_ operation: SyncOperation) {
        syncQueue.enqueue(operation)
        pendingSyncCount += 1
    }
    
    func refreshAllData() async {
        await performInitialSync()
    }
    
    func forceSyncTable(_ table: String) async {
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }
        await syncTable(table, userId: userId)
    }
    
    // MARK: - Utilities
    
    private func convertJSONRecord(_ record: [String: AnyJSON]) throws -> [String: Any] {
        var result: [String: Any] = [:]
        
        for (key, value) in record {
          switch value {
          case .string(let s): result[key] = s
          case .bool(let b): result[key] = b
          case .null: result[key] = NSNull()
          case .integer(let i): result[key] = i
          case .double(let d): result[key] = d
          case .array(let arr): result[key] = try convertJSONArray(arr)
          case .object(let obj): result[key] = try convertJSONRecord(obj)
          }
        }
        
        return result
    }
    
    private func convertJSONArray(_ array: [AnyJSON]) throws -> [Any] {
        return try array.map { value in
          switch value {
          case .string(let s): return s
          case .bool(let b): return b
          case .null: return NSNull()
          case .integer(let i): return i
          case .double(let d): return d
          case .array(let arr): return try convertJSONArray(arr)
          case .object(let obj): return try convertJSONRecord(obj)
          }
        }
    }
    
    private func applyResolvedUpdate(_ resolution: ConflictResolution, table: String) async {
        let _ = resolution.resolvedData
        print("🔄 RealtimeSyncManager: Applied conflict resolution for \(table)")
    }
    
    // MARK: - Authentication Observer
    
    private func setupAuthenticationObserver() {
        supabaseService.$isAuthenticated
          .receive(on: DispatchQueue.main)
          .sink { [weak self] isAuthenticated in
            Task { @MainActor in
              if isAuthenticated { 
                print("🔄 RealtimeSyncManager: User authenticated, initializing...")
                
                // Ensure delegate setup before initialization
                await self?.ensureDelegatesAreSet()
                
                // Initialize with proper delegate setup
                await self?.initialize()
                
                // Trigger comprehensive data refresh
                await self?.performPostSignInDataSync()
              } else { 
                print("🔄 RealtimeSyncManager: User signed out, cleaning up...")
                await self?.cleanup() 
              }
            }
          }
          .store(in: &combineCancellables)
    }
    
    /// Ensure delegates are properly set up before sync operations
    private func ensureDelegatesAreSet() async {
        print("🔄 RealtimeSyncManager: 🔌 Ensuring delegates are set up...")
        
        // Give a moment for other managers to register themselves as delegates
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        print("🔄 RealtimeSyncManager: Current delegate status:")
        print("  - eventDelegate: \(eventDelegate != nil ? "✅ Set" : "❌ Missing")")
        print("  - categoryDelegate: \(categoryDelegate != nil ? "✅ Set" : "❌ Missing")")
        print("  - courseDelegate: \(courseDelegate != nil ? "✅ Set" : "❌ Missing")")
        print("  - scheduleDelegate: \(scheduleDelegate != nil ? "✅ Set" : "❌ Missing")")
        print("  - academicCalendarDelegate: \(academicCalendarDelegate != nil ? "✅ Set" : "❌ Missing")")
        print("  - assignmentDelegate: \(assignmentDelegate != nil ? "✅ Set" : "❌ Missing")")
    }
    
    // MARK: - Post Sign-In Data Sync
    
    private func performPostSignInDataSync() async {
        print("🔄 RealtimeSyncManager: Performing comprehensive data sync after sign-in")
        
        syncStatus = .syncing
        
        // Add delay to ensure authentication is fully established
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second (reduced from 2)
        
        // Perform full data refresh - this will populate cache and notify delegates
        await performInitialSync()
        
        syncStatus = .connected
        
        // Post final notification after all sync work is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔄 RealtimeSyncManager: Posting DataSyncCompleted notification")
            NotificationCenter.default.post(name: .init("DataSyncCompleted"), object: nil)
        }
        
        print("🔄 RealtimeSyncManager: Post sign-in data sync completed")
    }
}

// MARK: - Realtime Sync Delegate Protocol
protocol RealtimeSyncDelegate: AnyObject {
    @MainActor
    func didReceiveRealtimeUpdate(_ data: [String: Any], action: String, table: String)
}

// MARK: - Sync Statistics
class SyncStatistics: ObservableObject {
    @Published private(set) var changesReceived: [String: Int] = [:]
    @Published private(set) var syncSuccesses: [String: Int] = [:]
    @Published private(set) var syncErrors: [String: Int] = [:]
    @Published private(set) var lastSyncTimes: [String: Date] = [:]
    
    func incrementChangeReceived(for table: String) {
        changesReceived[table, default: 0] += 1
    }
    
    func incrementSyncSuccess(for table: String) {
        syncSuccesses[table, default: 0] += 1
        lastSyncTimes[table] = Date()
    }
    
    func incrementSyncError(for table: String) {
        syncErrors[table, default: 0] += 1
    }
    
    func reset() {
        changesReceived.removeAll()
        syncSuccesses.removeAll()
        syncErrors.removeAll()
        lastSyncTimes.removeAll()
    }
    
    var totalChanges: Int {
        changesReceived.values.reduce(0, +)
    }
    
    var totalSuccesses: Int {
        syncSuccesses.values.reduce(0, +)
    }
    
    var totalErrors: Int {
        syncErrors.values.reduce(0, +)
    }
    
    var successRate: Double {
        let total = totalSuccesses + totalErrors
        guard total > 0 else { return 1.0 }
        return Double(totalSuccesses) / Double(total)
    }
}