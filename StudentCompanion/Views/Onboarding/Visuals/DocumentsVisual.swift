import SwiftUI

struct DocumentsVisual: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 16) {
            // Upload area
            VStack(spacing: 10) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(theme.primaryColor)

                Text("Upload Documents")
                    .font(.forma(.caption2, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Text("PDF, Images, Notes")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                            )
                            .foregroundColor(theme.primaryColor.opacity(0.3))
                    )
            )

            // Document list
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Your Documents")
                        .font(.forma(.caption, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text("4.2 MB / 50 MB")
                        .font(.forma(.caption2, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                documentRow(name: "Course Syllabus.pdf", size: "1.2 MB", icon: "doc.fill", color: .red)
                documentRow(name: "Lecture Notes.pdf", size: "2.1 MB", icon: "doc.text.fill", color: .blue)
                documentRow(name: "Assignment.pdf", size: "890 KB", icon: "doc.richtext.fill", color: .orange)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .frame(height: 300)
        .padding(.horizontal, 40)
    }

    private func documentRow(name: String, size: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(size)
                    .font(.forma(.caption2, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    DocumentsVisual(theme: AppTheme.forest)
        .preferredColorScheme(.dark)
        .background(Color.black)
}
