import SwiftUI
import PDFKit
import QuickLook

// MARK: - Document Viewer Sheet

struct DocumentViewerSheet: View {
    let documents: [CourseDocument]
    let initialIndex: Int
    @ObservedObject var storageService: DocumentStorageService
    @Environment(\.dismiss) var dismiss

    @State private var currentIndex: Int
    @State private var documentURLs: [UUID: URL] = [:]
    @State private var loadingStates: [UUID: Bool] = [:]
    @State private var errorMessages: [UUID: String] = [:]
    @State private var showShareSheet = false

    init(documents: [CourseDocument], initialIndex: Int = 0, storageService: DocumentStorageService) {
        self.documents = documents
        self.initialIndex = initialIndex
        self.storageService = storageService
        _currentIndex = State(initialValue: initialIndex)
    }

    private var currentDocument: CourseDocument {
        documents[currentIndex]
    }

    var body: some View {
        NavigationView {
            ZStack {
                TabView(selection: $currentIndex) {
                    ForEach(Array(documents.enumerated()), id: \.element.id) { index, document in
                        documentPageView(for: document, at: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Custom page indicator at bottom
                VStack {
                    Spacer()
                    if documents.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(0..<documents.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                                    .frame(width: 8, height: 8)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            currentIndex = index
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        )
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle(currentDocument.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if documentURLs[currentDocument.id] != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = documentURLs[currentDocument.id] {
                    ShareSheet(items: [url])
                }
            }
        }
        .task {
            await loadDocument(currentDocument)
        }
        .onChange(of: currentIndex) { newIndex in
            Task {
                let document = documents[newIndex]
                if documentURLs[document.id] == nil {
                    await loadDocument(document)
                }
            }
        }
    }

    // MARK: - Document Page View

    @ViewBuilder
    private func documentPageView(for document: CourseDocument, at index: Int) -> some View {
        ZStack {
            if loadingStates[document.id] == true {
                loadingView
            } else if let error = errorMessages[document.id] {
                errorView(message: error, document: document)
            } else if let url = documentURLs[document.id] {
                documentContentView(url: url, document: document)
            }
        }
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading document...")
                .font(.custom("FormaDJRText-Medium", size: 16))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(message: String, document: CourseDocument) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            VStack(spacing: 12) {
                Text("Failed to Load Document")
                    .font(.custom("FormaDJRText-Bold", size: 20))

                Text(message)
                    .font(.custom("FormaDJRText-Regular", size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: {
                Task {
                    await loadDocument(document)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.custom("FormaDJRText-Semibold", size: 16))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding()
    }

    // MARK: - Document Content View

    @ViewBuilder
    private func documentContentView(url: URL, document: CourseDocument) -> some View {
        switch document.fileType {
        case .pdf:
            PDFViewerWrapper(url: url)
                .ignoresSafeArea(edges: .bottom)

        case .image:
            imageViewer(url: url, document: document)

        case .word, .excel, .powerpoint, .text:
            QuickLookPreview(url: url)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Image Viewer

    @ViewBuilder
    private func imageViewer(url: URL, document: CourseDocument) -> some View {
        if let uiImage = UIImage(contentsOfFile: url.path) {
            ZoomableImageView(image: uiImage)
                .background(Color.black)
                .ignoresSafeArea(edges: .bottom)
        } else {
            errorView(message: "Failed to load image", document: document)
        }
    }

    // MARK: - Load Document

    private func loadDocument(_ document: CourseDocument) async {
        loadingStates[document.id] = true
        errorMessages[document.id] = nil
        documentURLs[document.id] = nil

        do {
            let url = try await storageService.downloadDocument(document)
            documentURLs[document.id] = url
            loadingStates[document.id] = false
        } catch {
            errorMessages[document.id] = error.localizedDescription
            loadingStates[document.id] = false
        }
    }
}

// MARK: - PDF Viewer Wrapper

struct PDFViewerWrapper: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}

// MARK: - QuickLook Preview

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return url as QLPreviewItem
        }
    }
}

// MARK: - Zoomable Image View

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ZoomableImageContainer {
        let container = ZoomableImageContainer(image: image)
        return container
    }

    func updateUIView(_ uiView: ZoomableImageContainer, context: Context) {
        // Update image if changed
        if uiView.imageView.image != image {
            uiView.setImage(image)
        }
    }
}

// MARK: - Zoomable Image Container

class ZoomableImageContainer: UIView {
    let scrollView = UIScrollView()
    let imageView = UIImageView()

    private var image: UIImage?

    init(image: UIImage) {
        self.image = image
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = .black

        // Setup scroll view
        scrollView.backgroundColor = .black
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true

        // Setup image view
        imageView.contentMode = .scaleAspectFit
        imageView.image = image

        // Add to hierarchy
        scrollView.addSubview(imageView)
        addSubview(scrollView)

        // Setup constraints
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let image = image, bounds.size.width > 0, bounds.size.height > 0 else { return }

        // Calculate the size to fit the image in the view
        let imageSize = image.size
        let viewSize = bounds.size

        let widthRatio = viewSize.width / imageSize.width
        let heightRatio = viewSize.height / imageSize.height
        let ratio = min(widthRatio, heightRatio)

        let scaledWidth = imageSize.width * ratio
        let scaledHeight = imageSize.height * ratio

        // Set imageView frame to fit the scaled size
        imageView.frame = CGRect(
            x: 0,
            y: 0,
            width: scaledWidth,
            height: scaledHeight
        )

        // Set content size
        scrollView.contentSize = CGSize(width: scaledWidth, height: scaledHeight)

        // Reset zoom scale to 1.0 (since we've already scaled the image to fit)
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.zoomScale = 1.0

        // Center the image
        centerImage()
    }

    func setImage(_ image: UIImage) {
        self.image = image
        imageView.image = image
        setNeedsLayout()
    }

    private func centerImage() {
        let scrollViewSize = scrollView.bounds.size
        let imageViewSize = imageView.frame.size

        let horizontalInset = max(0, (scrollViewSize.width - imageViewSize.width) / 2)
        let verticalInset = max(0, (scrollViewSize.height - imageViewSize.height) / 2)

        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }
}

// MARK: - UIScrollViewDelegate

extension ZoomableImageContainer: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview

struct DocumentViewerSheet_Previews: PreviewProvider {
    static var previews: some View {
        DocumentViewerSheet(
            documents: [
                CourseDocument(
                    courseId: UUID(),
                    userId: "user123",
                    name: "Sample Document.pdf",
                    fileType: .pdf,
                    fileSize: 1_500_000,
                    storagePath: "path/to/file"
                ),
                CourseDocument(
                    courseId: UUID(),
                    userId: "user123",
                    name: "Sample Image.png",
                    fileType: .image,
                    fileSize: 500_000,
                    storagePath: "path/to/image"
                )
            ],
            initialIndex: 0,
            storageService: DocumentStorageService()
        )
    }
}
