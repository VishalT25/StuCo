import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import PDFKit

struct AIImportStep: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var supabaseService: SupabaseService
    @Binding var importData: AIImportData?

    let semesterStartDate: Date
    let semesterEndDate: Date
    let scheduleType: ScheduleType

    @State private var importMethod: AIImportMethod = .text
    @State private var isProcessing = false
    @State private var textInput = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedDocument: URL?
    @State private var showingDocumentPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var uploadProgress: Double = 0.0

    @State private var showingReviewModal = false
    @State private var animatePulse: Bool = false

    private let courseColorPalette: [Color] = [
        .indigo, .orange, .green, .purple, .pink, .teal, .red, .cyan, .brown, .mint, .yellow, .blue
    ]

    var body: some View {
        VStack(spacing: 32) {
            headerSection
            methodSelector

            // AI Warning
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundColor(.orange)
                Text("AI may be inaccurate. Please double-check all imported information.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
            )

            inputSection

            if isProcessing {
                processingIndicator
            }

            if let importData {
                AIImportPreviewCard(
                    importData: importData,
                    onReviewTap: { showingReviewModal = true }
                )
                .environmentObject(themeManager)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: importData.parsedItems.count)
            }

            Spacer(minLength: 20)
        }
        .frame(maxWidth: 340)
        .padding(.horizontal, 0)
        .alert("Import Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showingReviewModal) {
            AIImportReviewModal(
                importData: $importData,
                scheduleType: scheduleType,
                palette: courseColorPalette,
                resolveColorForCourse: resolveColorForCourse,
                baseCourseName: baseCourseName
            )
            .environmentObject(themeManager)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                animatePulse = true
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor.opacity(0.15),
                                themeManager.currentTheme.secondaryColor.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(animatePulse ? 1.03 : 0.97)
                    .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: animatePulse)

                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(themeManager.currentTheme.primaryColor)
                        .opacity(0.7)
                        .position(
                            x: CGFloat([90, 30, 60][index]),
                            y: CGFloat([30, 90, 40][index])
                        )
                        .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.3), radius: 6, x: 0, y: 0)
                        .scaleEffect(animatePulse ? 1.2 : 0.9)
                        .animation(
                            .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.25),
                            value: animatePulse
                        )
                }
            }
            .frame(width: 120, height: 120)

            VStack(spacing: 8) {
                Text("AI Schedule Import")
                    .font(.forma(.title, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text("Upload your schedule document, image, or type it out to get started")
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
    }

    private var methodSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Method")
                .font(.forma(.headline, weight: .semibold))
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                ForEach(AIImportMethod.allCases, id: \.self) { method in
                    methodCard(for: method)
                }
            }
        }
    }

    private func methodCard(for method: AIImportMethod) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                importMethod = method
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: method.icon)
                    .font(.forma(.title2, weight: .semibold))
                    .foregroundColor(importMethod == method ? themeManager.currentTheme.primaryColor : themeManager.currentTheme.primaryColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(
                                importMethod == method
                                ? themeManager.currentTheme.primaryColor.opacity(0.2)
                                : themeManager.currentTheme.primaryColor.opacity(0.08)
                            )
                    )

                VStack(spacing: 1) {
                    Text(method.title)
                        .font(.forma(.caption, weight: .bold))
                        .foregroundColor(importMethod == method ? themeManager.currentTheme.primaryColor : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text(method.subtitle)
                        .font(.forma(.caption2))
                        .foregroundColor(importMethod == method ? themeManager.currentTheme.primaryColor.opacity(0.8) : .secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 90)
            .frame(height: 85)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                importMethod == method
                                ? themeManager.currentTheme.primaryColor.opacity(0.5)
                                : Color(.systemGray5),
                                lineWidth: importMethod == method ? 2 : 1
                            )
                    )
            )
            .shadow(
                color: importMethod == method
                ? themeManager.currentTheme.primaryColor.opacity(0.2)
                : .clear,
                radius: 8, x: 0, y: 4
            )
            .buttonStyle(.plain)
            .scaleEffect(importMethod == method ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: importMethod)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch importMethod {
            case .text:
                textInputSection
            case .image:
                imageInputSection
            case .pdf:
                pdfInputSection
            }

            if canProcessInput {
                processButton
            }
        }
    }

    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule Text")
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(.primary)

            TextEditor(text: $textInput)
                .font(.forma(.body))
                .padding(16)
                .frame(minHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    themeManager.currentTheme.primaryColor.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
                .overlay(
                    Group {
                        if textInput.isEmpty {
                            VStack {
                                Text("Paste or type your class schedule here...")
                                    .font(.forma(.body))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 24)
                                Spacer()
                            }
                        }
                    },
                    alignment: .topLeading
                )
        }
    }

    private var imageInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule Image")
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(.primary)

            PhotosPicker(
                selection: $selectedImage,
                matching: .images,
                photoLibrary: .shared()
            ) {
                VStack(spacing: 12) {
                    Image(systemName: selectedImage != nil ? "checkmark.circle.fill" : "photo.on.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(selectedImage != nil ? .green : themeManager.currentTheme.primaryColor)

                    VStack(spacing: 4) {
                        Text(selectedImage != nil ? "Image Selected" : "Select Image")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Choose a photo of your schedule")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedImage != nil
                                    ? Color.green.opacity(0.4)
                                    : themeManager.currentTheme.primaryColor.opacity(0.3),
                                    lineWidth: selectedImage != nil ? 2 : 1
                                )
                        )
                )
            }
        }
    }

    private var pdfInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule Document")
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(.primary)

            Button {
                showingDocumentPicker = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: selectedDocument != nil ? "checkmark.circle.fill" : "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(selectedDocument != nil ? .green : themeManager.currentTheme.primaryColor)

                    VStack(spacing: 4) {
                        Text(selectedDocument != nil ? "Document Selected" : "Select Document")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Choose a PDF of your schedule")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)

                        if let doc = selectedDocument {
                            Text(doc.lastPathComponent)
                                .font(.forma(.caption))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedDocument != nil
                                    ? Color.green.opacity(0.4)
                                    : themeManager.currentTheme.primaryColor.opacity(0.3),
                                    lineWidth: selectedDocument != nil ? 2 : 1
                                )
                        )
                )
            }
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let files):
                    selectedDocument = files.first
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private var processButton: some View {
        Button {
            processInput()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.forma(.body, weight: .semibold))

                Text("Process with AI")
                    .font(.forma(.headline, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.primaryColor,
                        themeManager.currentTheme.secondaryColor
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .shadow(
                color: themeManager.currentTheme.primaryColor.opacity(0.4),
                radius: 12, x: 0, y: 6
            )
        }
        .disabled(isProcessing)
    }

    private var processingIndicator: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
                .tint(themeManager.currentTheme.primaryColor)

            VStack(spacing: 8) {
                Text("Processing with AI")
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)

                Text("This may take a few moments...")
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
            }

            if uploadProgress > 0 && uploadProgress < 1 {
                ProgressView(value: uploadProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: themeManager.currentTheme.primaryColor))
                    .frame(width: 200)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var canProcessInput: Bool {
        switch importMethod {
        case .text:
            return !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image:
            return selectedImage != nil
        case .pdf:
            return selectedDocument != nil
        }
    }

    private func processInput() {
        guard !isProcessing else { return }
        isProcessing = true
        uploadProgress = 0.0

        Task {
            do {
                if importMethod == .pdf, let url = selectedDocument {
                    if let text = extractPDFText(from: url),
                       !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let result = try await AIImportService.shared.processScheduleImport(
                            method: .text,
                            textInput: text,
                            imageItem: nil,
                            documentURL: nil,
                            semesterStartDate: semesterStartDate,
                            semesterEndDate: semesterEndDate,
                            schedulePattern: (scheduleType == .rotating ? "rotating" : "traditional"),
                            progressHandler: { progress in
                                Task { @MainActor in
                                    uploadProgress = progress
                                }
                            }
                        )
                        await MainActor.run {
                            importData = autoAssignCourseColorsIfMissing(result)
                            isProcessing = false
                        }
                    } else {
                        await MainActor.run {
                            errorMessage = "Could not extract text from the selected PDF. Try a different PDF, export it as a text-based PDF, or import as an image."
                            showingError = true
                            isProcessing = false
                        }
                    }
                    return
                }

                let result = try await AIImportService.shared.processScheduleImport(
                    method: importMethod,
                    textInput: textInput,
                    imageItem: selectedImage,
                    documentURL: selectedDocument,
                    semesterStartDate: semesterStartDate,
                    semesterEndDate: semesterEndDate,
                    schedulePattern: (scheduleType == .rotating ? "rotating" : "traditional"),
                    progressHandler: { progress in
                        Task { @MainActor in
                            uploadProgress = progress
                        }
                    }
                )

                await MainActor.run {
                    importData = autoAssignCourseColorsIfMissing(result)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isProcessing = false
                }
            }
        }
    }

    private func autoAssignCourseColorsIfMissing(_ data: AIImportData) -> AIImportData {
        var data = data
        let defaultBlueHex = Color.blue.toHex() ?? "007AFF"
        var groups: [String: [Int]] = [:]
        for (i, item) in data.parsedItems.enumerated() {
            let key = baseCourseName(from: item.title)
            groups[key, default: []].append(i)
        }
        for (name, idxs) in groups {
            let hexes = idxs.compactMap { data.parsedItems[$0].color.toHex() }
            let allDefault = !hexes.isEmpty && hexes.allSatisfy { $0.uppercased() == defaultBlueHex.uppercased() }
            if allDefault {
                let color = resolveDeterministicColor(name: name)
                for i in idxs {
                    data.parsedItems[i].color = color
                }
            }
        }
        return data
    }

    private func resolveDeterministicColor(name: String) -> Color {
        let idx = abs(name.hashValue) % max(1, courseColorPalette.count)
        return courseColorPalette[idx]
    }

    private func baseCourseName(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: " - ") {
            return String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private func resolveColorForCourse(_ name: String) -> Color {
        if let items = importData?.parsedItems {
            if let first = items.first(where: { baseCourseName(from: $0.title) == name }) {
                return first.color
            }
        }
        let idx = abs(name.hashValue) % max(1, courseColorPalette.count)
        return courseColorPalette[idx]
    }
}

private func extractPDFText(from url: URL) -> String? {
    #if canImport(PDFKit)
    var didAccess = false
    if url.startAccessingSecurityScopedResource() {
        didAccess = true
    }
    defer {
        if didAccess { url.stopAccessingSecurityScopedResource() }
    }

    guard let document = PDFDocument(url: url) else { return nil }
    var text = ""
    for i in 0..<document.pageCount {
        if let page = document.page(at: i) {
            text += page.string ?? ""
        }
    }
    return text.isEmpty ? nil : text
    #else
    return nil
    #endif
}
