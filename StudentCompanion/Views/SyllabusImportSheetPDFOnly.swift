import SwiftUI
import UniformTypeIdentifiers

// MARK: - Syllabus Import Sheet (PDF Only)

struct SyllabusImportSheetPDFOnly: View {
    let course: Course
    let courseManager: UnifiedCourseManager?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager

    // Computed property to convert Course colorHex to Color
    private var courseColor: Color {
        Color(hex: course.colorHex) ?? .blue
    }

    // AI Feature color scheme
    private var aiPrimaryColor: Color {
        themeManager.currentTheme.primaryColor
    }

    private var aiSecondaryColor: Color {
        themeManager.currentTheme.secondaryColor
    }

    @State private var showSourceSelector = false
    @State private var importSource: ImportSource = .upload
    @State private var selectedExistingDocument: CourseDocument?
    @State private var isShowingDocumentPicker = false
    @State private var selectedDocumentURL: URL?
    @State private var selectedDocumentName: String?

    @State private var isProcessing = false
    @State private var processingProgress: Double = 0.0
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showReviewModal = false
    @State private var importData: SyllabusImportData?

    @StateObject private var storageService = DocumentStorageService()
    private let syllabusImportService = SyllabusImportService.shared

    enum ImportSource {
        case upload
        case existing
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                backgroundGradient

                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        headerView

                        // Source selector (Upload or Existing)
                        sourceSelector

                        // PDF Input
                        if importSource == .upload {
                            pdfInputView
                        } else {
                            existingDocumentsView
                        }

                        // Preview Card (if PDF selected)
                        if hasSelectedDocument {
                            previewCard
                        }

                        // Process Button
                        if hasSelectedDocument && !isProcessing {
                            importButton
                        }

                        // Processing Indicator
                        if isProcessing {
                            processingView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("AI Syllabus Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        dismiss()
                    }
                    .font(.custom("FormaDJRText-Semibold", size: 16))
                }
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
            .sheet(isPresented: $showReviewModal) {
                if let data = importData {
                    SyllabusReviewModal(
                        course: course,
                        importData: data,
                        onImport: { assignments in
                            // Add assignments via courseManager
                            for assignment in assignments {
                                courseManager?.addAssignment(assignment, to: course.id)
                            }
                            dismiss()
                        }
                    )
                }
            }
            .task {
                await loadDocuments()
            }
        }
    }

    // MARK: - Helper Computed Properties

    private var hasSelectedDocument: Bool {
        (importSource == .upload && selectedDocumentURL != nil) ||
        (importSource == .existing && selectedExistingDocument != nil)
    }

    private var selectedDocumentDisplayName: String? {
        if importSource == .upload {
            return selectedDocumentName
        } else {
            return selectedExistingDocument?.name
        }
    }

    // MARK: - Load Documents

    private func loadDocuments() async {
        do {
            try await storageService.loadDocuments(forCourse: course.id)
        } catch {
            print("Failed to load documents: \(error)")
        }
    }

    // MARK: - Background Gradient

    @ViewBuilder
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                aiPrimaryColor.opacity(colorScheme == .dark ? 0.15 : 0.12),
                aiSecondaryColor.opacity(colorScheme == .dark ? 0.08 : 0.06),
                Color.clear
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 16) {
            // AI icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                aiPrimaryColor.opacity(0.15),
                                aiSecondaryColor.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [aiPrimaryColor, aiSecondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 6) {
                Text(course.name)
                    .font(.custom("FormaDJRText-Bold", size: 20))
                    .foregroundColor(primaryTextColor)

                if !course.courseCode.isEmpty {
                    Text(course.courseCode)
                        .font(.custom("FormaDJRText-Regular", size: 15))
                        .foregroundColor(secondaryTextColor)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Source Selector

    private var sourceSelector: some View {
        HStack(spacing: 12) {
            // Upload button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    importSource = .upload
                    selectedExistingDocument = nil
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 14))

                    Text("Upload New")
                        .font(.custom("FormaDJRText-Semibold", size: 14))
                }
                .foregroundColor(importSource == .upload ? .white : aiPrimaryColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if importSource == .upload {
                            LinearGradient(
                                colors: [aiPrimaryColor, aiSecondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            LinearGradient(
                                colors: [Color.clear, Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(aiPrimaryColor.opacity(importSource == .upload ? 0 : 0.3), lineWidth: 1)
                )
                .cornerRadius(12)
            }

            // Existing button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    importSource = .existing
                    selectedDocumentURL = nil
                    selectedDocumentName = nil
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 14))

                    Text("Use Existing")
                        .font(.custom("FormaDJRText-Semibold", size: 14))
                }
                .foregroundColor(importSource == .existing ? .white : aiPrimaryColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if importSource == .existing {
                            LinearGradient(
                                colors: [aiPrimaryColor, aiSecondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            LinearGradient(
                                colors: [Color.clear, Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(aiPrimaryColor.opacity(importSource == .existing ? 0 : 0.3), lineWidth: 1)
                )
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Existing Documents View

    @ViewBuilder
    private var existingDocumentsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Select from Documents")
                    .font(.custom("FormaDJRText-Bold", size: 18))
                    .foregroundColor(primaryTextColor)

                Text("Choose a PDF that you've already uploaded to this course")
                    .font(.custom("FormaDJRText-Regular", size: 14))
                    .foregroundColor(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if storageService.documents.filter({ $0.fileType == .pdf }).isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "doc.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(secondaryTextColor)

                    Text("No PDF documents found")
                        .font(.custom("FormaDJRText-Medium", size: 15))
                        .foregroundColor(secondaryTextColor)

                    Text("Upload a new PDF or add documents to this course first")
                        .font(.custom("FormaDJRText-Regular", size: 13))
                        .foregroundColor(secondaryTextColor.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(secondaryTextColor.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                )
                .cornerRadius(20)
            } else {
                // Document list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(storageService.documents.filter({ $0.fileType == .pdf })) { document in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedExistingDocument = document
                                }
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }) {
                                HStack(spacing: 16) {
                                    // PDF icon
                                    ZStack {
                                        Circle()
                                            .fill(Color.red.opacity(0.15))
                                            .frame(width: 44, height: 44)

                                        Image(systemName: "doc.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.red)
                                    }

                                    // Document info
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(document.name)
                                            .font(.custom("FormaDJRText-Medium", size: 15))
                                            .foregroundColor(primaryTextColor)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)

                                        Text(document.formattedFileSize)
                                            .font(.custom("FormaDJRText-Regular", size: 12))
                                            .foregroundColor(secondaryTextColor)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    // Selection indicator
                                    if selectedExistingDocument?.id == document.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [aiPrimaryColor, aiSecondaryColor],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .font(.system(size: 22))
                                    }
                                }
                                .padding(16)
                                .background(cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            selectedExistingDocument?.id == document.id ?
                                            LinearGradient(
                                                colors: [aiPrimaryColor, aiSecondaryColor],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ) :
                                            LinearGradient(
                                                colors: [secondaryTextColor.opacity(0.2), secondaryTextColor.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: selectedExistingDocument?.id == document.id ? 2 : 1
                                        )
                                )
                                .cornerRadius(16)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }

    // MARK: - PDF Input View

    private var pdfInputView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Upload PDF Syllabus")
                    .font(.custom("FormaDJRText-Bold", size: 18))
                    .foregroundColor(primaryTextColor)

                Text("Our AI will automatically extract assignments, exams, and important dates from your syllabus")
                    .font(.custom("FormaDJRText-Regular", size: 14))
                    .foregroundColor(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: {
                isShowingDocumentPicker = true
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }) {
                VStack(spacing: 16) {
                    if let documentName = selectedDocumentName {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [aiPrimaryColor, aiSecondaryColor],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text(documentName)
                                .font(.custom("FormaDJRText-Medium", size: 15))
                                .foregroundColor(primaryTextColor)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Text("Tap to change")
                                .font(.custom("FormaDJRText-Regular", size: 13))
                                .foregroundColor(secondaryTextColor)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 48))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [aiPrimaryColor, aiSecondaryColor],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text("Tap to select PDF")
                                .font(.custom("FormaDJRText-Medium", size: 15))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [aiPrimaryColor.opacity(0.4), aiSecondaryColor.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                        )
                )
                .cornerRadius(20)
            }
            .sheet(isPresented: $isShowingDocumentPicker) {
                DocumentPickerView(
                    contentTypes: [.pdf],
                    onPicked: { urls in
                        guard let url = urls.first else { return }
                        selectedDocumentURL = url
                        selectedDocumentName = url.lastPathComponent
                    }
                )
            }
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 18))

                Text("Ready to Process")
                    .font(.custom("FormaDJRText-Bold", size: 16))
                    .foregroundColor(primaryTextColor)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("File:")
                        .font(.custom("FormaDJRText-Regular", size: 13))
                        .foregroundColor(secondaryTextColor)

                    Spacer()

                    Text(selectedDocumentDisplayName ?? "PDF")
                        .font(.custom("FormaDJRText-Medium", size: 13))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)
                }

                HStack {
                    Text("Source:")
                        .font(.custom("FormaDJRText-Regular", size: 13))
                        .foregroundColor(secondaryTextColor)

                    Spacer()

                    Text(importSource == .upload ? "New Upload" : "Existing Document")
                        .font(.custom("FormaDJRText-Medium", size: 13))
                        .foregroundColor(primaryTextColor)
                }

                HStack {
                    Text("Method:")
                        .font(.custom("FormaDJRText-Regular", size: 13))
                        .foregroundColor(secondaryTextColor)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("AI Processing")
                            .font(.custom("FormaDJRText-Medium", size: 13))
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: [aiPrimaryColor, aiSecondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }
        }
        .padding(20)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [aiPrimaryColor.opacity(0.5), aiSecondaryColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .cornerRadius(20)
    }

    // MARK: - Import Button

    private var importButton: some View {
        Button(action: {
            processImport()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16))

                Text("Process with AI")
                    .font(.custom("FormaDJRText-Semibold", size: 16))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [aiPrimaryColor, aiSecondaryColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: aiPrimaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 20) {
            // Progress bar
            VStack(spacing: 12) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))

                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [aiPrimaryColor, aiSecondaryColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(processingProgress))
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: processingProgress)
                    }
                }
                .frame(height: 8)

                Text("\(Int(processingProgress * 100))%")
                    .font(.custom("FormaDJRText-Medium", size: 14))
                    .foregroundColor(secondaryTextColor)
            }

            // Status indicator
            HStack(spacing: 12) {
                ProgressView()
                    .tint(aiPrimaryColor)

                Text(processingStatusText)
                    .font(.custom("FormaDJRText-Regular", size: 15))
                    .foregroundColor(secondaryTextColor)
            }
        }
        .padding(24)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [aiPrimaryColor.opacity(0.3), aiSecondaryColor.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .cornerRadius(20)
    }

    // MARK: - Helper Properties

    private var processingStatusText: String {
        if processingProgress < 0.2 {
            return "Uploading PDF..."
        } else if processingProgress < 0.6 {
            return "Processing with AI..."
        } else if processingProgress < 0.9 {
            return "Extracting assignments..."
        } else {
            return "Finalizing..."
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if colorScheme == .dark {
            Color.black.opacity(0.3)
                .background(.regularMaterial)
        } else {
            Color.white.opacity(0.7)
                .background(.regularMaterial)
        }
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }

    // MARK: - Processing Logic

    private func processImport() {
        isProcessing = true
        processingProgress = 0.0

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        Task {
            do {
                let documentURL: URL

                // Get document URL based on source
                if importSource == .upload {
                    guard let uploadedURL = selectedDocumentURL else { return }
                    documentURL = uploadedURL
                } else {
                    guard let existingDoc = selectedExistingDocument else { return }
                    // Download the existing document from storage
                    documentURL = try await storageService.downloadDocument(existingDoc)
                }

                let data = try await syllabusImportService.processSyllabusImport(
                    courseId: course.id,
                    method: .pdf,
                    textInput: "",
                    imageItem: nil,
                    documentURL: documentURL,
                    progressHandler: { progress in
                        DispatchQueue.main.async {
                            withAnimation {
                                processingProgress = progress
                            }
                        }
                    }
                )

                await MainActor.run {
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)

                    print("✅ Successfully imported \(data.parsedAssignments.count) assignments")
                    importData = data
                    showReviewModal = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true

                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Preview

struct SyllabusImportSheetPDFOnly_Previews: PreviewProvider {
    static var previews: some View {
        SyllabusImportSheetPDFOnly(
            course: Course(
                scheduleId: UUID(),
                name: "Introduction to Computer Science",
                iconName: "cpu.fill",
                courseCode: "CS 101"
            ),
            courseManager: nil
        )
        .environmentObject(ThemeManager())
    }
}
