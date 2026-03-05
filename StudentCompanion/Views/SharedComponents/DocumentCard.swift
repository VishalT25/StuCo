import SwiftUI

// MARK: - Document Card Component

struct DocumentCard: View {
    let document: CourseDocument
    let courseColor: Color
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Left: File type icon
                fileTypeIcon

                // Center: Document info
                VStack(alignment: .leading, spacing: 6) {
                    // Document name (2 lines max)
                    Text(document.name)
                        .font(.custom("FormaDJRText-Medium", size: 16))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // File type + size
                    Text("\(document.fileType.displayName) • \(document.formattedFileSize)")
                        .font(.custom("FormaDJRText-Regular", size: 13))
                        .foregroundColor(secondaryTextColor)

                    // Upload date
                    Text(document.relativeDateString)
                        .font(.custom("FormaDJRText-Regular", size: 12))
                        .foregroundColor(tertiaryTextColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tertiaryTextColor)
            }
            .padding(20)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(courseColor.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            Button(action: onTap) {
                Label("View Document", systemImage: "eye.fill")
            }

            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }

    // MARK: - File Type Icon

    @ViewBuilder
    private var fileTypeIcon: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(document.fileType.accentColor.opacity(0.15))
                .frame(width: 50, height: 50)

            // Icon
            Image(systemName: document.fileType.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(document.fileType.accentColor)
        }
    }

    // MARK: - Card Background

    @ViewBuilder
    private var cardBackground: some View {
        if colorScheme == .dark {
            Color.black.opacity(0.3)
                .background(.ultraThinMaterial)
        } else {
            Color.white.opacity(0.6)
                .background(.ultraThinMaterial)
        }
    }

    // MARK: - Text Colors

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }

    private var tertiaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.4)
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct DocumentCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            DocumentCard(
                document: CourseDocument(
                    courseId: UUID(),
                    userId: "user123",
                    name: "Introduction to Computer Science Syllabus.pdf",
                    fileType: .pdf,
                    fileSize: 2_450_000,
                    storagePath: "path/to/file"
                ),
                courseColor: .blue,
                onTap: {},
                onRename: {},
                onDelete: {}
            )

            DocumentCard(
                document: CourseDocument(
                    courseId: UUID(),
                    userId: "user123",
                    name: "Lecture Notes - Chapter 3.docx",
                    fileType: .word,
                    fileSize: 156_000,
                    storagePath: "path/to/file"
                ),
                courseColor: .green,
                onTap: {},
                onRename: {},
                onDelete: {}
            )

            DocumentCard(
                document: CourseDocument(
                    courseId: UUID(),
                    userId: "user123",
                    name: "Class Photo.jpg",
                    fileType: .image,
                    fileSize: 3_200_000,
                    storagePath: "path/to/file"
                ),
                courseColor: .purple,
                onTap: {},
                onRename: {},
                onDelete: {}
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .previewDisplayName("Document Cards")
    }
}
