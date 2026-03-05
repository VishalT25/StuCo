import Foundation
import SwiftUI

// MARK: - Data Migration Manager
@MainActor
class DataMigrationManager: ObservableObject {
    
    // MARK: - Published State
    @Published private(set) var migrationStatus: MigrationStatus = .notStarted
    @Published private(set) var migrationProgress: Double = 0.0
    @Published private(set) var currentMigrationStep: String = ""
    @Published private(set) var migrationLog: [MigrationLogEntry] = []
    @Published private(set) var lastMigrationDate: Date?
    
    // MARK: - Dependencies
    private let supabaseService = SupabaseService.shared
    private let cacheSystem = CacheSystem.shared
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Migration Configuration
    private let currentVersion = "2.0.0"
    private let migrationKey = "data_migration_version"
    private let legacyDataKeys = [
        "savedScheduleCollections",
        "activeScheduleID", 
        "savedCourses",
        "savedEvents",
        "savedCategories",
        "savedAssignments"
    ]
    
    init() {
        loadMigrationHistory()
    }
    
    // MARK: - Migration Check & Execution
    
    func checkAndPerformMigrationIfNeeded() async {
        let lastMigratedVersion = userDefaults.string(forKey: migrationKey)
        
        if lastMigratedVersion == nil {
            // First time user or legacy user - check for legacy data
            if hasLegacyData() {
                await performMigration(from: "1.0.0", to: currentVersion)
            } else {
                // Mark as migrated for new users
                markMigrationComplete()
            }
        } else if let lastVersion = lastMigratedVersion, lastVersion != currentVersion {
            // Incremental migration needed
            await performMigration(from: lastVersion, to: currentVersion)
        }
    }
    
    func forceMigration() async {
        await performMigration(from: "1.0.0", to: currentVersion)
    }
    
    private func performMigration(from fromVersion: String, to toVersion: String) async {
        guard supabaseService.isAuthenticated else {
            logMigration("Migration failed: User not authenticated", level: .error)
            return
        }
        
        migrationStatus = .inProgress
        migrationProgress = 0.0
        
        logMigration("Starting migration from \(fromVersion) to \(toVersion)", level: .info)
        
        do {
            // Migration steps
            let steps: [(String, () async throws -> Void)] = [
                ("Loading legacy data", loadLegacyData),
                ("Migrating schedules", migrateSchedules),
                ("Migrating courses", migrateCourses),
                ("Migrating assignments", migrateAssignments), 
                ("Migrating events", migrateEvents),
                ("Migrating categories", migrateCategories),
                ("Creating relationships", establishRelationships),
                ("Validating migration", validateMigration),
                ("Cleaning up", cleanupLegacyData)
            ]
            
            for (index, (stepName, stepFunction)) in steps.enumerated() {
                currentMigrationStep = stepName
                migrationProgress = Double(index) / Double(steps.count)
                
                logMigration("Executing: \(stepName)", level: .info)
                
                try await stepFunction()
                
                logMigration("Completed: \(stepName)", level: .success)
            }
            
            migrationProgress = 1.0
            migrationStatus = .completed
            markMigrationComplete()
            
            logMigration("Migration completed successfully", level: .success)
            
        } catch {
            migrationStatus = .failed(error)
            logMigration("Migration failed: \(error.localizedDescription)", level: .error)
        }
    }
    
    // MARK: - Legacy Data Detection & Loading
    
    private func hasLegacyData() -> Bool {
        return legacyDataKeys.contains { userDefaults.data(forKey: $0) != nil }
    }
    
    private var legacyData: LegacyData = LegacyData()
    
    private func loadLegacyData() async throws {
        // Load legacy schedule collections
        if let schedulesData = userDefaults.data(forKey: "savedScheduleCollections") {
            do {
                legacyData.scheduleCollections = try JSONDecoder().decode([ScheduleCollection].self, from: schedulesData)
                logMigration("Loaded \(legacyData.scheduleCollections.count) legacy schedules", level: .info)
            } catch {
                logMigration("Failed to decode legacy schedules: \(error)", level: .warning)
            }
        }
        
        // Load active schedule ID
        if let activeIdString = userDefaults.string(forKey: "activeScheduleID"),
           let activeId = UUID(uuidString: activeIdString) {
            legacyData.activeScheduleId = activeId
        }
        
        // Load legacy courses (from CourseStorage if it exists)
        legacyData.courses = loadLegacyCourses()
        
        // Load legacy events
        legacyData.events = loadLegacyEvents()
        
        // Load legacy categories
        legacyData.categories = loadLegacyCategories()
        
        // Load legacy assignments
        legacyData.assignments = loadLegacyAssignments()
    }
    
    private func loadLegacyCourses() -> [Course] {
        // Try to load from various possible storage locations
        var courses: [Course] = []
        
        // Check UserDefaults
        if let coursesData = userDefaults.data(forKey: "savedCourses") {
            do {
                courses = try JSONDecoder().decode([Course].self, from: coursesData)
            } catch {
                logMigration("Failed to decode legacy courses from UserDefaults: \(error)", level: .warning)
            }
        }
        
        // Check for courses embedded in schedule collections
        for schedule in legacyData.scheduleCollections {
            // Extract courses from schedule items if they exist
            for scheduleItem in schedule.scheduleItems {
                let course = Course.from(scheduleItem: scheduleItem, scheduleId: schedule.id)
                if !courses.contains(where: { $0.id == course.id }) {
                    courses.append(course)
                }
            }
        }
        
        return courses
    }
    
    private func loadLegacyEvents() -> [Event] {
        if let eventsData = userDefaults.data(forKey: "savedEvents") {
            do {
                return try JSONDecoder().decode([Event].self, from: eventsData)
            } catch {
                logMigration("Failed to decode legacy events: \(error)", level: .warning)
            }
        }
        return []
    }
    
    private func loadLegacyCategories() -> [Category] {
        if let categoriesData = userDefaults.data(forKey: "savedCategories") {
            do {
                return try JSONDecoder().decode([Category].self, from: categoriesData)
            } catch {
                logMigration("Failed to decode legacy categories: \(error)", level: .warning)
            }
        }
        return []
    }
    
    private func loadLegacyAssignments() -> [Assignment] {
        // Assignments might be embedded in courses
        var assignments: [Assignment] = []
        
        for course in legacyData.courses {
            assignments.append(contentsOf: course.assignments)
        }
        
        // Also check for standalone assignments
        if let assignmentsData = userDefaults.data(forKey: "savedAssignments") {
            do {
                let standaloneAssignments = try JSONDecoder().decode([Assignment].self, from: assignmentsData)
                for assignment in standaloneAssignments {
                    if !assignments.contains(where: { $0.id == assignment.id }) {
                        assignments.append(assignment)
                    }
                }
            } catch {
                logMigration("Failed to decode legacy assignments: \(error)", level: .warning)
            }
        }
        
        return assignments
    }
    
    // MARK: - Migration Steps
    
    private func migrateSchedules() async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw MigrationError.userNotAuthenticated
        }
        
        let scheduleRepo = BaseRepository<DatabaseSchedule, ScheduleCollection>(tableName: "schedules")
        
        for schedule in legacyData.scheduleCollections {
            do {
                _ = try await scheduleRepo.create(schedule, userId: userId)
                await cacheSystem.scheduleCache.store(schedule)
                
                logMigration("Migrated schedule: \(schedule.displayName)", level: .info)
            } catch {
                logMigration("Failed to migrate schedule \(schedule.displayName): \(error)", level: .warning)
            }
        }
    }
    
    private func migrateCourses() async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw MigrationError.userNotAuthenticated
        }
        
        let courseRepo = BaseRepository<DatabaseCourse, Course>(tableName: "courses")
        
        for course in legacyData.courses {
            do {
                _ = try await courseRepo.create(course, userId: userId)
                await cacheSystem.courseCache.store(course)
                
                logMigration("Migrated course: \(course.name)", level: .info)
            } catch {
                logMigration("Failed to migrate course \(course.name): \(error)", level: .warning)
            }
        }
    }
    
    private func migrateAssignments() async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw MigrationError.userNotAuthenticated
        }
        
        let assignmentRepo = BaseRepository<DatabaseAssignment, Assignment>(tableName: "assignments")
        
        for assignment in legacyData.assignments {
            do {
                _ = try await assignmentRepo.create(assignment, userId: userId)
                await cacheSystem.assignmentCache.store(assignment)
                
                logMigration("Migrated assignment: \(assignment.name)", level: .info)
            } catch {
                logMigration("Failed to migrate assignment \(assignment.name): \(error)", level: .warning)
            }
        }
    }
    
    private func migrateEvents() async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw MigrationError.userNotAuthenticated
        }
        
        let eventRepo = BaseRepository<DatabaseEvent, Event>(tableName: "events")
        
        for event in legacyData.events {
            do {
                _ = try await eventRepo.create(event, userId: userId)
                await cacheSystem.eventCache.store(event)
                
                logMigration("Migrated event: \(event.title)", level: .info)
            } catch {
                logMigration("Failed to migrate event \(event.title): \(error)", level: .warning)
            }
        }
    }
    
    private func migrateCategories() async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw MigrationError.userNotAuthenticated
        }
        
        let categoryRepo = BaseRepository<DatabaseCategory, Category>(tableName: "categories")
        
        for category in legacyData.categories {
            do {
                _ = try await categoryRepo.create(category, userId: userId)
                await cacheSystem.categoryCache.store(category)
                
                logMigration("Migrated category: \(category.name)", level: .info)
            } catch {
                logMigration("Failed to migrate category \(category.name): \(error)", level: .warning)
            }
        }
    }
    
    private func establishRelationships() async throws {
        guard supabaseService.isAuthenticated else {
            throw MigrationError.userNotAuthenticated
        }
        
        // Keep only setting the active schedule ID if present
        
        if let activeId = legacyData.activeScheduleId {
            userDefaults.set(activeId.uuidString, forKey: "activeScheduleID")
            logMigration("Preserved active schedule ID during migration", level: .info)
        } else {
            logMigration("No active schedule ID found to preserve", level: .info)
        }
    }
    
    private func validateMigration() async throws {
        // Verify data integrity after migration
        let validator = DataConsistencyValidator()
        let report = await validator.validateAllData()
        
        if report.totalErrors > 0 {
            logMigration("Migration validation found \(report.totalErrors) errors", level: .warning)
        } else {
            logMigration("Migration validation passed", level: .success)
        }
        
        // Log migration statistics
        let stats = MigrationStats(
            schedulesMigrated: legacyData.scheduleCollections.count,
            coursesMigrated: legacyData.courses.count,
            assignmentsMigrated: legacyData.assignments.count,
            eventsMigrated: legacyData.events.count,
            categoriesMigrated: legacyData.categories.count,
            validationErrors: report.totalErrors
        )
        
        logMigration("Migration stats: \(stats.summary)", level: .info)
    }
    
    private func cleanupLegacyData() async throws {
        // Create backup before cleanup
        await createLegacyDataBackup()
        
        // Remove legacy data from UserDefaults
        for key in legacyDataKeys {
            userDefaults.removeObject(forKey: key)
        }
        
        logMigration("Legacy data cleanup completed", level: .info)
    }
    
    // MARK: - Backup & Recovery
    
    private func createLegacyDataBackup() async {
        let backup = LegacyDataBackup(
            version: "1.0.0",
            timestamp: Date(),
            data: legacyData
        )
        
        do {
            let backupData = try JSONEncoder().encode(backup)
            userDefaults.set(backupData, forKey: "legacy_data_backup_\(Date().timeIntervalSince1970)")
            
            logMigration("Legacy data backup created", level: .info)
        } catch {
            logMigration("Failed to create legacy data backup: \(error)", level: .warning)
        }
    }
    
    func restoreFromBackup(_ backupId: String) async throws {
        guard let backupData = userDefaults.data(forKey: backupId) else {
            throw MigrationError.backupNotFound
        }
        
        let backup = try JSONDecoder().decode(LegacyDataBackup.self, from: backupData)
        legacyData = backup.data
        
        // Re-run migration
        await performMigration(from: backup.version, to: currentVersion)
    }
    
    func listAvailableBackups() -> [BackupInfo] {
        let allKeys = Array(userDefaults.dictionaryRepresentation().keys)
        let backupKeys = allKeys.filter { $0.hasPrefix("legacy_data_backup_") }
        
        return backupKeys.compactMap { key in
            guard let data = userDefaults.data(forKey: key),
                  let backup = try? JSONDecoder().decode(LegacyDataBackup.self, from: data) else {
                return nil
            }
            
            return BackupInfo(
                id: key,
                version: backup.version,
                timestamp: backup.timestamp,
                itemCount: backup.data.totalItems
            )
        }.sorted { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - Logging & History
    
    private func logMigration(_ message: String, level: MigrationLogLevel) {
        let entry = MigrationLogEntry(
            timestamp: Date(),
            message: message,
            level: level
        )
        
        migrationLog.append(entry)
        
        // Keep only last 100 entries
        if migrationLog.count > 100 {
            migrationLog = Array(migrationLog.suffix(100))
        }
        
        // Also log to console
        print("🔄 Migration: \(entry.formattedMessage)")
        
        // Persist log
        saveMigrationLog()
    }
    
    private func loadMigrationHistory() {
        if let logData = userDefaults.data(forKey: "migration_log") {
            do {
                migrationLog = try JSONDecoder().decode([MigrationLogEntry].self, from: logData)
            } catch {
                print("Failed to load migration log: \(error)")
            }
        }
        
        lastMigrationDate = userDefaults.object(forKey: "last_migration_date") as? Date
    }
    
    private func saveMigrationLog() {
        do {
            let logData = try JSONEncoder().encode(migrationLog)
            userDefaults.set(logData, forKey: "migration_log")
        } catch {
            print("Failed to save migration log: \(error)")
        }
    }
    
    private func markMigrationComplete() {
        userDefaults.set(currentVersion, forKey: migrationKey)
        lastMigrationDate = Date()
        userDefaults.set(lastMigrationDate, forKey: "last_migration_date")
    }
    
    // MARK: - Public Interface
    
    func clearMigrationHistory() {
        migrationLog.removeAll()
        userDefaults.removeObject(forKey: "migration_log")
        userDefaults.removeObject(forKey: migrationKey)
        lastMigrationDate = nil
    }
    
    var migrationSummary: MigrationSummary {
        return MigrationSummary(
            currentVersion: currentVersion,
            lastMigrationDate: lastMigrationDate,
            status: migrationStatus,
            hasLegacyData: hasLegacyData(),
            logEntryCount: migrationLog.count,
            availableBackups: listAvailableBackups().count
        )
    }
}

// MARK: - Supporting Types

enum MigrationStatus: Equatable {
    case notStarted
    case inProgress
    case completed
    case failed(Error)
    
    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
    
    static func == (lhs: MigrationStatus, rhs: MigrationStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted),
             (.inProgress, .inProgress),
             (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

enum MigrationError: Error, LocalizedError {
    case userNotAuthenticated
    case legacyDataCorrupted
    case backupNotFound
    case migrationAlreadyInProgress
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to perform migration"
        case .legacyDataCorrupted:
            return "Legacy data is corrupted and cannot be migrated"
        case .backupNotFound:
            return "Backup not found"
        case .migrationAlreadyInProgress:
            return "Migration is already in progress"
        }
    }
}

enum MigrationLogLevel: String, Codable {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case success = "SUCCESS"
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .success: return "checkmark.circle"
        }
    }
}

struct MigrationLogEntry: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: MigrationLogLevel
    
    var formattedMessage: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "[\(formatter.string(from: timestamp))] \(level.rawValue): \(message)"
    }
}

struct LegacyData: Codable {
    var scheduleCollections: [ScheduleCollection] = []
    var courses: [Course] = []
    var assignments: [Assignment] = []
    var events: [Event] = []
    var categories: [Category] = []
    var activeScheduleId: UUID?
    
    var totalItems: Int {
        scheduleCollections.count + courses.count + assignments.count + events.count + categories.count
    }
}

struct LegacyDataBackup: Codable {
    let version: String
    let timestamp: Date
    let data: LegacyData
}

struct BackupInfo: Identifiable {
    let id: String
    let version: String
    let timestamp: Date
    let itemCount: Int
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

struct MigrationStats {
    let schedulesMigrated: Int
    let coursesMigrated: Int
    let assignmentsMigrated: Int
    let eventsMigrated: Int
    let categoriesMigrated: Int
    let validationErrors: Int
    
    var totalMigrated: Int {
        schedulesMigrated + coursesMigrated + assignmentsMigrated + eventsMigrated + categoriesMigrated
    }
    
    var summary: String {
        "Migrated \(totalMigrated) items (\(schedulesMigrated) schedules, \(coursesMigrated) courses, \(assignmentsMigrated) assignments, \(eventsMigrated) events, \(categoriesMigrated) categories) with \(validationErrors) validation errors"
    }
}

struct MigrationSummary {
    let currentVersion: String
    let lastMigrationDate: Date?
    let status: MigrationStatus
    let hasLegacyData: Bool
    let logEntryCount: Int
    let availableBackups: Int
    
    var needsMigration: Bool {
        hasLegacyData && status != .completed
    }
}