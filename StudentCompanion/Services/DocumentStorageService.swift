import SwiftUI
import Foundation
import PDFKit
import UIKit

// MARK: - Document Storage Service

@MainActor
class DocumentStorageService: ObservableObject {
    @Published private(set) var documents: [CourseDocument] = []
    @Published private(set) var currentUsageBytes: Int64 = 0
    @Published private(set) var isLoading: Bool = false

    private let supabaseService = SupabaseService.shared
    private let storageQuotaBytes: Int64 = 5 * 1024 * 1024 // 5MB default (configurable)
    private let bucketName = "course-documents"

    // MARK: - Quota Properties

    var remainingBytes: Int64 {
        max(0, storageQuotaBytes - currentUsageBytes)
    }

    var usagePercentage: Double {
        guard storageQuotaBytes > 0 else { return 0 }
        return Double(currentUsageBytes) / Double(storageQuotaBytes) * 100
    }

    var quotaColor: Color {
        let percentage = usagePercentage
        if percentage < 50 {
            return .green
        } else if percentage < 80 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Load Documents

    func loadDocuments(forCourse courseId: UUID) async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw DocumentError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch documents from Supabase
            let response = try await supabaseService.client
                .from(DatabaseCourseDocument.tableName)
                .select()
                .eq("user_id", value: userId)
                .eq("course_id", value: courseId.uuidString)
                .order("upload_date", ascending: false)
                .execute()

            let databaseDocuments = try JSONDecoder().decode([DatabaseCourseDocument].self, from: response.data)
            documents = databaseDocuments.map { $0.toLocal() }

            // Calculate total usage
            await calculateTotalUsage()

            print("✅ Loaded \(documents.count) documents for course \(courseId)")
        } catch {
            print("❌ Failed to load documents: \(error)")
            throw DocumentError.loadFailed(error.localizedDescription)
        }
    }

    // MARK: - Calculate Total Usage

    private func calculateTotalUsage() async {
        guard let userId = supabaseService.currentUser?.id.uuidString else { return }

        do {
            let response = try await supabaseService.client
                .from(DatabaseCourseDocument.tableName)
                .select("file_size")
                .eq("user_id", value: userId)
                .execute()

            struct FileSizeResult: Codable {
                let file_size: Int64
            }

            let results = try JSONDecoder().decode([FileSizeResult].self, from: response.data)
            currentUsageBytes = results.reduce(0) { $0 + $1.file_size }

            print("📊 Current storage usage: \(ByteCountFormatter.string(fromByteCount: currentUsageBytes, countStyle: .file))")
        } catch {
            print("⚠️ Failed to calculate storage usage: \(error)")
        }
    }

    // MARK: - Check Quota

    func checkQuota(forFileSize fileSize: Int64) -> Bool {
        return (currentUsageBytes + fileSize) <= storageQuotaBytes
    }

    // MARK: - Upload Document

    func uploadDocument(
        url: URL,
        courseId: UUID,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> CourseDocument {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw DocumentError.notAuthenticated
        }

        // Try to access security-scoped resource (may not be needed if file is already copied)
        let needsSecurityAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Get file attributes
        guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = fileAttributes[.size] as? Int64 else {
            throw DocumentError.uploadFailed("Could not access file or determine file size")
        }

        // Check quota
        guard checkQuota(forFileSize: fileSize) else {
            throw DocumentError.quotaExceeded
        }

        // Determine file type
        let fileExtension = url.pathExtension.lowercased()
        guard let fileType = DocumentFileType.from(fileExtension: fileExtension) else {
            throw DocumentError.unsupportedFileType
        }

        progressHandler(0.1)

        // Read file data
        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch {
            throw DocumentError.uploadFailed("Failed to read file data: \(error.localizedDescription)")
        }

        progressHandler(0.2)

        // Generate storage path
        let timestamp = Int(Date().timeIntervalSince1970)
        let sanitizedFileName = url.lastPathComponent.replacingOccurrences(of: " ", with: "_")
        let storagePath = "\(userId)/\(courseId.uuidString)/\(timestamp)_\(sanitizedFileName)"

        // Debug logging
        #if DEBUG
        print("📤 Upload Debug:")
        print("   User ID: \(userId)")
        print("   Course ID: \(courseId.uuidString)")
        print("   Storage Path: \(storagePath)")
        print("   Auth UID: \(supabaseService.currentUser?.id.uuidString ?? "nil")")
        #endif

        // Upload to Supabase storage
        do {
            try await supabaseService.client.storage
                .from(bucketName)
                .upload(
                    path: storagePath,
                    file: fileData,
                    options: .init(
                        contentType: getMimeType(for: fileExtension)
                    )
                )
            print("✅ Uploaded file to storage: \(storagePath)")
        } catch {
            print("❌ Storage upload failed: \(error)")
            throw DocumentError.uploadFailed("Storage upload failed: \(error.localizedDescription)")
        }

        progressHandler(0.6)

        // Extract metadata
        let metadata = await extractMetadata(from: url, fileType: fileType)

        // Generate thumbnail
        let thumbnailData = await generateThumbnail(from: url, fileType: fileType)

        progressHandler(0.8)

        // Create document record
        let document = CourseDocument(
            courseId: courseId,
            userId: userId,
            name: url.lastPathComponent,
            fileType: fileType,
            fileSize: fileSize,
            storagePath: storagePath,
            thumbnailData: thumbnailData,
            metadata: metadata
        )

        // Save to local cache
        saveToLocalCache(document: document, fileData: fileData)

        // Save to database
        let databaseDocument = DatabaseCourseDocument(from: document, userId: userId)
        do {
            try await supabaseService.client
                .from(DatabaseCourseDocument.tableName)
                .insert(databaseDocument)
                .execute()

            print("✅ Saved document record to database")
        } catch {
            print("❌ Database insert failed: \(error)")
            // Attempt to delete uploaded file
            try? await supabaseService.client.storage
                .from(bucketName)
                .remove(paths: [storagePath])
            throw DocumentError.uploadFailed("Database insert failed: \(error.localizedDescription)")
        }

        progressHandler(1.0)

        // Update local state
        documents.insert(document, at: 0)
        currentUsageBytes += fileSize

        return document
    }

    // MARK: - Download Document

    func downloadDocument(_ document: CourseDocument) async throws -> URL {
        // Check local cache first
        if let cachedURL = getFromLocalCache(document: document) {
            print("✅ Found document in local cache")
            return cachedURL
        }

        // Download from Supabase
        print("📥 Downloading document from storage...")
        do {
            let data = try await supabaseService.client.storage
                .from(bucketName)
                .download(path: document.storagePath)

            // Save to local cache
            let cachedURL = saveToLocalCache(document: document, fileData: data)

            return cachedURL
        } catch {
            print("❌ Download failed: \(error)")
            throw DocumentError.downloadFailed(error.localizedDescription)
        }
    }

    // MARK: - Rename Document

    func renameDocument(_ document: CourseDocument, newName: String) async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw DocumentError.notAuthenticated
        }

        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw DocumentError.renameFailed("Name cannot be empty")
        }

        // Update in database
        do {
            try await supabaseService.client
                .from(DatabaseCourseDocument.tableName)
                .update(["name": trimmedName])
                .eq("id", value: document.id.uuidString)
                .eq("user_id", value: userId)
                .execute()

            print("✅ Renamed document in database")
        } catch {
            print("❌ Database rename failed: \(error)")
            throw DocumentError.renameFailed(error.localizedDescription)
        }

        // Rename local cache file if it exists
        let cacheDir = getCacheDirectory()
        let oldCacheURL = cacheDir.appendingPathComponent("\(document.id.uuidString)_\(document.name)")
        let newCacheURL = cacheDir.appendingPathComponent("\(document.id.uuidString)_\(trimmedName)")

        if FileManager.default.fileExists(atPath: oldCacheURL.path) {
            try? FileManager.default.moveItem(at: oldCacheURL, to: newCacheURL)
            print("✅ Renamed local cache file")
        }

        // Update local state
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index].name = trimmedName
        }
    }

    // MARK: - Delete Document

    func deleteDocument(_ document: CourseDocument) async throws {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw DocumentError.notAuthenticated
        }

        // Delete from database
        do {
            try await supabaseService.client
                .from(DatabaseCourseDocument.tableName)
                .delete()
                .eq("id", value: document.id.uuidString)
                .eq("user_id", value: userId)
                .execute()

            print("✅ Deleted document from database")
        } catch {
            print("❌ Database delete failed: \(error)")
            throw DocumentError.deleteFailed(error.localizedDescription)
        }

        // Delete from storage
        do {
            try await supabaseService.client.storage
                .from(bucketName)
                .remove(paths: [document.storagePath])

            print("✅ Deleted document from storage")
        } catch {
            print("⚠️ Storage delete failed (non-critical): \(error)")
            // Continue even if storage delete fails
        }

        // Delete from local cache
        deleteFromLocalCache(document: document)

        // Update local state
        documents.removeAll { $0.id == document.id }
        currentUsageBytes = max(0, currentUsageBytes - document.fileSize)
    }

    // MARK: - Metadata Extraction

    private func extractMetadata(from url: URL, fileType: DocumentFileType) async -> DocumentMetadata? {
        switch fileType {
        case .pdf:
            return extractPDFMetadata(from: url)
        case .image:
            return extractImageMetadata(from: url)
        default:
            return nil
        }
    }

    private func extractPDFMetadata(from url: URL) -> DocumentMetadata? {
        guard let pdfDocument = PDFDocument(url: url) else { return nil }

        return DocumentMetadata(
            pageCount: pdfDocument.pageCount,
            author: pdfDocument.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String,
            creationDate: pdfDocument.documentAttributes?[PDFDocumentAttribute.creationDateAttribute] as? Date
        )
    }

    private func extractImageMetadata(from url: URL) -> DocumentMetadata? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }

        let width = properties[kCGImagePropertyPixelWidth as String] as? CGFloat ?? 0
        let height = properties[kCGImagePropertyPixelHeight as String] as? CGFloat ?? 0

        return DocumentMetadata(
            dimensions: CGSize(width: width, height: height)
        )
    }

    // MARK: - Thumbnail Generation

    private func generateThumbnail(from url: URL, fileType: DocumentFileType) async -> Data? {
        switch fileType {
        case .pdf:
            return generatePDFThumbnail(from: url)
        case .image:
            return generateImageThumbnail(from: url)
        default:
            return nil
        }
    }

    private func generatePDFThumbnail(from url: URL) -> Data? {
        guard let pdfDocument = PDFDocument(url: url),
              let firstPage = pdfDocument.page(at: 0) else {
            return nil
        }

        let pageRect = firstPage.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100 * pageRect.height / pageRect.width))

        let image = renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))

            context.cgContext.translateBy(x: 0, y: renderer.format.bounds.height)
            context.cgContext.scaleBy(x: 100 / pageRect.width, y: -100 / pageRect.width)

            firstPage.draw(with: .mediaBox, to: context.cgContext)
        }

        return image.jpegData(compressionQuality: 0.7)
    }

    private func generateImageThumbnail(from url: URL) -> Data? {
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }

        let targetSize = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return thumbnail.jpegData(compressionQuality: 0.7)
    }

    // MARK: - Local Cache Management

    private func saveToLocalCache(document: CourseDocument, fileData: Data) -> URL {
        let cacheDir = getCacheDirectory()
        let fileURL = cacheDir.appendingPathComponent("\(document.id.uuidString)_\(document.name)")

        try? fileData.write(to: fileURL)

        return fileURL
    }

    private func getFromLocalCache(document: CourseDocument) -> URL? {
        let cacheDir = getCacheDirectory()
        let fileURL = cacheDir.appendingPathComponent("\(document.id.uuidString)_\(document.name)")

        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    private func deleteFromLocalCache(document: CourseDocument) {
        let cacheDir = getCacheDirectory()
        let fileURL = cacheDir.appendingPathComponent("\(document.id.uuidString)_\(document.name)")

        try? FileManager.default.removeItem(at: fileURL)
    }

    private func getCacheDirectory() -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let documentsCacheDir = cacheDir.appendingPathComponent("CourseDocuments", isDirectory: true)

        if !FileManager.default.fileExists(atPath: documentsCacheDir.path) {
            try? FileManager.default.createDirectory(at: documentsCacheDir, withIntermediateDirectories: true)
        }

        return documentsCacheDir
    }

    func clearCache() {
        let cacheDir = getCacheDirectory()
        try? FileManager.default.removeItem(at: cacheDir)
    }

    // MARK: - Helper Methods

    private func getMimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "pdf": return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic": return "image/heic"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "txt": return "text/plain"
        case "md": return "text/markdown"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Document Errors

enum DocumentError: LocalizedError {
    case notAuthenticated
    case quotaExceeded
    case unsupportedFileType
    case loadFailed(String)
    case uploadFailed(String)
    case downloadFailed(String)
    case deleteFailed(String)
    case renameFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to manage documents"
        case .quotaExceeded:
            return "Storage quota exceeded. Please delete some documents to free up space."
        case .unsupportedFileType:
            return "This file type is not supported"
        case .loadFailed(let message):
            return "Failed to load documents: \(message)"
        case .uploadFailed(let message):
            return "Failed to upload document: \(message)"
        case .downloadFailed(let message):
            return "Failed to download document: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete document: \(message)"
        case .renameFailed(let message):
            return "Failed to rename document: \(message)"
        }
    }
}
