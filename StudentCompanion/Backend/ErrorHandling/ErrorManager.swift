import Foundation
import SwiftUI
import Network

// MARK: - Error Types
enum AppError: Error, LocalizedError, Identifiable {
    case network(NetworkError)
    case database(DatabaseError)
    case authentication(AuthenticationError)
    case sync(SyncError)
    case validation(ValidationError)
    case cache(CacheError)
    case migration(MigrationError)
    case system(SystemError)
    case unknown(Error)
    
    var id: String {
        return errorDescription ?? "unknown_error"
    }
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            return "Network Error: \(error.localizedDescription)"
        case .database(let error):
            return "Database Error: \(error.localizedDescription)"
        case .authentication(let error):
            return "Authentication Error: \(error.localizedDescription)"
        case .sync(let error):
            return "Sync Error: \(error.localizedDescription)"
        case .validation(let error):
            return "Validation Error: \(error.localizedDescription)"
        case .cache(let error):
            return "Cache Error: \(error.localizedDescription)"
        case .migration(let error):
            return "Migration Error: \(error.localizedDescription)"
        case .system(let error):
            return "System Error: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown Error: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .network:
            return "Check your internet connection and try again."
        case .database:
            return "The operation will be retried automatically."
        case .authentication:
            return "Please sign in again."
        case .sync:
            return "Data will be synchronized when connection is restored."
        case .validation:
            return "Please check your input and try again."
        case .cache:
            return "Clear cache and restart the app if the problem persists."
        case .migration:
            return "Contact support if this issue continues."
        case .system:
            return "Restart the app and try again."
        case .unknown:
            return "If the problem persists, please contact support."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .authentication, .migration, .system:
            return .critical
        case .database, .sync:
            return .high
        case .network, .cache:
            return .medium
        case .validation:
            return .low
        case .unknown:
            return .high
        }
    }
    
    var category: ErrorCategory {
        switch self {
        case .network:
            return .connectivity
        case .database, .cache, .migration:
            return .data
        case .authentication:
            return .security
        case .sync:
            return .synchronization
        case .validation:
            return .userInput
        case .system, .unknown:
            return .system
        }
    }
}

enum NetworkError: Error, LocalizedError {
    case noConnection
    case timeout
    case serverError(Int)
    case rateLimited
    case invalidResponse
    case dnsFailure
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection available"
        case .timeout:
            return "Request timed out"
        case .serverError(let code):
            return "Server error (Code: \(code))"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .invalidResponse:
            return "Invalid response from server"
        case .dnsFailure:
            return "DNS resolution failed"
        }
    }
}

enum DatabaseError: Error, LocalizedError {
    case connectionFailed
    case queryFailed(String)
    case constraintViolation
    case dataCorruption
    case permissionDenied
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to database"
        case .queryFailed(let query):
            return "Database query failed: \(query)"
        case .constraintViolation:
            return "Data constraint violation"
        case .dataCorruption:
            return "Data corruption detected"
        case .permissionDenied:
            return "Database permission denied"
        case .quotaExceeded:
            return "Database quota exceeded"
        }
    }
}

enum AuthenticationError: Error, LocalizedError {
    case invalidCredentials
    case sessionExpired
    case accountLocked
    case mfaRequired
    case emailNotVerified
    case tokenInvalid
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .sessionExpired:
            return "Session expired. Please sign in again."
        case .accountLocked:
            return "Account is temporarily locked"
        case .mfaRequired:
            return "Multi-factor authentication required"
        case .emailNotVerified:
            return "Please verify your email address"
        case .tokenInvalid:
            return "Authentication token is invalid"
        }
    }
}

enum CacheError: Error, LocalizedError {
    case storageFailure
    case corruptedData
    case quotaExceeded
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .storageFailure:
            return "Failed to write to cache"
        case .corruptedData:
            return "Cached data is corrupted"
        case .quotaExceeded:
            return "Cache storage quota exceeded"
        case .accessDenied:
            return "Cache access denied"
        }
    }
}

enum SystemError: Error, LocalizedError {
    case memoryPressure
    case diskSpaceExhausted
    case cpuOverload
    case permissionDenied
    case fileSystemError
    
    var errorDescription: String? {
        switch self {
        case .memoryPressure:
            return "System is low on memory"
        case .diskSpaceExhausted:
            return "Insufficient disk space"
        case .cpuOverload:
            return "System CPU overloaded"
        case .permissionDenied:
            return "System permission denied"
        case .fileSystemError:
            return "File system error"
        }
    }
}

enum ErrorSeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.octagon"
        case .critical: return "xmark.octagon.fill"
        }
    }
}

enum ErrorCategory: String, CaseIterable, Codable {
    case connectivity = "connectivity"
    case data = "data"
    case security = "security"
    case synchronization = "synchronization"
    case userInput = "user_input"
    case system = "system"
}

// MARK: - Retry Configuration
struct RetryConfiguration {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double
    let jitterEnabled: Bool
    
    static let `default` = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0,
        jitterEnabled: true
    )
    
    static let aggressive = RetryConfiguration(
        maxAttempts: 5,
        baseDelay: 0.5,
        maxDelay: 10.0,
        backoffMultiplier: 1.5,
        jitterEnabled: true
    )
    
    static let conservative = RetryConfiguration(
        maxAttempts: 2,
        baseDelay: 2.0,
        maxDelay: 60.0,
        backoffMultiplier: 3.0,
        jitterEnabled: false
    )
    
    func calculateDelay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(backoffMultiplier, Double(attempt - 1))
        let clampedDelay = min(exponentialDelay, maxDelay)
        
        if jitterEnabled {
            let jitter = Double.random(in: 0.8...1.2)
            return clampedDelay * jitter
        } else {
            return clampedDelay
        }
    }
}

// MARK: - Error Manager
@MainActor
class ErrorManager: ObservableObject {
    static let shared = ErrorManager()
    
    // MARK: - Published Properties
    @Published private(set) var recentErrors: [ErrorRecord] = []
    @Published private(set) var activeRetries: [RetryOperation] = []
    @Published private(set) var errorStatistics = ErrorStatistics()
    @Published private(set) var systemAlerts: [SystemAlert] = []
    
    // MARK: - Configuration
    private let maxErrorsToKeep = 100
    private let errorRetentionDuration: TimeInterval = 86400 // 24 hours
    
    // MARK: - Dependencies
    private let performanceMonitor = PerformanceMonitor.shared
    private let networkMonitor = NetworkMonitor.shared
    
    // MARK: - Private Properties
    private var retryQueue = DispatchQueue(label: "error.retry", qos: .utility)
    private var errorPersistence = ErrorPersistence()
    
    private init() {
        loadPersistedErrors()
        setupCleanupTimer()
    }
    
    // MARK: - Error Handling
    
    func handle(_ error: Error, context: ErrorContext? = nil) {
        let appError = classifyError(error)
        let errorRecord = ErrorRecord(
            error: appError,
            context: context,
            timestamp: Date(),
            stackTrace: Thread.callStackSymbols
        )
        
        recordError(errorRecord)
        
        // Determine if this error should trigger a retry
        if shouldRetry(appError, context: context) {
            scheduleRetry(for: errorRecord)
        }
        
        // Check if this should trigger a system alert
        if appError.severity == .critical {
            createSystemAlert(for: appError, context: context)
        }
        
        // Log to performance monitor
        let operationId = performanceMonitor.startOperation("error_handling")
        performanceMonitor.endOperation(
            operationId,
            operation: "error_handling",
            success: true,
            dataSize: nil
        )
    }
    
    func handleAsync<T>(
        operation: @escaping () async throws -> T,
        context: ErrorContext? = nil,
        retryConfig: RetryConfiguration = .default
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...retryConfig.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                let appError = classifyError(error)
                
                // Record the error
                let errorRecord = ErrorRecord(
                    error: appError,
                    context: context,
                    timestamp: Date(),
                    stackTrace: Thread.callStackSymbols,
                    attempt: attempt
                )
                
                recordError(errorRecord)
                
                // Check if we should retry
                if attempt < retryConfig.maxAttempts && shouldRetry(appError, context: context) {
                    let delay = retryConfig.calculateDelay(for: attempt)
                    
                    // Record retry attempt
                    recordRetryAttempt(errorRecord, delay: delay)
                    
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    break
                }
            }
        }
        
        throw lastError ?? AppError.unknown(NSError(domain: "UnknownError", code: 0))
    }
    
    private func classifyError(_ error: Error) -> AppError {
        switch error {
        case let appError as AppError:
            return appError
            
        case let urlError as URLError:
            return .network(classifyURLError(urlError))
            
        case let nsError as NSError where nsError.domain == "SupabaseError":
            return .database(classifySupabaseError(nsError))
            
        case let authError as AuthError:
            return .authentication(classifyAuthError(authError))
            
        default:
            return .unknown(error)
        }
    }
    
    private func classifyURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .timedOut:
            return .timeout
        case .cannotFindHost, .dnsLookupFailed:
            return .dnsFailure
        case .httpTooManyRedirects, .resourceUnavailable:
            return .serverError(error.errorCode)
        default:
            return .invalidResponse
        }
    }
    
    private func classifySupabaseError(_ error: NSError) -> DatabaseError {
        switch error.code {
        case 401, 403:
            return .permissionDenied
        case 429:
            return .constraintViolation
        case 500, 502, 503:
            return .connectionFailed
        default:
            return .queryFailed(error.localizedDescription)
        }
    }
    
    private func classifyAuthError(_ error: AuthError) -> AuthenticationError {
        switch error {
        case .invalidEmail, .weakPassword, .authenticationFailed:
            return .invalidCredentials
        case .registrationFailed:
            return .emailNotVerified
        case .emailAlreadyExists, .emailAlreadyInUse:
            return .invalidCredentials // User trying to register with existing email
        case .emailNotConfirmed:
            return .emailNotVerified
        case .resetPasswordFailed:
            return .tokenInvalid // Generic token/auth issue for password reset failures
        case .storageError:
            return .tokenInvalid
        case .missingConfiguration:
            return .tokenInvalid
        case .notAuthenticated:
            return .tokenInvalid
        case .rateLimitExceeded:
            return .invalidCredentials // Treat rate limit as temporary auth issue
        case .accountDeletionFailed:
            return .tokenInvalid
        }
    }
    
    // MARK: - Retry Logic
    
    private func shouldRetry(_ error: AppError, context: ErrorContext?) -> Bool {
        switch error {
        case .network(.noConnection), .network(.timeout):
            return networkMonitor.isConnected
        case .database(.connectionFailed), .database(.queryFailed):
            return true
        case .authentication(.sessionExpired), .authentication(.tokenInvalid):
            return true
        case .sync:
            return true
        default:
            return false
        }
    }
    
    private func scheduleRetry(for errorRecord: ErrorRecord) {
        let retryOperation = RetryOperation(
            id: UUID(),
            errorRecord: errorRecord,
            scheduledTime: Date().addingTimeInterval(5.0), // Default 5 second delay
            maxAttempts: 3,
            currentAttempt: 0
        )
        
        activeRetries.append(retryOperation)
        
        retryQueue.asyncAfter(deadline: .now() + 5.0) {
            Task { @MainActor in
                await self.executeRetry(retryOperation)
            }
        }
    }
    
    private func executeRetry(_ operation: RetryOperation) async {
        guard let index = activeRetries.firstIndex(where: { $0.id == operation.id }) else {
            return
        }
        
        activeRetries[index].currentAttempt += 1
        
        // For now, just remove the retry operation
        // In a full implementation, this would re-execute the failed operation
        activeRetries.removeAll { $0.id == operation.id }
    }
    
    private func recordRetryAttempt(_ errorRecord: ErrorRecord, delay: TimeInterval) {
        errorStatistics.incrementRetry(for: errorRecord.error.category)
    }
    
    // MARK: - Error Recording & Management
    
    private func recordError(_ errorRecord: ErrorRecord) {
        recentErrors.append(errorRecord)
        
        // Keep only recent errors
        if recentErrors.count > maxErrorsToKeep {
            recentErrors = Array(recentErrors.suffix(maxErrorsToKeep))
        }
        
        // Update statistics
        errorStatistics.recordError(errorRecord.error)
        
        // Persist error
        errorPersistence.save(errorRecord)
        
        print("❌ ErrorManager: \(errorRecord.error.errorDescription ?? "Unknown error")")
    }
    
    private func createSystemAlert(for error: AppError, context: ErrorContext?) {
        let alert = SystemAlert(
            id: UUID(),
            title: "Critical Error",
            message: error.errorDescription ?? "An unknown critical error occurred",
            severity: error.severity,
            category: error.category,
            timestamp: Date(),
            isResolved: false,
            context: context
        )
        
        systemAlerts.append(alert)
        
        // Auto-resolve non-critical alerts after some time
        if error.severity != .critical {
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) { // 5 minutes
                self.resolveAlert(alert.id)
            }
        }
    }
    
    func resolveAlert(_ alertId: UUID) {
        if let index = systemAlerts.firstIndex(where: { $0.id == alertId }) {
            systemAlerts[index].isResolved = true
            systemAlerts[index].resolvedAt = Date()
        }
    }
    
    func dismissAlert(_ alertId: UUID) {
        systemAlerts.removeAll { $0.id == alertId }
    }
    
    // MARK: - Analytics & Reporting
    
    func getErrorReport() -> ErrorReport {
        let timeRange = DateInterval(
            start: Date().addingTimeInterval(-errorRetentionDuration),
            end: Date()
        )
        
        let relevantErrors = recentErrors.filter { timeRange.contains($0.timestamp) }
        
        let errorsByCategory = Dictionary(grouping: relevantErrors, by: { $0.error.category })
        let errorsBySeverity = Dictionary(grouping: relevantErrors, by: { $0.error.severity })
        let errorsByHour = Dictionary(grouping: relevantErrors, by: { Calendar.current.component(.hour, from: $0.timestamp) })
        
        return ErrorReport(
            timeRange: timeRange,
            totalErrors: relevantErrors.count,
            errorsByCategory: errorsByCategory.mapValues { $0.count },
            errorsBySeverity: errorsBySeverity.mapValues { $0.count },
            errorsByHour: errorsByHour.mapValues { $0.count },
            mostCommonErrors: getMostCommonErrors(from: relevantErrors),
            activeRetries: activeRetries.count,
            systemAlerts: systemAlerts.filter { !$0.isResolved }.count
        )
    }
    
    private func getMostCommonErrors(from errors: [ErrorRecord]) -> [MostCommonError] {
        let errorCounts = Dictionary(errors.map { ($0.error.errorDescription ?? "Unknown", 1) }, uniquingKeysWith: +)
        return errorCounts
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { MostCommonError(message: $0.key, occurrences: $0.value) }
    }
    
    func exportErrorLog() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let export = ErrorLogExport(
            exportDate: Date(),
            errors: Array(recentErrors.suffix(50)), // Last 50 errors
            statistics: errorStatistics,
            systemAlerts: systemAlerts,
            report: getErrorReport()
        )
        
        do {
            let data = try encoder.encode(export)
            return String(data: data, encoding: .utf8) ?? "Export failed"
        } catch {
            return "Export error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Cleanup & Maintenance
    
    private func setupCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in // Every hour
            Task { @MainActor in
                self.cleanupOldErrors()
                self.cleanupResolvedAlerts()
            }
        }
    }
    
    private func cleanupOldErrors() {
        let cutoffDate = Date().addingTimeInterval(-errorRetentionDuration)
        recentErrors.removeAll { $0.timestamp < cutoffDate }
    }
    
    private func cleanupResolvedAlerts() {
        let cutoffDate = Date().addingTimeInterval(-86400) // Remove resolved alerts after 24 hours
        systemAlerts.removeAll { alert in
            alert.isResolved && (alert.resolvedAt ?? Date.distantPast) < cutoffDate
        }
    }
    
    private func loadPersistedErrors() {
        recentErrors = errorPersistence.loadRecentErrors()
    }
    
    func clearErrorHistory() {
        recentErrors.removeAll()
        activeRetries.removeAll()
        systemAlerts.removeAll()
        errorStatistics = ErrorStatistics()
        errorPersistence.clearAll()
    }
}

// MARK: - Supporting Types

struct ErrorRecord: Identifiable, Codable {
    let id = UUID()
    let error: AppError
    let context: ErrorContext?
    let timestamp: Date
    let stackTrace: [String]
    let attempt: Int
    
    init(error: AppError, context: ErrorContext?, timestamp: Date, stackTrace: [String], attempt: Int = 1) {
        self.error = error
        self.context = context
        self.timestamp = timestamp
        self.stackTrace = stackTrace
        self.attempt = attempt
    }
}

struct ErrorContext: Codable {
    let operation: String
    let userId: String?
    let deviceInfo: [String: String]
    let appVersion: String
    let additionalData: [String: String]
    
    init(operation: String, userId: String? = nil, additionalData: [String: String] = [:]) {
        self.operation = operation
        self.userId = userId
        self.additionalData = additionalData
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        self.deviceInfo = [
            "model": UIDevice.current.model,
            "systemVersion": UIDevice.current.systemVersion,
            "systemName": UIDevice.current.systemName
        ]
    }
}

struct RetryOperation: Identifiable {
    let id: UUID
    let errorRecord: ErrorRecord
    let scheduledTime: Date
    let maxAttempts: Int
    var currentAttempt: Int
}

struct SystemAlert: Identifiable, Codable {
    let id: UUID
    let title: String
    let message: String
    let severity: ErrorSeverity
    let category: ErrorCategory
    let timestamp: Date
    var isResolved: Bool
    var resolvedAt: Date?
    let context: ErrorContext?
}

class ErrorStatistics: ObservableObject, Codable {
    @Published private(set) var totalErrors = 0
    @Published private(set) var errorsByCategory: [String: Int] = [:]
    @Published private(set) var errorsBySeverity: [String: Int] = [:]
    @Published private(set) var retriesAttempted = 0
    @Published private(set) var lastReset = Date()
    
    init() {}

    func recordError(_ error: AppError) {
        totalErrors += 1
        errorsByCategory[error.category.rawValue, default: 0] += 1
        errorsBySeverity[error.severity.rawValue, default: 0] += 1
    }
    
    func incrementRetry(for category: ErrorCategory) {
        retriesAttempted += 1
    }
    
    func reset() {
        totalErrors = 0
        errorsByCategory.removeAll()
        errorsBySeverity.removeAll()
        retriesAttempted = 0
        lastReset = Date()
    }
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case totalErrors, errorsByCategory, errorsBySeverity, retriesAttempted, lastReset
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalErrors = try container.decode(Int.self, forKey: .totalErrors)
        errorsByCategory = try container.decode([String: Int].self, forKey: .errorsByCategory)
        errorsBySeverity = try container.decode([String: Int].self, forKey: .errorsBySeverity)
        retriesAttempted = try container.decode(Int.self, forKey: .retriesAttempted)
        lastReset = try container.decode(Date.self, forKey: .lastReset)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalErrors, forKey: .totalErrors)
        try container.encode(errorsByCategory, forKey: .errorsByCategory)
        try container.encode(errorsBySeverity, forKey: .errorsBySeverity)
        try container.encode(retriesAttempted, forKey: .retriesAttempted)
        try container.encode(lastReset, forKey: .lastReset)
    }
}

struct MostCommonError: Codable {
    let message: String
    let occurrences: Int
}

struct ErrorReport: Codable {
    let timeRange: DateInterval
    let totalErrors: Int
    let errorsByCategory: [ErrorCategory: Int]
    let errorsBySeverity: [ErrorSeverity: Int]
    let errorsByHour: [Int: Int]
    let mostCommonErrors: [MostCommonError]
    let activeRetries: Int
    let systemAlerts: Int
    
    enum CodingKeys: String, CodingKey {
        case timeRangeStart
        case timeRangeEnd
        case totalErrors
        case errorsByCategory
        case errorsBySeverity
        case errorsByHour
        case mostCommonErrors
        case activeRetries
        case systemAlerts
    }
    
    init(
        timeRange: DateInterval,
        totalErrors: Int,
        errorsByCategory: [ErrorCategory: Int],
        errorsBySeverity: [ErrorSeverity: Int],
        errorsByHour: [Int: Int],
        mostCommonErrors: [MostCommonError],
        activeRetries: Int,
        systemAlerts: Int
    ) {
        self.timeRange = timeRange
        self.totalErrors = totalErrors
        self.errorsByCategory = errorsByCategory
        self.errorsBySeverity = errorsBySeverity
        self.errorsByHour = errorsByHour
        self.mostCommonErrors = mostCommonErrors
        self.activeRetries = activeRetries
        self.systemAlerts = systemAlerts
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let start = try container.decode(Date.self, forKey: .timeRangeStart)
        let end = try container.decode(Date.self, forKey: .timeRangeEnd)
        self.timeRange = DateInterval(start: start, end: end)
        
        self.totalErrors = try container.decode(Int.self, forKey: .totalErrors)
        self.errorsByHour = try container.decode([Int: Int].self, forKey: .errorsByHour)
        self.mostCommonErrors = try container.decode([MostCommonError].self, forKey: .mostCommonErrors)
        self.activeRetries = try container.decode(Int.self, forKey: .activeRetries)
        self.systemAlerts = try container.decode(Int.self, forKey: .systemAlerts)
        
        let categoryDict = try container.decode([String: Int].self, forKey: .errorsByCategory)
        self.errorsByCategory = Dictionary(uniqueKeysWithValues:
            categoryDict.compactMap { key, value in
                guard let category = ErrorCategory(rawValue: key) else { return nil }
                return (category, value)
            }
        )
        
        let severityDict = try container.decode([String: Int].self, forKey: .errorsBySeverity)
        self.errorsBySeverity = Dictionary(uniqueKeysWithValues:
            severityDict.compactMap { key, value in
                guard let severity = ErrorSeverity(rawValue: key) else { return nil }
                return (severity, value)
            }
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(timeRange.start, forKey: .timeRangeStart)
        try container.encode(timeRange.end, forKey: .timeRangeEnd)
        
        try container.encode(totalErrors, forKey: .totalErrors)
        try container.encode(errorsByHour, forKey: .errorsByHour)
        try container.encode(mostCommonErrors, forKey: .mostCommonErrors)
        try container.encode(activeRetries, forKey: .activeRetries)
        try container.encode(systemAlerts, forKey: .systemAlerts)
        
        let categoryDict = Dictionary(uniqueKeysWithValues: errorsByCategory.map { ($0.key.rawValue, $0.value) })
        try container.encode(categoryDict, forKey: .errorsByCategory)
        
        let severityDict = Dictionary(uniqueKeysWithValues: errorsBySeverity.map { ($0.key.rawValue, $0.value) })
        try container.encode(severityDict, forKey: .errorsBySeverity)
    }
}

struct ErrorLogExport: Codable {
    let exportDate: Date
    let errors: [ErrorRecord]
    let statistics: ErrorStatistics
    let systemAlerts: [SystemAlert]
    let report: ErrorReport
}

// MARK: - Error Persistence
class ErrorPersistence {
    private let userDefaults = UserDefaults.standard
    private let errorsKey = "persisted_errors"
    
    func save(_ errorRecord: ErrorRecord) {
        var errors = loadRecentErrors()
        errors.append(errorRecord)
        
        // Keep only last 50 errors
        if errors.count > 50 {
            errors = Array(errors.suffix(50))
        }
        
        do {
            let data = try JSONEncoder().encode(errors)
            userDefaults.set(data, forKey: errorsKey)
        } catch {
            print("Failed to persist error: \(error)")
        }
    }
    
    func loadRecentErrors() -> [ErrorRecord] {
        guard let data = userDefaults.data(forKey: errorsKey) else { return [] }
        
        do {
            return try JSONDecoder().decode([ErrorRecord].self, from: data)
        } catch {
            print("Failed to load persisted errors: \(error)")
            return []
        }
    }
    
    func clearAll() {
        userDefaults.removeObject(forKey: errorsKey)
    }
}

// MARK: - Network Monitor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: NWInterface.InterfaceType?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Codable Extensions
extension AppError: Codable {
    enum CodingKeys: String, CodingKey {
        case type, associatedValue
    }
    
    enum ErrorType: String, Codable {
        case network, database, authentication, sync, validation, cache, migration, system, unknown
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ErrorType.self, forKey: .type)
        
        switch type {
        case .network:
            let networkError = try container.decode(NetworkError.self, forKey: .associatedValue)
            self = .network(networkError)
        case .database:
            let dbError = try container.decode(DatabaseError.self, forKey: .associatedValue)
            self = .database(dbError)
        case .authentication:
            let authError = try container.decode(AuthenticationError.self, forKey: .associatedValue)
            self = .authentication(authError)
        case .cache:
            let cacheError = try container.decode(CacheError.self, forKey: .associatedValue)
            self = .cache(cacheError)
        case .system:
            let systemError = try container.decode(SystemError.self, forKey: .associatedValue)
            self = .system(systemError)
        default:
            // For other cases, create a generic error
            let message = try container.decode(String.self, forKey: .associatedValue)
            let genericError = NSError(domain: "AppError", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
            self = .unknown(genericError)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .network(let error):
            try container.encode(ErrorType.network, forKey: .type)
            try container.encode(error, forKey: .associatedValue)
        case .database(let error):
            try container.encode(ErrorType.database, forKey: .type)
            try container.encode(error, forKey: .associatedValue)
        case .authentication(let error):
            try container.encode(ErrorType.authentication, forKey: .type)
            try container.encode(error, forKey: .associatedValue)
        case .cache(let error):
            try container.encode(ErrorType.cache, forKey: .type)
            try container.encode(error, forKey: .associatedValue)
        case .system(let error):
            try container.encode(ErrorType.system, forKey: .type)
            try container.encode(error, forKey: .associatedValue)
        default:
            try container.encode(ErrorType.unknown, forKey: .type)
            try container.encode(self.localizedDescription, forKey: .associatedValue)
        }
    }
}

extension NetworkError: Codable {}
extension DatabaseError: Codable {}
extension AuthenticationError: Codable {}
extension CacheError: Codable {}
extension SystemError: Codable {}
