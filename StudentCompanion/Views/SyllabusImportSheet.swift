import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct SyllabusImportSheet: View {
    let course: Course
    let onImport: (SyllabusImportData) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedMethod: AIImportMethod = .pdf
    @State private var textInput: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isShowingDocumentPicker = false
    @State private var selectedDocumentURL: URL?
    @State private var selectedDocumentName: String?

    @State private var isProcessing = false
    @State private var processingProgress: Double = 0.0
    @State private var errorMessage: String?
    @State private var showError = false

    private let syllabusImportService = SyllabusImportService.shared

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerView

                        // Method Selector
                        methodSelectorView

                        // Input Section
                        inputSectionView

                        // Preview Card (if content available)
                        if hasContent {
                            previewCard
                        }

                        // Process Button
                        if hasContent && !isProcessing {
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
            .navigationTitle("Import Syllabus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        dismiss()
                    }
                    .font(.custom("FormaDJRDisplay-Regular", size: 16))
                }
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 12) {
            // Course Color Circle with Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                course.color,
                                course.color.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            VStack(spacing: 4) {
                Text(course.name)
                    .font(.custom("FormaDJRDisplay-Medium", size: 20))
                    .foregroundColor(.primary)

                if !course.courseCode.isEmpty {
                    Text(course.courseCode)
                        .font(.custom("FormaDJRDisplay-Regular", size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Method Selector

    private var methodSelectorView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Method")
                .font(.custom("FormaDJRDisplay-Medium", size: 16))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(AIImportMethod.allCases, id: \.self) { method in
                    methodButton(for: method)
                }
            }
        }
    }

    private func methodButton(for method: AIImportMethod) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMethod = method
            }
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            // Clear inputs when switching methods
            if method == .text {
                selectedPhotoItem = nil
                selectedImageData = nil
                selectedDocumentURL = nil
                selectedDocumentName = nil
            } else if method == .image {
                textInput = ""
                selectedDocumentURL = nil
                selectedDocumentName = nil
            } else if method == .pdf {
                textInput = ""
                selectedPhotoItem = nil
                selectedImageData = nil
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: method.icon)
                    .font(.system(size: 24))
                    .foregroundColor(selectedMethod == method ? .white : course.color)

                Text(method.title)
                    .font(.custom("FormaDJRDisplay-Regular", size: 12))
                    .foregroundColor(selectedMethod == method ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedMethod == method ? course.color : Color(uiColor: .tertiarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(course.color.opacity(selectedMethod == method ? 0 : 0.3), lineWidth: 1.5)
            )
        }
    }

    // MARK: - Input Section

    @ViewBuilder
    private var inputSectionView: some View {
        switch selectedMethod {
        case .text:
            textInputView
        case .image:
            imageInputView
        case .pdf:
            pdfInputView
        }
    }

    private var textInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste Syllabus Text")
                .font(.custom("FormaDJRDisplay-Medium", size: 16))
                .foregroundColor(.secondary)

            TextEditor(text: $textInput)
                .font(.system(size: 14))
                .padding(12)
                .frame(height: 200)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(course.color.opacity(0.3), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if textInput.isEmpty {
                        Text("Paste your syllabus text here...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var imageInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Image")
                .font(.custom("FormaDJRDisplay-Medium", size: 16))
                .foregroundColor(.secondary)

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images
            ) {
                VStack(spacing: 16) {
                    if let imageData = selectedImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(course.color)

                            Text("Tap to select syllabus image")
                                .font(.custom("FormaDJRDisplay-Regular", size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 200)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(course.color.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                )
            }
            .onChange(of: selectedPhotoItem) { newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }
        }
    }

    private var pdfInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select PDF")
                .font(.custom("FormaDJRDisplay-Medium", size: 16))
                .foregroundColor(.secondary)

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
                                .foregroundColor(course.color)

                            Text(documentName)
                                .font(.custom("FormaDJRDisplay-Medium", size: 14))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            Text("Tap to change")
                                .font(.custom("FormaDJRDisplay-Regular", size: 12))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(course.color)

                            Text("Tap to select PDF syllabus")
                                .font(.custom("FormaDJRDisplay-Regular", size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(course.color.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                )
            }
            .sheet(isPresented: $isShowingDocumentPicker) {
                DocumentPicker(
                    contentTypes: [.pdf],
                    onPicked: { url in
                        selectedDocumentURL = url
                        selectedDocumentName = url.lastPathComponent
                    }
                )
            }
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(course.color)
                Text("Ready to Process")
                    .font(.custom("FormaDJRDisplay-Medium", size: 16))
                    .foregroundColor(.primary)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Method")
                        .font(.custom("FormaDJRDisplay-Regular", size: 12))
                        .foregroundColor(.secondary)
                    Text(selectedMethod.title)
                        .font(.custom("FormaDJRDisplay-Medium", size: 14))
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Content")
                        .font(.custom("FormaDJRDisplay-Regular", size: 12))
                        .foregroundColor(.secondary)
                    Text(contentDescription)
                        .font(.custom("FormaDJRDisplay-Medium", size: 14))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [course.color.opacity(0.5), course.color.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    // MARK: - Import Button

    private var importButton: some View {
        Button(action: {
            processImport()
        }) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                Text("Process with AI")
                    .font(.custom("FormaDJRDisplay-Medium", size: 16))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [course.color, course.color.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: course.color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView(value: processingProgress, total: 1.0)
                .progressViewStyle(.linear)
                .tint(course.color)

            HStack {
                ProgressView()
                    .tint(course.color)

                Text(processingStatusText)
                    .font(.custom("FormaDJRDisplay-Regular", size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
    }

    // MARK: - Helper Properties

    private var hasContent: Bool {
        switch selectedMethod {
        case .text:
            return !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image:
            return selectedImageData != nil
        case .pdf:
            return selectedDocumentURL != nil
        }
    }

    private var contentDescription: String {
        switch selectedMethod {
        case .text:
            let charCount = textInput.trimmingCharacters(in: .whitespacesAndNewlines).count
            return "\(charCount) chars"
        case .image:
            return "Image selected"
        case .pdf:
            return selectedDocumentName ?? "PDF selected"
        }
    }

    private var processingStatusText: String {
        if processingProgress < 0.2 {
            return "Uploading..."
        } else if processingProgress < 0.6 {
            return "Processing with AI..."
        } else if processingProgress < 0.9 {
            return "Extracting data..."
        } else {
            return "Finalizing..."
        }
    }

    // MARK: - Processing Logic

    private func processImport() {
        isProcessing = true
        processingProgress = 0.0

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        Task {
            do {
                let importData = try await syllabusImportService.processSyllabusImport(
                    courseId: course.id,
                    method: selectedMethod,
                    textInput: textInput,
                    imageItem: selectedPhotoItem,
                    documentURL: selectedDocumentURL,
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

                    print("📄 SyllabusImportSheet: Successfully imported \(importData.parsedAssignments.count) assignments")
                    print("📄 SyllabusImportSheet: Calling onImport callback...")
                    onImport(importData)
                    print("📄 SyllabusImportSheet: Dismissing sheet...")
                    dismiss()
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

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void

        init(onPicked: @escaping (URL) -> Void) {
            self.onPicked = onPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPicked(url)
        }
    }
}
