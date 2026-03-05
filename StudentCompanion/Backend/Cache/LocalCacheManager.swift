import Foundation
import SwiftUI

// MARK: - Cache Protocol
protocol CacheManager {
    associatedtype CacheModel: Codable & Identifiable
    
    func store(_ items: [CacheModel]) async
    func store(_ item: CacheModel) async
    func retrieve() async -> [CacheModel]
    func retrieve(id: String) async -> CacheModel?
    func update(_ item: CacheModel) async
    func delete(id: String) async
    func deleteAll() async
    func getCacheInfo() async -> CacheInfo
}

struct CacheInfo {
    let itemCount: Int
    let lastUpdated: Date?
    let cacheSize: Int // in bytes
    let isStale: Bool
}

// MARK: - Generic Local Cache Manager
@MainActor
class LocalCacheManager<T: Codable & Identifiable>: CacheManager where T.ID == UUID {
    typealias CacheModel = T
    
    private let cacheKey: String
    private let maxCacheAge: TimeInterval
    private let fileManager = FileManager.default
    private var cache: [String: T] = [:]
    private var lastLoadTime: Date?
    
    init(cacheKey: String, maxCacheAge: TimeInterval = 3600) { // 1 hour default
        self.cacheKey = cacheKey
        self.maxCacheAge = maxCacheAge
        
        Task {
            await self.loadFromDisk()
        }
    }
    
    private var cacheDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cacheDir = documentsPath.appendingPathComponent("Cache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
        
        return cacheDir
    }
    
    private var cacheFileURL: URL {
        cacheDirectory.appendingPathComponent("\(cacheKey).json")
    }
    
    private var metadataFileURL: URL {
        cacheDirectory.appendingPathComponent("\(cacheKey)_metadata.json")
    }
    
    // MARK: - Cache Operations
    
    func store(_ items: [T]) async {
        cache.removeAll()
        
        for item in items {
            cache[item.id.uuidString] = item
        }
        
        await saveToDisk()
    }
    
    func store(_ item: T) async {
        cache[item.id.uuidString] = item
        await saveToDisk()
    }
    
    func retrieve() async -> [T] {
        if lastLoadTime == nil {
            await loadFromDisk()
        }
        
        return Array(cache.values)
    }
    
    func retrieve(id: String) async -> T? {
        if lastLoadTime == nil {
            await loadFromDisk()
        }
        
        return cache[id]
    }
    
    func update(_ item: T) async {
        cache[item.id.uuidString] = item
        await saveToDisk()
    }
    
    func delete(id: String) async {
        cache.removeValue(forKey: id)
        await saveToDisk()
    }
    
    func deleteAll() async {
        cache.removeAll()
        await saveToDisk()
        
        // Also remove files
        try? fileManager.removeItem(at: cacheFileURL)
        try? fileManager.removeItem(at: metadataFileURL)
        
    }
    
    func getCacheInfo() async -> CacheInfo {
        if lastLoadTime == nil {
            await loadFromDisk()
        }
        
        let cacheSize = getCacheSizeInBytes()
        let isStale = isCacheStale()
        
        return CacheInfo(
            itemCount: cache.count,
            lastUpdated: lastLoadTime,
            cacheSize: cacheSize,
            isStale: isStale
        )
    }
    
    // MARK: - Persistence
    
    private func saveToDisk() async {
        do {
            let items = Array(cache.values)
            let data = try JSONEncoder().encode(items)
            try data.write(to: cacheFileURL)
            
            // Save metadata
            let metadata = CacheMetadata(lastUpdated: Date(), itemCount: items.count)
            let metadataData = try JSONEncoder().encode(metadata)
            try metadataData.write(to: metadataFileURL)
            
            lastLoadTime = Date()
        } catch {
        }
    }
    
    private func loadFromDisk() async {
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let items = try JSONDecoder().decode([T].self, from: data)
            
            cache.removeAll()
            for item in items {
                cache[item.id.uuidString] = item
            }
            
            // Load metadata
            if let metadataData = try? Data(contentsOf: metadataFileURL),
               let metadata = try? JSONDecoder().decode(CacheMetadata.self, from: metadataData) {
                lastLoadTime = metadata.lastUpdated
            } else {
                lastLoadTime = Date()
            }
            
        } catch {
            cache.removeAll()
            lastLoadTime = Date()
        }
    }
    
    private func getCacheSizeInBytes() -> Int {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: cacheFileURL.path)
            return attributes[.size] as? Int ?? 0
        } catch {
            return 0
        }
    }
    
    private func isCacheStale() -> Bool {
        guard let lastLoad = lastLoadTime else { return true }
        return Date().timeIntervalSince(lastLoad) > maxCacheAge
    }
}

// MARK: - Cache Metadata
private struct CacheMetadata: Codable {
    let lastUpdated: Date
    let itemCount: Int
}

// MARK: - Comprehensive Cache System
@MainActor
class CacheSystem: ObservableObject {
    static let shared = CacheSystem()
    
    // Individual cache managers for each data type
    let academicCalendarCache = LocalCacheManager<AcademicCalendar>(cacheKey: "academic_calendars")
    let assignmentCache = LocalCacheManager<Assignment>(cacheKey: "assignments")
    let categoryCache = LocalCacheManager<Category>(cacheKey: "categories")
    let courseCache = LocalCacheManager<Course>(cacheKey: "courses")
    let eventCache = LocalCacheManager<Event>(cacheKey: "events")
    let scheduleCache = LocalCacheManager<ScheduleCollection>(cacheKey: "schedules")
    let scheduleItemCache = LocalCacheManager<ScheduleItem>(cacheKey: "schedule_items")
    let courseMeetingCache = LocalCacheManager<CourseMeeting>(cacheKey: "course_meetings")
    
    @Published private(set) var totalCacheSize: Int = 0
    @Published private(set) var totalItems: Int = 0
    @Published private(set) var isInitialized: Bool = false
    
    private init() {
        Task {
            await initializeCaches()
        }
    }
    
    private func initializeCaches() async {
        // Initialize all caches
        
        await updateCacheStats()
        isInitialized = true
        
    }
    
    func updateCacheStats() async {
        let cacheInfos = await [
            academicCalendarCache.getCacheInfo(),
            assignmentCache.getCacheInfo(),
            categoryCache.getCacheInfo(),
            courseCache.getCacheInfo(),
            eventCache.getCacheInfo(),
            scheduleCache.getCacheInfo(),
            scheduleItemCache.getCacheInfo(),
            courseMeetingCache.getCacheInfo()
        ]
        
        totalItems = cacheInfos.reduce(0) { $0 + $1.itemCount }
        totalCacheSize = cacheInfos.reduce(0) { $0 + $1.cacheSize }
    }
    
    func clearAllCaches() async {
        await academicCalendarCache.deleteAll()
        await assignmentCache.deleteAll()
        await categoryCache.deleteAll()
        await courseCache.deleteAll()
        await eventCache.deleteAll()
        await scheduleCache.deleteAll()
        await scheduleItemCache.deleteAll()
        
        await updateCacheStats()
        
    }
    
    /// Clears all user-specific cached data (alias for clearAllCaches for consistency)
    func clearAllUserData() async {
        await clearAllCaches()
    }
    
    func getCacheSystemInfo() -> CacheSystemInfo {
        return CacheSystemInfo(
            totalItems: totalItems,
            totalSize: totalCacheSize,
            isInitialized: isInitialized,
            formattedSize: formatBytes(totalCacheSize)
        )
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct CacheSystemInfo {
    let totalItems: Int
    let totalSize: Int
    let isInitialized: Bool
    let formattedSize: String
}

// MARK: - Cache-Aware Repository Wrapper
class CachedRepository<DBRow: DatabaseModel, LocalModel: Codable & Identifiable>: Repository where LocalModel.ID == UUID, DBRow.LocalModel == LocalModel {
    private let repository: BaseRepository<DBRow, LocalModel>
    private let cache: LocalCacheManager<LocalModel>
    private let supabaseService: SupabaseService
    
    var tableName: String { repository.tableName }
    
    init(repository: BaseRepository<DBRow, LocalModel>, cache: LocalCacheManager<LocalModel>, supabaseService: SupabaseService = .shared) {
        self.repository = repository
        self.cache = cache
        self.supabaseService = supabaseService
    }
    
    func create(_ item: LocalModel, userId: String) async throws -> LocalModel {
        let result: LocalModel

        if supabaseService.isConnected {
            // Create in database first
            result = try await repository.create(item, userId: userId)
            // Update cache
            await cache.store(result)
        } else {
            // Store in cache for later sync
            result = item
            await cache.store(result)

            // Queue operation for sync when online
            let dataDict = try await convertToDictionary(item)
            let operation = SyncOperation(
                type: getSyncDataType(),
                action: .create,
                data: dataDict
            )
            await queueSyncOperation(operation)
            print("📦 CachedRepository: Queued CREATE operation for offline sync - \(tableName)")
        }

        return result
    }
    
    func read(id: String) async throws -> LocalModel? {
        // Try cache first
        if let cachedItem = await cache.retrieve(id: id) {
            return cachedItem
        }
        
        // If not in cache and connected, try database
        if supabaseService.isConnected {
            if let item = try await repository.read(id: id) {
                await cache.store(item)
                return item
            }
        }
        
        return nil
    }
    
    func readAll(userId: String) async throws -> [LocalModel] {
        if supabaseService.isConnected {
            // Always fetch fresh data from database when connected
            do {
                let items = try await repository.readAll(userId: userId)
                await cache.store(items)
                return items
            } catch {
                // If database fails, fall back to cached items
                return await cache.retrieve()
            }
        } else {
            // Return cached items when offline
            return await cache.retrieve()
        }
    }
    
    func update(_ item: LocalModel, userId: String) async throws -> LocalModel {
        let result: LocalModel

        if supabaseService.isConnected {
            // Update in database first
            result = try await repository.update(item, userId: userId)
            // Update cache
            await cache.update(result)
        } else {
            // Update cache for later sync
            result = item
            await cache.update(result)

            // Queue operation for sync when online
            let dataDict = try await convertToDictionary(item)
            let operation = SyncOperation(
                type: getSyncDataType(),
                action: .update,
                data: dataDict
            )
            await queueSyncOperation(operation)
            print("📦 CachedRepository: Queued UPDATE operation for offline sync - \(tableName)")
        }

        return result
    }
    
    func delete(id: String) async throws {
        if supabaseService.isConnected {
            // Delete from database first
            try await repository.delete(id: id)
            // Remove from cache
            await cache.delete(id: id)
        } else {
            // Remove from cache and mark for deletion sync
            await cache.delete(id: id)

            // Queue operation for sync when online
            let operation = SyncOperation(
                type: getSyncDataType(),
                action: .delete,
                data: ["id": id]
            )
            await queueSyncOperation(operation)
            print("📦 CachedRepository: Queued DELETE operation for offline sync - \(tableName)")
        }
    }
    
    func deleteAll(userId: String) async throws {
        if supabaseService.isConnected {
            // Delete from database first
            try await repository.deleteAll(userId: userId)
            // Clear cache
            await cache.deleteAll()
        } else {
            // Clear cache and mark for deletion sync
            await cache.deleteAll()

            // Queue bulk delete operation
            let operation = SyncOperation(
                type: getSyncDataType(),
                action: .delete,
                data: ["user_id": userId, "bulk": true]
            )
            await queueSyncOperation(operation)
            print("📦 CachedRepository: Queued BULK DELETE operation for offline sync - \(tableName)")
        }
    }

    // MARK: - Helper Methods

    private func getSyncDataType() -> SyncDataType {
        switch tableName {
        case "academic_calendars": return .academicCalendars
        case "assignments": return .assignments
        case "categories": return .categories
        case "courses": return .courses
        case "events": return .events
        case "schedules": return .schedules
        case "schedule_items": return .scheduleItems
        default: return .events // Fallback
        }
    }

    private func convertToDictionary(_ item: LocalModel) async throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = json as? [String: Any] else {
            throw NSError(domain: "CachedRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert model to dictionary"])
        }
        return dict
    }

    private func queueSyncOperation(_ operation: SyncOperation) async {
        await MainActor.run {
            RealtimeSyncManager.shared.queueSyncOperation(operation)
        }
    }
}

