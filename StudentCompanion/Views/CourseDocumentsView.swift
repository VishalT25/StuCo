import SwiftUI

// MARK: - Course Documents View

struct CourseDocumentsView: View {
    let course: Course
    let courseManager: UnifiedCourseManager?

    @StateObject private var storageService = DocumentStorageService()
    @StateObject private var purchaseManager = PurchaseManager.shared
    @EnvironmentObject var themeManager: ThemeManager

    @State private var showDocumentPicker = false
    @State private var showDocumentViewer = false
    @State private var selectedDocumentIndex: Int?
    @State private var showSyllabusImport = false
    @State private var uploadProgress: Double = 0
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var documentToRename: CourseDocument?
    @State private var renameText: String = ""
    @State private var showRenameAlert = false

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    // Computed property to convert Course colorHex to Color
    private var courseColor: Color {
        Color(hex: course.colorHex) ?? .blue
    }

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView

                    // Storage quota bar
                    storageQuotaBar

                    // Upload button
                    uploadButton

                    // Documents list or empty state
                    if storageService.documents.isEmpty {
                        emptyStateView
                    } else {
                        documentsListView
                    }

                    // Syllabus import section (Premium only)
                    if isPremiumUser {
                        Divider()
                            .padding(.vertical, 8)

                        syllabusImportSection
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .font(.custom("FormaDJRText-Semibold", size: 16))
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { urls in
                guard let url = urls.first else { return }
                Task {
                    await uploadDocument(url: url)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedDocumentIndex != nil },
            set: { if !$0 { selectedDocumentIndex = nil } }
        )) {
            if let index = selectedDocumentIndex, !storageService.documents.isEmpty {
                DocumentViewerSheet(
                    documents: storageService.documents,
                    initialIndex: index,
                    storageService: storageService
                )
            }
        }
        .sheet(isPresented: $showSyllabusImport) {
            SyllabusImportSheetPDFOnly(course: course, courseManager: courseManager)
                .environmentObject(themeManager)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .alert("Rename Document", isPresented: $showRenameAlert) {
            TextField("Document name", text: $renameText)
            Button("Cancel", role: .cancel) {
                documentToRename = nil
                renameText = ""
            }
            Button("Rename") {
                if let document = documentToRename {
                    Task {
                        await renameDocument(document, newName: renameText)
                    }
                }
            }
        } message: {
            Text("Enter a new name for the document")
        }
        .overlay {
            if isUploading {
                uploadOverlay
            }
        }
        .task {
            await loadDocuments()
        }
    }

    // MARK: - Background Gradient

    @ViewBuilder
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                courseColor.opacity(colorScheme == .dark ? 0.15 : 0.12),
                courseColor.opacity(colorScheme == .dark ? 0.08 : 0.06),
                Color.clear
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 16) {
            // Course icon
            ZStack {
                Circle()
                    .fill(courseColor.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: course.iconName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(courseColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.custom("FormaDJRText-Bold", size: 22))
                    .foregroundColor(primaryTextColor)

                Text("Documents")
                    .font(.custom("FormaDJRText-Regular", size: 15))
                    .foregroundColor(secondaryTextColor)
            }

            Spacer()
        }
    }

    // MARK: - Storage Quota Bar

    @ViewBuilder
    private var storageQuotaBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Storage")
                    .font(.custom("FormaDJRText-Semibold", size: 16))
                    .foregroundColor(primaryTextColor)

                Spacer()

                Text("\(ByteCountFormatter.string(fromByteCount: storageService.currentUsageBytes, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: 5 * 1024 * 1024, countStyle: .file))")
                    .font(.custom("FormaDJRText-Medium", size: 14))
                    .foregroundColor(secondaryTextColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))

                    // Progress fill
                    RoundedRectangle(cornerRadius: 8)
                        .fill(storageService.quotaColor)
                        .frame(width: geometry.size.width * CGFloat(min(storageService.usagePercentage / 100, 1.0)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: storageService.usagePercentage)
                }
            }
            .frame(height: 8)

            // Percentage text
            if storageService.usagePercentage > 80 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("\(Int(storageService.usagePercentage))% used - Delete documents to free up space")
                        .font(.custom("FormaDJRText-Regular", size: 13))
                }
                .foregroundColor(.orange)
            }
        }
        .padding(20)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(courseColor.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(20)
    }

    // MARK: - Upload Button

    @ViewBuilder
    private var uploadButton: some View {
        Button(action: {
            showDocumentPicker = true
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))

                Text("Upload Document")
                    .font(.custom("FormaDJRText-Semibold", size: 16))

                Spacer()

                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 16))
            }
            .foregroundColor(.white)
            .padding(18)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [courseColor, courseColor.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: courseColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(storageService.usagePercentage >= 100)
        .opacity(storageService.usagePercentage >= 100 ? 0.5 : 1.0)
    }

    // MARK: - Empty State View

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.fill")
                .font(.system(size: 60))
                .foregroundColor(courseColor.opacity(0.5))
                .padding(.top, 40)

            VStack(spacing: 8) {
                Text("No Documents Yet")
                    .font(.custom("FormaDJRText-Bold", size: 20))
                    .foregroundColor(primaryTextColor)

                Text("Upload PDFs, images, and other files\nfor this course")
                    .font(.custom("FormaDJRText-Regular", size: 15))
                    .foregroundColor(secondaryTextColor)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Documents List View

    @ViewBuilder
    private var documentsListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(storageService.documents.enumerated()), id: \.element.id) { index, document in
                DocumentCard(
                    document: document,
                    courseColor: courseColor,
                    onTap: {
                        selectedDocumentIndex = index
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    },
                    onRename: {
                        documentToRename = document
                        renameText = document.name
                        showRenameAlert = true
                    },
                    onDelete: {
                        Task {
                            await deleteDocument(document)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Syllabus Import Section

    @ViewBuilder
    private var syllabusImportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundColor(courseColor)

                Text("AI Syllabus Import")
                    .font(.custom("FormaDJRText-Bold", size: 18))
                    .foregroundColor(primaryTextColor)

                Spacer()

                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
            }

            Text("Import your course syllabus and let AI automatically extract assignments, exams, and important dates")
                .font(.custom("FormaDJRText-Regular", size: 14))
                .foregroundColor(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                showSyllabusImport = true
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16))

                    Text("Import Syllabus (PDF)")
                        .font(.custom("FormaDJRText-Semibold", size: 15))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                }
                .foregroundColor(.white)
                .padding(16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.purple,
                            Color.blue
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
        )
        .cornerRadius(20)
    }

    // MARK: - Upload Overlay

    @ViewBuilder
    private var uploadOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ProgressView(value: uploadProgress, total: 1.0)
                    .progressViewStyle(CircularProgressViewStyle(tint: courseColor))
                    .scaleEffect(2)

                VStack(spacing: 8) {
                    Text("Uploading Document")
                        .font(.custom("FormaDJRText-Bold", size: 18))
                        .foregroundColor(.white)

                    Text("\(Int(uploadProgress * 100))%")
                        .font(.custom("FormaDJRText-Medium", size: 15))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }

    // MARK: - Card Background

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

    // MARK: - Text Colors

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }

    // MARK: - Premium Check

    private var isPremiumUser: Bool {
        // Use RevenueCat as source of truth for subscription status
        return purchaseManager.hasProAccess
    }

    // MARK: - Load Documents

    private func loadDocuments() async {
        do {
            try await storageService.loadDocuments(forCourse: course.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Upload Document

    private func uploadDocument(url: URL) async {
        isUploading = true
        uploadProgress = 0

        do {
            _ = try await storageService.uploadDocument(url: url, courseId: course.id) { progress in
                uploadProgress = progress
            }

            // Success haptic
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)

        } catch {
            errorMessage = error.localizedDescription
            showError = true

            // Error haptic
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        }

        isUploading = false
        uploadProgress = 0
    }

    // MARK: - Rename Document

    private func renameDocument(_ document: CourseDocument, newName: String) async {
        do {
            try await storageService.renameDocument(document, newName: newName)

            // Success haptic
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)

            // Clear rename state
            documentToRename = nil
            renameText = ""

        } catch {
            errorMessage = error.localizedDescription
            showError = true

            // Error haptic
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        }
    }

    // MARK: - Delete Document

    private func deleteDocument(_ document: CourseDocument) async {
        do {
            try await storageService.deleteDocument(document)

            // Success haptic
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)

        } catch {
            errorMessage = error.localizedDescription
            showError = true

            // Error haptic
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        }
    }
}

// MARK: - Preview

struct CourseDocumentsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CourseDocumentsView(
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
}
