import Foundation
import NaturalLanguage

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let citations: [Citation]?

    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }

    init(role: MessageRole, content: String, citations: [Citation]? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.citations = citations
    }
}

// MARK: - Citation

struct Citation: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let chunkIndex: Int
    let text: String

    init(fileName: String, chunkIndex: Int, text: String) {
        self.id = UUID()
        self.fileName = fileName
        self.chunkIndex = chunkIndex
        self.text = text
    }
}

// MARK: - Course Assistant Engine

/// RAG-powered course assistant using Apple Foundation Models (iOS 18.2+)
@MainActor
final class CourseAssistantEngine: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing = false
    @Published var lastError: Error?

    private let courseId: UUID
    private let courseName: String
    private let userId: String

    private let embeddingService = EmbeddingService.shared
    private let vectorSearchService = VectorSearchService.shared

    init(courseId: UUID, courseName: String, userId: String) {
        self.courseId = courseId
        self.courseName = courseName
        self.userId = userId
    }

    // MARK: - Process Query

    /// Process user query using RAG pipeline
    func processQuery(_ query: String) async {
        // Add user message
        let userMessage = ChatMessage(role: .user, content: query)
        messages.append(userMessage)

        isProcessing = true
        defer { isProcessing = false }

        do {
            // Step 1: Generate query embedding
            print("🔍 Generating query embedding...")
            let queryEmbedding = try await embeddingService.generateEmbedding(for: query)

            // Step 2: Search for relevant document chunks
            print("📚 Searching for relevant context...")
            let relevantChunks = try await vectorSearchService.searchSimilarChunks(
                queryEmbedding: queryEmbedding,
                courseId: courseId,
                userId: userId,
                matchThreshold: 0.7,
                matchCount: 5
            )

            // Step 3: Build context from retrieved chunks
            let context = buildContext(from: relevantChunks)
            let citations = relevantChunks.map { chunk in
                Citation(
                    fileName: chunk.fileName,
                    chunkIndex: chunk.chunkIndex,
                    text: chunk.chunkText
                )
            }

            // Step 4: Generate response using Foundation Models
            print("🤖 Generating AI response...")
            let response = try await generateResponse(query: query, context: context)

            // Step 5: Add assistant message with citations
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: response,
                citations: citations.isEmpty ? nil : citations
            )
            messages.append(assistantMessage)

        } catch {
            print("❌ Error: \(error.localizedDescription)")
            lastError = error

            // Add error message
            let errorMessage = ChatMessage(
                role: .assistant,
                content: "I encountered an error processing your question. Please try again."
            )
            messages.append(errorMessage)
        }
    }

    // MARK: - Context Building

    private func buildContext(from chunks: [DocumentChunk]) -> String {
        guard !chunks.isEmpty else {
            return "No relevant context found in course materials."
        }

        var context = "Here are relevant excerpts from the course materials:\n\n"

        for (index, chunk) in chunks.enumerated() {
            context += "[\(index + 1)] From \(chunk.fileName):\n"
            context += chunk.chunkText.trimmingCharacters(in: .whitespacesAndNewlines)
            context += "\n\n"
        }

        return context
    }

    // MARK: - Response Generation

    private func generateResponse(query: String, context: String) async throws -> String {
        // Check iOS version
        if #available(iOS 18.2, *) {
            return try await generateResponseWithFoundationModels(query: query, context: context)
        } else {
            return try await generateFallbackResponse(query: query, context: context)
        }
    }

    @available(iOS 18.2, *)
    private func generateResponseWithFoundationModels(query: String, context: String) async throws -> String {
        // Build prompt
        let systemPrompt = """
        You are a helpful AI assistant for the course "\(courseName)".

        Answer the student's question based ONLY on the provided course materials.
        If the answer cannot be found in the materials, say so clearly.
        Be concise and accurate. Cite specific details from the materials when relevant.
        """

        let userPrompt = """
        Context from course materials:
        \(context)

        Student's question:
        \(query)
        """

        // Note: Apple Foundation Models API is not publicly documented yet as of iOS 18.2
        // This is a placeholder for when the API becomes available
        // For now, we'll use the fallback approach

        return try await generateFallbackResponse(query: query, context: context)
    }

    private func generateFallbackResponse(query: String, context: String) async throws -> String {
        // Simple fallback: return context with guidance
        // In production, this could call a cloud-based LLM if needed

        var response = "Based on the course materials, here's what I found:\n\n"

        if context.contains("No relevant context found") {
            response = "I couldn't find relevant information in the uploaded course materials to answer your question. "
            response += "You may want to:\n"
            response += "• Rephrase your question\n"
            response += "• Upload additional course materials\n"
            response += "• Ask a more specific question about the topics covered"
        } else {
            response += context
            response += "\n\nPlease review the excerpts above for information related to: \(query)"
        }

        return response
    }

    // MARK: - Clear Chat

    func clearChat() {
        messages.removeAll()
    }
}

// MARK: - Errors

enum AssistantError: LocalizedError {
    case noContext
    case generationFailed
    case unsupportedDevice

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "No relevant context found in course materials"
        case .generationFailed:
            return "Failed to generate response"
        case .unsupportedDevice:
            return "AI features require iOS 18.2 or later"
        }
    }
}
