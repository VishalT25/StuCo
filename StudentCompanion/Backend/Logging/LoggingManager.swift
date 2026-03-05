import Foundation
import SwiftUI
import OSLog

// MARK: - Log Levels
enum LogLevel: String, CaseIterable, Comparable {
    case trace = "TRACE"
    case debug = "DEBUG" 
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var osLogType: OSLogType {
        switch self {
        case .trace, .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
    
    var color: Color {
        switch self {
        case .trace: return .purple
        case .debug: return .blue
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .trace: return "magnifyingglass"
        case .debug: return "ladybug"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .critical: return "flame"
        }
    }
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        let order: [LogLevel] = [.trace, .debug, .info, .warning, .error, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

// MARK: - Log Categories
enum LogCategory: String, CaseIterable {
    case authentication = "auth"
    case database = "database"
    case sync = "sync"
    case cache = "cache"
    case network = "network"
    case ui = "ui"
    case performance = "performance"
    case migration = "migration"
    case system = "system"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .authentication: return "Authentication"
        case .database: return "Database"
        case .sync: return "Synchronization"
        case .cache: return "Cache"
        case .network: return "Network"
        case .ui: return "User Interface"
        case .performance: return "Performance"
        case .migration: return "Migration"
        case .system: return "System"
        case .general: return "General"
        }
    }
    
    var osLog: OSLog {
        return OSLog(subsystem: "com.studentcompanion.app", category: self.rawValue)
    }
}

// MARK: - Log Entry
struct LogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let metadata: [String: String]
    let file: String
    let function: String
    let line: Int
    let thread: String
    let sessionId: String
    
    init(
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.file = URL(fileURLWithPath: file).lastPathComponent
        self.function = function
        self.line = line
        self.thread = Thread.isMainThread ? "main" : "background"
        self.sessionId = LoggingManager.shared.sessionId
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    var formattedMessage: String {
        let metadataString = metadata.isEmpty ? "" : " | " + metadata.map { "\($0)=\($1)" }.joined(separator: ", ")
        return "[\(formattedTimestamp)] [\(level.rawValue)] [\(category.displayName)] \(message)\(metadataString)"
    }
    
    var detailedMessage: String {
        return "\(formattedMessage)\n  at \(file):\(line) in \(function)() on \(thread) thread"
    }
}

// MARK: - Log Configuration
struct LogConfiguration {
    let minLevel: LogLevel
    let enabledCategories: Set<LogCategory>
    let maxLogEntries: Int
    let enableFileLogging: Bool
    let enableRemoteLogging: Bool
    let enablePerformanceLogging: Bool
    let logRetentionDays: Int
    
    static let development = LogConfiguration(
        minLevel: .trace,
        enabledCategories: Set(LogCategory.allCases),
        maxLogEntries: 10000,
        enableFileLogging: true,
        enableRemoteLogging: false,
        enablePerformanceLogging: true,
        logRetentionDays: 7
    )
    
    static let production = LogConfiguration(
        minLevel: .info,
        enabledCategories: Set([.authentication, .database, .sync, .network, .system]),
        maxLogEntries: 5000,
        enableFileLogging: true,
        enableRemoteLogging: true,
        enablePerformanceLogging: false,
        logRetentionDays: 30
    )
    
    static let testing = LogConfiguration(
        minLevel: .debug,
        enabledCategories: Set(LogCategory.allCases),
        maxLogEntries: 1000,
        enableFileLogging: false,
        enableRemoteLogging: false,
        enablePerformanceLogging: true,
        logRetentionDays: 1
    )
}

// MARK: - Logging Manager
@MainActor
class LoggingManager: ObservableObject {
    static let shared = LoggingManager()
    
    // MARK: - Published Properties
    @Published private(set) var logEntries: [LogEntry] = []
    @Published private(set) var isLogging = true
    @Published private(set) var currentConfiguration: LogConfiguration = .development
    @Published private(set) var logStatistics = LogStatistics()
    
    // MARK: - Session & Identity
    let sessionId = UUID().uuidString
    private let startTime = Date()
    
    // MARK: - File Logging
    private let fileManager = FileManager.default
    private let loggingQueue = DispatchQueue(label: "logging.queue", qos: .utility)
    private var currentLogFile: URL?
    
    // MARK: - Remote Logging
    private let remoteLogger = RemoteLogger()
    
    // MARK: - Performance Tracking
    private var performanceTimer: Timer?
    
    private init() {
        setupConfiguration()
        setupFileLogging()
        setupRemoteLogging()
        setupPerformanceLogging()
        setupCleanupTimer()
        
        // Log startup
        log(.info, category: .system, "LoggingManager initialized - Session: \(sessionId)")
    }
    
    // MARK: - Configuration
    
    private func setupConfiguration() {
        #if DEBUG
        currentConfiguration = .development
        #else
        currentConfiguration = .production
        #endif
    }
    
    func updateConfiguration(_ config: LogConfiguration) {
        currentConfiguration = config
        log(.info, category: .system, "Logging configuration updated", metadata: [
            "minLevel": config.minLevel.rawValue,
            "enabledCategories": "\(config.enabledCategories.count)",
            "fileLogging": "\(config.enableFileLogging)"
        ])
    }
    
    // MARK: - Main Logging Methods
    
    func log(
        _ level: LogLevel,
        category: LogCategory,
        _ message: String,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isLogging else { return }
        guard level >= currentConfiguration.minLevel else { return }
        guard currentConfiguration.enabledCategories.contains(category) else { return }
        
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
        
        processLogEntry(entry)
    }
    
    private func processLogEntry(_ entry: LogEntry) {
        // Add to in-memory log
        logEntries.append(entry)
        
        // Maintain size limit
        if logEntries.count > currentConfiguration.maxLogEntries {
            logEntries.removeFirst(logEntries.count - currentConfiguration.maxLogEntries)
        }
        
        // Update statistics
        logStatistics.recordEntry(entry)
        
        // OS Log
        os_log("%{public}@", log: entry.category.osLog, type: entry.level.osLogType, entry.formattedMessage)
        
        // Console log for debugging
        #if DEBUG
        #endif
        
        // File logging
        if currentConfiguration.enableFileLogging {
            writeToFile(entry)
        }
        
        // Remote logging for critical entries
        if currentConfiguration.enableRemoteLogging && entry.level >= .error {
            remoteLogger.send(entry)
        }
    }
    
    // MARK: - Convenience Methods
    
    func trace(_ message: String, category: LogCategory = .general, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(.trace, category: category, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    func debug(_ message: String, category: LogCategory = .general, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, category: category, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: LogCategory = .general, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, category: category, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: LogCategory = .general, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, category: category, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: LogCategory = .general, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, category: category, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, category: LogCategory = .general, metadata: [String: String] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(.critical, category: category, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    // MARK: - Structured Logging
    
    func logOperation<T>(
        _ operation: String,
        category: LogCategory,
        metadata: [String: String] = [:],
        block: () throws -> T
    ) rethrows -> T {
        let operationId = UUID().uuidString
        let startTime = Date()
        
        log(.debug, category: category, "Started: \(operation)", metadata: metadata.merging([
            "operationId": operationId
        ], uniquingKeysWith: { _, new in new }))
        
        do {
            let result = try block()
            let duration = Date().timeIntervalSince(startTime)
            
            log(.debug, category: category, "Completed: \(operation)", metadata: metadata.merging([
                "operationId": operationId,
                "duration": String(format: "%.3f", duration),
                "success": "true"
            ], uniquingKeysWith: { _, new in new }))
            
            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            log(.error, category: category, "Failed: \(operation)", metadata: metadata.merging([
                "operationId": operationId,
                "duration": String(format: "%.3f", duration),
                "success": "false",
                "error": error.localizedDescription
            ], uniquingKeysWith: { _, new in new }))
            
            throw error
        }
    }
    
    func logAsyncOperation<T>(
        _ operation: String,
        category: LogCategory,
        metadata: [String: String] = [:],
        block: () async throws -> T
    ) async rethrows -> T {
        let operationId = UUID().uuidString
        let startTime = Date()
        
        log(.debug, category: category, "Started: \(operation)", metadata: metadata.merging([
            "operationId": operationId
        ], uniquingKeysWith: { _, new in new }))
        
        do {
            let result = try await block()
            let duration = Date().timeIntervalSince(startTime)
            
            log(.debug, category: category, "Completed: \(operation)", metadata: metadata.merging([
                "operationId": operationId,
                "duration": String(format: "%.3f", duration),
                "success": "true"
            ], uniquingKeysWith: { _, new in new }))
            
            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            log(.error, category: category, "Failed: \(operation)", metadata: metadata.merging([
                "operationId": operationId,
                "duration": String(format: "%.3f", duration),
                "success": "false",
                "error": error.localizedDescription
            ], uniquingKeysWith: { _, new in new }))
            
            throw error
        }
    }
    
    // MARK: - File Logging
    
    private func setupFileLogging() {
        guard currentConfiguration.enableFileLogging else { return }
        
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDirectory = documentsPath.appendingPathComponent("Logs")
        
        try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "app_log_\(dateFormatter.string(from: startTime)).log"
        
        currentLogFile = logsDirectory.appendingPathComponent(filename)
        
        // Write session header
        if let logFile = currentLogFile {
            let header = """
                =====================================
                StudentCompanion App Log
                Session: \(sessionId)
                Started: \(ISO8601DateFormatter().string(from: startTime))
                =====================================
                
                """
            
            loggingQueue.async {
                try? header.write(to: logFile, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func writeToFile(_ entry: LogEntry) {
        guard let logFile = currentLogFile else { return }
        
        loggingQueue.async {
            do {
                let logLine = entry.detailedMessage + "\n"
                
                if self.fileManager.fileExists(atPath: logFile.path) {
                    let fileHandle = try FileHandle(forWritingTo: logFile)
                    defer { fileHandle.closeFile() }
                    
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(logLine.data(using: .utf8)!)
                } else {
                    try logLine.write(to: logFile, atomically: true, encoding: .utf8)
                }
            } catch {
                os_log("Failed to write to log file: %{public}@", log: OSLog.default, type: .error, error.localizedDescription)
            }
        }
    }
    
    // MARK: - Remote Logging
    
    private func setupRemoteLogging() {
        guard currentConfiguration.enableRemoteLogging else { return }
        remoteLogger.configure(sessionId: sessionId)
    }
    
    // MARK: - Performance Logging
    
    private func setupPerformanceLogging() {
        guard currentConfiguration.enablePerformanceLogging else { return }
        
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            Task { @MainActor in
                self.logSystemPerformance()
            }
        }
    }
    
    private func logSystemPerformance() {
        let memoryUsage = ProcessInfo.processInfo.physicalMemory
        let cpuUsage = getCurrentCPUUsage()
        
        log(.info, category: .performance, "System performance snapshot", metadata: [
            "memoryUsage": "\(memoryUsage)",
            "cpuUsage": String(format: "%.2f", cpuUsage),
            "logEntries": "\(logEntries.count)"
        ])
    }
    
    private func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage calculation
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Double(info.resident_size) / 1024.0 / 1024.0 : 0.0
    }
    
    // MARK: - Log Analysis & Export
    
    func getLogSummary() -> LogSummary {
        let totalEntries = logEntries.count
        let entriesByLevel = Dictionary(grouping: logEntries) { $0.level }
        let entriesByCategory = Dictionary(grouping: logEntries) { $0.category }
        
        let recentErrors = logEntries.filter { 
            $0.level >= .error && $0.timestamp > Date().addingTimeInterval(-3600) // Last hour
        }
        
        return LogSummary(
            sessionId: sessionId,
            sessionDuration: Date().timeIntervalSince(startTime),
            totalEntries: totalEntries,
            entriesByLevel: entriesByLevel.mapValues { $0.count },
            entriesByCategory: entriesByCategory.mapValues { $0.count },
            recentErrors: recentErrors.count,
            configuration: currentConfiguration
        )
    }
    
    func exportLogs(format: LogExportFormat = .json) -> String {
        switch format {
        case .json:
            return exportLogsAsJSON()
        case .text:
            return exportLogsAsText()
        case .csv:
            return exportLogsAsCSV()
        }
    }
    
    private func exportLogsAsJSON() -> String {
        let export = LogExport(
            sessionId: sessionId,
            exportDate: Date(),
            configuration: currentConfiguration,
            entries: Array(logEntries.suffix(1000)), // Last 1000 entries
            summary: getLogSummary()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(export)
            return String(data: data, encoding: .utf8) ?? "Export failed"
        } catch {
            return "Export error: \(error.localizedDescription)"
        }
    }
    
    private func exportLogsAsText() -> String {
        let header = """
            StudentCompanion App Logs
            Session: \(sessionId)
            Export Date: \(ISO8601DateFormatter().string(from: Date()))
            
            """
        
        let entries = logEntries.suffix(1000).map { $0.detailedMessage }.joined(separator: "\n")
        
        return header + entries
    }
    
    private func exportLogsAsCSV() -> String {
        let header = "Timestamp,Level,Category,Message,File,Function,Line,Thread\n"
        
        let rows = logEntries.suffix(1000).map { entry in
            let escapedMessage = entry.message.replacingOccurrences(of: "\"", with: "\"\"")
            return "\(entry.timestamp.timeIntervalSince1970),\(entry.level.rawValue),\(entry.category.rawValue),\"\(escapedMessage)\",\(entry.file),\(entry.function),\(entry.line),\(entry.thread)"
        }.joined(separator: "\n")
        
        return header + rows
    }
    
    // MARK: - Log Management
    
    func clearLogs() {
        logEntries.removeAll()
        logStatistics = LogStatistics()
        log(.info, category: .system, "Log history cleared")
    }
    
    func filterLogs(level: LogLevel? = nil, category: LogCategory? = nil, searchText: String? = nil) -> [LogEntry] {
        return logEntries.filter { entry in
            if let level = level, entry.level < level {
                return false
            }
            
            if let category = category, entry.category != category {
                return false
            }
            
            if let searchText = searchText, !searchText.isEmpty {
                return entry.message.localizedCaseInsensitiveContains(searchText) ||
                       entry.function.localizedCaseInsensitiveContains(searchText)
            }
            
            return true
        }
    }
    
    private func setupCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in // Every hour
            Task { @MainActor in
                self.cleanupOldLogs()
            }
        }
    }
    
    private func cleanupOldLogs() {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(currentConfiguration.logRetentionDays * 24 * 3600))
        
        // Clean up log files
        cleanupOldLogFiles(olderThan: cutoffDate)
        
        // Clean up in-memory logs if needed
        if logEntries.count > currentConfiguration.maxLogEntries * 2 {
            logEntries = Array(logEntries.suffix(currentConfiguration.maxLogEntries))
            log(.info, category: .system, "Cleaned up old log entries")
        }
    }
    
    private func cleanupOldLogFiles(olderThan cutoffDate: Date) {
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let logsDirectory = documentsPath.appendingPathComponent("Logs")
        
        do {
            let logFiles = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for fileURL in logFiles {
                if let creationDate = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                    log(.debug, category: .system, "Removed old log file", metadata: ["file": fileURL.lastPathComponent])
                }
            }
        } catch {
            log(.warning, category: .system, "Failed to cleanup old log files", metadata: ["error": error.localizedDescription])
        }
    }
    
    func pauseLogging() {
        isLogging = false
        log(.info, category: .system, "Logging paused")
    }
    
    func resumeLogging() {
        isLogging = true
        log(.info, category: .system, "Logging resumed")
    }
}

// MARK: - Supporting Types

enum LogExportFormat {
    case json
    case text
    case csv
}

struct LogSummary {
    let sessionId: String
    let sessionDuration: TimeInterval
    let totalEntries: Int
    let entriesByLevel: [LogLevel: Int]
    let entriesByCategory: [LogCategory: Int]
    let recentErrors: Int
    let configuration: LogConfiguration
    
    var formattedSessionDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: sessionDuration) ?? "0s"
    }
}

struct LogExport: Codable {
    let sessionId: String
    let exportDate: Date
    let configuration: LogConfiguration
    let entries: [LogEntry]
    let summary: LogSummary
}

class LogStatistics: ObservableObject {
    @Published private(set) var totalEntries = 0
    @Published private(set) var entriesByLevel: [LogLevel: Int] = [:]
    @Published private(set) var entriesByCategory: [LogCategory: Int] = [:]
    @Published private(set) var errorsInLastHour = 0
    @Published private(set) var lastUpdate = Date()
    
    func recordEntry(_ entry: LogEntry) {
        totalEntries += 1
        entriesByLevel[entry.level, default: 0] += 1
        entriesByCategory[entry.category, default: 0] += 1
        
        if entry.level >= .error && entry.timestamp > Date().addingTimeInterval(-3600) {
            errorsInLastHour += 1
        }
        
        lastUpdate = Date()
    }
    
    func reset() {
        totalEntries = 0
        entriesByLevel.removeAll()
        entriesByCategory.removeAll()
        errorsInLastHour = 0
        lastUpdate = Date()
    }
}

// MARK: - Remote Logger
class RemoteLogger {
    private var sessionId: String = ""
    private let uploadQueue = DispatchQueue(label: "remote.logging", qos: .utility)
    
    func configure(sessionId: String) {
        self.sessionId = sessionId
    }
    
    func send(_ entry: LogEntry) {
        // In a production app, this would send logs to a remote service
        uploadQueue.async {
            // Implementation would depend on your logging service
            // e.g., Sentry, LogRocket, custom analytics
        }
    }
}

// MARK: - Codable Extensions
extension LogConfiguration: Codable {
    enum CodingKeys: String, CodingKey {
        case minLevel, enabledCategories, maxLogEntries, enableFileLogging
        case enableRemoteLogging, enablePerformanceLogging, logRetentionDays
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minLevel = try container.decode(LogLevel.self, forKey: .minLevel)
        maxLogEntries = try container.decode(Int.self, forKey: .maxLogEntries)
        enableFileLogging = try container.decode(Bool.self, forKey: .enableFileLogging)
        enableRemoteLogging = try container.decode(Bool.self, forKey: .enableRemoteLogging)
        enablePerformanceLogging = try container.decode(Bool.self, forKey: .enablePerformanceLogging)
        logRetentionDays = try container.decode(Int.self, forKey: .logRetentionDays)
        
        let categoryStrings = try container.decode([String].self, forKey: .enabledCategories)
        enabledCategories = Set(categoryStrings.compactMap { LogCategory(rawValue: $0) })
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(minLevel, forKey: .minLevel)
        try container.encode(Array(enabledCategories.map { $0.rawValue }), forKey: .enabledCategories)
        try container.encode(maxLogEntries, forKey: .maxLogEntries)
        try container.encode(enableFileLogging, forKey: .enableFileLogging)
        try container.encode(enableRemoteLogging, forKey: .enableRemoteLogging)
        try container.encode(enablePerformanceLogging, forKey: .enablePerformanceLogging)
        try container.encode(logRetentionDays, forKey: .logRetentionDays)
    }
}

extension LogSummary: Codable {
    enum CodingKeys: String, CodingKey {
        case sessionId, sessionDuration, totalEntries, entriesByLevel, entriesByCategory, recentErrors, configuration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        sessionDuration = try container.decode(TimeInterval.self, forKey: .sessionDuration)
        totalEntries = try container.decode(Int.self, forKey: .totalEntries)
        recentErrors = try container.decode(Int.self, forKey: .recentErrors)
        configuration = try container.decode(LogConfiguration.self, forKey: .configuration)
        
        // Decode enum dictionaries
        let levelDict = try container.decode([String: Int].self, forKey: .entriesByLevel)
        entriesByLevel = Dictionary(uniqueKeysWithValues:
            levelDict.compactMap { key, value in
                guard let level = LogLevel(rawValue: key) else { return nil }
                return (level, value)
            }
        )
        
        let categoryDict = try container.decode([String: Int].self, forKey: .entriesByCategory)
        entriesByCategory = Dictionary(uniqueKeysWithValues:
            categoryDict.compactMap { key, value in
                guard let category = LogCategory(rawValue: key) else { return nil }
                return (category, value)
            }
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(sessionDuration, forKey: .sessionDuration)
        try container.encode(totalEntries, forKey: .totalEntries)
        try container.encode(recentErrors, forKey: .recentErrors)
        try container.encode(configuration, forKey: .configuration)
        
        let levelDict = Dictionary(uniqueKeysWithValues: entriesByLevel.map { ($0.key.rawValue, $0.value) })
        try container.encode(levelDict, forKey: .entriesByLevel)
        
        let categoryDict = Dictionary(uniqueKeysWithValues: entriesByCategory.map { ($0.key.rawValue, $0.value) })
        try container.encode(categoryDict, forKey: .entriesByCategory)
    }
}

extension LogLevel: Codable {}
extension LogCategory: Codable {}
