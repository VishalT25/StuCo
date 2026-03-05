import Foundation
import SwiftUI
import Combine

// MARK: - Performance Metrics
struct PerformanceMetrics {
    let timestamp: Date
    let operation: String
    let duration: TimeInterval
    let success: Bool
    let dataSize: Int?
    let networkLatency: TimeInterval?
    let cacheHit: Bool?
    let memoryUsage: UInt64?
    let cpuUsage: Double?
    
    var formattedDuration: String {
        if duration < 0.001 {
            return String(format: "%.2fμs", duration * 1_000_000)
        } else if duration < 1.0 {
            return String(format: "%.2fms", duration * 1000)
        } else {
            return String(format: "%.2fs", duration)
        }
    }
}

struct AggregatedMetrics {
    let operation: String
    let totalOperations: Int
    let averageDuration: TimeInterval
    let minDuration: TimeInterval
    let maxDuration: TimeInterval
    let successRate: Double
    let averageDataSize: Double?
    let averageNetworkLatency: TimeInterval?
    let cacheHitRate: Double?
    let timeRange: DateInterval
    
    var formattedAverageDuration: String {
        if averageDuration < 0.001 {
            return String(format: "%.2fμs", averageDuration * 1_000_000)
        } else if averageDuration < 1.0 {
            return String(format: "%.2fms", averageDuration * 1000)
        } else {
            return String(format: "%.2fs", averageDuration)
        }
    }
}

// MARK: - Performance Monitor
@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    // MARK: - Published Properties
    @Published private(set) var recentMetrics: [PerformanceMetrics] = []
    @Published private(set) var aggregatedMetrics: [String: AggregatedMetrics] = [:]
    @Published private(set) var systemHealth: SystemHealth = SystemHealth()
    @Published private(set) var isMonitoring = false
    @Published private(set) var monitoringStartTime: Date?
    
    // MARK: - Configuration
    private let maxMetricsToKeep = 1000
    private let aggregationInterval: TimeInterval = 60 // 1 minute
    private let healthCheckInterval: TimeInterval = 30 // 30 seconds
    
    // MARK: - Private Properties
    private var metricsBuffer: [PerformanceMetrics] = []
    private var aggregationTimer: Timer?
    private var healthCheckTimer: Timer?
    private let monitoringQueue = DispatchQueue(label: "performance.monitoring", qos: .utility)
    
    // Performance tracking
    private var activeOperations: [String: Date] = [:]
    private let operationLock = NSLock()
    
    private init() {}
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        monitoringStartTime = Date()
        
        startAggregationTimer()
        startHealthCheckTimer()
        
        print("📊 PerformanceMonitor: Monitoring started")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        aggregationTimer?.invalidate()
        healthCheckTimer?.invalidate()
        
        print("📊 PerformanceMonitor: Monitoring stopped")
    }
    
    private func startAggregationTimer() {
        aggregationTimer = Timer.scheduledTimer(withTimeInterval: aggregationInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.performAggregation()
            }
        }
    }
    
    private func startHealthCheckTimer() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.updateSystemHealth()
            }
        }
    }
    
    // MARK: - Operation Tracking
    
    func startOperation(_ operation: String) -> String {
        let operationId = UUID().uuidString
        let startTime = Date()
        
        operationLock.withLock {
            activeOperations[operationId] = startTime
        }
        
        return operationId
    }
    
    func endOperation(
        _ operationId: String,
        operation: String,
        success: Bool = true,
        dataSize: Int? = nil,
        networkLatency: TimeInterval? = nil,
        cacheHit: Bool? = nil
    ) {
        let endTime = Date()
        var duration: TimeInterval = 0
        
        operationLock.withLock {
            if let startTime = activeOperations.removeValue(forKey: operationId) {
                duration = endTime.timeIntervalSince(startTime)
            }
        }
        
        let metrics = PerformanceMetrics(
            timestamp: endTime,
            operation: operation,
            duration: duration,
            success: success,
            dataSize: dataSize,
            networkLatency: networkLatency,
            cacheHit: cacheHit,
            memoryUsage: getCurrentMemoryUsage(),
            cpuUsage: getCurrentCPUUsage()
        )
        
        recordMetrics(metrics)
    }
    
    func measureOperation<T>(
        _ operation: String,
        dataSize: Int? = nil,
        block: () async throws -> T
    ) async throws -> T {
        let operationId = startOperation(operation)
        let startTime = Date()
        
        do {
            let result = try await block()
            let networkLatency = measureNetworkLatency()
            
            endOperation(
                operationId,
                operation: operation,
                success: true,
                dataSize: dataSize,
                networkLatency: networkLatency
            )
            
            return result
        } catch {
            endOperation(
                operationId,
                operation: operation,
                success: false,
                dataSize: dataSize
            )
            throw error
        }
    }
    
    func measureSyncOperation<T>(
        _ operation: String,
        dataSize: Int? = nil,
        block: () throws -> T
    ) throws -> T {
        let operationId = startOperation(operation)
        
        do {
            let result = try block()
            
            endOperation(
                operationId,
                operation: operation,
                success: true,
                dataSize: dataSize
            )
            
            return result
        } catch {
            endOperation(
                operationId,
                operation: operation,
                success: false,
                dataSize: dataSize
            )
            throw error
        }
    }
    
    // MARK: - Metrics Recording & Management
    
    private func recordMetrics(_ metrics: PerformanceMetrics) {
        monitoringQueue.async {
            self.metricsBuffer.append(metrics)
            
            // Batch update UI
            if self.metricsBuffer.count >= 10 || Date().timeIntervalSince(metrics.timestamp) > 5.0 {
                Task { @MainActor in
                    self.flushMetricsBuffer()
                }
            }
        }
    }
    
    private func flushMetricsBuffer() {
        guard !metricsBuffer.isEmpty else { return }
        
        recentMetrics.append(contentsOf: metricsBuffer)
        metricsBuffer.removeAll()
        
        // Keep only recent metrics
        if recentMetrics.count > maxMetricsToKeep {
            recentMetrics = Array(recentMetrics.suffix(maxMetricsToKeep))
        }
        
        // Update real-time statistics
        updateRealTimeStats()
    }
    
    private func updateRealTimeStats() {
        let recentOperations = recentMetrics.suffix(100)
        
        systemHealth.averageResponseTime = recentOperations.isEmpty ? 0 : 
            recentOperations.reduce(0) { $0 + $1.duration } / Double(recentOperations.count)
        
        systemHealth.successRate = recentOperations.isEmpty ? 1.0 :
            Double(recentOperations.filter { $0.success }.count) / Double(recentOperations.count)
        
        if let latestMemory = recentOperations.last?.memoryUsage {
            systemHealth.memoryUsage = latestMemory
        }
        
        if let latestCPU = recentOperations.last?.cpuUsage {
            systemHealth.cpuUsage = latestCPU
        }
        
        systemHealth.lastUpdated = Date()
    }
    
    // MARK: - Aggregation
    
    private func performAggregation() async {
        let cutoffTime = Date().addingTimeInterval(-aggregationInterval * 10) // Last 10 intervals
        let relevantMetrics = recentMetrics.filter { $0.timestamp > cutoffTime }
        
        let groupedMetrics = Dictionary(grouping: relevantMetrics) { $0.operation }
        
        var newAggregatedMetrics: [String: AggregatedMetrics] = [:]
        
        for (operation, metrics) in groupedMetrics {
            guard !metrics.isEmpty else { continue }
            
            let durations = metrics.map { $0.duration }
            let successfulOperations = metrics.filter { $0.success }
            let dataSizes = metrics.compactMap { $0.dataSize }
            let networkLatencies = metrics.compactMap { $0.networkLatency }
            let cacheHits = metrics.compactMap { $0.cacheHit }
            
            let timeRange = DateInterval(
                start: metrics.map { $0.timestamp }.min() ?? Date(),
                end: metrics.map { $0.timestamp }.max() ?? Date()
            )
            
            let aggregated = AggregatedMetrics(
                operation: operation,
                totalOperations: metrics.count,
                averageDuration: durations.reduce(0, +) / Double(durations.count),
                minDuration: durations.min() ?? 0,
                maxDuration: durations.max() ?? 0,
                successRate: Double(successfulOperations.count) / Double(metrics.count),
                averageDataSize: dataSizes.isEmpty ? nil : Double(dataSizes.reduce(0, +)) / Double(dataSizes.count),
                averageNetworkLatency: networkLatencies.isEmpty ? nil : networkLatencies.reduce(0, +) / Double(networkLatencies.count),
                cacheHitRate: cacheHits.isEmpty ? nil : Double(cacheHits.filter { $0 }.count) / Double(cacheHits.count),
                timeRange: timeRange
            )
            
            newAggregatedMetrics[operation] = aggregated
        }
        
        aggregatedMetrics = newAggregatedMetrics
    }
    
    // MARK: - System Health Monitoring
    
    private func updateSystemHealth() async {
        systemHealth.isOnline = await checkConnectivity()
        systemHealth.databaseHealth = await checkDatabaseHealth()
        systemHealth.cacheHealth = await checkCacheHealth()
        systemHealth.syncHealth = await checkSyncHealth()
        
        // Update performance scores
        systemHealth.performanceScore = calculatePerformanceScore()
        systemHealth.lastHealthCheck = Date()
    }
    
    private func checkConnectivity() async -> Bool {
        return SupabaseService.shared.isConnected
    }
    
    private func checkDatabaseHealth() async -> HealthStatus {
        let databaseOperations = recentMetrics.filter { $0.operation.contains("database") || $0.operation.contains("supabase") }
        
        guard !databaseOperations.isEmpty else { return .unknown }
        
        let recentOperations = databaseOperations.suffix(10)
        let successRate = Double(recentOperations.filter { $0.success }.count) / Double(recentOperations.count)
        let averageLatency = recentOperations.reduce(0) { $0 + $1.duration } / Double(recentOperations.count)
        
        if successRate >= 0.95 && averageLatency < 1.0 {
            return .healthy
        } else if successRate >= 0.8 && averageLatency < 3.0 {
            return .warning
        } else {
            return .unhealthy
        }
    }
    
    private func checkCacheHealth() async -> HealthStatus {
        let cacheOperations = recentMetrics.filter { $0.operation.contains("cache") }
        
        guard !cacheOperations.isEmpty else { return .unknown }
        
        let cacheHits = cacheOperations.compactMap { $0.cacheHit }
        guard !cacheHits.isEmpty else { return .unknown }
        
        let hitRate = Double(cacheHits.filter { $0 }.count) / Double(cacheHits.count)
        
        if hitRate >= 0.8 {
            return .healthy
        } else if hitRate >= 0.6 {
            return .warning
        } else {
            return .unhealthy
        }
    }
    
    private func checkSyncHealth() async -> HealthStatus {
        let syncOperations = recentMetrics.filter { $0.operation.contains("sync") }
        
        guard !syncOperations.isEmpty else { return .unknown }
        
        let recentSyncs = syncOperations.suffix(5)
        let successRate = Double(recentSyncs.filter { $0.success }.count) / Double(recentSyncs.count)
        
        if successRate >= 0.9 {
            return .healthy
        } else if successRate >= 0.7 {
            return .warning
        } else {
            return .unhealthy
        }
    }
    
    private func calculatePerformanceScore() -> Double {
        var score = 1.0
        
        // Factor in success rate
        score *= systemHealth.successRate
        
        // Factor in response time (penalize slow responses)
        let responseTimePenalty = min(systemHealth.averageResponseTime / 2.0, 0.5)
        score *= (1.0 - responseTimePenalty)
        
        // Factor in memory usage (penalize high memory usage)
        let memoryGB = Double(systemHealth.memoryUsage) / (1024 * 1024 * 1024)
        let memoryPenalty = min(memoryGB / 4.0, 0.3) // Penalize if > 4GB
        score *= (1.0 - memoryPenalty)
        
        // Factor in CPU usage
        let cpuPenalty = min(systemHealth.cpuUsage / 100.0, 0.2)
        score *= (1.0 - cpuPenalty)
        
        return max(0.0, score)
    }
    
    // MARK: - System Metrics
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = task_thread_times_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_thread_times_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_THREAD_TIMES_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        let totalTime = Double(info.user_time.seconds + info.system_time.seconds) +
                       Double(info.user_time.microseconds + info.system_time.microseconds) / 1_000_000
        
        // This is a simplified CPU calculation - in practice, you'd track delta over time
        return min(totalTime * 100.0, 100.0)
    }
    
    private func measureNetworkLatency() -> TimeInterval? {
        // This would measure actual network latency to Supabase
        // For now, return nil - this would be implemented with ping or connection timing
        return nil
    }
    
    // MARK: - Analytics & Reporting
    
    func getOperationAnalytics() -> OperationAnalytics {
        let totalOperations = recentMetrics.count
        let successfulOperations = recentMetrics.filter { $0.success }.count
        let operationTypes = Set(recentMetrics.map { $0.operation }).count
        
        let averageResponseTime = recentMetrics.isEmpty ? 0 :
            recentMetrics.reduce(0) { $0 + $1.duration } / Double(recentMetrics.count)
        
        let operationDistribution = Dictionary(recentMetrics.map { ($0.operation, 1) }, uniquingKeysWith: +)
        let performanceByOperation = aggregatedMetrics.mapValues { $0.formattedAverageDuration }
        
        return OperationAnalytics(
            totalOperations: totalOperations,
            successfulOperations: successfulOperations,
            operationTypes: operationTypes,
            averageResponseTime: averageResponseTime,
            operationDistribution: operationDistribution,
            performanceByOperation: performanceByOperation
        )
    }
    
    func exportMetrics() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let export = MetricsExport(
            exportDate: Date(),
            monitoringDuration: monitoringStartTime.map { Date().timeIntervalSince($0) },
            systemHealth: systemHealth,
            recentMetrics: Array(recentMetrics.suffix(100)), // Last 100 operations
            aggregatedMetrics: Array(aggregatedMetrics.values),
            analytics: getOperationAnalytics()
        )
        
        do {
            let data = try encoder.encode(export)
            return String(data: data, encoding: .utf8) ?? "Export failed"
        } catch {
            return "Export error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Cleanup
    
    func clearMetrics() {
        recentMetrics.removeAll()
        aggregatedMetrics.removeAll()
        metricsBuffer.removeAll()
        systemHealth = SystemHealth()
    }
    
    deinit {
        aggregationTimer?.invalidate()
        healthCheckTimer?.invalidate()
    }
}

// MARK: - Supporting Types

enum HealthStatus: String, Codable {
    case healthy = "healthy"
    case warning = "warning"
    case unhealthy = "unhealthy"
    case unknown = "unknown"
    
    var color: Color {
        switch self {
        case .healthy: return .green
        case .warning: return .yellow
        case .unhealthy: return .red
        case .unknown: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .unhealthy: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

struct SystemHealth: Codable {
    var isOnline: Bool = false
    var databaseHealth: HealthStatus = .unknown
    var cacheHealth: HealthStatus = .unknown
    var syncHealth: HealthStatus = .unknown
    var averageResponseTime: TimeInterval = 0
    var successRate: Double = 1.0
    var memoryUsage: UInt64 = 0
    var cpuUsage: Double = 0
    var performanceScore: Double = 1.0
    var lastUpdated: Date = Date()
    var lastHealthCheck: Date?
    
    var overallHealth: HealthStatus {
        let healthValues: [HealthStatus] = [databaseHealth, cacheHealth, syncHealth]
        
        if healthValues.contains(.unhealthy) {
            return .unhealthy
        } else if healthValues.contains(.warning) {
            return .warning
        } else if healthValues.allSatisfy({ $0 == .healthy }) {
            return .healthy
        } else {
            return .unknown
        }
    }
    
    var formattedMemoryUsage: String {
        let mb = Double(memoryUsage) / (1024 * 1024)
        if mb < 1024 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.2f GB", mb / 1024)
        }
    }
    
    var formattedPerformanceScore: String {
        return String(format: "%.1f%%", performanceScore * 100)
    }
}

struct OperationAnalytics {
    let totalOperations: Int
    let successfulOperations: Int
    let operationTypes: Int
    let averageResponseTime: TimeInterval
    let operationDistribution: [String: Int]
    let performanceByOperation: [String: String]
    
    var successRate: Double {
        guard totalOperations > 0 else { return 1.0 }
        return Double(successfulOperations) / Double(totalOperations)
    }
    
    var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate * 100)
    }
    
    var formattedAverageResponseTime: String {
        if averageResponseTime < 0.001 {
            return String(format: "%.2fμs", averageResponseTime * 1_000_000)
        } else if averageResponseTime < 1.0 {
            return String(format: "%.2fms", averageResponseTime * 1000)
        } else {
            return String(format: "%.2fs", averageResponseTime)
        }
    }
}

struct MetricsExport: Codable {
    let exportDate: Date
    let monitoringDuration: TimeInterval?
    let systemHealth: SystemHealth
    let recentMetrics: [PerformanceMetrics]
    let aggregatedMetrics: [AggregatedMetrics]
    let analytics: OperationAnalytics
}

// MARK: - Codable Conformance

extension PerformanceMetrics: Codable {
    enum CodingKeys: String, CodingKey {
        case timestamp, operation, duration, success, dataSize, networkLatency, cacheHit, memoryUsage, cpuUsage
    }
}

extension AggregatedMetrics: Codable {
    enum CodingKeys: String, CodingKey {
        case operation, totalOperations, averageDuration, minDuration, maxDuration
        case successRate, averageDataSize, averageNetworkLatency, cacheHitRate, timeRange
    }
}

extension OperationAnalytics: Codable {
    enum CodingKeys: String, CodingKey {
        case totalOperations, successfulOperations, operationTypes, averageResponseTime
        case operationDistribution, performanceByOperation
    }
}