import Foundation
import Supabase

/// Service for generating text embeddings via Supabase Edge Function
@MainActor
final class EmbeddingService: ObservableObject {
    static let shared = EmbeddingService()

    @Published var isGenerating = false
    @Published var lastError: Error?

    private let supabaseClient = SupabaseService.shared.client

    private init() {}

    // MARK: - Generate Embeddings

    /// Generate embeddings for an array of text chunks
    func generateEmbeddings(for texts: [String]) async throws -> [[Double]] {
        guard !texts.isEmpty else { return [] }

        isGenerating = true
        defer { isGenerating = false }

        // Call Edge Function
        struct EmbeddingRequest: Encodable {
            let texts: [String]
        }

        struct EmbeddingResponse: Decodable {
            let embeddings: [[Double]]
        }

        let requestBody = EmbeddingRequest(texts: texts)

        let response: EmbeddingResponse = try await supabaseClient.functions
            .invoke("generate-embeddings", options: FunctionInvokeOptions(
                body: requestBody
            ))

        let embeddings = response.embeddings

        guard embeddings.count == texts.count else {
            throw EmbeddingError.embeddingCountMismatch(expected: texts.count, got: embeddings.count)
        }

        return embeddings
    }

    /// Generate embedding for a single text
    func generateEmbedding(for text: String) async throws -> [Double] {
        let embeddings = try await generateEmbeddings(for: [text])
        guard let embedding = embeddings.first else {
            throw EmbeddingError.noEmbeddingGenerated
        }
        return embedding
    }

    // MARK: - Batch Processing

    /// Generate embeddings in batches to avoid timeouts
    func generateEmbeddingsInBatches(
        for texts: [String],
        batchSize: Int = 20
    ) async throws -> [[Double]] {
        var allEmbeddings: [[Double]] = []

        // Split into batches
        let batches = stride(from: 0, to: texts.count, by: batchSize).map {
            Array(texts[$0..<min($0 + batchSize, texts.count)])
        }

        print("📊 Generating embeddings in \(batches.count) batches...")

        for (index, batch) in batches.enumerated() {
            print("📦 Processing batch \(index + 1)/\(batches.count)...")

            let batchEmbeddings = try await generateEmbeddings(for: batch)
            allEmbeddings.append(contentsOf: batchEmbeddings)

            // Small delay between batches to avoid rate limiting
            if index < batches.count - 1 {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }

        print("✅ Generated \(allEmbeddings.count) embeddings")
        return allEmbeddings
    }
}

// MARK: - Errors

enum EmbeddingError: LocalizedError {
    case invalidResponse
    case embeddingCountMismatch(expected: Int, got: Int)
    case noEmbeddingGenerated
    case rateLimitExceeded
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from embedding service"
        case .embeddingCountMismatch(let expected, let got):
            return "Expected \(expected) embeddings but got \(got)"
        case .noEmbeddingGenerated:
            return "No embedding was generated"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .networkError:
            return "Network error occurred"
        }
    }
}
