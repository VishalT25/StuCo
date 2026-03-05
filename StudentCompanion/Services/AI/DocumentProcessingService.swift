import Foundation
import PDFKit
import Vision
import UIKit

/// Service for extracting text from documents (PDF, images) and chunking for embeddings
@MainActor
final class DocumentProcessingService: ObservableObject {
    static let shared = DocumentProcessingService()

    // Chunk settings (optimized for OpenAI text-embedding-3-small)
    private let maxChunkTokens = 800
    private let chunkOverlapTokens = 100
    private let approximateCharsPerToken = 4

    private init() {}

    // MARK: - Document Processing

    /// Extract text from a document file
    func extractText(from fileURL: URL) async throws -> String {
        let fileExtension = fileURL.pathExtension.lowercased()

        switch fileExtension {
        case "pdf":
            return try await extractTextFromPDF(fileURL)

        case "jpg", "jpeg", "png", "heic", "heif":
            return try await extractTextFromImage(fileURL)

        case "txt", "md":
            return try String(contentsOf: fileURL, encoding: .utf8)

        default:
            throw DocumentProcessingError.unsupportedFileType(fileExtension)
        }
    }

    // MARK: - PDF Text Extraction

    private func extractTextFromPDF(_ url: URL) async throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentProcessingError.failedToLoadPDF
        }

        var fullText = ""

        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            if let pageText = page.string {
                fullText += pageText + "\n\n"
            }
        }

        guard !fullText.isEmpty else {
            throw DocumentProcessingError.noTextExtracted
        }

        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Image OCR Text Extraction

    private func extractTextFromImage(_ url: URL) async throws -> String {
        guard let image = UIImage(contentsOfFile: url.path) else {
            throw DocumentProcessingError.failedToLoadImage
        }

        guard let cgImage = image.cgImage else {
            throw DocumentProcessingError.failedToLoadImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: DocumentProcessingError.noTextExtracted)
                    return
                }

                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                if recognizedText.isEmpty {
                    continuation.resume(throwing: DocumentProcessingError.noTextExtracted)
                } else {
                    continuation.resume(returning: recognizedText)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Text Chunking

    /// Chunk text into segments suitable for embedding generation
    /// Returns array of (chunkText, metadata)
    func chunkText(_ text: String, fileName: String) -> [(text: String, metadata: [String: Any])] {
        // Clean and normalize text
        let cleanedText = cleanText(text)

        // Split into sentences (simple approach)
        let sentences = cleanedText.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var chunks: [(text: String, metadata: [String: Any])] = []
        var currentChunk = ""
        var chunkIndex = 0

        for sentence in sentences {
            let proposedChunk = currentChunk.isEmpty ? sentence : currentChunk + ". " + sentence
            let estimatedTokens = proposedChunk.count / approximateCharsPerToken

            if estimatedTokens > maxChunkTokens {
                // Save current chunk
                if !currentChunk.isEmpty {
                    chunks.append((
                        text: currentChunk,
                        metadata: [
                            "chunk_index": chunkIndex,
                            "file_name": fileName,
                            "char_count": currentChunk.count
                        ]
                    ))
                    chunkIndex += 1
                }

                // Start new chunk with overlap
                if chunkIndex > 0 {
                    // Add last sentence of previous chunk for overlap
                    currentChunk = sentence
                } else {
                    currentChunk = sentence
                }
            } else {
                currentChunk = proposedChunk
            }
        }

        // Add final chunk
        if !currentChunk.isEmpty {
            chunks.append((
                text: currentChunk,
                metadata: [
                    "chunk_index": chunkIndex,
                    "file_name": fileName,
                    "char_count": currentChunk.count
                ]
            ))
        }

        return chunks
    }

    // MARK: - Text Cleaning

    private func cleanText(_ text: String) -> String {
        // Remove excessive whitespace
        var cleaned = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // Remove control characters
        cleaned = cleaned.components(separatedBy: .controlCharacters).joined()

        // Normalize line breaks
        cleaned = cleaned.replacingOccurrences(of: "\n\n+", with: "\n\n", options: .regularExpression)

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum DocumentProcessingError: LocalizedError {
    case unsupportedFileType(String)
    case failedToLoadPDF
    case failedToLoadImage
    case noTextExtracted
    case chunkingFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let ext):
            return "Unsupported file type: .\(ext)"
        case .failedToLoadPDF:
            return "Failed to load PDF document"
        case .failedToLoadImage:
            return "Failed to load image"
        case .noTextExtracted:
            return "No text could be extracted from document"
        case .chunkingFailed:
            return "Failed to chunk document text"
        }
    }
}
