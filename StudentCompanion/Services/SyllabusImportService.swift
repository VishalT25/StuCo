import Foundation
import PhotosUI
import SwiftUI
import Supabase

// MARK: - Syllabus Import Service
class SyllabusImportService: ObservableObject {
    static let shared = SyllabusImportService()
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
        if SyllabusImportService.debugLogging {
            print("📄 SyllabusImport:", message)
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
    func processSyllabusImport(
        courseId: UUID,
        method: AIImportMethod,
        textInput: String = "",
        imageItem: PhotosPickerItem? = nil,
        documentURL: URL? = nil,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> SyllabusImportData {

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
        var storedPDFPath: String?
        var inputText = textInput

        debugLog("Starting syllabus import. courseId=\(courseId.uuidString), method=\(method.rawValue), textChars=\(textInput.count), hasImage=\(imageItem != nil), hasPDF=\(documentURL != nil)")

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
            let (signedURL, storagePath) = try await uploadPDF(
                courseId: courseId,
                documentURL: documentURL,
                progressHandler: { progress in
                    progressHandler(0.1 + (progress * 0.4)) // 10% to 50%
                }
            )
            uploadedFileURL = signedURL
            storedPDFPath = storagePath
            debugLog("PDF uploaded. signedURL=\(uploadedFileURL ?? "nil"), storagePath=\(storagePath)")
            progressHandler(0.5)
        }

        // Step 2: Call AI processing edge function
        progressHandler(0.6)
        let aiResponse = try await callSyllabusAIFunction(
            method: method,
            textInput: inputText,
            fileURL: uploadedFileURL,
            courseId: courseId.uuidString
        )
        progressHandler(0.9)

        // Step 3: Parse and validate the response
        let importData = try parseSyllabusResponse(
            aiResponse,
            originalInput: inputText,
            method: method,
            storedPDFPath: storedPDFPath
        )
        progressHandler(1.0)

        // Update rate limiting tracking after successful import
        updateRateLimitTracking()

        debugLog("Import complete. assignments=\(importData.parsedAssignments.count), confidence=\(String(format: "%.2f", importData.confidence)), missing=\(importData.missingFields.joined(separator: ", "))")

        return importData
    }

    // MARK: - File Upload Functions

    private func uploadImage(_ item: PhotosPickerItem, progressHandler: @escaping (Double) -> Void) async throws -> String {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw AIImportError.fileProcessingFailed("Could not load image data")
        }

        let fileName = "syllabus_image_\(UUID().uuidString).jpg"
        return try await uploadFileToStorage(
            data: data,
            fileName: fileName,
            contentType: "image/jpeg",
            progressHandler: progressHandler
        )
    }

    private func uploadPDF(
        courseId: UUID,
        documentURL: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> (signedURL: String, storagePath: String) {
        // Try to read the file data
        // When using DocumentPicker with asCopy: true, the file is already copied
        // and doesn't need security-scoped resource access
        let data: Data

        // First try without security-scoped access (for copied files)
        if let fileData = try? Data(contentsOf: documentURL) {
            data = fileData
        } else {
            // Fallback: try with security-scoped access
            guard documentURL.startAccessingSecurityScopedResource() else {
                throw AIImportError.fileProcessingFailed("Cannot access selected file")
            }
            defer { documentURL.stopAccessingSecurityScopedResource() }

            data = try Data(contentsOf: documentURL)
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "syllabus_\(courseId.uuidString)_\(timestamp).pdf"

        let signedURL = try await uploadFileToStorage(
            data: data,
            fileName: fileName,
            contentType: "application/pdf",
            progressHandler: progressHandler
        )

        return (signedURL, fileName)
    }

    private func uploadFileToStorage(
        data: Data,
        fileName: String,
        contentType: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String {
        let bucket = "syllabus-imports"
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

    private func callSyllabusAIFunction(
        method: AIImportMethod,
        textInput: String,
        fileURL: String?,
        courseId: String
    ) async throws -> SyllabusAIResponse {
        let userRole = await MainActor.run { purchaseManager.subscriptionTier.rawValue }
        let requestBody = SyllabusAIRequest(
            method: method.rawValue,
            textInput: textInput.isEmpty ? nil : textInput,
            fileURL: fileURL,
            courseId: courseId,
            userRole: userRole
        )

        if let reqData = try? JSONEncoder().encode(requestBody),
           let reqString = String(data: reqData, encoding: .utf8) {
            debugLog("Invoking edge function with request: \(reqString)")
        } else {
            debugLog("Invoking edge function with request (encoding failed)")
        }

        do {
            let aiResponse: SyllabusAIResponse = try await supabaseService.client.functions
                .invoke("process-syllabus-ai", options: .init(body: requestBody))
            let count = aiResponse.assignments.count
            let conf = aiResponse.confidence
            debugLog("Edge function returned typed response. success=\(aiResponse.success), assignments=\(count), confidence=\(conf)")
            return aiResponse
        } catch {
            // Try parsing raw string with fallbacks
            do {
                let rawString: String = try await supabaseService.client.functions
                    .invoke("process-syllabus-ai", options: .init(body: requestBody))

                let preview = rawString.count > 2000 ? String(rawString.prefix(2000)) + "…(truncated)" : rawString
                debugLog("Edge function returned raw string (\(rawString.count) chars):\n\(preview)")

                if let cleanedData = cleanJsonString(rawString).data(using: .utf8) {
                    // Try direct parsing
                    if let parsed = try? JSONDecoder().decode(SyllabusAIResponse.self, from: cleanedData) {
                        debugLog("Parsed SyllabusAIResponse from cleaned JSON.")
                        return parsed
                    }

                    // Try unwrapping from nested structure
                    if let any = try? JSONSerialization.jsonObject(with: cleanedData, options: []) as? [String: Any] {
                        if let inner = any["data"] ?? any["body"] {
                            if let innerData = try? JSONSerialization.data(withJSONObject: inner) {
                                if let parsed = try? JSONDecoder().decode(SyllabusAIResponse.self, from: innerData) {
                                    debugLog("Parsed SyllabusAIResponse from {data/body} wrapper.")
                                    return parsed
                                }
                            }
                        }

                        // Try parsing assignments array directly
                        if let assignmentsArray = any["assignments"] {
                            if let assignmentsData = try? JSONSerialization.data(withJSONObject: assignmentsArray) {
                                if let assignments = try? JSONDecoder().decode([AIAssignmentItem].self, from: assignmentsData) {
                                    debugLog("Parsed assignments array directly. Creating response wrapper.")
                                    return SyllabusAIResponse(
                                        success: true,
                                        assignments: assignments,
                                        confidence: (any["confidence"] as? Double) ?? 0.8,
                                        missingFields: (any["missingFields"] as? [String]) ?? [],
                                        error: nil
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

    private func parseSyllabusResponse(
        _ response: SyllabusAIResponse,
        originalInput: String,
        method: AIImportMethod,
        storedPDFPath: String?
    ) throws -> SyllabusImportData {
        guard response.success else {
            throw AIImportError.aiProcessingFailed(response.error ?? "Unknown AI processing error")
        }

        let assignments = response.assignments
        debugLog("Parsed \(assignments.count) assignments")

        // Log each assignment for debugging
        for (index, assignment) in assignments.enumerated() {
            debugLog("Assignment \(index + 1): \(assignment.name), weight: \(assignment.weight ?? 0), category: \(assignment.category)")
        }

        let importData = SyllabusImportData(
            parsedAssignments: assignments,
            originalInput: originalInput,
            importType: method,
            confidence: response.confidence,
            missingFields: response.missingFields,
            courseMetadata: response.courseMetadata,
            storedPDFURL: storedPDFPath
        )

        debugLog("Created SyllabusImportData with \(importData.parsedAssignments.count) assignments, confidence: \(importData.confidence)")

        return importData
    }

    // MARK: - PDF Access

    func getSignedPDFURL(storagePath: String) async throws -> URL {
        let bucket = "syllabus-imports"
        let signedURL = try await supabaseService.client.storage
            .from(bucket)
            .createSignedURL(path: storagePath, expiresIn: 3600)
        return signedURL
    }
}

// MARK: - Data Models for Syllabus AI Processing

struct SyllabusAIRequest: Codable {
    let method: String
    let textInput: String?
    let fileURL: String?
    let courseId: String
    let userRole: String

    enum CodingKeys: String, CodingKey {
        case method
        case textInput = "textInput"
        case fileURL = "fileURL"
        case courseId = "courseId"
        case userRole = "userRole"
    }
}

struct SyllabusAIResponse: Decodable {
    let success: Bool
    let assignments: [AIAssignmentItem]
    let confidence: Double
    let missingFields: [String]
    let courseMetadata: SyllabusCourseMetadata?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case assignments
        case confidence
        case missingFields = "missingFields"
        case missing_fields
        case courseMetadata = "courseMetadata"
        case course_metadata
        case error
    }

    init(success: Bool, assignments: [AIAssignmentItem], confidence: Double, missingFields: [String], error: String?) {
        self.success = success
        self.assignments = assignments
        self.confidence = confidence
        self.missingFields = missingFields
        self.courseMetadata = nil
        self.error = error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = (try? c.decode(Bool.self, forKey: .success)) ?? false
        self.confidence = (try? c.decode(Double.self, forKey: .confidence)) ?? 0.8

        // Decode assignments with detailed logging
        do {
            let decodedAssignments = try c.decode([AIAssignmentItem].self, forKey: .assignments)
            self.assignments = decodedAssignments
            print("📄 SyllabusAIResponse: Successfully decoded \(decodedAssignments.count) assignments")
        } catch {
            print("📄 SyllabusAIResponse: Failed to decode assignments - \(error)")
            print("📄 SyllabusAIResponse: Error details: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("📄 SyllabusAIResponse: Key '\(key.stringValue)' not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("📄 SyllabusAIResponse: Type '\(type)' mismatch: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("📄 SyllabusAIResponse: Value '\(type)' not found: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("📄 SyllabusAIResponse: Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("📄 SyllabusAIResponse: Unknown decoding error")
                }
            }
            self.assignments = []
        }

        if let fields = try? c.decode([String].self, forKey: .missingFields) {
            self.missingFields = fields
        } else if let fields = try? c.decode([String].self, forKey: .missing_fields) {
            self.missingFields = fields
        } else {
            self.missingFields = []
        }

        if let meta = try? c.decode(SyllabusCourseMetadata.self, forKey: .courseMetadata) {
            self.courseMetadata = meta
        } else if let meta = try? c.decode(SyllabusCourseMetadata.self, forKey: .course_metadata) {
            self.courseMetadata = meta
        } else {
            self.courseMetadata = nil
        }

        self.error = try? c.decode(String.self, forKey: .error)
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

// MARK: - Date Extensions

//extension Date {
//    func toISOString() -> String {
//        let formatter = ISO8601DateFormatter()
//        return formatter.string(from: self)
//    }
//}
