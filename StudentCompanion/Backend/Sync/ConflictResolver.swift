import Foundation

// MARK: - Conflict Types
struct DataConflict {
    let id: String
    let table: String
    let localData: [String: Any]
    let remoteOldData: [String: Any]
    let remoteNewData: [String: Any]
    let conflictedFields: [String]
    let timestamp: Date
    
    var hasConflict: Bool {
        !conflictedFields.isEmpty
    }
    
    var severity: ConflictSeverity {
        // Determine severity based on conflicted fields and data types
        if conflictedFields.contains(where: { criticalFields.contains($0) }) {
            return .high
        } else if conflictedFields.count > 3 {
            return .medium
        } else {
            return .low
        }
    }
    
    private var criticalFields: [String] {
        switch table {
        case "courses":
            return ["name", "schedule_id", "user_id"]
        case "schedules":
            return ["name", "is_active", "user_id"]
        case "events":
            return ["title", "event_date", "user_id"]
        default:
            return ["name", "user_id"]
        }
    }
}

enum ConflictSeverity {
    case low, medium, high
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

enum ConflictResolutionStrategy {
    case useLocal          // Keep local changes
    case useRemote         // Use remote changes
    case merge            // Attempt to merge both
    case lastWriteWins    // Use most recent timestamp
    case userChoose       // Let user decide
    
    var displayName: String {
        switch self {
        case .useLocal: return "Keep Local"
        case .useRemote: return "Use Remote"
        case .merge: return "Merge Changes"
        case .lastWriteWins: return "Last Write Wins"
        case .userChoose: return "User Choice"
        }
    }
}

struct ConflictResolution {
    let conflict: DataConflict
    let strategy: ConflictResolutionStrategy
    let resolvedData: [String: Any]
    let resolutionReason: String
    let timestamp: Date
    
    init(conflict: DataConflict, strategy: ConflictResolutionStrategy, resolvedData: [String: Any], reason: String) {
        self.conflict = conflict
        self.strategy = strategy
        self.resolvedData = resolvedData
        self.resolutionReason = reason
        self.timestamp = Date()
    }
}

// MARK: - Conflict Resolver
@MainActor
class ConflictResolver: ObservableObject {
    @Published private(set) var pendingConflicts: [DataConflict] = []
    @Published private(set) var resolvedConflicts: [ConflictResolution] = []
    @Published private(set) var resolutionStatistics = ConflictStatistics()
    
    private let userDefaults = UserDefaults.standard
    private let conflictsKey = "pending_conflicts"
    private let resolutionsKey = "resolved_conflicts"
    
    // Default resolution strategies by table
    private var defaultStrategies: [String: ConflictResolutionStrategy] = [
        "academic_calendars": .lastWriteWins,
        "assignments": .merge,
        "categories": .lastWriteWins,
        "courses": .merge,
        "events": .merge,
        "schedules": .lastWriteWins,
        "schedule_items": .merge
    ]
    
    init() {
        loadPersistedConflicts()
    }
    
    // MARK: - Conflict Detection
    
    func detectConflict(
        localData: [String: Any],
        remoteOld: [String: Any],
        remoteNew: [String: Any],
        table: String
    ) async -> DataConflict {
        
        let conflictedFields = findConflictedFields(
            local: localData,
            remoteOld: remoteOld,
            remoteNew: remoteNew
        )
        
        let conflict = DataConflict(
            id: localData["id"] as? String ?? UUID().uuidString,
            table: table,
            localData: localData,
            remoteOldData: remoteOld,
            remoteNewData: remoteNew,
            conflictedFields: conflictedFields,
            timestamp: Date()
        )
        
        if conflict.hasConflict {
            pendingConflicts.append(conflict)
            resolutionStatistics.incrementDetected(for: table)
            persistConflicts()
            
            print("⚠️ ConflictResolver: Detected conflict in \(table) with \(conflictedFields.count) fields")
        }
        
        return conflict
    }
    
    private func findConflictedFields(
        local: [String: Any],
        remoteOld: [String: Any],
        remoteNew: [String: Any]
    ) -> [String] {
        
        var conflicted: [String] = []
        
        // Find fields that have been modified both locally and remotely
        for (key, localValue) in local {
            guard let remoteOldValue = remoteOld[key],
                  let remoteNewValue = remoteNew[key] else { continue }
            
            // Check if local differs from remote old (local modification)
            let localModified = !areValuesEqual(localValue, remoteOldValue)
            
            // Check if remote new differs from remote old (remote modification)
            let remoteModified = !areValuesEqual(remoteOldValue, remoteNewValue)
            
            // Check if local differs from remote new (actual conflict)
            let valuesConflict = !areValuesEqual(localValue, remoteNewValue)
            
            if localModified && remoteModified && valuesConflict {
                conflicted.append(key)
            }
        }
        
        return conflicted
    }
    
    private func areValuesEqual(_ value1: Any, _ value2: Any) -> Bool {
        // Handle different types of values for comparison
        switch (value1, value2) {
        case (let str1 as String, let str2 as String):
            return str1 == str2
        case (let num1 as NSNumber, let num2 as NSNumber):
            return num1 == num2
        case (let bool1 as Bool, let bool2 as Bool):
            return bool1 == bool2
        case (let date1 as Date, let date2 as Date):
            return abs(date1.timeIntervalSince(date2)) < 1.0 // Within 1 second
        case (let arr1 as [Any], let arr2 as [Any]):
            return NSArray(array: arr1).isEqual(to: arr2)
        case (let dict1 as [String: Any], let dict2 as [String: Any]):
            return NSDictionary(dictionary: dict1).isEqual(to: dict2)
        default:
            // For NSNull or other types
            return String(describing: value1) == String(describing: value2)
        }
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflict(_ conflict: DataConflict) async -> ConflictResolution {
        let strategy = getResolutionStrategy(for: conflict)
        
        let resolution: ConflictResolution
        
        switch strategy {
        case .useLocal:
            resolution = ConflictResolution(
                conflict: conflict,
                strategy: .useLocal,
                resolvedData: conflict.localData,
                reason: "Local changes preserved"
            )
            
        case .useRemote:
            resolution = ConflictResolution(
                conflict: conflict,
                strategy: .useRemote,
                resolvedData: conflict.remoteNewData,
                reason: "Remote changes accepted"
            )
            
        case .merge:
            let mergedData = await mergeData(conflict)
            resolution = ConflictResolution(
                conflict: conflict,
                strategy: .merge,
                resolvedData: mergedData,
                reason: "Changes merged automatically"
            )
            
        case .lastWriteWins:
            let useLocal = isLocalNewer(conflict)
            resolution = ConflictResolution(
                conflict: conflict,
                strategy: .lastWriteWins,
                resolvedData: useLocal ? conflict.localData : conflict.remoteNewData,
                reason: useLocal ? "Local change is newer" : "Remote change is newer"
            )
            
        case .userChoose:
            // For now, default to last write wins
            // In a full implementation, this would show a UI for user choice
            let useLocal = isLocalNewer(conflict)
            resolution = ConflictResolution(
                conflict: conflict,
                strategy: .userChoose,
                resolvedData: useLocal ? conflict.localData : conflict.remoteNewData,
                reason: "User choice required (defaulted to newer)"
            )
        }
        
        // Record resolution
        resolvedConflicts.append(resolution)
        pendingConflicts.removeAll { $0.id == conflict.id }
        resolutionStatistics.incrementResolved(for: conflict.table, strategy: strategy)
        
        persistConflicts()
        
        print("✅ ConflictResolver: Resolved conflict in \(conflict.table) using \(strategy.displayName)")
        
        return resolution
    }
    
    private func getResolutionStrategy(for conflict: DataConflict) -> ConflictResolutionStrategy {
        // Use table-specific strategy or user preference
        return defaultStrategies[conflict.table] ?? .lastWriteWins
    }
    
    private func mergeData(_ conflict: DataConflict) async -> [String: Any] {
        var merged = conflict.localData
        
        // Smart merging based on field types and table
        for field in conflict.conflictedFields {
            let localValue = conflict.localData[field]
            let remoteValue = conflict.remoteNewData[field]
            
            // Apply field-specific merge logic
            merged[field] = await mergeFieldValue(
                field: field,
                localValue: localValue,
                remoteValue: remoteValue,
                table: conflict.table
            )
        }
        
        // Always use the most recent updated_at timestamp
        if let remoteUpdated = conflict.remoteNewData["updated_at"] as? String,
           let localUpdated = conflict.localData["updated_at"] as? String {
            
            let remoteDate = Date.fromISOString(remoteUpdated) ?? Date()
            let localDate = Date.fromISOString(localUpdated) ?? Date()
            
            merged["updated_at"] = remoteDate > localDate ? remoteUpdated : localUpdated
        }
        
        return merged
    }
    
    private func mergeFieldValue(
        field: String,
        localValue: Any?,
        remoteValue: Any?,
        table: String
    ) async -> Any? {
        
        // Table and field-specific merge logic
        switch (table, field) {
        case (_, "skipped_instances"), (_, "breaks"):
            // For arrays, merge unique values
            if let localArray = localValue as? [String],
               let remoteArray = remoteValue as? [String] {
                return Array(Set(localArray + remoteArray))
            }
            
        case ("assignments", "grade"), ("assignments", "weight"):
            // For grades and weights, prefer non-empty values
            if let localStr = localValue as? String, !localStr.isEmpty {
                return localValue
            } else {
                return remoteValue
            }
            
        case ("courses", "final_grade_goal"), ("courses", "weight_of_remaining_tasks"):
            // Prefer non-empty academic data
            if let localStr = localValue as? String, !localStr.isEmpty {
                return localValue
            } else {
                return remoteValue
            }
            
        case (_, "location"), (_, "instructor"), (_, "notes"), (_, "description"):
            // For text fields, prefer non-empty or longer content
            if let localStr = localValue as? String,
               let remoteStr = remoteValue as? String {
                return localStr.count >= remoteStr.count ? localValue : remoteValue
            }
            
        default:
            // Default: use newer timestamp or local value
            return isLocalNewer(DataConflict(
                id: "",
                table: table,
                localData: ["updated_at": Date().toISOString()],
                remoteOldData: [:],
                remoteNewData: ["updated_at": Date().toISOString()],
                conflictedFields: [],
                timestamp: Date()
            )) ? localValue : remoteValue
        }
        
        return remoteValue
    }
    
    private func isLocalNewer(_ conflict: DataConflict) -> Bool {
        guard let localUpdated = conflict.localData["updated_at"] as? String,
              let remoteUpdated = conflict.remoteNewData["updated_at"] as? String,
              let localDate = Date.fromISOString(localUpdated),
              let remoteDate = Date.fromISOString(remoteUpdated) else {
            return false
        }
        
        return localDate > remoteDate
    }
    
    // MARK: - Conflict Management
    
    func resolveAllConflicts() async {
        print("🔧 ConflictResolver: Resolving \(pendingConflicts.count) pending conflicts")
        
        let conflicts = pendingConflicts
        for conflict in conflicts {
            _ = await resolveConflict(conflict)
        }
    }
    
    func dismissConflict(_ conflictId: String) {
        pendingConflicts.removeAll { $0.id == conflictId }
        persistConflicts()
    }
    
    func setResolutionStrategy(for table: String, strategy: ConflictResolutionStrategy) {
        defaultStrategies[table] = strategy
        
        // Persist strategy preference
        let strategies = defaultStrategies.mapValues { $0.rawValue }
        userDefaults.set(strategies, forKey: "conflict_resolution_strategies")
    }
    
    func clearResolvedConflicts() {
        resolvedConflicts.removeAll()
        persistConflicts()
    }
    
    // MARK: - Persistence
    
    private func persistConflicts() {
        do {
            // Save pending conflicts
            let pendingData = try JSONEncoder().encode(pendingConflicts)
            userDefaults.set(pendingData, forKey: conflictsKey)
            
            // Save resolved conflicts (keep last 100)
            let recentResolutions = Array(resolvedConflicts.suffix(100))
            let resolvedData = try JSONEncoder().encode(recentResolutions)
            userDefaults.set(resolvedData, forKey: resolutionsKey)
            
        } catch {
            print("⚠️ ConflictResolver: Failed to persist conflicts: \(error)")
        }
    }
    
    private func loadPersistedConflicts() {
        // Load pending conflicts
        if let pendingData = userDefaults.data(forKey: conflictsKey) {
            do {
                pendingConflicts = try JSONDecoder().decode([DataConflict].self, from: pendingData)
            } catch {
                print("⚠️ ConflictResolver: Failed to load pending conflicts: \(error)")
                pendingConflicts = []
            }
        }
        
        // Load resolved conflicts
        if let resolvedData = userDefaults.data(forKey: resolutionsKey) {
            do {
                resolvedConflicts = try JSONDecoder().decode([ConflictResolution].self, from: resolvedData)
            } catch {
                print("⚠️ ConflictResolver: Failed to load resolved conflicts: \(error)")
                resolvedConflicts = []
            }
        }
        
        // Load strategy preferences
        if let strategies = userDefaults.object(forKey: "conflict_resolution_strategies") as? [String: String] {
            for (table, strategyRaw) in strategies {
                if let strategy = ConflictResolutionStrategy(rawValue: strategyRaw) {
                    defaultStrategies[table] = strategy
                }
            }
        }
    }
    
    // MARK: - Statistics
    
    var conflictSummary: ConflictSummary {
        ConflictSummary(
            pendingCount: pendingConflicts.count,
            resolvedCount: resolvedConflicts.count,
            totalDetected: resolutionStatistics.totalDetected,
            resolutionRate: resolutionStatistics.resolutionRate,
            averageResolutionTime: calculateAverageResolutionTime()
        )
    }
    
    private func calculateAverageResolutionTime() -> TimeInterval {
        guard !resolvedConflicts.isEmpty else { return 0 }
        
        let totalTime = resolvedConflicts.reduce(0.0) { sum, resolution in
            sum + resolution.timestamp.timeIntervalSince(resolution.conflict.timestamp)
        }
        
        return totalTime / Double(resolvedConflicts.count)
    }
}

// MARK: - Supporting Types

extension ConflictResolutionStrategy: RawRepresentable {
    public var rawValue: String {
        switch self {
        case .useLocal: return "useLocal"
        case .useRemote: return "useRemote"
        case .merge: return "merge"
        case .lastWriteWins: return "lastWriteWins"
        case .userChoose: return "userChoose"
        }
    }
    
    public init?(rawValue: String) {
        switch rawValue {
        case "useLocal": self = .useLocal
        case "useRemote": self = .useRemote
        case "merge": self = .merge
        case "lastWriteWins": self = .lastWriteWins
        case "userChoose": self = .userChoose
        default: return nil
        }
    }
}

extension DataConflict: Codable {
    enum CodingKeys: String, CodingKey {
        case id, table, localData, remoteOldData, remoteNewData, conflictedFields, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        table = try container.decode(String.self, forKey: .table)
        
        let localEncoded = try container.decode([String: AnyCodable].self, forKey: .localData)
        localData = localEncoded.mapValues { $0.value }
        
        let remoteOldEncoded = try container.decode([String: AnyCodable].self, forKey: .remoteOldData)
        remoteOldData = remoteOldEncoded.mapValues { $0.value }
        
        let remoteNewEncoded = try container.decode([String: AnyCodable].self, forKey: .remoteNewData)
        remoteNewData = remoteNewEncoded.mapValues { $0.value }
        
        conflictedFields = try container.decode([String].self, forKey: .conflictedFields)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(table, forKey: .table)
        try container.encode(localData.mapValues { AnyCodable($0) }, forKey: .localData)
        try container.encode(remoteOldData.mapValues { AnyCodable($0) }, forKey: .remoteOldData)
        try container.encode(remoteNewData.mapValues { AnyCodable($0) }, forKey: .remoteNewData)
        try container.encode(conflictedFields, forKey: .conflictedFields)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

extension ConflictResolution: Codable {
    enum CodingKeys: String, CodingKey {
        case conflict, strategy, resolvedData, resolutionReason, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conflict = try container.decode(DataConflict.self, forKey: .conflict)
        let strategyRaw = try container.decode(String.self, forKey: .strategy)
        strategy = ConflictResolutionStrategy(rawValue: strategyRaw) ?? .lastWriteWins
        
        let resolvedEncoded = try container.decode([String: AnyCodable].self, forKey: .resolvedData)
        resolvedData = resolvedEncoded.mapValues { $0.value }
        
        resolutionReason = try container.decode(String.self, forKey: .resolutionReason)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(conflict, forKey: .conflict)
        try container.encode(strategy.rawValue, forKey: .strategy)
        try container.encode(resolvedData.mapValues { AnyCodable($0) }, forKey: .resolvedData)
        try container.encode(resolutionReason, forKey: .resolutionReason)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

class ConflictStatistics: ObservableObject {
    @Published private(set) var detected: [String: Int] = [:]
    @Published private(set) var resolved: [String: Int] = [:]
    @Published private(set) var strategies: [String: Int] = [:]
    
    func incrementDetected(for table: String) {
        detected[table, default: 0] += 1
    }
    
    func incrementResolved(for table: String, strategy: ConflictResolutionStrategy) {
        resolved[table, default: 0] += 1
        strategies[strategy.rawValue, default: 0] += 1
    }
    
    var totalDetected: Int { detected.values.reduce(0, +) }
    var totalResolved: Int { resolved.values.reduce(0, +) }
    
    var resolutionRate: Double {
        guard totalDetected > 0 else { return 1.0 }
        return Double(totalResolved) / Double(totalDetected)
    }
}

struct ConflictSummary {
    let pendingCount: Int
    let resolvedCount: Int
    let totalDetected: Int
    let resolutionRate: Double
    let averageResolutionTime: TimeInterval
    
    var formattedResolutionTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: averageResolutionTime) ?? "0s"
    }
}