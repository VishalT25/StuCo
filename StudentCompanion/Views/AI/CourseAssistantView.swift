import SwiftUI

struct CourseAssistantView: View {
    let course: Course

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @StateObject private var assistant: CourseAssistantEngine
    @State private var inputText = ""
    @State private var showCitations = false
    @State private var selectedCitations: [Citation]?

    init(course: Course) {
        self.course = course

        // Initialize assistant with dummy userId for now
        // In production, get real userId from SupabaseService
        _assistant = StateObject(wrappedValue: CourseAssistantEngine(
            courseId: course.id,
            courseName: course.name,
            userId: "user-id-placeholder"
        ))
    }

    var body: some View {
        ZStack {
            // Glassmorphic background
            themeManager.currentTheme.darkModeBackgroundFill
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection

                // Messages scroll view
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if assistant.messages.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(assistant.messages) { message in
                                    MessageBubble(
                                        message: message,
                                        themeManager: themeManager,
                                        onShowCitations: { citations in
                                            selectedCitations = citations
                                            showCitations = true
                                        }
                                    )
                                    .id(message.id)
                                }
                            }

                            if assistant.isProcessing {
                                typingIndicator
                            }
                        }
                        .padding()
                    }
                    .onChange(of: assistant.messages.count) { _ in
                        if let lastMessage = assistant.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input section
                inputSection
            }
        }
        .sheet(isPresented: $showCitations) {
            if let citations = selectedCitations {
                CitationsSheet(citations: citations, themeManager: themeManager)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.darkModeAccentHue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(course.name)
                        .font(.headline)
                        .lineLimit(1)
                }

                Text("AI answers generated privately on your device")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                assistant.clearChat()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .disabled(assistant.messages.isEmpty)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title2)
            }
        }
        .padding()
        .background(
            Color(.systemBackground).opacity(0.95)
                .blur(radius: 10)
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.primaryColor,
                            themeManager.currentTheme.darkModeAccentHue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 60)

            VStack(spacing: 8) {
                Text("Course AI Assistant")
                    .font(.title2.bold())

                Text("Ask questions about your course materials")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                ExampleQuestion(text: "What topics are covered in Chapter 3?")
                ExampleQuestion(text: "Explain the key concepts from the lecture notes")
                ExampleQuestion(text: "What's the formula for calculating X?")
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        HStack(spacing: 12) {
            HStack {
                TextField("Ask about course materials...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .disabled(assistant.isProcessing)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(20)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || assistant.isProcessing
                            ? AnyShapeStyle(Color.gray)
                            : AnyShapeStyle(LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.darkModeAccentHue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || assistant.isProcessing)
        }
        .padding()
        .background(
            Color(.systemBackground).opacity(0.95)
                .blur(radius: 10)
        )
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .animation(
                    Animation.easeInOut(duration: 0.6).repeatForever().delay(0),
                    value: assistant.isProcessing
                )

            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .animation(
                    Animation.easeInOut(duration: 0.6).repeatForever().delay(0.2),
                    value: assistant.isProcessing
                )

            Circle()
                .fill(Color.gray)
                .frame(width: 8, height: 8)
                .animation(
                    Animation.easeInOut(duration: 0.6).repeatForever().delay(0.4),
                    value: assistant.isProcessing
                )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        inputText = ""

        Task {
            await assistant.processQuery(trimmedText)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    let themeManager: ThemeManager
    let onShowCitations: ([Citation]) -> Void

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                Text(message.content)
                    .padding(12)
                    .background(
                        message.role == .user
                            ? AnyShapeStyle(LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.darkModeAccentHue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(Color(.systemGray6))
                    )
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)

                if let citations = message.citations, !citations.isEmpty {
                    Button {
                        onShowCitations(citations)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                            Text("\(citations.count) source\(citations.count == 1 ? "" : "s")")
                        }
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Example Question

struct ExampleQuestion: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
}

// MARK: - Citations Sheet

struct CitationsSheet: View {
    let citations: [Citation]
    let themeManager: ThemeManager

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                themeManager.currentTheme.darkModeBackgroundFill
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(citations) { citation in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(themeManager.currentTheme.primaryColor)
                                    Text(citation.fileName)
                                        .font(.headline)
                                }

                                Text(citation.text)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
