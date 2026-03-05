import SwiftUI

struct AICalendarImportVisual: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 16) {
            // Document mockup
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 110, height: 140)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 36))
                                .foregroundColor(theme.primaryColor)

                            Text("Syllabus")
                                .font(.forma(.caption, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))

                            // Mock highlighted text
                            VStack(spacing: 2) {
                                ForEach(0..<3) { _ in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.yellow.opacity(0.3))
                                        .frame(width: 70, height: 3)
                                }
                            }
                        }
                    )
            }

            // Arrow
            Image(systemName: "arrow.down")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(theme.primaryColor)

            // Extracted dates
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(theme.primaryColor)
                    Text("4 Dates Extracted")
                        .font(.forma(.caption, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 6) {
                    dateRow(icon: "flag.fill", text: "Sep 3 - Start", color: .green)
                    dateRow(icon: "book.closed.fill", text: "Oct 14 - Reading Week", color: .blue)
                    dateRow(icon: "leaf.fill", text: "Nov 27 - Thanksgiving", color: .orange)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .frame(height: 260)
        .padding(.horizontal, 40)
    }

    private func dateRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
                .frame(width: 16, height: 16)
                .background(
                    Circle()
                        .fill(color.opacity(0.2))
                )

            Text(text)
                .font(.forma(.caption2, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Spacer()
        }
    }
}

#Preview {
    AICalendarImportVisual(theme: AppTheme.forest)
        .preferredColorScheme(.dark)
        .background(Color.black)
}
