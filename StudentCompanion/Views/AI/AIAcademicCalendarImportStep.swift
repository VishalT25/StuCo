import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import PDFKit

struct AIAcademicCalendarImportStep: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var supabaseService: SupabaseService
    @StateObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Binding var importData: AIAcademicCalendarImportData?

    let calendarName: String
    let academicYear: String
    let startDate: Date
    let endDate: Date

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

    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroSection
                methodSelectorCard
                inputSectionCard

                if isProcessing {
                    processingIndicator
                }

                if let importData {
                    previewCard(importData)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .alert("Import Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showingReviewModal) {
            AIAcademicCalendarImportReviewModal(
                importData: $importData,
                calendarName: calendarName,
                academicYear: academicYear,
                startDate: startDate,
                endDate: endDate
            )
            .environmentObject(themeManager)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                currentTheme.primaryColor,
                                currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("AI Academic Calendar Import")
                    .font(.forma(.title, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                currentTheme.primaryColor,
                                currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)

                Text("Upload your calendar document or paste text to auto-extract breaks and important dates")
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    currentTheme.primaryColor.opacity(0.3),
                                    currentTheme.primaryColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: currentTheme.primaryColor.opacity(
                        colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15
                    ),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
    }

    // MARK: - Method Selector Card

    private var methodSelectorCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Import Method")
                .font(.forma(.headline, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                ForEach(AIImportMethod.allCases, id: \.self) { method in
                    methodButton(for: method)
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func methodButton(for method: AIImportMethod) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                importMethod = method
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: method.icon)
                    .font(.forma(.title2, weight: .semibold))
                    .foregroundColor(importMethod == method ? currentTheme.primaryColor : .secondary)
                    .frame(width: 32, height: 32)

                VStack(spacing: 2) {
                    Text(method.title)
                        .font(.forma(.caption, weight: .bold))
                        .foregroundColor(importMethod == method ? currentTheme.primaryColor : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text(method.subtitle)
                        .font(.forma(.caption2))
                        .foregroundColor(importMethod == method ? currentTheme.primaryColor.opacity(0.8) : .secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    importMethod == method
                    ? currentTheme.primaryColor.opacity(0.1)
                    : Color(.systemGray6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            importMethod == method
                            ? currentTheme.primaryColor.opacity(0.5)
                            : Color.clear,
                            lineWidth: importMethod == method ? 2 : 0
                        )
                )
        )
        .buttonStyle(.plain)
    }

    // MARK: - Input Section Card

    private var inputSectionCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch importMethod {
            case .text:
                textInputSection
            case .image:
                imageInputSection
            case .pdf:
                pdfInputSection
            }

            if canProcessInput && !isProcessing {
                processButton
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Input Sections

    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.forma(.subheadline))
                    .foregroundColor(currentTheme.primaryColor)

                Text("Calendar Information")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $textInput)
                    .font(.forma(.body))
                    .padding(16)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)

                if textInput.isEmpty {
                    Text("Paste your academic calendar info here...\n\nInclude:\n• Semester dates\n• Winter/Spring/Summer breaks\n• Reading weeks\n• Exam periods")
                        .font(.forma(.body))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .allowsHitTesting(false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    private var imageInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.forma(.subheadline))
                    .foregroundColor(currentTheme.primaryColor)

                Text("Calendar Image")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
            }

            PhotosPicker(
                selection: $selectedImage,
                matching: .images,
                photoLibrary: .shared()
            ) {
                VStack(spacing: 16) {
                    Image(systemName: selectedImage != nil ? "checkmark.circle.fill" : "photo.on.rectangle")
                        .font(.system(size: 44))
                        .foregroundColor(selectedImage != nil ? .green : currentTheme.primaryColor)

                    VStack(spacing: 6) {
                        Text(selectedImage != nil ? "Image Selected" : "Select Image")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Choose a photo of your academic calendar")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedImage != nil
                                    ? Color.green.opacity(0.4)
                                    : currentTheme.primaryColor.opacity(0.3),
                                    lineWidth: selectedImage != nil ? 2 : 1
                                )
                        )
                )
            }
        }
    }

    private var pdfInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.forma(.subheadline))
                    .foregroundColor(currentTheme.primaryColor)

                Text("Calendar Document")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
            }

            Button {
                showingDocumentPicker = true
            } label: {
                VStack(spacing: 16) {
                    Image(systemName: selectedDocument != nil ? "checkmark.circle.fill" : "doc.text")
                        .font(.system(size: 44))
                        .foregroundColor(selectedDocument != nil ? .green : currentTheme.primaryColor)

                    VStack(spacing: 6) {
                        Text(selectedDocument != nil ? "Document Selected" : "Select PDF")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(selectedDocument?.lastPathComponent ?? "Choose a PDF of your academic calendar")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedDocument != nil
                                    ? Color.green.opacity(0.4)
                                    : currentTheme.primaryColor.opacity(0.3),
                                    lineWidth: selectedDocument != nil ? 2 : 1
                                )
                        )
                )
            }
            .buttonStyle(.plain)
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

    // MARK: - Process Button

    private var processButton: some View {
        Button {
            processInput()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.forma(.body, weight: .semibold))

                Text("Process with AI")
                    .font(.forma(.headline, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                currentTheme.primaryColor,
                                currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(
                color: currentTheme.primaryColor.opacity(0.4),
                radius: 12, x: 0, y: 6
            )
        }
        .buttonStyle(PremiumMainButtonStyle())
    }

    // MARK: - Processing Indicator

    private var processingIndicator: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
                .tint(currentTheme.primaryColor)

            VStack(spacing: 8) {
                Text("Processing with AI")
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Extracting breaks and important dates...")
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
            }

            if uploadProgress > 0 && uploadProgress < 1 {
                ProgressView(value: uploadProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: currentTheme.primaryColor))
                    .frame(maxWidth: 200)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Preview Card

    private func previewCard(_ data: AIAcademicCalendarImportData) -> some View {
        Button {
            showingReviewModal = true
        } label: {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.forma(.title3, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            currentTheme.primaryColor,
                                            currentTheme.secondaryColor
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Import Complete")
                            .font(.forma(.headline, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Tap to review and customize")
                            .font(.forma(.subheadline))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.forma(.body, weight: .semibold))
                        .foregroundColor(currentTheme.primaryColor)
                }

                Divider()

                HStack(spacing: 16) {
                    statPill(
                        icon: "calendar",
                        value: data.calendarName,
                        label: "Calendar",
                        color: currentTheme.primaryColor
                    )

                    statPill(
                        icon: "minus.circle.fill",
                        value: "\(data.breaks.count)",
                        label: "Breaks",
                        color: currentTheme.secondaryColor
                    )

                    if !data.missingFields.isEmpty {
                        statPill(
                            icon: "exclamationmark.triangle.fill",
                            value: "\(data.missingFields.count)",
                            label: "Issues",
                            color: .orange
                        )
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        currentTheme.primaryColor.opacity(0.3),
                                        currentTheme.secondaryColor.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
            .shadow(
                color: currentTheme.primaryColor.opacity(0.15),
                radius: 20, x: 0, y: 10
            )
        }
        .buttonStyle(PremiumCardButtonStyle())
        .transition(.scale.combined(with: .opacity))
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(color)

                Text(value)
                    .font(.forma(.subheadline, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(label)
                .font(.forma(.caption2, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Helper Properties

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

    // MARK: - Processing Logic

    private func processInput() {
        guard !isProcessing else { return }

        // Check Pro access (includes premium, pro, and founder tiers)
        guard purchaseManager.hasProAccess else {
            errorMessage = "AI import requires StuCo Pro"
            showingError = true
            return
        }

        isProcessing = true
        uploadProgress = 0.0

        Task {
            do {
                let result = try await AIAcademicCalendarImportService.shared.processAcademicCalendarImport(
                    method: importMethod,
                    textInput: textInput,
                    imageItem: selectedImage,
                    documentURL: selectedDocument,
                    calendarName: calendarName,
                    academicYear: academicYear,
                    startDate: startDate,
                    endDate: endDate,
                    progressHandler: { progress in
                        Task { @MainActor in
                            uploadProgress = progress
                        }
                    }
                )

                await MainActor.run {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        importData = result
                        isProcessing = false
                    }
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
}

// MARK: - Button Styles

//struct PremiumMainButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
//            .brightness(configuration.isPressed ? -0.05 : 0)
//            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: configuration.isPressed)
//    }
//}

struct PremiumCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
