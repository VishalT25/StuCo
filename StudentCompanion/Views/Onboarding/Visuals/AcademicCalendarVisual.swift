import SwiftUI

struct AcademicCalendarVisual: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 16) {
            // Calendar header
            HStack {
                Text("Fall 2026 Semester")
                    .font(.forma(.subheadline, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "calendar")
                    .foregroundColor(theme.primaryColor)
            }
            .padding(.horizontal, 4)

            // Timeline view
            VStack(spacing: 0) {
                // Semester start
                calendarEvent(
                    icon: "flag.fill",
                    title: "Semester Start",
                    date: "Sep 3",
                    color: .green,
                    isFirst: true
                )

                // Reading week
                calendarEvent(
                    icon: "book.closed.fill",
                    title: "Reading Week",
                    date: "Oct 14-20",
                    color: .blue,
                    isFirst: false
                )

                // Thanksgiving
                calendarEvent(
                    icon: "leaf.fill",
                    title: "Thanksgiving Break",
                    date: "Nov 27-29",
                    color: .orange,
                    isFirst: false
                )

                // Semester end
                calendarEvent(
                    icon: "checkmark.circle.fill",
                    title: "Semester End",
                    date: "Dec 20",
                    color: theme.primaryColor,
                    isFirst: false
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .frame(height: 300)
        .padding(.horizontal, 40)
    }

    private func calendarEvent(icon: String, title: String, date: String, color: Color, isFirst: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 2, height: 12)
                }

                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)

                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 2, height: 12)
            }

            // Event info
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.forma(.caption, weight: .semibold))
                    .foregroundColor(.white)

                Text(date)
                    .font(.forma(.caption2, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
    }
}

#Preview {
    AcademicCalendarVisual(theme: AppTheme.forest)
        .preferredColorScheme(.dark)
        .background(Color.black)
}
