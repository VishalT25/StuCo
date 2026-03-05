import SwiftUI
import PDFKit

struct PDFViewerSheet: View {
    let pdfURL: URL
    let courseName: String?

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var loadError: String?

    init(pdfURL: URL, courseName: String? = nil) {
        self.pdfURL = pdfURL
        self.courseName = courseName
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                if let error = loadError {
                    errorView(message: error)
                } else if isLoading {
                    loadingView
                } else {
                    PDFKitView(url: pdfURL, isLoading: $isLoading, loadError: $loadError)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle(courseName ?? "Syllabus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        dismiss()
                    }
                    .font(.custom("FormaDJRDisplay-Medium", size: 16))
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: {
                            sharePDF()
                        }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Button(action: {
                            openInFiles()
                        }) {
                            Label("Open in Files", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                    }
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading PDF...")
                .font(.custom("FormaDJRDisplay-Regular", size: 16))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Failed to Load PDF")
                .font(.custom("FormaDJRDisplay-Medium", size: 20))
                .foregroundColor(.primary)

            Text(message)
                .font(.custom("FormaDJRDisplay-Regular", size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                isLoading = true
                loadError = nil
            }) {
                Text("Try Again")
                    .font(.custom("FormaDJRDisplay-Medium", size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func sharePDF() {
        let activityViewController = UIActivityViewController(
            activityItems: [pdfURL],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }

    private func openInFiles() {
        UIApplication.shared.open(pdfURL)
    }
}

// MARK: - PDFKit View Wrapper

struct PDFKitView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.backgroundColor = UIColor.systemGroupedBackground
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical

        // Load PDF
        loadPDF(into: pdfView)

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // No updates needed
    }

    private func loadPDF(into pdfView: PDFView) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Check if URL is a remote URL or local file
            if url.scheme == "http" || url.scheme == "https" {
                // Remote URL - download the PDF
                guard let pdfData = try? Data(contentsOf: url),
                      let document = PDFDocument(data: pdfData) else {
                    DispatchQueue.main.async {
                        isLoading = false
                        loadError = "Could not download or open the PDF file."
                    }
                    return
                }

                DispatchQueue.main.async {
                    pdfView.document = document
                    isLoading = false
                }
            } else {
                // Local file
                guard let document = PDFDocument(url: url) else {
                    DispatchQueue.main.async {
                        isLoading = false
                        loadError = "Could not open the PDF file."
                    }
                    return
                }

                DispatchQueue.main.async {
                    pdfView.document = document
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PDFViewerSheet(
        pdfURL: URL(string: "https://example.com/sample.pdf")!,
        courseName: "Computer Science 101"
    )
}
