import Foundation
import SwiftUI
import Combine

// MARK: - Sync Operation Types
enum SyncAction: String, Codable {
    case create = "INSERT"
    case update = "UPDATE"
    case delete = "DELETE"
}

enum SyncDataType: String, CaseIterable, Codable {
    case academicCalendars = "academic_calendars"
    case assignments = "assignments"
    case categories = "categories"
    case courses = "courses"
    case events = "events"
    case schedules = "schedules"
    case scheduleItems = "schedule_items"
}

struct SyncOperation: Identifiable, Codable {
    let id: UUID
    let type: SyncDataType
    let action: SyncAction
    let data: [String: AnyCodable]
    let timestamp: Date
    var retryCount: Int
    var lastRetryTime: Date?
    var isProcessing: Bool = false
    
    init(type: SyncDataType, action: SyncAction, data: [String: Any], retryCount: Int = 0) {
        self.id = UUID()
        self.type = type
        self.action = action
        self.data = data.mapValues { AnyCodable($0) }
        self.timestamp = Date()
        self.retryCount = retryCount
        self.lastRetryTime = nil
    }
    
    var isStale: Bool {
        // Operations older than 24 hours are considered stale
        Date().timeIntervalSince(timestamp) > 86400
    }
    
    var shouldRetry: Bool {
        guard retryCount < 3 else { return false }
        
        if let lastRetry = lastRetryTime {
            // Exponential backoff: 30s, 2m, 5m
            let delays: [TimeInterval] = [30, 120, 300]
            let delay = retryCount < delays.count ? delays[retryCount] : delays.last!
            return Date().timeIntervalSince(lastRetry) > delay
        }
        
        return true
    }
}

// MARK: - AnyCodable Helper
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            if mirror.children.count == 0 {
                try container.encodeNil()
                return
            } else if let wrapped = mirror.children.first?.value {
                try AnyCodable(wrapped).encode(to: encoder)
                return
            }
        }
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Sync Queue Manager
@MainActor
class SyncQueue: ObservableObject {
    @Published private(set) var queuedOperations: [SyncOperation] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var processingProgress: Double = 0.0
    @Published private(set) var lastProcessTime: Date?
    @Published private(set) var queueStatistics = QueueStatistics()
    
    private let supabaseService = SupabaseService.shared
    private let maxRetries = 3
    private let processingQueue = DispatchQueue(label: "sync.queue.processing", qos: .utility)
    private var processingTimer: Timer?
    private let persistenceKey = "sync_queue_operations"
    
    init() {
        loadPersistedOperations()
        startProcessingTimer()
        setupConnectionObserver()
    }
    
    // MARK: - Queue Operations
    
    func enqueue(_ operation: SyncOperation) {
        // DROP: schedule_items operations (schema no longer uses this table)
        if operation.type == .scheduleItems {
            return
        }
        
        queuedOperations.append(operation)
        queueStatistics.incrementQueued(for: operation.type)
        persistOperations()
        
        
        if supabaseService.isAuthenticated && !isProcessing {
            Task {
                await processQueue()
            }
        }
    }
    
    func dequeue(_ operationId: UUID) {
        queuedOperations.removeAll { $0.id == operationId }
        persistOperations()
    }
    
    func clearQueue() {
        queuedOperations.removeAll()
        queueStatistics.reset()
        persistOperations()
        
    }
    
    func clearStaleOperations() {
        let staleCount = queuedOperations.filter { $0.isStale }.count
        queuedOperations.removeAll { $0.isStale }
        
        if staleCount > 0 {
            persistOperations()
        }
    }
    
    // MARK: - Processing
    
    func processQueue() async {
        guard supabaseService.isAuthenticated, !isProcessing, !queuedOperations.isEmpty else {
            return
        }
        
        isProcessing = true
        processingProgress = 0.0
        

        // Filter out schedule_items if any slipped through persisted storage
        queuedOperations.removeAll { $0.type == .scheduleItems }
        persistOperations()

        let operations = queuedOperations.filter { !$0.isProcessing && $0.shouldRetry }
        let totalOperations = operations.count

        for (index, operation) in operations.enumerated() {
            if let operationIndex = queuedOperations.firstIndex(where: { $0.id == operation.id }) {
                queuedOperations[operationIndex].isProcessing = true
            }

            let success = await processOperation(operation)

            if success {
                dequeue(operation.id)
                queueStatistics.incrementProcessed(for: operation.type)
            } else {
                if let operationIndex = queuedOperations.firstIndex(where: { $0.id == operation.id }) {
                    queuedOperations[operationIndex].retryCount += 1
                    queuedOperations[operationIndex].lastRetryTime = Date()
                    queuedOperations[operationIndex].isProcessing = false
                    if queuedOperations[operationIndex].retryCount >= maxRetries {
                        queueStatistics.incrementFailed(for: operation.type)
                    }
                }
                queueStatistics.incrementRetried(for: operation.type)
            }

            processingProgress = Double(index + 1) / Double(totalOperations)
        }

        persistOperations()
        isProcessing = false
        processingProgress = 0.0
        lastProcessTime = Date()

    }
    
    private func processOperation(_ operation: SyncOperation) async -> Bool {
        do {
            await supabaseService.ensureValidToken()
            
            switch operation.action {
            case .create:
                _ = try await supabaseService.client
                    .from(operation.type.rawValue)
                    .insert(operation.data)
                    .execute()
                
            case .update:
                guard let id = extractId(from: operation.data) else {
                    return false
                }
                
                _ = try await supabaseService.client
                    .from(operation.type.rawValue)
                    .update(operation.data)
                    .eq("id", value: id)
                    .execute()
                
            case .delete:
                guard let id = extractId(from: operation.data) else {
                    return false
                }
                
                _ = try await supabaseService.client
                    .from(operation.type.rawValue)
                    .delete()
                    .eq("id", value: id)
                    .execute()
            }
            
            return true
            
        } catch {
            return false
        }
    }
    
    // MARK: - Timer & Observers
    
    private func startProcessingTimer() {
        processingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                await self.processQueue()
                self.clearStaleOperations()
            }
        }
    }
    
    private func setupConnectionObserver() {
        supabaseService.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                if isConnected {
                    Task { @MainActor in
                        await self?.processQueue()
                    }
                }
            }
            .store(in: &cancellables)
        
        supabaseService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuth in
                if isAuth {
                    Task { @MainActor in
                        await self?.processQueue()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables: Set<AnyCancellable> = []

    private func extractId(from data: [String: AnyCodable]) -> String? {
        if let str = data["id"]?.value as? String {
            return str
        }
        if let uuid = data["id"]?.value as? UUID {
            return uuid.uuidString
        }
        if let intVal = data["id"]?.value as? Int {
            return String(intVal)
        }
        return nil
    }

    // MARK: - Persistence
    
    private func persistOperations() {
        do {
            let data = try JSONEncoder().encode(queuedOperations)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
        }
    }
    
    private func loadPersistedOperations() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        
        do {
            queuedOperations = try JSONDecoder().decode([SyncOperation].self, from: data)
        } catch {
            queuedOperations = []
        }
    }
    
    // MARK: - Statistics
    
    var queueInfo: QueueInfo {
        QueueInfo(
            totalOperations: queuedOperations.count,
            pendingOperations: queuedOperations.filter { !$0.isProcessing }.count,
            processingOperations: queuedOperations.filter { $0.isProcessing }.count,
            failedOperations: queuedOperations.filter { $0.retryCount >= maxRetries }.count,
            oldestOperation: queuedOperations.map { $0.timestamp }.min()
        )
    }
    
    deinit {
        processingTimer?.invalidate()
    }
}

// MARK: - Queue Statistics
class QueueStatistics: ObservableObject {
    @Published private(set) var queued: [String: Int] = [:]
    @Published private(set) var processed: [String: Int] = [:]
    @Published private(set) var retried: [String: Int] = [:]
    @Published private(set) var failed: [String: Int] = [:]
    
    func incrementQueued(for type: SyncDataType) {
        queued[type.rawValue, default: 0] += 1
    }
    
    func incrementProcessed(for type: SyncDataType) {
        processed[type.rawValue, default: 0] += 1
    }
    
    func incrementRetried(for type: SyncDataType) {
        retried[type.rawValue, default: 0] += 1
    }
    
    func incrementFailed(for type: SyncDataType) {
        failed[type.rawValue, default: 0] += 1
    }
    
    func reset() {
        queued.removeAll()
        processed.removeAll()
        retried.removeAll()
        failed.removeAll()
    }
    
    var totalQueued: Int { queued.values.reduce(0, +) }
    var totalProcessed: Int { processed.values.reduce(0, +) }
    var totalRetried: Int { retried.values.reduce(0, +) }
    var totalFailed: Int { failed.values.reduce(0, +) }
    
    var successRate: Double {
        let total = totalProcessed + totalFailed
        guard total > 0 else { return 1.0 }
        return Double(totalProcessed) / Double(total)
    }
}

struct QueueInfo {
    let totalOperations: Int
    let pendingOperations: Int
    let processingOperations: Int
    let failedOperations: Int
    let oldestOperation: Date?
}
