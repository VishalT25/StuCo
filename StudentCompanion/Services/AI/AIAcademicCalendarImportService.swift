import Foundation
import PhotosUI
import SwiftUI
import Supabase

class AIAcademicCalendarImportService: ObservableObject {
    static let shared = AIAcademicCalendarImportService()
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
        if AIAcademicCalendarImportService.debugLogging {
            print("🤖 AIAcademicCalendarImport:", message)
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
    func processAcademicCalendarImport(
        method: AIImportMethod,
        textInput: String = "",
        imageItem: PhotosPickerItem? = nil,
        documentURL: URL? = nil,
        calendarName: String,
        academicYear: String,
        startDate: Date,
        endDate: Date,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> AIAcademicCalendarImportData {

        // Verify user is authenticated by checking for valid session
        debugLog("🔒 Checking authentication...")
        do {
            _ = try await supabaseService.client.auth.session
            debugLog("✅ Valid session found")
        } catch {
            debugLog("❌ No valid session: \(error)")
            throw AIImportError.notAuthenticated
        }

        // Check rate limiting
        try checkRateLimit()

        // Check premium access via RevenueCat (main actor isolated)
        debugLog("🔄 Checking premium access via RevenueCat...")

        let hasAccess = await MainActor.run {
            // Debug log subscription details from RevenueCat
            debugLog("✅ RevenueCat subscription status:")
            debugLog("  - Subscription Tier: \(purchaseManager.subscriptionTier.rawValue)")
            debugLog("  - Has Pro Access: \(purchaseManager.hasProAccess)")
            debugLog("  - Is Founder: \(purchaseManager.hasFounderStatus)")
            debugLog("  - Is Pro User: \(purchaseManager.isProUser)")
            if let expirationDate = purchaseManager.subscriptionExpirationDate {
                debugLog("  - Expiration Date: \(expirationDate)")
            }
            return purchaseManager.hasProAccess
        }

        guard hasAccess else {
            let tierInfo = await MainActor.run { purchaseManager.subscriptionTier.rawValue }
            debugLog("❌ Insufficient permissions. User tier: \(tierInfo), hasProAccess: \(hasAccess)")
            throw AIImportError.insufficientPermissions
        }

        let tier = await MainActor.run { purchaseManager.subscriptionTier.rawValue }
        debugLog("✅ Permission check passed. User tier: \(tier)")

        var uploadedFileURL: String?
        var inputText = textInput
        
        debugLog("Starting academic calendar import. method=\(method.rawValue), textChars=\(textInput.count), hasImage=\(imageItem != nil), hasPDF=\(documentURL != nil)")
        
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
        let aiResponse = try await callAIAcademicCalendarProcessingFunction(
            method: method,
            textInput: inputText,
            fileURL: uploadedFileURL,
            calendarName: calendarName,
            academicYear: academicYear,
            startDate: startDate,
            endDate: endDate
        )
        progressHandler(0.9)
        
        // Step 3: Parse and validate the response
        let importData = try parseAIResponse(aiResponse, originalInput: inputText, calendarName: calendarName, academicYear: academicYear, startDate: startDate, endDate: endDate)
        progressHandler(1.0)
        
        debugLog("Academic calendar import complete. breaks=\(importData.breaks.count), confidence=\(String(format: "%.2f", importData.confidence))")
        
        return importData
    }
    
    // MARK: - File Upload Functions
    
    private func uploadImage(_ item: PhotosPickerItem, progressHandler: @escaping (Double) -> Void) async throws -> String {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw AIImportError.fileProcessingFailed("Could not load image data")
        }
        
        let fileName = "academic_calendar_image_\(UUID().uuidString).jpg"
        return try await uploadFileToStorage(data: data, fileName: fileName, contentType: "image/jpeg", progressHandler: progressHandler)
    }
    
    private func uploadDocument(_ url: URL, progressHandler: @escaping (Double) -> Void) async throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw AIImportError.fileProcessingFailed("Cannot access selected file")
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let data = try Data(contentsOf: url)
        let fileName = "academic_calendar_doc_\(UUID().uuidString).pdf"
        return try await uploadFileToStorage(data: data, fileName: fileName, contentType: "application/pdf", progressHandler: progressHandler)
    }
    
    private func uploadFileToStorage(
        data: Data,
        fileName: String,
        contentType: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String {
        let bucket = "academic-calendar-imports"
        
        // Ensure we have a valid user session and get fresh auth info
        do {
            let user = try await supabaseService.client.auth.user()
            debugLog("🔑 Auth user retrieved successfully: \(user.id.uuidString)")

            // Add user ID to file path for RLS policy (must be lowercase to match auth.uid())
            let userFileName = "\(user.id.uuidString.lowercased())/\(fileName)"
            debugLog("📁 Upload path: \(userFileName)")
            debugLog("📦 Bucket: \(bucket)")
            debugLog("📄 Content type: \(contentType)")
            debugLog("💾 File size: \(data.count) bytes")
            
            // Ensure token is valid before upload
            await supabaseService.ensureValidToken()
            
            let uploadResult = try await supabaseService.client.storage
                .from(bucket)
                .upload(
                    path: userFileName,
                    file: data,
                    options: .init(
                        cacheControl: "3600",
                        contentType: contentType,
                        upsert: true
                    )
                )
            
            debugLog("✅ Upload successful: \(uploadResult)")
            progressHandler(1.0)
            
            let signedURL = try await supabaseService.client.storage
                .from(bucket)
                .createSignedURL(path: userFileName, expiresIn: 3600)
            
            debugLog("🔗 Signed URL created: \(signedURL.absoluteString)")
            return signedURL.absoluteString
            
        } catch let authError {
            debugLog("❌ Auth error: \(authError)")
            throw AIImportError.notAuthenticated
        }
    }
    
    // MARK: - AI Processing Function Call
    
    private func callAIAcademicCalendarProcessingFunction(
        method: AIImportMethod,
        textInput: String,
        fileURL: String?,
        calendarName: String,
        academicYear: String,
        startDate: Date,
        endDate: Date
    ) async throws -> AIAcademicCalendarProcessingResponse {
        let userRole = await MainActor.run { purchaseManager.subscriptionTier.rawValue }
        let requestBody = AIAcademicCalendarProcessingRequest(
            method: method.rawValue,
            textInput: textInput.isEmpty ? nil : textInput,
            fileURL: fileURL,
            calendarName: calendarName,
            academicYear: academicYear,
            startDate: startDate.toISOString(),
            endDate: endDate.toISOString(),
            userRole: userRole
        )
        
        if let reqData = try? JSONEncoder().encode(requestBody),
           let reqString = String(data: reqData, encoding: .utf8) {
            debugLog("Invoking edge function with request: \(reqString)")
        } else {
            debugLog("Invoking edge function with request (encoding failed)")
        }
        
        do {
            let aiResponse: AIAcademicCalendarProcessingResponse = try await supabaseService.client.functions
                .invoke("process-academic-calendar-ai", options: .init(body: requestBody))
            debugLog("Edge function returned typed response. success=\(aiResponse.success), breaks=\(aiResponse.calendarData?.breaks.count ?? 0)")
            return aiResponse
        } catch {
            do {
                let rawString: String = try await supabaseService.client.functions
                    .invoke("process-academic-calendar-ai", options: .init(body: requestBody))
                
                let preview = rawString.count > 4000 ? String(rawString.prefix(4000)) + "…(truncated)" : rawString
                debugLog("Edge function returned raw string (\(rawString.count) chars):\n\(preview)")
                
                if let cleanedData = cleanJsonString(rawString).data(using: .utf8) {
                    if let parsed = try? JSONDecoder().decode(AIAcademicCalendarProcessingResponse.self, from: cleanedData) {
                        debugLog("Parsed AIAcademicCalendarProcessingResponse from cleaned JSON.")
                        return parsed
                    }
                    if let calendarOnly = try? JSONDecoder().decode(AIAcademicCalendarData.self, from: cleanedData) {
                        debugLog("Parsed AIAcademicCalendarData from cleaned JSON. Wrapping into response.")
                        return AIAcademicCalendarProcessingResponse(
                            success: true,
                            method: method.rawValue,
                            confidence: 0.8,
                            calendarData: calendarOnly,
                            error: nil
                        )
                    }
                }
            } catch {
                // ignore inner error and fall through to throw below
            }
            print("AI academic calendar processing error: \(error)")
            throw AIImportError.aiProcessingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Response Parsing
    
    private func parseAIResponse(
        _ response: AIAcademicCalendarProcessingResponse,
        originalInput: String,
        calendarName: String,
        academicYear: String,
        startDate: Date,
        endDate: Date
    ) throws -> AIAcademicCalendarImportData {
        guard response.success else {
            throw AIImportError.aiProcessingFailed(response.error ?? "Unknown AI processing error")
        }
        guard let calendarData = response.calendarData else {
            throw AIImportError.invalidResponse("No calendar data received")
        }
        
        let breaks = try parseAcademicBreaks(from: calendarData.breaks)
        let missingFields = identifyMissingFields(in: breaks)

        // Update rate limiting tracking after successful import
        updateRateLimitTracking()

        debugLog("Parsed \(breaks.count) breaks")

        return AIAcademicCalendarImportData(
            calendarName: calendarData.calendarName ?? calendarName,
            academicYear: calendarData.academicYear ?? academicYear,
            startDate: parseDate(calendarData.startDate) ?? startDate,
            endDate: parseDate(calendarData.endDate) ?? endDate,
            breaks: breaks,
            originalInput: originalInput,
            importType: AIImportType(rawValue: response.method) ?? .text,
            confidence: response.confidence ?? 0.8,
            missingFields: missingFields
        )
    }
    
    private func parseAcademicBreaks(from items: [AIAcademicBreakItem]) throws -> [AcademicBreak] {
        var result: [AcademicBreak] = []
        for aiBreak in items {
            guard !aiBreak.name.isEmpty,
                  let startDate = parseDate(aiBreak.startDate),
                  let endDate = parseDate(aiBreak.endDate) else {
                debugLog("Skipping break (invalid): name='\(aiBreak.name)' start='\(aiBreak.startDate)' end='\(aiBreak.endDate)'")
                continue
            }
            
            let breakType = BreakType.fromString(aiBreak.type) ?? .custom
            
            let academicBreak = AcademicBreak(
                name: aiBreak.name,
                type: breakType,
                startDate: startDate,
                endDate: endDate
            )
            
            debugLog("Accepted break: '\(aiBreak.name)' start='\(aiBreak.startDate)' end='\(aiBreak.endDate)' type='\(aiBreak.type ?? "custom")'")
            result.append(academicBreak)
        }
        return result
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        // Try ISO format first
        if let date = ISO8601DateFormatter().date(from: dateString) {
            return date
        }
        
        // Try common date formats
        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "yyyy/MM/dd",
            "MMM dd, yyyy",
            "dd MMM yyyy",
            "MMMM dd, yyyy",
            "dd MMMM yyyy"
        ]
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    private func identifyMissingFields(in breaks: [AcademicBreak]) -> [String] {
        var missing: [String] = []
        
        if breaks.isEmpty {
            missing.append("breaks")
        }
        
        return missing
    }
}

// MARK: - Data Models for AI Academic Calendar Processing

struct AIAcademicCalendarProcessingRequest: Codable {
    let method: String
    let textInput: String?
    let fileURL: String?
    let calendarName: String
    let academicYear: String
    let startDate: String
    let endDate: String
    let userRole: String
    
    enum CodingKeys: String, CodingKey {
        case method
        case textInput = "textInput"
        case fileURL = "fileURL"
        case calendarName = "calendarName"
        case academicYear = "academicYear"
        case startDate = "startDate"
        case endDate = "endDate"
        case userRole = "userRole"
    }
}

struct AIAcademicCalendarProcessingResponse: Decodable {
    let success: Bool
    let method: String
    let confidence: Double?
    let calendarData: AIAcademicCalendarData?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case method
        case confidence
        case calendarData = "calendarData"
        case error
        case calendar_data
    }
    
    init(success: Bool, method: String, confidence: Double?, calendarData: AIAcademicCalendarData?, error: String?) {
        self.success = success
        self.method = method
        self.confidence = confidence
        self.calendarData = calendarData
        self.error = error
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = (try? c.decode(Bool.self, forKey: .success)) ?? false
        self.method = (try? c.decode(String.self, forKey: .method)) ?? "text"
        self.confidence = try? c.decode(Double.self, forKey: .confidence)
        self.error = try? c.decode(String.self, forKey: .error)
        if let cd = try? c.decode(AIAcademicCalendarData.self, forKey: .calendarData) {
            self.calendarData = cd
        } else if let cd2 = try? c.decode(AIAcademicCalendarData.self, forKey: .calendar_data) {
            self.calendarData = cd2
        } else {
            self.calendarData = nil
        }
    }
}

struct AIAcademicCalendarData: Decodable {
    let calendarName: String?
    let academicYear: String?
    let startDate: String?
    let endDate: String?
    let breaks: [AIAcademicBreakItem]
    
    enum CodingKeys: String, CodingKey {
        case calendarName = "calendarName"
        case academicYear = "academicYear"
        case startDate = "startDate"
        case endDate = "endDate"
        case breaks
        case calendar_name
        case academic_year
        case start_date
        case end_date
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.calendarName = (try? c.decode(String.self, forKey: .calendarName)) ?? (try? c.decode(String.self, forKey: .calendar_name))
        self.academicYear = (try? c.decode(String.self, forKey: .academicYear)) ?? (try? c.decode(String.self, forKey: .academic_year))
        self.startDate = (try? c.decode(String.self, forKey: .startDate)) ?? (try? c.decode(String.self, forKey: .start_date))
        self.endDate = (try? c.decode(String.self, forKey: .endDate)) ?? (try? c.decode(String.self, forKey: .end_date))
        self.breaks = (try? c.decode([AIAcademicBreakItem].self, forKey: .breaks)) ?? []
    }
}

struct AIAcademicBreakItem: Decodable {
    let name: String
    let startDate: String
    let endDate: String
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case startDate = "startDate"
        case endDate = "endDate"
        case type
        case start_date
        case end_date
        case break_type
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? c.decode(String.self, forKey: .name)) ?? ""
        self.startDate = (try? c.decode(String.self, forKey: .startDate)) ?? (try? c.decode(String.self, forKey: .start_date)) ?? ""
        self.endDate = (try? c.decode(String.self, forKey: .endDate)) ?? (try? c.decode(String.self, forKey: .end_date)) ?? ""
        self.type = (try? c.decode(String.self, forKey: .type)) ?? (try? c.decode(String.self, forKey: .break_type))
    }
}

// MARK: - Academic Break Type Extension

extension BreakType {
    static func fromString(_ string: String?) -> BreakType? {
        guard let string = string else { return nil }
        switch string.lowercased() {
        case "winter", "winter break": return .winterBreak
        case "spring", "spring break": return .springBreak
        case "summer", "summer break": return .custom // Note: there's no .summerBreak in BreakType
        case "reading", "reading week": return .readingWeek
        case "exam", "exams", "exam period": return .examPeriod
        case "holiday", "holidays": return .holiday
        default: return .custom
        }
    }
}

// MARK: - Helper Functions

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