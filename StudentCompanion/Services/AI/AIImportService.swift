import Foundation
import PhotosUI
import SwiftUI
import Supabase

// MARK: - AI Import Service
class AIImportService: ObservableObject {
    static let shared = AIImportService()
    private let supabaseService = SupabaseService.shared
    private let purchaseManager = PurchaseManager.shared

    // Rate limiting
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 30.0 // 30 seconds between requests
    private let dailyRequestLimit: Int = 20 // Max 20 AI imports per day
    private var dailyRequestCount: Int = 0
    private var dailyRequestResetDate: Date?

    private init() {}

    private static let debugLogging = true
    private func debugLog(_ message: String) {
        if AIImportService.debugLogging {
            print("🤖 AIImport:", message)
        }
    }

    // MARK: - Rate Limiting

    private func checkRateLimit() throws {
        // Check minimum interval
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minimumRequestInterval {
                let retryAfter = minimumRequestInterval - elapsed
                throw AIImportError.rateLimited(retryAfter: retryAfter)
            }
        }

        // Check daily limit
        resetDailyCountIfNeeded()
        if dailyRequestCount >= dailyRequestLimit {
            throw AIImportError.dailyLimitReached
        }
    }

    private func resetDailyCountIfNeeded() {
        let calendar = Calendar.current
        let now = Date()

        // If no reset date set, or if we've crossed into a new day, reset
        if let resetDate = dailyRequestResetDate {
            if !calendar.isDate(now, inSameDayAs: resetDate) {
                dailyRequestCount = 0
                dailyRequestResetDate = now
            }
        } else {
            dailyRequestResetDate = now
        }
    }

    private func updateRateLimitTracking() {
        lastRequestTime = Date()
        dailyRequestCount += 1
    }

    // MARK: - Main Processing Function
    func processScheduleImport(
        method: AIImportMethod,
        textInput: String = "",
        imageItem: PhotosPickerItem? = nil,
        documentURL: URL? = nil,
        semesterStartDate: Date,
        semesterEndDate: Date,
        schedulePattern: String?,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> AIImportData {

        guard supabaseService.isAuthenticated else {
            throw AIImportError.notAuthenticated
        }

        // Check rate limiting
        try checkRateLimit()

        // Check RevenueCat subscription for premium access (main actor isolated)
        let hasAccess = await MainActor.run { purchaseManager.hasProAccess }
        guard hasAccess else {
            let tierInfo = await MainActor.run { purchaseManager.subscriptionTier.rawValue }
            debugLog("❌ Insufficient permissions. User tier: \(tierInfo), hasProAccess: \(hasAccess)")
            throw AIImportError.insufficientPermissions
        }
        
        var uploadedFileURL: String?
        var inputText = textInput
        
        debugLog("Starting import. method=\(method.rawValue), textChars=\(textInput.count), hasImage=\(imageItem != nil), hasPDF=\(documentURL != nil), start=\(semesterStartDate), end=\(semesterEndDate)")

        // Step 1: Handle file uploads if needed
        switch method {
        case .text:
            if textInput.isEmpty {
                throw AIImportError.invalidInput("Text input cannot be empty")
            }
            progressHandler(0.1)
            
        case .image:
            guard let imageItem = imageItem else {
                throw AIImportError.invalidInput("No image selected")
            }
            
            progressHandler(0.1)
            uploadedFileURL = try await uploadImage(imageItem, progressHandler: { progress in
                progressHandler(0.1 + (progress * 0.4)) // 10% to 50%
            })
            debugLog("Image uploaded. signedURL=\(uploadedFileURL ?? "nil")")
            progressHandler(0.5)
            
        case .pdf:
            guard let documentURL = documentURL else {
                throw AIImportError.invalidInput("No document selected")
            }
            
            progressHandler(0.1)
            uploadedFileURL = try await uploadDocument(documentURL, progressHandler: { progress in
                progressHandler(0.1 + (progress * 0.4)) // 10% to 50%
            })
            debugLog("PDF uploaded. signedURL=\(uploadedFileURL ?? "nil")")
            progressHandler(0.5)
        }
        
        // Step 2: Call AI processing edge function
        progressHandler(0.6)
        let aiResponse = try await callAIProcessingFunction(
            method: method,
            textInput: inputText,
            fileURL: uploadedFileURL,
            semesterStartDate: semesterStartDate,
            semesterEndDate: semesterEndDate,
            schedulePattern: schedulePattern
        )
        progressHandler(0.9)
        
        // Step 3: Parse and validate the response
        let importData = try parseAIResponse(aiResponse, originalInput: inputText)
        progressHandler(1.0)

        // Update rate limiting tracking after successful import
        updateRateLimitTracking()

        debugLog("Import complete. items=\(importData.parsedItems.count), confidence=\(String(format: "%.2f", importData.confidence)), missing=\(importData.missingFields.joined(separator: ", "))")

        return importData
    }
    
    // MARK: - File Upload Functions
    
    private func uploadImage(_ item: PhotosPickerItem, progressHandler: @escaping (Double) -> Void) async throws -> String {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw AIImportError.fileProcessingFailed("Could not load image data")
        }
        
        let fileName = "schedule_image_\(UUID().uuidString).jpg"
        return try await uploadFileToStorage(data: data, fileName: fileName, contentType: "image/jpeg", progressHandler: progressHandler)
    }
    
    private func uploadDocument(_ url: URL, progressHandler: @escaping (Double) -> Void) async throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw AIImportError.fileProcessingFailed("Cannot access selected file")
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let data = try Data(contentsOf: url)
        let fileName = "schedule_doc_\(UUID().uuidString).pdf"
        return try await uploadFileToStorage(data: data, fileName: fileName, contentType: "application/pdf", progressHandler: progressHandler)
    }
    
    private func uploadFileToStorage(
        data: Data,
        fileName: String,
        contentType: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String {
        let bucket = "schedule-imports"
        do {
            _ = try await supabaseService.client.storage
                .from(bucket)
                .upload(
                    path: fileName,
                    file: data
                )
            progressHandler(1.0)

            let signedURL = try await supabaseService.client.storage
                .from(bucket)
                .createSignedURL(path: fileName, expiresIn: 3600)
            return signedURL.absoluteString
        } catch {
            print("Storage upload error: \(error)")
            throw AIImportError.uploadFailed(error.localizedDescription)
        }
    }
    
    // MARK: - AI Processing Function Call
    
    private func callAIProcessingFunction(
        method: AIImportMethod,
        textInput: String,
        fileURL: String?,
        semesterStartDate: Date,
        semesterEndDate: Date,
        schedulePattern: String?
    ) async throws -> AIProcessingResponse {
        let userRole = await MainActor.run {
            purchaseManager.subscriptionTier.rawValue
        }
        let requestBody = AIProcessingRequest(
            method: method.rawValue,
            textInput: textInput.isEmpty ? nil : textInput,
            fileURL: fileURL,
            semesterStartDate: semesterStartDate.toISOString(),
            semesterEndDate: semesterEndDate.toISOString(),
            userRole: userRole,
            schedulePattern: schedulePattern
        )
        if let reqData = try? JSONEncoder().encode(requestBody),
           let reqString = String(data: reqData, encoding: .utf8) {
            debugLog("Invoking edge function with request: \(reqString)")
        } else {
            debugLog("Invoking edge function with request (encoding failed)")
        }

        do {
            let aiResponse: AIProcessingResponse = try await supabaseService.client.functions
                .invoke("process-schedule-ai", options: .init(body: requestBody))
            let count = aiResponse.scheduleData?.items.count ?? 0
            let conf = aiResponse.confidence ?? -1
            debugLog("Edge function returned typed response. success=\(aiResponse.success), method=\(aiResponse.method), items=\(count), confidence=\(conf)")
            return aiResponse
        } catch {
            do {
                let rawString: String = try await supabaseService.client.functions
                    .invoke("process-schedule-ai", options: .init(body: requestBody))

                let preview = rawString.count > 4000 ? String(rawString.prefix(4000)) + "…(truncated)" : rawString
                debugLog("Edge function returned raw string (\(rawString.count) chars):\n\(preview)")

                if let cleanedData = cleanJsonString(rawString).data(using: .utf8) {
                    let cleanedPreview = cleanedData.count > 4000 ? String((String(data: cleanedData, encoding: .utf8) ?? "").prefix(4000)) + "…(truncated)" : (String(data: cleanedData, encoding: .utf8) ?? "")
                    debugLog("Cleaned JSON (\(cleanedData.count) bytes):\n\(cleanedPreview)")

                    if let parsed = try? JSONDecoder().decode(AIProcessingResponse.self, from: cleanedData) {
                        debugLog("Parsed AIProcessingResponse from cleaned JSON.")
                        return parsed
                    }
                    if let scheduleOnly = try? JSONDecoder().decode(AIScheduleData.self, from: cleanedData) {
                        debugLog("Parsed AIScheduleData from cleaned JSON. Wrapping into AIProcessingResponse.")
                        return AIProcessingResponse(
                            success: true,
                            method: method.rawValue,
                            confidence: 0.8,
                            scheduleData: scheduleOnly,
                            error: nil,
                            usage: nil
                        )
                    }
                    if let any = try? JSONSerialization.jsonObject(with: cleanedData, options: []) as? [String: Any] {
                        if let inner = any["data"] ?? any["body"] {
                            if let innerData = try? JSONSerialization.data(withJSONObject: inner) {
                                if let parsed = try? JSONDecoder().decode(AIProcessingResponse.self, from: innerData) {
                                    debugLog("Parsed AIProcessingResponse from {data/body} wrapper.")
                                    return parsed
                                }
                                if let scheduleOnly = try? JSONDecoder().decode(AIScheduleData.self, from: innerData) {
                                    debugLog("Parsed AIScheduleData from {data/body} wrapper. Wrapping into AIProcessingResponse.")
                                    return AIProcessingResponse(
                                        success: true,
                                        method: method.rawValue,
                                        confidence: 0.8,
                                        scheduleData: scheduleOnly,
                                        error: nil,
                                        usage: nil
                                    )
                                }
                            }
                        }
                    }
                }
            } catch {
                // ignore inner error and fall through to throw below
            }
            print("AI processing error: \(error)")
            throw AIImportError.aiProcessingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Response Parsing
    
    private func parseAIResponse(_ response: AIProcessingResponse, originalInput: String) throws -> AIImportData {
        guard response.success else {
            throw AIImportError.aiProcessingFailed(response.error ?? "Unknown AI processing error")
        }
        guard let scheduleData = response.scheduleData else {
            throw AIImportError.invalidResponse("No schedule data received")
        }

        let (scheduleItems, rotationLabels, rotationAssignment) = try parseScheduleItemsAndRotation(from: scheduleData.items)
        let missingFields = identifyMissingFields(in: scheduleItems)

        let sample = scheduleItems.prefix(5).map { item in
            let days = item.daysOfWeek.map { $0.abbreviation }.joined(separator: ",")
            let tf = DateFormatter()
            tf.timeStyle = .short
            return "\(item.title) [\(days)] \(tf.string(from: item.startTime))-\(tf.string(from: item.endTime)) @\(item.location)"
        }.joined(separator: "\n - ")
        debugLog("Parsed \(scheduleItems.count) items. Sample:\n - \(sample)")

        return AIImportData(
            parsedItems: scheduleItems,
            originalInput: originalInput,
            importType: AIImportType(rawValue: response.method) ?? .text,
            confidence: response.confidence ?? 0.8,
            missingFields: missingFields,
            rotationLabelsByItemID: rotationLabels,
            rotationAssignmentByItemID: rotationAssignment
        )
    }
    
    private func parseScheduleItems(from items: [AIScheduleItem]) throws -> [ScheduleItem] {
        var result: [ScheduleItem] = []
        for aiItem in items {
            let title = aiItem.title
            let rawDays = aiItem.days
            let colorStr = aiItem.color
            guard !title.isEmpty,
                  let startTime = parseTime(aiItem.startTime),
                  let endTime = parseTime(aiItem.endTime) else {
                debugLog("Skipping item (invalid): title='\(aiItem.title)' days=\(aiItem.days) start='\(aiItem.startTime)' end='\(aiItem.endTime)'")
                continue
            }
            // Map to DayOfWeek if possible; allow empty if rotation labels like "Day 1" are present
            let daysOfWeek = rawDays.compactMap { DayOfWeek.fromAbbreviation($0) }
            let color = Color.fromString(colorStr) ?? .blue
            let reminderTime = ReminderTime.fromString(aiItem.reminder ?? "") ?? .none

            let item = ScheduleItem(
                id: UUID(),
                title: title,
                startTime: startTime,
                endTime: endTime,
                daysOfWeek: daysOfWeek,
                location: aiItem.location ?? "",
                instructor: aiItem.instructor ?? "",
                color: color,
                isLiveActivityEnabled: aiItem.liveActivity ?? true,
                reminderTime: reminderTime
            )
            debugLog("Accepted item: '\(title)' days=\(rawDays.joined(separator: ",")) start='\(aiItem.startTime)' end='\(aiItem.endTime)' color='\(colorStr)'")
            result.append(item)
        }
        return result
    }
    
    private func parseScheduleItemsAndRotation(from items: [AIScheduleItem]) throws -> ([ScheduleItem], [UUID: [String]], [UUID: Int]) {
        var result: [ScheduleItem] = []
        var rotationMap: [UUID: [String]] = [:]
        var assignmentMap: [UUID: Int] = [:]
        
        for aiItem in items {
            let title = aiItem.title
            let rawDays = aiItem.days
            let colorStr = aiItem.color
            
            guard !title.isEmpty,
                  let startTime = parseTime(aiItem.startTime),
                  let endTime = parseTime(aiItem.endTime) else {
                debugLog("Skipping item (invalid): title='\(aiItem.title)' days=\(aiItem.days) start='\(aiItem.startTime)' end='\(aiItem.endTime)'")
                continue
            }
            
            let mappedDays = rawDays.compactMap { DayOfWeek.fromAbbreviation($0) }
            let color = Color.fromString(colorStr) ?? .blue
            let reminderTime = ReminderTime.fromString(aiItem.reminder ?? "") ?? .none
            
            let newId = UUID()
            let item = ScheduleItem(
                id: newId,
                title: title,
                startTime: startTime,
                endTime: endTime,
                daysOfWeek: mappedDays, // may be empty for rotation labels
                location: aiItem.location ?? "",
                instructor: aiItem.instructor ?? "",
                color: color,
                isLiveActivityEnabled: aiItem.liveActivity ?? true,
                reminderTime: reminderTime
            )
            
            // If we couldn't map to weekdays, but we have labels (e.g., "Day 1","Day 2"), preserve them
            if mappedDays.isEmpty, !rawDays.isEmpty {
                rotationMap[newId] = rawDays
                // Default assignment: if label includes "2", choose Day 2 else Day 1
                if rawDays.contains(where: { $0.range(of: "2", options: .caseInsensitive) != nil }) {
                    assignmentMap[newId] = 2
                } else {
                    assignmentMap[newId] = 1
                }
            }
            
            debugLog("Accepted item: '\(title)' days=\(rawDays.joined(separator: ",")) start='\(aiItem.startTime)' end='\(aiItem.endTime)' color='\(colorStr)'")
            result.append(item)
        }
        return (result, rotationMap, assignmentMap)
    }
    
    private func parseTime(_ timeString: String) -> Date? {
        let fmts = [
            "HH:mm",
            "H:mm",
            "HH:mm:ss",
            "H:mm:ss",
            "h:mm a",
            "hh:mm a",
            "h a",
            "ha",
            "hh a",
            "h:mma",
            "hh:mma",
            "HHmm",
            "Hmm"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for f in fmts {
            formatter.dateFormat = f
            if let d = formatter.date(from: timeString.trimmingCharacters(in: .whitespaces)) {
                return d
            }
        }
        return nil
    }
    
    private func identifyMissingFields(in items: [ScheduleItem]) -> [String] {
        var missing: [String] = []
        
        let hasEmptyLocations = items.contains { $0.location.isEmpty }
        let hasEmptyInstructors = items.contains { $0.instructor.isEmpty }
        
        if hasEmptyLocations {
            missing.append("locations")
        }
        if hasEmptyInstructors {
            missing.append("instructors")
        }
        
        return missing
    }
}

// MARK: - Data Models for AI Processing

struct AIProcessingRequest: Codable {
    let method: String
    let textInput: String?
    let fileURL: String?
    let semesterStartDate: String
    let semesterEndDate: String
    let userRole: String
    let schedulePattern: String?

    enum CodingKeys: String, CodingKey {
        case method
        case textInput = "textInput"
        case fileURL = "fileURL"
        case semesterStartDate = "semesterStartDate"
        case semesterEndDate = "semesterEndDate"
        case userRole = "userRole"
        case schedulePattern = "schedulePattern"
    }
}

struct AIProcessingResponse: Decodable {
    let success: Bool
    let method: String
    let confidence: Double?
    let scheduleData: AIScheduleData?
    let error: String?
    let usage: AIUsageInfo?

    enum CodingKeys: String, CodingKey {
        case success
        case method
        case confidence
        case scheduleData = "scheduleData"
        case error
        case usage
        // snake_case fallbacks
        case schedule_data
    }

    init(success: Bool, method: String, confidence: Double?, scheduleData: AIScheduleData?, error: String?, usage: AIUsageInfo?) {
        self.success = success
        self.method = method
        self.confidence = confidence
        self.scheduleData = scheduleData
        self.error = error
        self.usage = usage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = (try? c.decode(Bool.self, forKey: .success)) ?? false
        self.method = (try? c.decode(String.self, forKey: .method)) ?? "text"
        self.confidence = try? c.decode(Double.self, forKey: .confidence)
        self.error = try? c.decode(String.self, forKey: .error)
        self.usage = try? c.decode(AIUsageInfo.self, forKey: .usage)
        if let sd = try? c.decode(AIScheduleData.self, forKey: .scheduleData) {
            self.scheduleData = sd
        } else if let sd2 = try? c.decode(AIScheduleData.self, forKey: .schedule_data) {
            self.scheduleData = sd2
        } else {
            self.scheduleData = nil
        }
    }
}

struct AIScheduleData: Decodable {
    let version: Int
    let timezone: String?
    let items: [AIScheduleItem]

    enum CodingKeys: String, CodingKey {
        case version
        case timezone
        case time_zone
        case items
        case courses
    }

    private struct AICourseDTO: Decodable {
        let code: String?
        let name: String?
        let color: String?
        let instructor: String?
        let meetings: [AIMeetingDTO]?
    }

    private struct AIMeetingDTO: Decodable {
        let type: String?
        let days: [String]?
        let rotationDays: [String]?
        let start: String?
        let end: String?
        let location: String?
        let instructor: String?
        let reminder: String?
        let liveActivity: Bool?
    }

    init(version: Int, timezone: String?, items: [AIScheduleItem]) {
        self.version = version
        self.timezone = timezone
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.version = (try? c.decode(Int.self, forKey: .version)) ?? 1

        if let tz = try? c.decode(String.self, forKey: .timezone) {
            self.timezone = tz
        } else if let tz2 = try? c.decode(String.self, forKey: .time_zone) {
            self.timezone = tz2
        } else {
            self.timezone = nil
        }

        if let directItems = try? c.decode([AIScheduleItem].self, forKey: .items) {
            self.items = directItems
            return
        }

        if let courses = try? c.decode([AICourseDTO].self, forKey: .courses) {
            var flattened: [AIScheduleItem] = []
            for course in courses {
                let courseName = (course.name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                    ?? (course.code?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                    ?? "Course"
                let courseColor = (course.color?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "blue"
                let courseInstructor = course.instructor

                for meeting in course.meetings ?? [] {
                    guard let start = meeting.start, let end = meeting.end else { continue }

                    // accept rotationDays when days aren't present
                    let meetingDays = (meeting.days ?? meeting.rotationDays) ?? []

                    let typeSuffix = (meeting.type?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                    let title = typeSuffix != nil ? "\(courseName) - \(typeSuffix!)" : courseName

                    let item = AIScheduleItem(
                        title: title,
                        days: meetingDays,
                        start: start,
                        end: end,
                        color: courseColor,
                        location: meeting.location,
                        instructor: meeting.instructor ?? courseInstructor,
                        reminder: meeting.reminder,
                        liveActivity: meeting.liveActivity
                    )
                    flattened.append(item)
                }
            }
            self.items = flattened
            return
        }

        self.items = []
    }
}

struct AIScheduleItem: Decodable {
    let title: String
    let days: [String]
    let startTime: String
    let endTime: String
    let color: String
    let location: String?
    let instructor: String?
    let reminder: String?
    let liveActivity: Bool?

    init(
        title: String,
        days: [String],
        start: String,
        end: String,
        color: String,
        location: String? = nil,
        instructor: String? = nil,
        reminder: String? = nil,
        liveActivity: Bool? = nil
    ) {
        self.title = title
        self.days = days
        self.startTime = start
        self.endTime = end
        self.color = color
        self.location = location
        self.instructor = instructor
        self.reminder = reminder
        self.liveActivity = liveActivity
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case name
        case days
        case daysOfWeek
        case days_of_week
        case start
        case end
        case start_time
        case end_time
        case startTime
        case endTime
        case color
        case color_hex
        case colour
        case location
        case instructor
        case reminder
        case liveActivity
        case live_activity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.title = (try? c.decode(String.self, forKey: .title))
            ?? (try? c.decode(String.self, forKey: .name))
            ?? ""

        if let arr = try? c.decode([String].self, forKey: .days) {
            self.days = AIScheduleItem.normalizeDays(arr)
        } else if let arr = try? c.decode([String].self, forKey: .daysOfWeek) {
            self.days = AIScheduleItem.normalizeDays(arr)
        } else if let arr = try? c.decode([String].self, forKey: .days_of_week) {
            self.days = AIScheduleItem.normalizeDays(arr)
        } else if let s = try? c.decode(String.self, forKey: .days) {
            self.days = AIScheduleItem.normalizeDays(s.components(separatedBy: CharacterSet(charactersIn: ",/ ")).filter { !$0.isEmpty })
        } else {
            self.days = []
        }

        let startStr =
            (try? c.decode(String.self, forKey: .start)) ??
            (try? c.decode(String.self, forKey: .start_time)) ??
            (try? c.decode(String.self, forKey: .startTime))
        let endStr =
            (try? c.decode(String.self, forKey: .end)) ??
            (try? c.decode(String.self, forKey: .end_time)) ??
            (try? c.decode(String.self, forKey: .endTime))

        self.startTime = startStr ?? ""
        self.endTime = endStr ?? ""

        self.color =
            (try? c.decode(String.self, forKey: .color)) ??
            (try? c.decode(String.self, forKey: .color_hex)) ??
            (try? c.decode(String.self, forKey: .colour)) ??
            "blue"

        self.location = try? c.decodeIfPresent(String.self, forKey: .location)
        self.instructor = try? c.decodeIfPresent(String.self, forKey: .instructor)
        self.reminder = try? c.decodeIfPresent(String.self, forKey: .reminder)
        self.liveActivity =
            (try? c.decodeIfPresent(Bool.self, forKey: .liveActivity)) ??
            (try? c.decodeIfPresent(Bool.self, forKey: .live_activity))
    }

    private static func normalizeDays(_ tokens: [String]) -> [String] {
        var out: [String] = []
        for raw in tokens {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { continue }
            let lower = t.lowercased()
            if lower == "mwf" {
                out.append(contentsOf: ["Mon","Wed","Fri"])
                continue
            }
            if lower == "tr" || lower == "rt" {
                out.append(contentsOf: ["Tue","Thu"])
                continue
            }
            if lower == "mw" {
                out.append(contentsOf: ["Mon","Wed"])
                continue
            }
            if lower == "wf" {
                out.append(contentsOf: ["Wed","Fri"])
                continue
            }
            let split = t
                .replacingOccurrences(of: "/", with: ",")
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if split.count > 1 {
                out.append(contentsOf: split)
            } else {
                out.append(t)
            }
        }
        return out
    }
}

struct AIUsageInfo: Decodable {
    let tokensUsed: Int?
    let processingTime: Double?
    let modelUsed: String?

    enum CodingKeys: String, CodingKey {
        case tokensUsed = "tokensUsed"
        case processingTime = "processingTime"
        case modelUsed = "modelUsed"
        case tokens_used
        case processing_time
        case model_used
    }

    init(tokensUsed: Int?, processingTime: Double?, modelUsed: String?) {
        self.tokensUsed = tokensUsed
        self.processingTime = processingTime
        self.modelUsed = modelUsed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.tokensUsed = (try? c.decode(Int.self, forKey: .tokensUsed)) ?? (try? c.decode(Int.self, forKey: .tokens_used))
        self.processingTime = (try? c.decode(Double.self, forKey: .processingTime)) ?? (try? c.decode(Double.self, forKey: .processing_time))
        self.modelUsed = (try? c.decode(String.self, forKey: .modelUsed)) ?? (try? c.decode(String.self, forKey: .model_used))
    }
}

// MARK: - Enhanced Data Models

extension AIImportData {
    var hasHighConfidence: Bool {
        confidence >= 0.8
    }
    
    var hasCriticalMissing: Bool {
        missingFields.contains("times") || missingFields.contains("days")
    }
}

extension AIImportType {
    var rawValue: String {
        switch self {
        case .text: return "text"
        case .image: return "image" 
        case .pdf: return "pdf"
        }
    }
    
    init?(rawValue: String) {
        switch rawValue {
        case "text": self = .text
        case "image": self = .image
        case "pdf": self = .pdf
        default: return nil
        }
    }
}

// MARK: - AI Import Errors

enum AIImportError: LocalizedError {
    case notAuthenticated
    case insufficientPermissions
    case invalidInput(String)
    case fileProcessingFailed(String)
    case uploadFailed(String)
    case aiProcessingFailed(String)
    case invalidResponse(String)
    case rateLimited(retryAfter: TimeInterval)
    case dailyLimitReached
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to use AI import"
        case .insufficientPermissions:
            return "AI import requires a Premium or Founder subscription"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .fileProcessingFailed(let message):
            return "File processing failed: \(message)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .aiProcessingFailed(let message):
            return "AI processing failed: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .rateLimited(let retryAfter):
            let seconds = Int(ceil(retryAfter))
            return "Please wait \(seconds) seconds before trying again"
        case .dailyLimitReached:
            return "Daily AI import limit reached (20 per day). Please try again tomorrow."
        }
    }
}

// MARK: - Helper Extensions

extension DayOfWeek {
    static func fromAbbreviation(_ abbr: String) -> DayOfWeek? {
        switch abbr.lowercased() {
        case "sun", "sunday": return .sunday
        case "mon", "monday": return .monday
        case "tue", "tuesday": return .tuesday
        case "wed", "wednesday": return .wednesday
        case "thu", "thursday": return .thursday
        case "fri", "friday": return .friday
        case "sat", "saturday": return .saturday
        default: return nil
        }
    }
    
    var abbreviation: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

extension Color {
    static func fromString(_ string: String) -> Color? {
        switch string.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "yellow": return .yellow
        case "pink": return .pink
        case "gray", "grey": return .gray
        default: return nil
        }
    }
}

extension ReminderTime {
    static func fromString(_ string: String) -> ReminderTime? {
        switch string.lowercased() {
        case "none", "0": return .none
        case "5m", "5min": return .fiveMinutes
        case "10m", "10min": return .tenMinutes
        case "15m", "15min": return .fifteenMinutes
        case "30m", "30min": return .thirtyMinutes
        case "1h", "1hr": return .oneHour
        default: return nil
        }
    }
}

private func cleanJsonString(_ input: String) -> String {
    var cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if cleaned.hasPrefix("```json") {
        cleaned = String(cleaned.dropFirst(7))
    }
    if cleaned.hasPrefix("```") {
        cleaned = String(cleaned.dropFirst(3))
    }
    if cleaned.hasSuffix("```") {
        cleaned = String(cleaned.dropLast(3))
    }
    if let startIndex = cleaned.firstIndex(of: "{"),
       let endIndex = cleaned.lastIndex(of: "}") {
        cleaned = String(cleaned[startIndex...endIndex])
    }
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
}