import Foundation
import Supabase

/// Search result from vector similarity search
struct DocumentChunk: Identifiable, Codable {
    let id: UUID
    let chunkText: String
    let metadata: [String: String]
    let similarity: Double

    var fileName: String {
        metadata["file_name"] ?? "Unknown"
    }

    var chunkIndex: Int {
        Int(metadata["chunk_index"] ?? "0") ?? 0
    }
}

/// Encodable struct for RPC search parameters
private struct VectorSearchParams: Encodable {
    let query_embedding: [Double]
    let course_id_param: String
    let user_id_param: String
    let match_threshold: Double
    let match_count: Int
}

/// Encodable struct for document embedding inserts
private struct DocumentEmbeddingInsert: Encodable {
    let user_id: String
    let course_id: String
    let document_id: String
    let chunk_index: Int
    let chunk_text: String
    let embedding: [Double]
    let metadata: [String: String]
}

/// Service for vector similarity search in document embeddings
@MainActor
final class VectorSearchService: ObservableObject {
    static let shared = VectorSearchService()

    @Published var isSearching = false
    @Published var lastError: Error?

    private let supabaseClient = SupabaseService.shared.client

    private init() {}

    // MARK: - Vector Search

    /// Search for similar document chunks using vector similarity
    func searchSimilarChunks(
        queryEmbedding: [Double],
        courseId: UUID,
        userId: String,
        matchThreshold: Double = 0.7,
        matchCount: Int = 5
    ) async throws -> [DocumentChunk] {
        isSearching = true
        defer { isSearching = false }

        // Call RPC function for vector search
        let params = VectorSearchParams(
            query_embedding: queryEmbedding,
            course_id_param: courseId.uuidString,
            user_id_param: userId,
            match_threshold: matchThreshold,
            match_count: matchCount
        )

        let response = try await supabaseClient
            .rpc("search_document_embeddings", params: params)
            .execute()

        // Parse response
        let data = response.data

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        struct SearchResult: Codable {
            let id: String
            let chunkText: String
            let metadata: [String: String]?
            let similarity: Double
        }

        let results = try decoder.decode([SearchResult].self, from: data)

        return results.map { result in
            DocumentChunk(
                id: UUID(uuidString: result.id) ?? UUID(),
                chunkText: result.chunkText,
                metadata: result.metadata ?? [:],
                similarity: result.similarity
            )
        }
    }

    // MARK: - Store Embeddings

    /// Store document embeddings in vector database
    func storeDocumentEmbeddings(
        chunks: [(text: String, metadata: [String: Any])],
        embeddings: [[Double]],
        courseId: UUID,
        documentId: UUID,
        userId: String
    ) async throws {
        guard chunks.count == embeddings.count else {
            throw VectorSearchError.chunkEmbeddingMismatch
        }

        // Prepare records for batch insert
        var records: [DocumentEmbeddingInsert] = []

        for (index, (chunk, embedding)) in zip(chunks, embeddings).enumerated() {
            let metadata = chunk.metadata.compactMapValues { value -> String? in
                switch value {
                case let v as String: return v
                case let v as Int: return String(v)
                case let v as Double: return String(v)
                default: return nil
                }
            }

            records.append(
                DocumentEmbeddingInsert(
                    user_id: userId,
                    course_id: courseId.uuidString,
                    document_id: documentId.uuidString,
                    chunk_index: index,
                    chunk_text: chunk.text,
                    embedding: embedding,
                    metadata: metadata
                )
            )
        }

        // Batch insert (Supabase supports up to 1000 rows per insert)
        let batchSize = 100
        let batches = stride(from: 0, to: records.count, by: batchSize).map {
            Array(records[$0..<min($0 + batchSize, records.count)])
        }

        print("💾 Storing \(records.count) embeddings in \(batches.count) batches...")

        for (batchIndex, batch) in batches.enumerated() {
            print("📦 Inserting batch \(batchIndex + 1)/\(batches.count)...")

            try await supabaseClient
                .from("document_embeddings")
                .insert(batch)
                .execute()
        }

        print("✅ Stored \(records.count) document embeddings")
    }

    // MARK: - Delete Embeddings

    /// Delete all embeddings for a document
    func deleteDocumentEmbeddings(documentId: UUID, userId: String) async throws {
        try await supabaseClient
            .from("document_embeddings")
            .delete()
            .eq("document_id", value: documentId.uuidString)
            .eq("user_id", value: userId)
            .execute()

        print("🗑️ Deleted embeddings for document \(documentId)")
    }

    /// Delete all embeddings for a course
    func deleteCourseEmbeddings(courseId: UUID, userId: String) async throws {
        try await supabaseClient
            .from("document_embeddings")
            .delete()
            .eq("course_id", value: courseId.uuidString)
            .eq("user_id", value: userId)
            .execute()

        print("🗑️ Deleted embeddings for course \(courseId)")
    }
}

// MARK: - Errors

enum VectorSearchError: LocalizedError {
    case invalidResponse
    case chunkEmbeddingMismatch
    case storageError
    case deletionError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from vector search"
        case .chunkEmbeddingMismatch:
            return "Number of chunks doesn't match number of embeddings"
        case .storageError:
            return "Failed to store embeddings"
        case .deletionError:
            return "Failed to delete embeddings"
        }
    }
}
