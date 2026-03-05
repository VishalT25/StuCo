import SwiftUI
import Foundation
import UniformTypeIdentifiers

// MARK: - Course Document Model

struct CourseDocument: Identifiable, Codable, Equatable {
    var id: UUID
    var courseId: UUID
    var userId: String
    var name: String
    var fileType: DocumentFileType
    var fileSize: Int64
    var storagePath: String
    var localCachePath: String?
    var uploadDate: Date
    var lastModified: Date
    var thumbnailData: Data?
    var metadata: DocumentMetadata?

    init(
        id: UUID = UUID(),
        courseId: UUID,
        userId: String,
        name: String,
        fileType: DocumentFileType,
        fileSize: Int64,
        storagePath: String,
        localCachePath: String? = nil,
        uploadDate: Date = Date(),
        lastModified: Date = Date(),
        thumbnailData: Data? = nil,
        metadata: DocumentMetadata? = nil
    ) {
        self.id = id
        self.courseId = courseId
        self.userId = userId
        self.name = name
        self.fileType = fileType
        self.fileSize = fileSize
        self.storagePath = storagePath
        self.localCachePath = localCachePath
        self.uploadDate = uploadDate
        self.lastModified = lastModified
        self.thumbnailData = thumbnailData
        self.metadata = metadata
    }

    /// Formatted file size string (e.g., "2.3 MB")
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// Relative upload date (e.g., "2 days ago")
    var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: uploadDate, relativeTo: Date())
    }
}

// MARK: - Document File Type

enum DocumentFileType: String, Codable, CaseIterable, Identifiable {
    case pdf
    case image
    case word
    case excel
    case powerpoint
    case text

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pdf: return "PDF"
        case .image: return "Image"
        case .word: return "Word Document"
        case .excel: return "Excel Spreadsheet"
        case .powerpoint: return "PowerPoint Presentation"
        case .text: return "Text File"
        }
    }

    var icon: String {
        switch self {
        case .pdf: return "doc.richtext.fill"
        case .image: return "photo.fill"
        case .word: return "doc.text.fill"
        case .excel: return "tablecells.fill"
        case .powerpoint: return "rectangle.fill.on.rectangle.fill"
        case .text: return "doc.plaintext.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .pdf: return .red
        case .image: return .blue
        case .word: return Color(hex: "2B579A") ?? Color(red: 43/255, green: 87/255, blue: 154/255) // Microsoft Word blue
        case .excel: return Color(hex: "217346") ?? Color(red: 33/255, green: 115/255, blue: 70/255) // Microsoft Excel green
        case .powerpoint: return Color(hex: "D24726") ?? Color(red: 210/255, green: 71/255, blue: 38/255) // Microsoft PowerPoint orange
        case .text: return .gray
        }
    }

    var allowedExtensions: [String] {
        switch self {
        case .pdf: return ["pdf"]
        case .image: return ["jpg", "jpeg", "png", "heic", "heif"]
        case .word: return ["doc", "docx"]
        case .excel: return ["xls", "xlsx", "csv"]
        case .powerpoint: return ["ppt", "pptx"]
        case .text: return ["txt", "md", "rtf"]
        }
    }

    var utTypes: [UTType] {
        switch self {
        case .pdf: return [.pdf]
        case .image: return [.image, .jpeg, .png, .heic]
        case .word: return [.init(filenameExtension: "doc") ?? .data, .init(filenameExtension: "docx") ?? .data]
        case .excel: return [.init(filenameExtension: "xls") ?? .data, .init(filenameExtension: "xlsx") ?? .data, .commaSeparatedText]
        case .powerpoint: return [.init(filenameExtension: "ppt") ?? .data, .init(filenameExtension: "pptx") ?? .data]
        case .text: return [.plainText, .init(filenameExtension: "md") ?? .data, .rtf]
        }
    }

    /// Detect file type from file extension
    static func from(fileExtension: String) -> DocumentFileType? {
        let ext = fileExtension.lowercased()
        for type in DocumentFileType.allCases {
            if type.allowedExtensions.contains(ext) {
                return type
            }
        }
        return nil
    }

    /// All supported UTTypes for document picker
    static var allSupportedUTTypes: [UTType] {
        return DocumentFileType.allCases.flatMap { $0.utTypes }
    }
}

// MARK: - Document Metadata

struct DocumentMetadata: Codable, Equatable {
    var pageCount: Int?
    var dimensions: CGSize?
    var author: String?
    var creationDate: Date?
    var wordCount: Int?

    init(
        pageCount: Int? = nil,
        dimensions: CGSize? = nil,
        author: String? = nil,
        creationDate: Date? = nil,
        wordCount: Int? = nil
    ) {
        self.pageCount = pageCount
        self.dimensions = dimensions
        self.author = author
        self.creationDate = creationDate
        self.wordCount = wordCount
    }
}
