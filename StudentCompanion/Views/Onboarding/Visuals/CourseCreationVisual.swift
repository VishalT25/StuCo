import SwiftUI

struct CourseCreationVisual: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 16) {
            // Mock course header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.primaryColor.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: "book.fill")
                        .font(.system(size: 24))
                        .foregroundColor(theme.primaryColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("CS 101")
                        .font(.forma(.body, weight: .bold))
                        .foregroundColor(.white)
                    Text("Introduction to CS")
                        .font(.forma(.caption, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Color picker mockup
                Circle()
                    .fill(theme.primaryColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )

            // Meeting times
            VStack(alignment: .leading, spacing: 12) {
                Text("Meeting Times")
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))

                // Lecture
                meetingRow(type: "Lecture", days: "Mon, Wed", time: "9:00 - 10:30 AM", color: .blue)

                // Lab
                meetingRow(type: "Lab", days: "Friday", time: "2:00 - 4:00 PM", color: .green)

                // Tutorial
                meetingRow(type: "Tutorial", days: "Thursday", time: "11:00 AM - 12:00 PM", color: .orange)
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

    private func meetingRow(type: String, days: String, time: String, color: Color) -> some View {
        HStack(spacing: 10) {
            // Type badge
            Text(type)
                .font(.forma(.caption2, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(color.opacity(0.3))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(days)
                    .font(.forma(.caption, weight: .semibold))
                    .foregroundColor(.white)
                Text(time)
                    .font(.forma(.caption2, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
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
    CourseCreationVisual(theme: AppTheme.forest)
        .preferredColorScheme(.dark)
        .background(Color.black)
}
